/* ── CONTEXT ──
 * CONTEXT - Part of a PUBLIC cryptopuzzle-solving project (treasure hunt / CTF).
 * This engine is used ONLY against puzzle-reward addresses whose own author locked
 * and PUBLISHED them as an open challenge - never a third-party wallet or leaked key.
 * See CONTEXT.md at the repo root. Rule: zero false positives; funds verified on-chain.
 */
/*
 * arweave_var_engine.cu - CUDA engine for the Arweave Puzzle series,
 * variable-length passphrase variant (any concatenation of 1..6 slot
 * tokens, total length <= 111 bytes).
 *
 * Per-attempt pipeline (validated byte-for-byte against the live puzzle
 * pages' own client-side decoder and their test oracle):
 *
 *   passphrase P  = concatenation of the per-slot tokens (<= 111 ASCII bytes)
 *   1) SHA-512 chain : h = SHA512(P); repeat 11512x  h = SHA512(h)   (11513 total)
 *      keyhex = hex(h)  -> 128 ASCII chars (the AES "passphrase" string)
 *   2) OpenSSL EvpKDF (MD5, iterations=10000) over (keyhex[128 bytes], salt[8])
 *      -> 144 bytes = key(128) || iv(16).   CryptoJS quirk keySize=32 (#293).
 *   3) Rijndael with Nk=32, Nr=38 (generalised AES key schedule, SubWord when
 *      i%Nk==4 for Nk>6), CBC. Decrypt cipher block 0:  p0 = AESdec(C0) ^ iv.
 *   4) Success iff p0 starts with the JWK prefix  {"kty"  (full match on host).
 *
 * Reuse: the SHA-512 device core (K512 table, SHA512_ROUND/WSTEP macros,
 *   sha512_compress) is the SAME implementation shipped in
 *   bip39_passphrase_engine.cu in this directory. The 64-byte-in / 64-byte-out
 *   hot loop here uses a specialised single-block compressor (hardcoded
 *   padding), the same optimisation style as sha512_compress_hmac64 there.
 *
 * Cost model (dominant): 11513 sequential SHA-512 + 90000 sequential MD5 per
 *   attempt; the single AES block-0 decrypt is negligible. 1 thread = 1 attempt.
 *
 * NO BRUTE-FORCE IS LAUNCHED FROM HERE. The .so exposes:
 *   - arv_selftest()         : on-device validation of 1 known vector (host-fed)
 *   - arv_init(salt,c0)      : load 8-byte salt + 16-byte cipher block 0
 *   - arv_run_index_range()  : evaluate a contiguous mixed-radix index range
 *                               (the host streamer would call this; not invoked
 *                                by the self-test).
 *
 * Build: see build.sh (compiled to compute_80/90 PTX, JIT to the local GPU).
 */

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <cuda_runtime.h>

/* Threads-per-block the bench/range kernels are tuned for (launch_bounds).
 * PZL3_MINBLK = min blocks/SM hint; 0 = let ptxas use up to 255 regs (max
 * registers, lowest occupancy, zero spills - best for this latency-bound chain). */
#ifndef PZL3_BENCH_TPB
#define PZL3_BENCH_TPB 64
#endif
/* PZL3_MINBLK=6 is the measured RTX 5080 (sm_120) optimum: 254-reg/0-spill at
 * minblk<=5 underfills the SM (8 warps); forcing >=6 resident blocks trades a
 * few register spills for ~12 warps/SM and nets +2.2% on the latency-bound
 * SHA-512 chain. minblk>=7 over-spills and regresses. (Was 0 = max-reg, which is
 * optimal only for the older JIT-from-sm_90 build.) */
#ifndef PZL3_MINBLK
#define PZL3_MINBLK 6
#endif
#if PZL3_MINBLK > 0
#define PZL3_LB __launch_bounds__(PZL3_BENCH_TPB, PZL3_MINBLK)
#else
#define PZL3_LB __launch_bounds__(PZL3_BENCH_TPB)
#endif
/* Profiling knob only: number of MD5 re-hash iterations (default = correct 9999). */
#ifndef PZL3_MD5_ITERS
#define PZL3_MD5_ITERS 9999
#endif

/* ============================================================
 * PART 1: SHA-512 device core  (REUSED from bip39_passphrase_engine.cu)
 * ============================================================ */

__constant__ uint64_t K512[80] = {
    0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL, 0xe9b5dba58189dbbcULL,
    0x3956c25bf348b538ULL, 0x59f111f1b605d019ULL, 0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL,
    0xd807aa98a3030242ULL, 0x12835b0145706fbeULL, 0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL,
    0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL, 0xc19bf174cf692694ULL,
    0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL, 0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL,
    0x2de92c6f592b0275ULL, 0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL,
    0x983e5152ee66dfabULL, 0xa831c66d2db43210ULL, 0xb00327c898fb213fULL, 0xbf597fc7beef0ee4ULL,
    0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL, 0x06ca6351e003826fULL, 0x142929670a0e6e70ULL,
    0x27b70a8546d22ffcULL, 0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL, 0x53380d139d95b3dfULL,
    0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL, 0x92722c851482353bULL,
    0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL, 0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL,
    0xd192e819d6ef5218ULL, 0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL,
    0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL, 0x2748774cdf8eeb99ULL, 0x34b0bcb5e19b48a8ULL,
    0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL, 0x5b9cca4f7763e373ULL, 0x682e6ff3d6b2b8a3ULL,
    0x748f82ee5defb2fcULL, 0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
    0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL, 0xc67178f2e372532bULL,
    0xca273eceea26619cULL, 0xd186b8c721c0c207ULL, 0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL,
    0x06f067aa72176fbaULL, 0x0a637dc5a2c898a6ULL, 0x113f9804bef90daeULL, 0x1b710b35131c471bULL,
    0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL, 0x431d67c49c100d4cULL,
    0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL, 0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL
};

#define SHA512_H0 0x6a09e667f3bcc908ULL
#define SHA512_H1 0xbb67ae8584caa73bULL
#define SHA512_H2 0x3c6ef372fe94f82bULL
#define SHA512_H3 0xa54ff53a5f1d36f1ULL
#define SHA512_H4 0x510e527fade682d1ULL
#define SHA512_H5 0x9b05688c2b3e6c1fULL
#define SHA512_H6 0x1f83d9abfb41bd6bULL
#define SHA512_H7 0x5be0cd19137e2179ULL

#define ROTR64(x,n) (((x)>>(n))|((x)<<(64-(n))))
#define CH64(x,y,z) (((x)&(y))^(~(x)&(z)))
#define MAJ64(x,y,z) (((x)&(y))^((x)&(z))^((y)&(z)))
#define EP064(x) (ROTR64(x,28)^ROTR64(x,34)^ROTR64(x,39))
#define EP164(x) (ROTR64(x,14)^ROTR64(x,18)^ROTR64(x,41))
#define SIG064(x) (ROTR64(x,1)^ROTR64(x,8)^((x)>>7))
#define SIG164(x) (ROTR64(x,19)^ROTR64(x,61)^((x)>>6))

#define SHA512_ROUND(a,b,c,d,e,f,g,h,Wi,Ki) do { \
    uint64_t t1 = (h) + EP164(e) + CH64(e,f,g) + (Ki) + (Wi); \
    uint64_t t2 = EP064(a) + MAJ64(a,b,c); \
    (h) = (g); (g) = (f); (f) = (e); (e) = (d) + t1; \
    (d) = (c); (c) = (b); (b) = (a); (a) = t1 + t2; \
} while(0)

