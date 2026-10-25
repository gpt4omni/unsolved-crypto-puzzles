// p2wsh_2of2_pairs.cu -- engine #6: every ordered pair (i, j) of a set of public keys
// -> witness script  OP_2 <Ki> <Kj> OP_2 OP_CHECKMULTISIG  -> SHA-256 -> compare with up to 8
// target P2WSH witness programs (32 bytes). Generic: any puzzle whose escrow is a 2-of-2 P2WSH
// with enumerable keys can use it. Both key orders are covered by construction (ordered pairs),
// so BIP-67 sorted scripts are covered too.
//
//   p2wsh_2of2_pairs --keys K.bin --targets T.hex [--i0 A --i1 B] [--chunk 8192] [--out hits.txt]
//   p2wsh_2of2_pairs --bench N            (N random keys, 1 random target, N*N pairs)
//
// K.bin : N records of 66 bytes, [len (33|65)][65 bytes, zero padded].
// T.hex : up to 8 lines of 64 hex characters (witness program = sha256(script)).
// Output: "HIT i j t" on stdout (and in --out), progress on stderr, "DONE ..." at the end.
// Every hit must be re-derived on the CPU by the host driver before it is called a match.
//
// Build (native Blackwell): nvcc -ccbin g++-12 -O3 -arch=sm_120 -o p2wsh_2of2_pairs p2wsh_2of2_pairs.cu
// Build (JIT):              nvcc -O3 -gencode arch=compute_80,code=compute_80 -gencode arch=compute_90,code=compute_90 -o p2wsh_2of2_pairs p2wsh_2of2_pairs.cu
// Measured: 1.95e9 ordered pairs/s on an RTX 5080 (N = 447,922 keys, 2.0e11 pairs in 103 s, 2026-08-29).

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <vector>
#include <string>
#include <chrono>
#include <cuda_runtime.h>

#define REC 66
#define TI 16          // i-keys per block, held in shared memory
#define THREADS 256
#define MAXHITS 4096
#define MAXTGT 8

#define CK(x) do { cudaError_t e = (x); if (e != cudaSuccess) { \
    fprintf(stderr, "CUDA %s @%d: %s\n", #x, __LINE__, cudaGetErrorString(e)); exit(2);} } while (0)

__constant__ uint32_t c_tgt[MAXTGT][8];
__constant__ uint32_t c_ntgt;

__constant__ uint32_t K256[64] = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2 };

#define ROTR(x,n) (((x) >> (n)) | ((x) << (32 - (n))))
#define CH(x,y,z)  (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTR(x,2) ^ ROTR(x,13) ^ ROTR(x,22))
#define EP1(x) (ROTR(x,6) ^ ROTR(x,11) ^ ROTR(x,25))
#define SIG0(x) (ROTR(x,7) ^ ROTR(x,18) ^ ((x) >> 3))
#define SIG1(x) (ROTR(x,17) ^ ROTR(x,19) ^ ((x) >> 10))

__device__ __forceinline__ void sha256_compress(uint32_t s[8], const uint32_t blk[16]) {
    uint32_t W[16];
#pragma unroll
    for (int i = 0; i < 16; i++) W[i] = blk[i];
    uint32_t a=s[0],b=s[1],c=s[2],d=s[3],e=s[4],f=s[5],g=s[6],h=s[7];
#pragma unroll
    for (int i = 0; i < 64; i++) {
        if (i >= 16)
            W[i & 15] = SIG1(W[(i-2)&15]) + W[(i-7)&15] + SIG0(W[(i-15)&15]) + W[i&15];
        uint32_t t1 = h + EP1(e) + CH(e,f,g) + K256[i] + W[i&15];
        uint32_t t2 = EP0(a) + MAJ(a,b,c);
        h=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2;
    }
    s[0]+=a; s[1]+=b; s[2]+=c; s[3]+=d; s[4]+=e; s[5]+=f; s[6]+=g; s[7]+=h;
}

// SHA-256 of a message of L <= 192 bytes held in m[192] (padding is written here).
__device__ __forceinline__ void sha256_msg(uint8_t *m, int L, uint32_t out[8]) {
    uint32_t s[8] = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19};
    int total = ((L + 9 + 63) / 64) * 64;
    m[L] = 0x80;
    for (int i = L + 1; i < total - 8; i++) m[i] = 0;
    uint64_t bits = (uint64_t)L * 8;
    for (int i = 0; i < 8; i++) m[total - 1 - i] = (uint8_t)(bits >> (8 * i));
    for (int off = 0; off < total; off += 64) {
        uint32_t blk[16];
#pragma unroll
        for (int w = 0; w < 16; w++) {
            const uint8_t *p = m + off + 4 * w;
            blk[w] = ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
        }
        sha256_compress(s, blk);
    }