#define SHA512_WSTEP(W, i) \
    W[(i) & 15] = SIG164(W[((i) - 2) & 15]) + W[((i) - 7) & 15] \
                + SIG064(W[((i) - 15) & 15]) + W[(i) & 15]

/* Generic single-block compression (matches bip39 engine sha512_compress). */
__device__ __forceinline__ void sha512_compress(uint64_t state[8], const uint64_t block[16]) {
    uint64_t W[16];
    #pragma unroll
    for (int i = 0; i < 16; i++) W[i] = block[i];
    uint64_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint64_t e = state[4], f = state[5], g = state[6], h = state[7];
    #pragma unroll
    for (int i = 0; i < 16; i++) SHA512_ROUND(a,b,c,d,e,f,g,h, W[i], K512[i]);
    #pragma unroll
    for (int i = 16; i < 80; i++) { SHA512_WSTEP(W, i); SHA512_ROUND(a,b,c,d,e,f,g,h, W[i & 15], K512[i]); }
    state[0]+=a; state[1]+=b; state[2]+=c; state[3]+=d;
    state[4]+=e; state[5]+=f; state[6]+=g; state[7]+=h;
}

/*
 * sha512_chain64 - the hot inner loop.
 * Input  state8[8] holds a 64-byte message (8 big-endian words) = digest_i.
 * Computes SHA512 of those 64 bytes and overwrites state8 with digest_{i+1}.
 * Block is fixed: msg[0..7] || 0x80.. || zeros || bitlen=512. Same trick as
 * sha512_compress_hmac64 (here bitlen=512 because the message is 64 bytes).
 */
/*
 * Specialised 64-byte compressor for the chain (digest_i -> digest_{i+1}).
 * The message is exactly io[0..7] then fixed padding: W[8]=0x80<<56, W[9..14]=0,
 * W[15]=512. We keep W in 16 registers (ring buffer) and constant-fold the known
 * padding words so ptxas drops the dead adds in the early schedule steps. The IV
 * (H0..H7) is constant so round 0's t1/t2 fold to a few ops. Unroll all 80 rounds
 * fully (W lives entirely in registers - no local-memory schedule array).
 */
__device__ __forceinline__ void sha512_round64(uint64_t io[8]) {
    uint64_t W[16];
    W[0]=io[0]; W[1]=io[1]; W[2]=io[2]; W[3]=io[3];
    W[4]=io[4]; W[5]=io[5]; W[6]=io[6]; W[7]=io[7];
    W[8]=0x8000000000000000ULL;
    W[9]=0; W[10]=0; W[11]=0; W[12]=0; W[13]=0; W[14]=0;
    W[15]=512ULL;
    uint64_t a=SHA512_H0,b=SHA512_H1,c=SHA512_H2,d=SHA512_H3,
             e=SHA512_H4,f=SHA512_H5,g=SHA512_H6,h=SHA512_H7;
    #pragma unroll
    for (int i = 0; i < 16; i++) SHA512_ROUND(a,b,c,d,e,f,g,h, W[i], K512[i]);
    #pragma unroll
    for (int i = 16; i < 80; i++) { SHA512_WSTEP(W, i); SHA512_ROUND(a,b,c,d,e,f,g,h, W[i & 15], K512[i]); }
    io[0]=SHA512_H0+a; io[1]=SHA512_H1+b; io[2]=SHA512_H2+c; io[3]=SHA512_H3+d;
    io[4]=SHA512_H4+e; io[5]=SHA512_H5+f; io[6]=SHA512_H6+g; io[7]=SHA512_H7+h;
}

/* First hash: SHA512 of the 32-byte passphrase P (single block, len=32). */

/* Variable-length first SHA-512 block (len <= 111 so message+pad+len fit one
 * 128-byte block).  Generalisation of sha512_first32 for the arweave-var engine. */
__device__ __forceinline__ void sha512_first_var(const uint8_t *p, int len, uint64_t io[8]) {
    uint8_t buf[128];
    #pragma unroll 1
    for (int i = 0; i < 128; i++) buf[i] = 0;
    #pragma unroll 1
    for (int i = 0; i < len; i++) buf[i] = p[i];
    buf[len] = 0x80;
    uint64_t bits = (uint64_t)len * 8ULL;
    buf[120] = (uint8_t)(bits >> 56); buf[121] = (uint8_t)(bits >> 48);
    buf[122] = (uint8_t)(bits >> 40); buf[123] = (uint8_t)(bits >> 32);
    buf[124] = (uint8_t)(bits >> 24); buf[125] = (uint8_t)(bits >> 16);
    buf[126] = (uint8_t)(bits >>  8); buf[127] = (uint8_t)(bits);
    uint64_t block[16];
    #pragma unroll
    for (int i = 0; i < 16; i++) {
        block[i] = ((uint64_t)buf[i*8]<<56)|((uint64_t)buf[i*8+1]<<48)|((uint64_t)buf[i*8+2]<<40)|
                   ((uint64_t)buf[i*8+3]<<32)|((uint64_t)buf[i*8+4]<<24)|((uint64_t)buf[i*8+5]<<16)|
                   ((uint64_t)buf[i*8+6]<<8)|((uint64_t)buf[i*8+7]);
    }
    uint64_t s[8] = { SHA512_H0,SHA512_H1,SHA512_H2,SHA512_H3,
                      SHA512_H4,SHA512_H5,SHA512_H6,SHA512_H7 };
    sha512_compress(s, block);
    #pragma unroll
    for (int i = 0; i < 8; i++) io[i] = s[i];
}

__device__ __forceinline__ void sha512_first32(const uint8_t p[32], uint64_t io[8]) {
    uint64_t block[16];
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        block[i] = ((uint64_t)p[i*8]<<56)|((uint64_t)p[i*8+1]<<48)|((uint64_t)p[i*8+2]<<40)|
                   ((uint64_t)p[i*8+3]<<32)|((uint64_t)p[i*8+4]<<24)|((uint64_t)p[i*8+5]<<16)|
                   ((uint64_t)p[i*8+6]<<8)|((uint64_t)p[i*8+7]);
    }
    block[4]  = 0x8000000000000000ULL;  /* 0x80 right after 32 message bytes */
    block[5]=0; block[6]=0; block[7]=0; block[8]=0; block[9]=0;
    block[10]=0; block[11]=0; block[12]=0; block[13]=0; block[14]=0;
    block[15] = 256ULL;                 /* 32 bytes * 8 bits */
    uint64_t s[8] = { SHA512_H0,SHA512_H1,SHA512_H2,SHA512_H3,
                      SHA512_H4,SHA512_H5,SHA512_H6,SHA512_H7 };
    sha512_compress(s, block);
    #pragma unroll
    for (int i = 0; i < 8; i++) io[i] = s[i];
}

/* ============================================================
 * PART 2: MD5 device core (for OpenSSL EvpKDF)
 * ============================================================ */

/* "saves-an-op" round-function forms (hashcat OpenCL/inc_hash_md5.h). nvcc fuses
 * each into a single LOP3.LUT on sm_50+; the algebraic identities below give it
 * the cleanest 3-input boolean to fold. */
#define MD5_F(x,y,z) ((z)^((x)&((y)^(z))))      /* (b&c)|(~b&d) */
#define MD5_G(x,y,z) ((y)^((z)&((x)^(y))))      /* (b&d)|(c&~d) */
#define MD5_H(x,y,z) ((x)^(y)^(z))
#define MD5_I(x,y,z) ((y)^((x)|~(z)))
#define ROTL32(x,n) (((x)<<(n))|((x)>>(32-(n))))
#define MD5_STEP(f,a,b,c,d,x,t,s) do { \
    (a) += f((b),(c),(d)) + (x) + (t); (a) = ROTL32((a),(s)) + (b); } while(0)
/* STEP0: message word is 0 (or its constant has been folded into t). Drops the
 * +x operand from the IADD3, used for the 48 foldable steps of a fixed 16-byte
 * message MD5 (M[4]=0x80, M[5..13]=0, M[14]=128, M[15]=0). */
#define MD5_STEP0(f,a,b,c,d,t,s) do { \
    (a) += f((b),(c),(d)) + (t); (a) = ROTL32((a),(s)) + (b); } while(0)

/* MD5 of a single 64-byte block already laid out as 16 little-endian words.
 * Initial state passed in/out via abcd[4] so the caller controls padding. */
__device__ __forceinline__ void md5_block(uint32_t abcd[4], const uint32_t M[16]) {
    uint32_t a=abcd[0], b=abcd[1], c=abcd[2], d=abcd[3];
    /* Round 1 */
    MD5_STEP(MD5_F,a,b,c,d,M[ 0],0xd76aa478, 7); MD5_STEP(MD5_F,d,a,b,c,M[ 1],0xe8c7b756,12);
    MD5_STEP(MD5_F,c,d,a,b,M[ 2],0x242070db,17); MD5_STEP(MD5_F,b,c,d,a,M[ 3],0xc1bdceee,22);
    MD5_STEP(MD5_F,a,b,c,d,M[ 4],0xf57c0faf, 7); MD5_STEP(MD5_F,d,a,b,c,M[ 5],0x4787c62a,12);
    MD5_STEP(MD5_F,c,d,a,b,M[ 6],0xa8304613,17); MD5_STEP(MD5_F,b,c,d,a,M[ 7],0xfd469501,22);
    MD5_STEP(MD5_F,a,b,c,d,M[ 8],0x698098d8, 7); MD5_STEP(MD5_F,d,a,b,c,M[ 9],0x8b44f7af,12);
    MD5_STEP(MD5_F,c,d,a,b,M[10],0xffff5bb1,17); MD5_STEP(MD5_F,b,c,d,a,M[11],0x895cd7be,22);
    MD5_STEP(MD5_F,a,b,c,d,M[12],0x6b901122, 7); MD5_STEP(MD5_F,d,a,b,c,M[13],0xfd987193,12);
    MD5_STEP(MD5_F,c,d,a,b,M[14],0xa679438e,17); MD5_STEP(MD5_F,b,c,d,a,M[15],0x49b40821,22);
    /* Round 2 */
    MD5_STEP(MD5_G,a,b,c,d,M[ 1],0xf61e2562, 5); MD5_STEP(MD5_G,d,a,b,c,M[ 6],0xc040b340, 9);
    MD5_STEP(MD5_G,c,d,a,b,M[11],0x265e5a51,14); MD5_STEP(MD5_G,b,c,d,a,M[ 0],0xe9b6c7aa,20);
    MD5_STEP(MD5_G,a,b,c,d,M[ 5],0xd62f105d, 5); MD5_STEP(MD5_G,d,a,b,c,M[10],0x02441453, 9);
    MD5_STEP(MD5_G,c,d,a,b,M[15],0xd8a1e681,14); MD5_STEP(MD5_G,b,c,d,a,M[ 4],0xe7d3fbc8,20);
    MD5_STEP(MD5_G,a,b,c,d,M[ 9],0x21e1cde6, 5); MD5_STEP(MD5_G,d,a,b,c,M[14],0xc33707d6, 9);
    MD5_STEP(MD5_G,c,d,a,b,M[ 3],0xf4d50d87,14); MD5_STEP(MD5_G,b,c,d,a,M[ 8],0x455a14ed,20);
    MD5_STEP(MD5_G,a,b,c,d,M[13],0xa9e3e905, 5); MD5_STEP(MD5_G,d,a,b,c,M[ 2],0xfcefa3f8, 9);
    MD5_STEP(MD5_G,c,d,a,b,M[ 7],0x676f02d9,14); MD5_STEP(MD5_G,b,c,d,a,M[12],0x8d2a4c8a,20);
    /* Round 3 */
    MD5_STEP(MD5_H,a,b,c,d,M[ 5],0xfffa3942, 4); MD5_STEP(MD5_H,d,a,b,c,M[ 8],0x8771f681,11);
    MD5_STEP(MD5_H,c,d,a,b,M[11],0x6d9d6122,16); MD5_STEP(MD5_H,b,c,d,a,M[14],0xfde5380c,23);
    MD5_STEP(MD5_H,a,b,c,d,M[ 1],0xa4beea44, 4); MD5_STEP(MD5_H,d,a,b,c,M[ 4],0x4bdecfa9,11);
    MD5_STEP(MD5_H,c,d,a,b,M[ 7],0xf6bb4b60,16); MD5_STEP(MD5_H,b,c,d,a,M[10],0xbebfbc70,23);
    MD5_STEP(MD5_H,a,b,c,d,M[13],0x289b7ec6, 4); MD5_STEP(MD5_H,d,a,b,c,M[ 0],0xeaa127fa,11);
    MD5_STEP(MD5_H,c,d,a,b,M[ 3],0xd4ef3085,16); MD5_STEP(MD5_H,b,c,d,a,M[ 6],0x04881d05,23);
    MD5_STEP(MD5_H,a,b,c,d,M[ 9],0xd9d4d039, 4); MD5_STEP(MD5_H,d,a,b,c,M[12],0xe6db99e5,11);
    MD5_STEP(MD5_H,c,d,a,b,M[15],0x1fa27cf8,16); MD5_STEP(MD5_H,b,c,d,a,M[ 2],0xc4ac5665,23);
    /* Round 4 */
    MD5_STEP(MD5_I,a,b,c,d,M[ 0],0xf4292244, 6); MD5_STEP(MD5_I,d,a,b,c,M[ 7],0x432aff97,10);
    MD5_STEP(MD5_I,c,d,a,b,M[14],0xab9423a7,15); MD5_STEP(MD5_I,b,c,d,a,M[ 5],0xfc93a039,21);
    MD5_STEP(MD5_I,a,b,c,d,M[12],0x655b59c3, 6); MD5_STEP(MD5_I,d,a,b,c,M[ 3],0x8f0ccc92,10);
    MD5_STEP(MD5_I,c,d,a,b,M[10],0xffeff47d,15); MD5_STEP(MD5_I,b,c,d,a,M[ 1],0x85845dd1,21);
    MD5_STEP(MD5_I,a,b,c,d,M[ 8],0x6fa87e4f, 6); MD5_STEP(MD5_I,d,a,b,c,M[15],0xfe2ce6e0,10);
    MD5_STEP(MD5_I,c,d,a,b,M[ 6],0xa3014314,15); MD5_STEP(MD5_I,b,c,d,a,M[13],0x4e0811a1,21);
    MD5_STEP(MD5_I,a,b,c,d,M[ 4],0xf7537e82, 6); MD5_STEP(MD5_I,d,a,b,c,M[11],0xbd3af235,10);
    MD5_STEP(MD5_I,c,d,a,b,M[ 2],0x2ad7d2bb,15); MD5_STEP(MD5_I,b,c,d,a,M[ 9],0xeb86d391,21);
    abcd[0]+=a; abcd[1]+=b; abcd[2]+=c; abcd[3]+=d;
}