#pragma unroll
    for (int i = 0; i < 8; i++) out[i] = s[i];
}

__global__ void k_pairs(const uint8_t *__restrict__ keys, uint32_t N, uint32_t i0, uint32_t i1,
                        uint32_t *hits, uint32_t *nhits) {
    __shared__ uint8_t ski[TI][REC];
    uint32_t ibase = i0 + blockIdx.x * TI;
    if (ibase >= i1) return;
    for (int t = threadIdx.x; t < TI * REC; t += blockDim.x) {
        int a = t / REC, b = t % REC;
        uint32_t ii = ibase + a;
        ski[a][b] = (ii < i1) ? keys[(size_t)ii * REC + b] : 0;
    }
    __syncthreads();
    int ni = (i1 - ibase < TI) ? (int)(i1 - ibase) : TI;

    for (uint32_t j = threadIdx.x; j < N; j += blockDim.x) {
        uint8_t kj[REC];
        const uint8_t *pj = keys + (size_t)j * REC;
#pragma unroll
        for (int b = 0; b < REC; b++) kj[b] = __ldg(pj + b);
        int lj = kj[0];
        for (int a = 0; a < ni; a++) {
            int li = ski[a][0];
            uint8_t m[192];
            m[0] = 0x52; m[1] = (uint8_t)li;
            for (int b = 0; b < li; b++) m[2 + b] = ski[a][1 + b];
            m[2 + li] = (uint8_t)lj;
            for (int b = 0; b < lj; b++) m[3 + li + b] = kj[1 + b];
            m[3 + li + lj] = 0x52; m[4 + li + lj] = 0xae;
            int L = 5 + li + lj;
            uint32_t h[8];
            sha256_msg(m, L, h);
            for (uint32_t t = 0; t < c_ntgt; t++) {
                bool eq = true;
#pragma unroll
                for (int w = 0; w < 8; w++) eq &= (h[w] == c_tgt[t][w]);
                if (eq) {
                    uint32_t idx = atomicAdd(nhits, 1u);
                    if (idx < MAXHITS) { hits[idx*3] = ibase + a; hits[idx*3+1] = j; hits[idx*3+2] = t; }
                }
            }
        }
    }
}