/* MD5 of an exactly-16-byte message held as 4 little-endian words (= the digest
 * words of the previous MD5). Returns the 4 result words. This is the register-
 * native form of md5_16 used by the 9999-iter EvpKDF inner loop: it avoids the
 * word<->byte round-trip every iteration (the 16 input bytes ARE the LE bytes of
 * abcd[0..3], so M[0..3] = the words verbatim). */
__device__ __forceinline__ void md5_16_words(uint32_t w0, uint32_t w1, uint32_t w2, uint32_t w3,
                                             uint32_t out[4]) {
    /* Fully constant-folded MD5 of a fixed 16-byte message: only M[0..3] vary;
     * M[4]=0x80, M[5..13]=0, M[14]=128, M[15]=0. Of the 64 steps, 48 reference a
     * zero/constant message word, so they use MD5_STEP0 (no +x add) with the 0x80
     * constant folded into the round constant where applicable (8 steps). This
     * removes ~48 IADD3 message operands and the whole M[16] schedule array from
     * the 90000-iters/attempt EvpKDF inner loop. Round vars start at the MD5 IV. */
    const uint32_t M0=w0, M1=w1, M2=w2, M3=w3;
    uint32_t a=0x67452301u, b=0xefcdab89u, c=0x98badcfeu, d=0x10325476u;
    MD5_STEP(MD5_F,a,b,c,d,M0,0xd76aa478u,7);
    MD5_STEP(MD5_F,d,a,b,c,M1,0xe8c7b756u,12);
    MD5_STEP(MD5_F,c,d,a,b,M2,0x242070dbu,17);
    MD5_STEP(MD5_F,b,c,d,a,M3,0xc1bdceeeu,22);
    MD5_STEP0(MD5_F,a,b,c,d,0xf57c102fu,7);  /* M[4]=0x80 folded */
    MD5_STEP0(MD5_F,d,a,b,c,0x4787c62au,12);
    MD5_STEP0(MD5_F,c,d,a,b,0xa8304613u,17);
    MD5_STEP0(MD5_F,b,c,d,a,0xfd469501u,22);
    MD5_STEP0(MD5_F,a,b,c,d,0x698098d8u,7);
    MD5_STEP0(MD5_F,d,a,b,c,0x8b44f7afu,12);
    MD5_STEP0(MD5_F,c,d,a,b,0xffff5bb1u,17);
    MD5_STEP0(MD5_F,b,c,d,a,0x895cd7beu,22);
    MD5_STEP0(MD5_F,a,b,c,d,0x6b901122u,7);
    MD5_STEP0(MD5_F,d,a,b,c,0xfd987193u,12);
    MD5_STEP0(MD5_F,c,d,a,b,0xa679440eu,17);  /* M[14]=0x80 folded */
    MD5_STEP0(MD5_F,b,c,d,a,0x49b40821u,22);
    MD5_STEP(MD5_G,a,b,c,d,M1,0xf61e2562u,5);
    MD5_STEP0(MD5_G,d,a,b,c,0xc040b340u,9);
    MD5_STEP0(MD5_G,c,d,a,b,0x265e5a51u,14);
    MD5_STEP(MD5_G,b,c,d,a,M0,0xe9b6c7aau,20);
    MD5_STEP0(MD5_G,a,b,c,d,0xd62f105du,5);
    MD5_STEP0(MD5_G,d,a,b,c,0x02441453u,9);
    MD5_STEP0(MD5_G,c,d,a,b,0xd8a1e681u,14);
    MD5_STEP0(MD5_G,b,c,d,a,0xe7d3fc48u,20);  /* M[4]=0x80 folded */
    MD5_STEP0(MD5_G,a,b,c,d,0x21e1cde6u,5);
    MD5_STEP0(MD5_G,d,a,b,c,0xc3370856u,9);  /* M[14]=0x80 folded */
    MD5_STEP(MD5_G,c,d,a,b,M3,0xf4d50d87u,14);
    MD5_STEP0(MD5_G,b,c,d,a,0x455a14edu,20);
    MD5_STEP0(MD5_G,a,b,c,d,0xa9e3e905u,5);
    MD5_STEP(MD5_G,d,a,b,c,M2,0xfcefa3f8u,9);
    MD5_STEP0(MD5_G,c,d,a,b,0x676f02d9u,14);
    MD5_STEP0(MD5_G,b,c,d,a,0x8d2a4c8au,20);
    MD5_STEP0(MD5_H,a,b,c,d,0xfffa3942u,4);
    MD5_STEP0(MD5_H,d,a,b,c,0x8771f681u,11);
    MD5_STEP0(MD5_H,c,d,a,b,0x6d9d6122u,16);
    MD5_STEP0(MD5_H,b,c,d,a,0xfde5388cu,23);  /* M[14]=0x80 folded */
    MD5_STEP(MD5_H,a,b,c,d,M1,0xa4beea44u,4);
    MD5_STEP0(MD5_H,d,a,b,c,0x4bded029u,11);  /* M[4]=0x80 folded */
    MD5_STEP0(MD5_H,c,d,a,b,0xf6bb4b60u,16);
    MD5_STEP0(MD5_H,b,c,d,a,0xbebfbc70u,23);
    MD5_STEP0(MD5_H,a,b,c,d,0x289b7ec6u,4);
    MD5_STEP(MD5_H,d,a,b,c,M0,0xeaa127fau,11);
    MD5_STEP(MD5_H,c,d,a,b,M3,0xd4ef3085u,16);
    MD5_STEP0(MD5_H,b,c,d,a,0x04881d05u,23);
    MD5_STEP0(MD5_H,a,b,c,d,0xd9d4d039u,4);
    MD5_STEP0(MD5_H,d,a,b,c,0xe6db99e5u,11);
    MD5_STEP0(MD5_H,c,d,a,b,0x1fa27cf8u,16);
    MD5_STEP(MD5_H,b,c,d,a,M2,0xc4ac5665u,23);
    MD5_STEP(MD5_I,a,b,c,d,M0,0xf4292244u,6);
    MD5_STEP0(MD5_I,d,a,b,c,0x432aff97u,10);
    MD5_STEP0(MD5_I,c,d,a,b,0xab942427u,15);  /* M[14]=0x80 folded */
    MD5_STEP0(MD5_I,b,c,d,a,0xfc93a039u,21);
    MD5_STEP0(MD5_I,a,b,c,d,0x655b59c3u,6);
    MD5_STEP(MD5_I,d,a,b,c,M3,0x8f0ccc92u,10);
    MD5_STEP0(MD5_I,c,d,a,b,0xffeff47du,15);
    MD5_STEP(MD5_I,b,c,d,a,M1,0x85845dd1u,21);
    MD5_STEP0(MD5_I,a,b,c,d,0x6fa87e4fu,6);
    MD5_STEP0(MD5_I,d,a,b,c,0xfe2ce6e0u,10);
    MD5_STEP0(MD5_I,c,d,a,b,0xa3014314u,15);
    MD5_STEP0(MD5_I,b,c,d,a,0x4e0811a1u,21);
    MD5_STEP0(MD5_I,a,b,c,d,0xf7537f02u,6);  /* M[4]=0x80 folded */
    MD5_STEP0(MD5_I,d,a,b,c,0xbd3af235u,10);
    MD5_STEP(MD5_I,c,d,a,b,M2,0x2ad7d2bbu,15);
    MD5_STEP0(MD5_I,b,c,d,a,0xeb86d391u,21);
    out[0]=a+0x67452301u; out[1]=b+0xefcdab89u; out[2]=c+0x98badcfeu; out[3]=d+0x10325476u;
}

/* MD5 of an exactly-16-byte message (one padded block). Used by the EvpKDF
 * inner re-hash loop (a = MD5(a), a is always 16 bytes). */
__device__ __forceinline__ void md5_16(const uint8_t in[16], uint8_t out[16]) {
    uint32_t M[16];
    #pragma unroll
    for (int i = 0; i < 4; i++)
        M[i] = (uint32_t)in[i*4] | ((uint32_t)in[i*4+1]<<8) | ((uint32_t)in[i*4+2]<<16) | ((uint32_t)in[i*4+3]<<24);
    M[4] = 0x80;            /* 0x80 after 16 message bytes */
    #pragma unroll
    for (int i = 5; i < 14; i++) M[i] = 0;
    M[14] = 128;            /* 16 bytes * 8 bits, low word */
    M[15] = 0;
    uint32_t abcd[4] = {0x67452301u,0xefcdab89u,0x98badcfeu,0x10325476u};
    md5_block(abcd, M);
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        out[i*4]   = (uint8_t)(abcd[i]);
        out[i*4+1] = (uint8_t)(abcd[i]>>8);
        out[i*4+2] = (uint8_t)(abcd[i]>>16);
        out[i*4+3] = (uint8_t)(abcd[i]>>24);
    }
}

/*
 * md5_var - general MD5 over a multi-block message held in a byte buffer.
 * Used for the FIRST MD5 of each EvpKDF block: MD5(prev[0|16] || keyhex[128] || salt[8]).
 * Total length = (prev) + 128 + 8 = 136 or 152 bytes -> 3 blocks (with padding).
 */
__device__ void md5_var(const uint8_t *msg, int len, uint8_t out[16]) {
    uint32_t abcd[4] = {0x67452301u,0xefcdab89u,0x98badcfeu,0x10325476u};
    /* padded length */
    int total = ((len + 9 + 63) / 64) * 64;
    uint8_t buf[192];   /* >= max 152+padding */
    for (int i = 0; i < len; i++) buf[i] = msg[i];
    buf[len] = 0x80;
    for (int i = len + 1; i < total; i++) buf[i] = 0;
    uint64_t bits = (uint64_t)len * 8;
    for (int i = 0; i < 8; i++) buf[total - 8 + i] = (uint8_t)(bits >> (8*i));
    for (int off = 0; off < total; off += 64) {
        uint32_t M[16];
        #pragma unroll
        for (int i = 0; i < 16; i++)
            M[i] = (uint32_t)buf[off+i*4] | ((uint32_t)buf[off+i*4+1]<<8) |
                   ((uint32_t)buf[off+i*4+2]<<16) | ((uint32_t)buf[off+i*4+3]<<24);
        md5_block(abcd, M);
    }
    out[0]=(uint8_t)abcd[0]; out[1]=(uint8_t)(abcd[0]>>8); out[2]=(uint8_t)(abcd[0]>>16); out[3]=(uint8_t)(abcd[0]>>24);
    out[4]=(uint8_t)abcd[1]; out[5]=(uint8_t)(abcd[1]>>8); out[6]=(uint8_t)(abcd[1]>>16); out[7]=(uint8_t)(abcd[1]>>24);
    out[8]=(uint8_t)abcd[2]; out[9]=(uint8_t)(abcd[2]>>8); out[10]=(uint8_t)(abcd[2]>>16); out[11]=(uint8_t)(abcd[2]>>24);
    out[12]=(uint8_t)abcd[3]; out[13]=(uint8_t)(abcd[3]>>8); out[14]=(uint8_t)(abcd[3]>>16); out[15]=(uint8_t)(abcd[3]>>24);
}

/* ============================================================
 * PART 3: AES (Rijndael) inverse cipher, Nk=32 / Nr=38 quirk
 * ============================================================ */

/* AES inverse S-box in constant memory. */
__constant__ uint8_t INV_SBOX[256] = {
0x52,0x09,0x6a,0xd5,0x30,0x36,0xa5,0x38,0xbf,0x40,0xa3,0x9e,0x81,0xf3,0xd7,0xfb,
0x7c,0xe3,0x39,0x82,0x9b,0x2f,0xff,0x87,0x34,0x8e,0x43,0x44,0xc4,0xde,0xe9,0xcb,
0x54,0x7b,0x94,0x32,0xa6,0xc2,0x23,0x3d,0xee,0x4c,0x95,0x0b,0x42,0xfa,0xc3,0x4e,
0x08,0x2e,0xa1,0x66,0x28,0xd9,0x24,0xb2,0x76,0x5b,0xa2,0x49,0x6d,0x8b,0xd1,0x25,
0x72,0xf8,0xf6,0x64,0x86,0x68,0x98,0x16,0xd4,0xa4,0x5c,0xcc,0x5d,0x65,0xb6,0x92,
0x6c,0x70,0x48,0x50,0xfd,0xed,0xb9,0xda,0x5e,0x15,0x46,0x57,0xa7,0x8d,0x9d,0x84,
0x90,0xd8,0xab,0x00,0x8c,0xbc,0xd3,0x0a,0xf7,0xe4,0x58,0x05,0xb8,0xb3,0x45,0x06,
0xd0,0x2c,0x1e,0x8f,0xca,0x3f,0x0f,0x02,0xc1,0xaf,0xbd,0x03,0x01,0x13,0x8a,0x6b,
0x3a,0x91,0x11,0x41,0x4f,0x67,0xdc,0xea,0x97,0xf2,0xcf,0xce,0xf0,0xb4,0xe6,0x73,
0x96,0xac,0x74,0x22,0xe7,0xad,0x35,0x85,0xe2,0xf9,0x37,0xe8,0x1c,0x75,0xdf,0x6e,
0x47,0xf1,0x1a,0x71,0x1d,0x29,0xc5,0x89,0x6f,0xb7,0x62,0x0e,0xaa,0x18,0xbe,0x1b,
0xfc,0x56,0x3e,0x4b,0xc6,0xd2,0x79,0x20,0x9a,0xdb,0xc0,0xfe,0x78,0xcd,0x5a,0xf4,
0x1f,0xdd,0xa8,0x33,0x88,0x07,0xc7,0x31,0xb1,0x12,0x10,0x59,0x27,0x80,0xec,0x5f,
0x60,0x51,0x7f,0xa9,0x19,0xb5,0x4a,0x0d,0x2d,0xe5,0x7a,0x9f,0x93,0xc9,0x9c,0xef,
0xa0,0xe0,0x3b,0x4d,0xae,0x2a,0xf5,0xb0,0xc8,0xeb,0xbb,0x3c,0x83,0x53,0x99,0x61,
0x17,0x2b,0x04,0x7e,0xba,0x77,0xd6,0x26,0xe1,0x69,0x14,0x63,0x55,0x21,0x0c,0x7d
};
/* AES forward S-box (needed only by the key schedule SubWord). */
__constant__ uint8_t FWD_SBOX[256] = {
0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16
};

#define AES_NK 32
#define AES_NR 38
#define AES_NWORDS (4*(AES_NR+1))   /* 156 round-key words */

__device__ __forceinline__ uint32_t aes_subword(uint32_t w) {
    return ((uint32_t)FWD_SBOX[(w>>24)&0xff]<<24) | ((uint32_t)FWD_SBOX[(w>>16)&0xff]<<16) |
           ((uint32_t)FWD_SBOX[(w>>8)&0xff]<<8)   |  (uint32_t)FWD_SBOX[w&0xff];
}
__device__ __forceinline__ uint32_t aes_rotword(uint32_t w) { return (w<<8)|(w>>24); }