static int hexval(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

int main(int argc, char **argv) {
    std::string keys_path, tgt_path, out_path;
    long long bench = 0; uint32_t i0 = 0, i1 = 0; uint32_t chunk = 8192;
    for (int a = 1; a < argc; a++) {
        std::string s = argv[a];
        if (s == "--keys" && a + 1 < argc) keys_path = argv[++a];
        else if (s == "--targets" && a + 1 < argc) tgt_path = argv[++a];
        else if (s == "--out" && a + 1 < argc) out_path = argv[++a];
        else if (s == "--bench" && a + 1 < argc) bench = atoll(argv[++a]);
        else if (s == "--i0" && a + 1 < argc) i0 = (uint32_t)atoll(argv[++a]);
        else if (s == "--i1" && a + 1 < argc) i1 = (uint32_t)atoll(argv[++a]);
        else if (s == "--chunk" && a + 1 < argc) chunk = (uint32_t)atoll(argv[++a]);
        else { fprintf(stderr, "unknown argument: %s\n", argv[a]); return 2; }
    }

    std::vector<uint8_t> keys; uint32_t N = 0;
    uint32_t tg[MAXTGT][8]; uint32_t ntgt = 0;
    if (bench > 0) {
        N = (uint32_t)bench; keys.assign((size_t)N * REC, 0);
        srand(12345);
        for (uint32_t i = 0; i < N; i++) {
            uint8_t *r = &keys[(size_t)i * REC]; r[0] = 33; r[1] = 2 + (rand() & 1);
            for (int b = 2; b < 34; b++) r[b] = (uint8_t)rand();
        }
        ntgt = 1; for (int w = 0; w < 8; w++) tg[0][w] = (uint32_t)rand() * 2654435761u;
    } else {
        if (keys_path.empty() || tgt_path.empty()) { fprintf(stderr, "usage: --keys K.bin --targets T.hex | --bench N\n"); return 2; }
        FILE *f = fopen(keys_path.c_str(), "rb"); if (!f) { perror("keys"); return 2; }
        fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
        if (sz % REC) { fprintf(stderr, "size %ld is not a multiple of %d\n", sz, REC); return 2; }
        N = (uint32_t)(sz / REC); keys.resize(sz);
        if (fread(keys.data(), 1, sz, f) != (size_t)sz) { fprintf(stderr, "read keys\n"); return 2; }
        fclose(f);
        FILE *t = fopen(tgt_path.c_str(), "r"); if (!t) { perror("targets"); return 2; }
        char line[256];
        while (fgets(line, sizeof line, t) && ntgt < MAXTGT) {
            std::string h; for (char *p = line; *p; p++) if (hexval(*p) >= 0) h.push_back(*p);
            if (h.size() != 64) continue;
            for (int w = 0; w < 8; w++) { uint32_t v = 0; for (int k = 0; k < 8; k++) v = (v << 4) | hexval(h[8*w+k]); tg[ntgt][w] = v; }
            ntgt++;
        }
        fclose(t);
        if (!ntgt) { fprintf(stderr, "no valid target\n"); return 2; }
    }
    if (i1 == 0 || i1 > N) i1 = N;
    if (i0 >= i1) { fprintf(stderr, "empty range\n"); return 2; }

    uint8_t *d_keys; uint32_t *d_hits, *d_nhits;
    CK(cudaMalloc(&d_keys, keys.size())); CK(cudaMemcpy(d_keys, keys.data(), keys.size(), cudaMemcpyHostToDevice));
    CK(cudaMalloc(&d_hits, MAXHITS * 3 * sizeof(uint32_t))); CK(cudaMalloc(&d_nhits, sizeof(uint32_t)));
    CK(cudaMemset(d_nhits, 0, sizeof(uint32_t)));
    CK(cudaMemcpyToSymbol(c_tgt, tg, sizeof(uint32_t) * 8 * ntgt));
    CK(cudaMemcpyToSymbol(c_ntgt, &ntgt, sizeof(uint32_t)));

    fprintf(stderr, "[p2wsh_2of2_pairs] N=%u targets=%u i-range=[%u,%u) pairs=%.3e\n", N, ntgt, i0, i1, (double)(i1 - i0) * N);
    auto t0 = std::chrono::steady_clock::now();
    double last_print = 0;
    for (uint32_t a = i0; a < i1; a += chunk) {
        uint32_t b = (a + chunk < i1) ? a + chunk : i1;
        uint32_t tiles = (b - a + TI - 1) / TI;
        k_pairs<<<tiles, THREADS>>>(d_keys, N, a, b, d_hits, d_nhits);
        CK(cudaGetLastError()); CK(cudaDeviceSynchronize());
        double secs = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
        if (secs - last_print >= 5.0 || b == i1) {
            double done = (double)(b - i0) * N;
            fprintf(stderr, "  i=%u/%u  %.3e pairs  %.1f s  %.3e pairs/s\n", b, i1, done, secs, done / secs);
            last_print = secs;
        }
    }
    double secs = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
    uint32_t nh = 0; CK(cudaMemcpy(&nh, d_nhits, sizeof(uint32_t), cudaMemcpyDeviceToHost));
    uint32_t nshow = nh < MAXHITS ? nh : MAXHITS;
    std::vector<uint32_t> hh(nshow * 3);
    if (nshow) CK(cudaMemcpy(hh.data(), d_hits, nshow * 3 * sizeof(uint32_t), cudaMemcpyDeviceToHost));
    FILE *fo = out_path.empty() ? nullptr : fopen(out_path.c_str(), "w");
    for (uint32_t k = 0; k < nshow; k++) {
        printf("HIT %u %u %u\n", hh[k*3], hh[k*3+1], hh[k*3+2]);
        if (fo) fprintf(fo, "HIT %u %u %u\n", hh[k*3], hh[k*3+1], hh[k*3+2]);
    }
    if (fo) fclose(fo);
    double pairs = (double)(i1 - i0) * N;
    printf("DONE pairs=%.0f secs=%.3f rate=%.3e hits=%u exhausted=%s\n", pairs, secs, pairs / secs, nh, (i0 == 0 && i1 == N) ? "yes" : "partial");
    return 0;
}