/* rcon: rcon[j] used at i%Nk==0, j = i/Nk - 1. xtime chain. */
__device__ __forceinline__ uint8_t aes_xtime(uint8_t x){ return (uint8_t)((x<<1) ^ ((x>>7)*0x1b)); }

/* Expand a 128-byte key into AES_NWORDS round-key words (CryptoJS _doReset). */
__device__ void aes_key_expansion(const uint8_t key[128], uint32_t w[AES_NWORDS]) {
    #pragma unroll
    for (int i = 0; i < AES_NK; i++)
        w[i] = ((uint32_t)key[4*i]<<24)|((uint32_t)key[4*i+1]<<16)|((uint32_t)key[4*i+2]<<8)|key[4*i+3];
    uint8_t rc = 1;          /* rcon for the first i%Nk==0 (j=0) */
    for (int i = AES_NK; i < AES_NWORDS; i++) {
        uint32_t temp = w[i-1];
        int m = i % AES_NK;
        if (m == 0) {
            temp = aes_subword(aes_rotword(temp)) ^ ((uint32_t)rc << 24);
            rc = aes_xtime(rc);
        } else if (m == 4) {            /* Nk>6 extra SubWord */
            temp = aes_subword(temp);
        }
        w[i] = w[i-AES_NK] ^ temp;
    }
}

/* GF(2^8) multiply (used by InvMixColumns). */
__device__ __forceinline__ uint8_t gmul(uint8_t a, uint8_t b) {
    uint8_t p = 0;
    #pragma unroll
    for (int i = 0; i < 8; i++) {
        if (b & 1) p ^= a;
        uint8_t hi = a & 0x80;
        a <<= 1;
        if (hi) a ^= 0x1b;
        b >>= 1;
    }
    return p;
}

/* Inverse cipher: decrypt one 16-byte block in-place using round keys w. */
__device__ void aes_decrypt_block(const uint8_t in[16], uint8_t out[16], const uint32_t w[AES_NWORDS]) {
    uint8_t s[4][4];
    #pragma unroll
    for (int i = 0; i < 16; i++) s[i%4][i/4] = in[i];

    /* AddRoundKey(Nr) */
    #pragma unroll
    for (int c = 0; c < 4; c++) {
        uint32_t wd = w[AES_NR*4+c];
        s[0][c]^=(wd>>24)&0xff; s[1][c]^=(wd>>16)&0xff; s[2][c]^=(wd>>8)&0xff; s[3][c]^=wd&0xff;
    }

    for (int rnd = AES_NR-1; rnd >= 1; rnd--) {
        /* InvShiftRows: row r cyclically right by r */
        uint8_t t;
        t=s[1][3]; s[1][3]=s[1][2]; s[1][2]=s[1][1]; s[1][1]=s[1][0]; s[1][0]=t;
        t=s[2][0]; s[2][0]=s[2][2]; s[2][2]=t; t=s[2][1]; s[2][1]=s[2][3]; s[2][3]=t;
        t=s[3][0]; s[3][0]=s[3][1]; s[3][1]=s[3][2]; s[3][2]=s[3][3]; s[3][3]=t;
        /* InvSubBytes */
        #pragma unroll
        for (int r = 0; r < 4; r++)
            #pragma unroll
            for (int c = 0; c < 4; c++) s[r][c] = INV_SBOX[s[r][c]];
        /* AddRoundKey(rnd) */
        #pragma unroll
        for (int c = 0; c < 4; c++) {
            uint32_t wd = w[rnd*4+c];
            s[0][c]^=(wd>>24)&0xff; s[1][c]^=(wd>>16)&0xff; s[2][c]^=(wd>>8)&0xff; s[3][c]^=wd&0xff;
        }
        /* InvMixColumns */
        #pragma unroll
        for (int c = 0; c < 4; c++) {
            uint8_t a0=s[0][c],a1=s[1][c],a2=s[2][c],a3=s[3][c];
            s[0][c]=gmul(a0,14)^gmul(a1,11)^gmul(a2,13)^gmul(a3,9);
            s[1][c]=gmul(a0,9)^gmul(a1,14)^gmul(a2,11)^gmul(a3,13);
            s[2][c]=gmul(a0,13)^gmul(a1,9)^gmul(a2,14)^gmul(a3,11);
            s[3][c]=gmul(a0,11)^gmul(a1,13)^gmul(a2,9)^gmul(a3,14);
        }
    }
    /* Final round: InvShiftRows, InvSubBytes, AddRoundKey(0) */
    uint8_t t;
    t=s[1][3]; s[1][3]=s[1][2]; s[1][2]=s[1][1]; s[1][1]=s[1][0]; s[1][0]=t;
    t=s[2][0]; s[2][0]=s[2][2]; s[2][2]=t; t=s[2][1]; s[2][1]=s[2][3]; s[2][3]=t;
    t=s[3][0]; s[3][0]=s[3][1]; s[3][1]=s[3][2]; s[3][2]=s[3][3]; s[3][3]=t;
    #pragma unroll
    for (int r = 0; r < 4; r++)
        #pragma unroll
        for (int c = 0; c < 4; c++) s[r][c] = INV_SBOX[s[r][c]];
    #pragma unroll
    for (int c = 0; c < 4; c++) {
        uint32_t wd = w[c];
        s[0][c]^=(wd>>24)&0xff; s[1][c]^=(wd>>16)&0xff; s[2][c]^=(wd>>8)&0xff; s[3][c]^=wd&0xff;
    }
    #pragma unroll
    for (int i = 0; i < 16; i++) out[i] = s[i%4][i/4];
}

/* ============================================================
 * PART 4: full per-attempt evaluation
 * ============================================================ */

/* Device-side puzzle parameters (loaded by host before any run). */
__constant__ uint8_t  c_salt[8];
__constant__ uint8_t  c_c0[16];    /* cipher block 0 */

/* Hex nibble lookup, lowercase ASCII. */
__device__ __forceinline__ uint8_t hex_lo(uint8_t nib) {
    return nib < 10 ? (uint8_t)('0'+nib) : (uint8_t)('a'+nib-10);
}

/*
 * pzl3_eval - run the full chain for passphrase P (32 bytes), salt+c0 given,
 * and return p0[16] = decrypted block-0 plaintext (already XOR'd with iv).
 * Caller checks p0[0..4] == "{\"kty".
 */
__device__ void pzl3_eval(const uint8_t *P, int plen, const uint8_t *salt, const uint8_t *c0, uint8_t p0[16]) {
    /* (1) SHA-512 chain: 1 + 11512 iterations. */
    uint64_t h[8];
    sha512_first_var(P, plen, h);
#ifndef PZL3_SKIP_SHA
    #pragma unroll 1
    for (int i = 0; i < 11512; i++) sha512_round64(h);
#endif

    /* keyhex = 128 lowercase hex chars of the 64-byte digest h (big-endian). */
    uint8_t keyhex[128];
    #pragma unroll
    for (int wi = 0; wi < 8; wi++) {
        uint64_t v = h[wi];
        #pragma unroll
        for (int b = 0; b < 8; b++) {
            uint8_t byte = (uint8_t)(v >> (56 - 8*b));
            keyhex[wi*16 + b*2]     = hex_lo(byte >> 4);
            keyhex[wi*16 + b*2 + 1] = hex_lo(byte & 0xf);
        }
    }

    /* (2) EvpKDF(MD5, iters=10000): D = key(128)||iv(16) = 9 MD5 blocks of 16 bytes. */
    uint8_t D[144];
    uint8_t prev[16];
    int prev_len = 0;          /* 0 for first block, 16 thereafter */
    int dlen = 0;
    while (dlen < 144) {
        /* first MD5 over (prev[prev_len] || keyhex[128] || salt[8]) */
        uint8_t msg[16 + 128 + 8];
        int off = 0;
        for (int i = 0; i < prev_len; i++) msg[off++] = prev[i];
        for (int i = 0; i < 128; i++)      msg[off++] = keyhex[i];
        for (int i = 0; i < 8;   i++)      msg[off++] = salt[i];
        uint8_t a[16];
        md5_var(msg, off, a);
        /* then 9999 re-hashes a = MD5(a), kept entirely in registers (the 16-byte
         * state IS the 4 LE words, so no byte<->word marshalling per iteration). */
        uint32_t w[4];
        #pragma unroll
        for (int k = 0; k < 4; k++)
            w[k] = (uint32_t)a[k*4] | ((uint32_t)a[k*4+1]<<8) | ((uint32_t)a[k*4+2]<<16) | ((uint32_t)a[k*4+3]<<24);
        #pragma unroll 1
        for (int n = 0; n < (PZL3_MD5_ITERS); n++) {
            uint32_t o[4];
            md5_16_words(w[0], w[1], w[2], w[3], o);
            w[0]=o[0]; w[1]=o[1]; w[2]=o[2]; w[3]=o[3];
        }
        #pragma unroll
        for (int k = 0; k < 4; k++) {
            uint8_t b0=(uint8_t)w[k], b1=(uint8_t)(w[k]>>8), b2=(uint8_t)(w[k]>>16), b3=(uint8_t)(w[k]>>24);
            prev[k*4]=b0;   prev[k*4+1]=b1;   prev[k*4+2]=b2;   prev[k*4+3]=b3;
            D[dlen+k*4]=b0; D[dlen+k*4+1]=b1; D[dlen+k*4+2]=b2; D[dlen+k*4+3]=b3;
        }
        prev_len = 16;
        dlen += 16;
    }
    /* key = D[0..127], iv = D[128..143] */

    /* (3) AES key expansion on the 128-byte key + (4) decrypt block 0. */
    uint32_t rk[AES_NWORDS];
    aes_key_expansion(D, rk);
    uint8_t dec[16];
    aes_decrypt_block(c0, dec, rk);
    /* CBC: p0 = dec XOR iv  (iv = D[128..143]) */
    #pragma unroll
    for (int k = 0; k < 16; k++) p0[k] = dec[k] ^ D[128 + k];
}

/* ============================================================
 * PART 5: kernels + host C ABI (.so).  NO BRUTE LAUNCHED HERE.
 * ============================================================ */

/* Wordlists in constant memory: up to 8 slots, each up to 256 4-char tokens. */
#define MAX_TOK 96
#define MAX_TLEN 64
#define MAX_PASS 111
#define NSLOT_MAX 6
__constant__ char    c_words[NSLOT_MAX][MAX_TOK][MAX_TLEN];
__constant__ uint8_t c_tlen[NSLOT_MAX][MAX_TOK];   /* byte length of each token */
__constant__ int     c_wlen[NSLOT_MAX];            /* token count per slot */
__constant__ int     c_nslot;                      /* active slots (1..8) */


/* Build the 32-byte passphrase for a given mixed-radix global index. */
__device__ __forceinline__ int index_to_pass(uint64_t idx, uint8_t *P) {
    int off = 0;
    int ns = c_nslot;
    for (int k = 0; k < ns; k++) {
        int n = c_wlen[k];
        int sel = (int)(idx % (uint64_t)n);
        idx /= (uint64_t)n;
        int L = (int)c_tlen[k][sel];
        for (int j = 0; j < L; j++) P[off + j] = (uint8_t)c_words[k][sel][j];
        off += L;
    }
    return off;
}

/* Result reporting: -1 = none; otherwise winning global index. */
__device__ long long g_hit_index;

/*
 * Range kernel - the host streamer would launch this over [start, start+count).
 * Grid-stride. Each thread evaluates one index, early-out on block-0 prefix.
 * (Self-test does NOT call this.)
 */
__global__ void pzl3_range_kernel(uint64_t start, uint64_t count) {
    uint64_t stride = (uint64_t)gridDim.x * blockDim.x;
    for (uint64_t t = blockIdx.x*blockDim.x + threadIdx.x; t < count; t += stride) {
        uint8_t P[MAX_PASS];
        int plen = index_to_pass(start + t, P);
        uint8_t p0[16];
        pzl3_eval(P, plen, c_salt, c_c0, p0);
        /* JWK prefix {"kty  -> 0x7b 0x22 0x6b 0x74 0x79 */
        if (p0[0]==0x7b && p0[1]==0x22 && p0[2]==0x6b && p0[3]==0x74 && p0[4]==0x79) {
            atomicExch((unsigned long long*)&g_hit_index, (unsigned long long)(start + t));
        }
    }
}

/*
 * Bench kernel - RAW SPEED measurement on SYNTHETIC inputs.
 *
 * Each thread derives its own 32-byte passphrase DIRECTLY from its global index
 * (no wordlist read, no real-ciphertext comparison): the 8 tokens are produced
 * by hashing the index into printable lowercase ASCII. The full per-attempt
 * pipeline (SHA-512^11513 + EvpKDF(MD5) + AES) then runs, and a single output
 * byte is accumulated into a global sink so the compiler cannot dead-code-
 * eliminate the work. This measures attempts/sec of the engine, nothing else.
 *
 * IMPORTANT: this kernel NEVER touches c_words, the real c_salt, or the real
 * c_c0 of the puzzle; it uses a fixed synthetic salt/c0 passed by the host. It
 * cannot reveal anything about the real solution - it is a pure speed harness.
 */
__device__ unsigned long long g_bench_sink;

__global__ void PZL3_LB
arv_bench_kernel(uint64_t base, uint64_t count,
                  const uint8_t *syn_salt, const uint8_t *syn_c0) {
    uint64_t stride = (uint64_t)gridDim.x * blockDim.x;
    uint8_t salt[8], c0[16];
    #pragma unroll
    for (int i = 0; i < 8;  i++) salt[i] = syn_salt[i];
    #pragma unroll
    for (int i = 0; i < 16; i++) c0[i]   = syn_c0[i];

    unsigned long long acc = 0;
    for (uint64_t t = blockIdx.x*blockDim.x + threadIdx.x; t < count; t += stride) {
        uint64_t idx = base + t;
        /* Synthesize 32 printable lowercase ASCII bytes from the index alone.
         * Cheap LCG-style mix per byte; deterministic, no memory reads. */
        uint8_t P[32];
        uint64_t x = idx * 0x9E3779B97F4A7C15ULL + 0x1234567;
        #pragma unroll
        for (int k = 0; k < 32; k++) {
            x ^= x >> 33; x *= 0xff51afd7ed558ccdULL; x ^= x >> 29;
            P[k] = (uint8_t)('a' + (x & 0xff) % 26);
        }
        uint8_t p0[16];
        pzl3_eval(P, 32, salt, c0, p0);
        acc += p0[0];           /* anti-DCE: consume an output byte */
    }
    /* Single atomic per thread keeps the sink live without serialising the loop. */
    atomicAdd(&g_bench_sink, acc);
}

/*
 * Self-test kernel - evaluate ONE explicit 32-byte passphrase against a
 * host-provided salt/c0 and copy the recovered p0[16] back. This is the only
 * thing the build verification runs. It is a single attempt, NOT a sweep.
 */
__global__ void arv_selftest_kernel(const uint8_t *P, int plen, const uint8_t *salt,
                                     const uint8_t *c0, uint8_t *out_p0) {
    if (blockIdx.x==0 && threadIdx.x==0) {
        uint8_t Pl[MAX_PASS], sl[8], cl[16], p0[16];
        for (int i=0;i<plen;i++) Pl[i]=P[i];
        #pragma unroll
        for (int i=0;i<8;i++) sl[i]=salt[i];
        #pragma unroll
        for (int i=0;i<16;i++) cl[i]=c0[i];
        pzl3_eval(Pl, plen, sl, cl, p0);
        #pragma unroll
        for (int i=0;i<16;i++) out_p0[i]=p0[i];
    }
}

extern "C" {

/* Load the puzzle salt (8 bytes) + cipher block 0 (16 bytes) into constant mem.
 * Also resets the free-slot to "none" (c_free_k=-1) so callers that don't opt
 * into the generated-slot mode keep the original pure-wordlist behaviour. */
int arv_init(const uint8_t *salt8, const uint8_t *c0_16) {
    cudaError_t e;
    e = cudaMemcpyToSymbol(c_salt, salt8, 8);              if (e) return -1;
    e = cudaMemcpyToSymbol(c_c0,   c0_16, 16);             if (e) return -2;
    long long none = -1;
    e = cudaMemcpyToSymbol(g_hit_index, &none, sizeof(none)); if (e) return -3;
    return 0;
}

/* Load wordlists. words = NSLOT_MAX*MAX_TOK*MAX_TLEN bytes, tlens =
 * NSLOT_MAX*MAX_TOK bytes (per-token length), counts = int[NSLOT_MAX],
 * nslot = number of ACTIVE slots (1..8). */
int arv_set_wordlists(const char *words, const unsigned char *tlens,
                       const int *counts, int nslot) {
    cudaError_t e;
    if (nslot < 1) nslot = 1; if (nslot > NSLOT_MAX) nslot = NSLOT_MAX;
    e = cudaMemcpyToSymbol(c_words, words, sizeof(char)*NSLOT_MAX*MAX_TOK*MAX_TLEN); if (e) return -1;
    e = cudaMemcpyToSymbol(c_tlen,  tlens, sizeof(unsigned char)*NSLOT_MAX*MAX_TOK); if (e) return -2;
    e = cudaMemcpyToSymbol(c_wlen,  counts, sizeof(int)*NSLOT_MAX);                  if (e) return -3;
    e = cudaMemcpyToSymbol(c_nslot, &nslot, sizeof(int));                            if (e) return -4;
    return 0;
}

/*
 * Evaluate a contiguous index range [start, start+count). Returns the winning
 * global index, or -1 if none. THE HOST DRIVER WOULD CALL THIS to stream the
 * search; it is intentionally NOT exercised by the self-test.
 */
long long arv_run_index_range(uint64_t start, uint64_t count, int threads, int blocks) {
    long long none = -1;
    cudaMemcpyToSymbol(g_hit_index, &none, sizeof(none));
    if (threads <= 0) threads = 64;
    if (blocks  <= 0) blocks  = 1024;
    pzl3_range_kernel<<<blocks, threads>>>(start, count);
    cudaError_t e = cudaDeviceSynchronize();
    if (e) return -2;
    long long hit;
    cudaMemcpyFromSymbol(&hit, g_hit_index, sizeof(hit));
    return hit;
}

/*
 * arv_bench - RAW SPEED benchmark on synthetic inputs. Launches
 * arv_bench_kernel with `blocks`x`threads`, evaluating `count` synthetic
 * attempts (grid-stride). Times the kernel with CUDA events and writes the
 * elapsed milliseconds to *out_ms. Returns 0 on success.
 *
 * Does NOT read wordlists nor the real puzzle ciphertext: caller supplies a
 * synthetic salt/c0 (any bytes). This is purely a throughput probe.
 */
int arv_bench(uint64_t base, uint64_t count, int threads, int blocks,
               const uint8_t *syn_salt8, const uint8_t *syn_c0_16, float *out_ms) {
    if (threads <= 0) threads = PZL3_BENCH_TPB;
    if (blocks  <= 0) blocks  = 1024;
    uint8_t *dS, *dC;
    if (cudaMalloc(&dS, 8))  return -1;
    if (cudaMalloc(&dC, 16)) return -1;
    cudaMemcpy(dS, syn_salt8, 8,  cudaMemcpyHostToDevice);
    cudaMemcpy(dC, syn_c0_16, 16, cudaMemcpyHostToDevice);

    cudaEvent_t e0, e1;
    cudaEventCreate(&e0); cudaEventCreate(&e1);
    cudaEventRecord(e0);
    arv_bench_kernel<<<blocks, threads>>>(base, count, dS, dC);
    cudaError_t le = cudaGetLastError();      /* catch invalid launch config */
    if (le) { fprintf(stderr, "bench launch err: %s\n", cudaGetErrorString(le));
              cudaEventDestroy(e0); cudaEventDestroy(e1);
              cudaFree(dS); cudaFree(dC); return -3; }
    cudaEventRecord(e1);
    cudaError_t e = cudaEventSynchronize(e1);
    if (e) { fprintf(stderr, "bench kernel err: %s\n", cudaGetErrorString(e));
             cudaEventDestroy(e0); cudaEventDestroy(e1);
             cudaFree(dS); cudaFree(dC); return -2; }
    float ms = 0.f;
    cudaEventElapsedTime(&ms, e0, e1);
    if (out_ms) *out_ms = ms;
    cudaEventDestroy(e0); cudaEventDestroy(e1);
    cudaFree(dS); cudaFree(dC);
    return 0;
}

/*
 * On-device self-test of ONE known vector. Inputs:
 *   P32   : 32-byte passphrase ('test4444'+padding handled by host)
 *   salt8 : 8-byte salt of the self-test ciphertext
 *   c0_16 : 16-byte cipher block 0 of the self-test ciphertext
 * Writes the recovered 16-byte plaintext block 0 to out_p0 (host buffer).
 * Returns 0 on launch success. Host compares out_p0 to the expected value.
 */
int arv_selftest(const uint8_t *P32, int plen, const uint8_t *salt8, const uint8_t *c0_16, uint8_t *out_p0) {
    uint8_t *dP,*dS,*dC,*dO;
    if (plen < 0 || plen > MAX_PASS) return -9;
    if (cudaMalloc(&dP,MAX_PASS)) return -1;
    if (cudaMalloc(&dS,8))  return -1;
    if (cudaMalloc(&dC,16)) return -1;
    if (cudaMalloc(&dO,16)) return -1;
    cudaMemcpy(dP, P32,   plen, cudaMemcpyHostToDevice);
    cudaMemcpy(dS, salt8, 8,  cudaMemcpyHostToDevice);
    cudaMemcpy(dC, c0_16, 16, cudaMemcpyHostToDevice);
    arv_selftest_kernel<<<1,1>>>(dP, plen, dS, dC, dO);
    cudaError_t e = cudaDeviceSynchronize();
    if (e) { fprintf(stderr, "selftest kernel err: %s\n", cudaGetErrorString(e)); return -2; }
    cudaMemcpy(out_p0, dO, 16, cudaMemcpyDeviceToHost);
    cudaFree(dP); cudaFree(dS); cudaFree(dC); cudaFree(dO);
    return 0;
}

} /* extern "C" */
