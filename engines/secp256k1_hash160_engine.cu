/* ── CONTEXT ──
 * CONTEXT - Part of a PUBLIC cryptopuzzle-solving project (treasure hunt / CTF).
 * This engine is used ONLY against puzzle-reward addresses whose own author locked
 * and PUBLISHED them as an open challenge - never a third-party wallet or leaked key.
 * See CONTEXT.md at the repo root. Rule: zero false positives; funds verified on-chain.
 */
/*
 * Brainwallet GPU cracker (RushWallet-style brainwallet puzzles)
 *
 * Derivation (certified against RushWallet's own contest.js, 3 public oracles):
 *   privkey = SHA256(utf8(passphrase))       (verbatim; no trim/lower/salt)
 *   pubkey  = secp256k1 point, UNCOMPRESSED (0x04||X||Y)  -> primary
 *             also tested COMPRESSED as a safety net
 *   hash160 = RIPEMD160(SHA256(pubkey))
 *   address = base58check(0x00 || hash160)
 *
 * Adds pt_to_uncompressed (0x04||X||Y, 65 bytes) and the rushwallet kernel
 * on top of the shared secp256k1 / SHA-256 / RIPEMD-160 / hash160 device
 * primitives used across this engine set.
 *
 * Pipeline per thread:
 *   read passphrase (variable length) -> SHA256 -> scalar -> scalar_mult_G
 *   -> serialize uncompressed + compressed -> hash160 -> compare to targets.
 *
 * Host: generates candidate passphrases (corpus + rules), packs them into a
 * flat buffer (pinned), and streams batches to the GPU with double buffering.
 *
 * Build:  see build.sh   (compute_80 PTX -> JIT on sm_120 Blackwell)
 */
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include <unordered_set>
#include <cuda_runtime.h>

/* ================================================================
 * SHA-256
 * ================================================================ */
__constant__ uint32_t K256[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};
#define ROTR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define CH(x, y, z)  (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x)  (ROTR(x, 2)  ^ ROTR(x, 13) ^ ROTR(x, 22))
#define EP1(x)  (ROTR(x, 6)  ^ ROTR(x, 11) ^ ROTR(x, 25))
#define SIG0(x) (ROTR(x, 7)  ^ ROTR(x, 18) ^ ((x) >> 3))
#define SIG1(x) (ROTR(x, 17) ^ ROTR(x, 19) ^ ((x) >> 10))
#define SHA256_H0 0x6a09e667u
#define SHA256_H1 0xbb67ae85u
#define SHA256_H2 0x3c6ef372u
#define SHA256_H3 0xa54ff53au
#define SHA256_H4 0x510e527fu
#define SHA256_H5 0x9b05688cu
#define SHA256_H6 0x1f83d9abu
#define SHA256_H7 0x5be0cd19u

__device__ void sha256_compress(uint32_t state[8], const uint32_t block[16]) {
    uint32_t W[16];
    for (int i = 0; i < 16; i++) W[i] = block[i];
    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint32_t e = state[4], f = state[5], g = state[6], h = state[7];
    for (int i = 0; i < 64; i++) {
        if (i >= 16) {
            W[i & 15] = SIG1(W[(i - 2) & 15]) + W[(i - 7) & 15]
                       + SIG0(W[(i - 15) & 15]) + W[i & 15];
        }
        uint32_t t1 = h + EP1(e) + CH(e, f, g) + K256[i] + W[i & 15];
        uint32_t t2 = EP0(a) + MAJ(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }
    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

/* SHA-256 of arbitrary message (up to ~MAX_PP_LEN bytes). Output big-endian. */
__device__ void sha256_msg(const uint8_t *msg, int len, uint8_t hash[32]) {
    uint32_t state[8] = {
        SHA256_H0, SHA256_H1, SHA256_H2, SHA256_H3,
        SHA256_H4, SHA256_H5, SHA256_H6, SHA256_H7
    };
    uint8_t buf[256];
    for (int i = 0; i < len; i++) buf[i] = msg[i];
    buf[len] = 0x80;
    int pad_start = len + 1;
    int total;
    if (len < 56) total = 64;
    else if (len < 120) total = 128;
    else if (len < 184) total = 192;
    else total = 256;
    for (int i = pad_start; i < total; i++) buf[i] = 0;
    uint64_t bitlen = (uint64_t)len * 8;
    for (int i = 0; i < 8; i++)
        buf[total - 1 - i] = (uint8_t)(bitlen >> (i * 8));
    for (int off = 0; off < total; off += 64) {
        uint32_t block[16];
        for (int i = 0; i < 16; i++) {
            block[i] = ((uint32_t)buf[off + i * 4 + 0] << 24) |
                       ((uint32_t)buf[off + i * 4 + 1] << 16) |
                       ((uint32_t)buf[off + i * 4 + 2] <<  8) |
                       ((uint32_t)buf[off + i * 4 + 3]);
        }
        sha256_compress(state, block);
    }
    for (int i = 0; i < 8; i++) {
        hash[i * 4 + 0] = (uint8_t)(state[i] >> 24);
        hash[i * 4 + 1] = (uint8_t)(state[i] >> 16);
        hash[i * 4 + 2] = (uint8_t)(state[i] >>  8);
        hash[i * 4 + 3] = (uint8_t)(state[i]);
    }
}

/* sha256_full - fixed for 33/65-byte pubkeys (one or two blocks) */
__device__ void sha256_full(const uint8_t *msg, int len, uint8_t hash[32]) {
    sha256_msg(msg, len, hash);
}

/* ================================================================
 * secp256k1 field arithmetic
 * ================================================================ */
typedef struct { uint32_t d[8]; } fe_t;
typedef struct { fe_t x, y, z; } pt_t;

__device__ const uint32_t SECP256K1_P[8] = {
    0xFFFFFC2F, 0xFFFFFFFE, 0xFFFFFFFF, 0xFFFFFFFF,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF
};
__device__ const uint32_t SECP256K1_GX[8] = {
    0x16F81798, 0x59F2815B, 0x2DCE28D9, 0x029BFCDB,
    0xCE870B07, 0x55A06295, 0xF9DCBBAC, 0x79BE667E
};
__device__ const uint32_t SECP256K1_GY[8] = {
    0xFB10D4B8, 0x9C47D08F, 0xA6855419, 0xFD17B448,
    0x0E1108A8, 0x5DA4FBFC, 0x26A3C465, 0x483ADA77
};

/* ----------------------------------------------------------------
 * Precomputed table for 4-bit windowed scalar mult: nG for n=1..15,
 * affine coords, little-endian uint32 limbs. Replaces naive
 * double-and-add (256 dbl + ~128 add) with 256 dbl + <=64 add.
 * Values verified against the standalone precomputed-table kernel and against the
 * oracle selftest (RushWallet) which must stay green after this change.
 * ---------------------------------------------------------------- */
__device__ const uint32_t PRECOMP_GX[15][8] = {
    {0x16F81798, 0x59F2815B, 0x2DCE28D9, 0x029BFCDB, 0xCE870B07, 0x55A06295, 0xF9DCBBAC, 0x79BE667E},
    {0x5C709EE5, 0xABAC09B9, 0x8CEF3CA7, 0x5C778E4B, 0x95C07CD8, 0x3045406E, 0x41ED7D6D, 0xC6047F94},
    {0xBCE036F9, 0x8601F113, 0x836F99B0, 0xB531C845, 0xF89D5229, 0x49344F85, 0x9258C310, 0xF9308A01},
    {0xE8C4CD13, 0x74FA94AB, 0x0EE07584, 0xCC6C1390, 0x930B1404, 0x581E4904, 0xC10D80F3, 0xE493DBF1},
    {0xB240EFE4, 0xCBA8D569, 0xDC619AB7, 0xE88B84BD, 0x0A5C5128, 0x55B4A725, 0x1A072093, 0x2F8BDE4D},
    {0x60297556, 0x2F057A14, 0x8568A18B, 0x82F6472F, 0x355235D3, 0x20453A14, 0x755EEEA4, 0xFFF97BD5},
    {0xCAC4F9BC, 0xE92BDDED, 0x0330E39C, 0x3D419B7E, 0xF2EA7A0E, 0xA398F365, 0x6E5DB4EA, 0x5CBDF064},
    {0xE10A2A01, 0x67784EF3, 0xE5AF888A, 0x0A1BDD05, 0xB70F3C2F, 0xAFF3843F, 0x5CCA351D, 0x2F01E5E1},
    {0xFC27CCBE, 0xC35F110D, 0x4C57E714, 0xE0979697, 0x9F559ABD, 0x09AD178A, 0xF0C7F653, 0xACD484E2},
    {0x47E247C7, 0x52A68E2A, 0x1943C2B7, 0x3442D49B, 0x1AE6AE5D, 0x35477C7B, 0x47F3C862, 0xA0434D9E},
    {0x5DA008CB, 0xBBEC1789, 0xE5C17891, 0x5649980B, 0x70C65AAC, 0x5EF4246B, 0x58A9411E, 0x774AE7F8},
    {0x70AFE85A, 0xC5B0F470, 0x9620095B, 0x687CF441, 0x4D734633, 0x15C38F00, 0x48E7561B, 0xD01115D5},
    {0x19405AA8, 0xDEEDDF8F, 0x610E58CD, 0xB075FBC6, 0xC3748651, 0xC7D1D205, 0xD975288B, 0xF28773C2},
    {0x60E823E4, 0xE49B241A, 0x678949E6, 0x26AA7B63, 0x07D38E32, 0xFD64E67F, 0x895E719C, 0x499FDF9E},
    {0xE27E080E, 0x44ADBCF8, 0x3C85F79E, 0x31E5946F, 0x095FF411, 0x5A465AE3, 0x7D43EA96, 0xD7924D4F},
};
__device__ const uint32_t PRECOMP_GY[15][8] = {
    {0xFB10D4B8, 0x9C47D08F, 0xA6855419, 0xFD17B448, 0x0E1108A8, 0x5DA4FBFC, 0x26A3C465, 0x483ADA77},
    {0x50CFE52A, 0x236431A9, 0x3266D0E1, 0xF7F63265, 0x466CEAEE, 0xA3C58419, 0xA63DC339, 0x1AE168FE},
    {0x84B8E672, 0x6CB9FD75, 0x34C2231B, 0x6500A999, 0x2A37F356, 0x0FE337E6, 0x632DE814, 0x388F7B0F},
    {0x47739922, 0xCFE97BDC, 0xBFBDFE40, 0xD967AE33, 0x8EA51448, 0x5642E209, 0xA0D455B7, 0x51ED993E},
    {0xA6AC62D6, 0xDCA87D3A, 0xAB0D6840, 0xF788271B, 0xA6C9C426, 0xD4DBA9DD, 0x36E5E3D6, 0xD8AC2226},
    {0xB075F297, 0x3C870C36, 0x518FE4A0, 0xDE80F0F6, 0x7F45C560, 0xF3BE9601, 0xACFBB620, 0xAE12777A},
    {0x087264DA, 0xA5082628, 0x13FDE7B5, 0xA813D0B8, 0x861A54DB, 0xA3178D6D, 0xBA255960, 0x6AEBCA40},
    {0x6CBDE904, 0xB5DA2CB7, 0xBA5B7617, 0xC2E213D6, 0x132D13B4, 0x293D082A, 0x41539949, 0x5C4DA8A7},
    {0xC64F9C37, 0x05CC262A, 0x375F8E0F, 0xADD888A4, 0x763B61E9, 0x64380971, 0xB0A7D9FD, 0xCC338921},
    {0x037368D7, 0x3CBEE53B, 0xD877A159, 0x6F794C2E, 0x93A24C69, 0xA3B6C7E6, 0x5419BC27, 0x893ABA42},
    {0xC953C61B, 0x301D74C9, 0xDFF9D6A8, 0x372DB1E2, 0xD7B7B365, 0x0243DD56, 0xEB6B5E19, 0xD984A032},
    {0xF4062327, 0x6B051B13, 0xD9A86D52, 0x79238C5D, 0xE17BD815, 0xA8B64537, 0xC815E0D7, 0xA9F34FFD},
    {0xDB03ED81, 0x29B5CB52, 0x521FA91F, 0x3A1A06DA, 0x65CDAF47, 0x758212EB, 0x8D880A89, 0x0AB0902E},
    {0x03A13F5B, 0xC65F40D4, 0x7A3F95BC, 0x464279C2, 0xA7B3D464, 0x90F044E4, 0xB54E8551, 0xCAC2F6C4},
    {0xF6A26B58, 0xC504DC9F, 0xD896D3A5, 0xEA40AF2B, 0x28CC6DEF, 0x83842EC2, 0xA86C72A6, 0x581E2872},
};
__device__ void fe_set_zero(fe_t *r){ for(int i=0;i<8;i++) r->d[i]=0; }
__device__ void fe_set_one(fe_t *r){ r->d[0]=1; for(int i=1;i<8;i++) r->d[i]=0; }
__device__ void fe_copy(fe_t *r, const fe_t *a){ for(int i=0;i<8;i++) r->d[i]=a->d[i]; }
__device__ void fe_set(fe_t *r, const uint32_t v[8]){ for(int i=0;i<8;i++) r->d[i]=v[i]; }
__device__ void fe_set_int(fe_t *r, uint32_t v){ r->d[0]=v; for(int i=1;i<8;i++) r->d[i]=0; }
__device__ int fe_is_zero(const fe_t *a){ uint32_t z=0; for(int i=0;i<8;i++) z|=a->d[i]; return z==0; }

__device__ void fe_add(const fe_t *a, const fe_t *b, fe_t *r) {
    uint64_t carry = 0;
    for (int i = 0; i < 8; i++) {
        carry += (uint64_t)a->d[i] + (uint64_t)b->d[i];
        r->d[i] = (uint32_t)carry; carry >>= 32;
    }
    if (carry || (r->d[7] > SECP256K1_P[7]) ||
        (r->d[7] == SECP256K1_P[7] && r->d[6] >= SECP256K1_P[6])) {
        uint32_t t[8]; int64_t borrow = 0;
        for (int i = 0; i < 8; i++) {
            int64_t d = (int64_t)r->d[i] - (int64_t)SECP256K1_P[i] - borrow;
            t[i] = (uint32_t)d; borrow = (d < 0) ? 1 : 0;
        }
        if (carry || borrow == 0) for (int i = 0; i < 8; i++) r->d[i] = t[i];
    }
}
__device__ void fe_sub(const fe_t *a, const fe_t *b, fe_t *r) {
    int64_t borrow = 0;
    for (int i = 0; i < 8; i++) {
        int64_t d = (int64_t)a->d[i] - (int64_t)b->d[i] - borrow;
        r->d[i] = (uint32_t)d; borrow = (d < 0) ? 1 : 0;
    }
    if (borrow) {
        uint64_t carry = 0;
        for (int i = 0; i < 8; i++) {
            carry += (uint64_t)r->d[i] + (uint64_t)SECP256K1_P[i];
            r->d[i] = (uint32_t)carry; carry >>= 32;
        }
    }
}
__device__ void fe_mul(const fe_t *a, const fe_t *b, fe_t *res) {
    uint32_t r[16]; for (int i = 0; i < 16; i++) r[i] = 0;
    for (int i = 0; i < 8; i++) {
        uint64_t carry = 0;
        for (int j = 0; j < 8; j++) {
            uint64_t t = (uint64_t)a->d[i] * (uint64_t)b->d[j] + (uint64_t)r[i + j] + carry;
            r[i + j] = (uint32_t)t; carry = t >> 32;
        }
        r[i + 8] = (uint32_t)carry;
    }
    uint32_t s[10]; uint64_t c = 0;
    for (int i = 0; i < 8; i++) {
        c += (uint64_t)r[i] + (uint64_t)r[i + 8] * 977ULL;
        s[i] = (uint32_t)c; c >>= 32;
    }
    s[8] = (uint32_t)c; s[9] = 0;
    c = 0;
    for (int i = 1; i <= 8; i++) {
        c += (uint64_t)s[i] + (uint64_t)r[7 + i];
        s[i] = (uint32_t)c; c >>= 32;
    }
    s[9] = (uint32_t)c;
    uint64_t ov = ((uint64_t)s[9] << 32) | (uint64_t)s[8];
    uint64_t ov977 = ov * 977ULL;
    c = (uint64_t)s[0] + (uint32_t)ov977; s[0] = (uint32_t)c; c >>= 32;
    c += (uint64_t)s[1] + (ov977 >> 32) + (ov & 0xFFFFFFFFULL); s[1] = (uint32_t)c; c >>= 32;
    c += (uint64_t)s[2] + (ov >> 32); s[2] = (uint32_t)c; c >>= 32;
    for (int i = 3; i < 8 && c; i++) { c += (uint64_t)s[i]; s[i] = (uint32_t)c; c >>= 32; }
    if (c) {
        uint64_t cc = 0x3D1ULL;
        for (int i = 0; i < 8; i++) {
            cc += (uint64_t)s[i]; s[i] = (uint32_t)cc; cc >>= 32;
            if (i == 0) cc += 1;
        }
    }
    uint32_t t[8]; int64_t bw = 0;
    for (int i = 0; i < 8; i++) {
        int64_t d = (int64_t)s[i] - (int64_t)SECP256K1_P[i] - bw;
        t[i] = (uint32_t)d; bw = (d < 0) ? 1 : 0;
    }
    if (!bw) for (int i = 0; i < 8; i++) res->d[i] = t[i];
    else     for (int i = 0; i < 8; i++) res->d[i] = s[i];
}
__device__ void fe_sqr(const fe_t *a, fe_t *r){ fe_mul(a, a, r); }
/* Repeated squaring: r = a^(2^n). */
__device__ void fe_sqr_n(const fe_t *a, int n, fe_t *r) {
    fe_t t; fe_copy(&t, a);
    for (int i = 0; i < n; i++) { fe_t s; fe_sqr(&t, &s); t = s; }
    *r = t;
}
/* Modular inverse via the secp256k1 addition chain for exponent p-2.
 * p-2 = 2^256 - 2^32 - 977 - 1. This is the standard bitcoin-core chain:
 * ~255 squarings but only ~15 multiplications (vs ~250 muls in the naive
 * square-and-multiply loop) -> the per-key inversion gets much cheaper.
 * Verified: oracle selftest stays green (it exercises pt_to_affine->fe_inv). */
__device__ void fe_inv(const fe_t *a, fe_t *r) {
    fe_t x2, x3, x6, x9, x11, x22, x44, x88, x176, x220, x223, t, u;
    /* x2 = a^(2^2-1) = a^3 */
    fe_sqr(a, &u); fe_mul(&u, a, &x2);
    /* x3 = a^(2^3-1) */
    fe_sqr(&x2, &u); fe_mul(&u, a, &x3);
    /* x6 = a^(2^6-1) */
    fe_sqr_n(&x3, 3, &u); fe_mul(&u, &x3, &x6);
    /* x9 */
    fe_sqr_n(&x6, 3, &u); fe_mul(&u, &x3, &x9);
    /* x11 */
    fe_sqr_n(&x9, 2, &u); fe_mul(&u, &x2, &x11);
    /* x22 */
    fe_sqr_n(&x11, 11, &u); fe_mul(&u, &x11, &x22);
    /* x44 */
    fe_sqr_n(&x22, 22, &u); fe_mul(&u, &x22, &x44);
    /* x88 */
    fe_sqr_n(&x44, 44, &u); fe_mul(&u, &x44, &x88);
    /* x176 */
    fe_sqr_n(&x88, 88, &u); fe_mul(&u, &x88, &x176);
    /* x220 */
    fe_sqr_n(&x176, 44, &u); fe_mul(&u, &x44, &x220);
    /* x223 */
    fe_sqr_n(&x220, 3, &u); fe_mul(&u, &x3, &x223);
    /* final: t = x223^(2^23) * x22 */
    fe_sqr_n(&x223, 23, &u); fe_mul(&u, &x22, &t);
    /* t = t^(2^5) * a */
    fe_sqr_n(&t, 5, &u); fe_mul(&u, a, &t);
    /* t = t^(2^3) * x2 */
    fe_sqr_n(&t, 3, &u); fe_mul(&u, &x2, &t);
    /* t = t^(2^2) * a  ->  this is a^(p-2) = a^-1 */
    fe_sqr_n(&t, 2, &u); fe_mul(&u, a, r);
}
__device__ void fe_to_bytes_be(const fe_t *a, uint8_t bytes[32]) {
    for (int i = 0; i < 8; i++) {
        int off = (7 - i) * 4;
        bytes[off + 0] = (uint8_t)(a->d[i] >> 24);
        bytes[off + 1] = (uint8_t)(a->d[i] >> 16);
        bytes[off + 2] = (uint8_t)(a->d[i] >> 8);
        bytes[off + 3] = (uint8_t)(a->d[i]);
    }
}

/* ================================================================
 * secp256k1 point ops (Jacobian)
 * ================================================================ */
__device__ void pt_double(const pt_t *P, pt_t *R) {
    if (fe_is_zero(&P->y) || fe_is_zero(&P->z)) { memset(R, 0, sizeof(pt_t)); return; }
    fe_t A, B, C, D, tmp, tmp2;
    fe_sqr(&P->y, &A);
    fe_mul(&P->x, &A, &tmp); fe_add(&tmp, &tmp, &tmp2); fe_add(&tmp2, &tmp2, &B);
    fe_sqr(&A, &tmp); fe_add(&tmp, &tmp, &tmp2); fe_add(&tmp2, &tmp2, &tmp); fe_add(&tmp, &tmp, &C);
    fe_sqr(&P->x, &tmp); fe_add(&tmp, &tmp, &tmp2); fe_add(&tmp2, &tmp, &D);
    fe_sqr(&D, &tmp); fe_add(&B, &B, &tmp2); fe_sub(&tmp, &tmp2, &R->x);
    fe_sub(&B, &R->x, &tmp); fe_mul(&D, &tmp, &tmp2); fe_sub(&tmp2, &C, &R->y);
    fe_mul(&P->y, &P->z, &tmp); fe_add(&tmp, &tmp, &R->z);
}
__device__ void pt_add_mixed(const pt_t *P, const fe_t *x2, const fe_t *y2, pt_t *R) {
    if (fe_is_zero(&P->z)) {
        fe_copy(&R->x, x2); fe_copy(&R->y, y2); fe_set_int(&R->z, 1); return;
    }
    fe_t Z1sq, Z1cu, U2, S2, H, Rv, HH, HHH, U1HH, tmp, tmp2;
    fe_sqr(&P->z, &Z1sq); fe_mul(&P->z, &Z1sq, &Z1cu);
    fe_mul(x2, &Z1sq, &U2); fe_mul(y2, &Z1cu, &S2);
    fe_sub(&U2, &P->x, &H); fe_sub(&S2, &P->y, &Rv);
    if (fe_is_zero(&H)) {
        if (fe_is_zero(&Rv)) { pt_double(P, R); return; }
        memset(R, 0, sizeof(pt_t)); return;
    }
    fe_sqr(&H, &HH); fe_mul(&H, &HH, &HHH); fe_mul(&P->x, &HH, &U1HH);
    fe_sqr(&Rv, &tmp); fe_sub(&tmp, &HHH, &R->x);
    fe_add(&U1HH, &U1HH, &tmp2); fe_sub(&R->x, &tmp2, &R->x);
    fe_sub(&U1HH, &R->x, &tmp); fe_mul(&Rv, &tmp, &R->y);
    fe_mul(&P->y, &HHH, &tmp); fe_sub(&R->y, &tmp, &R->y);
    fe_mul(&P->z, &H, &R->z);
}
/* 4-bit windowed scalar*G using the PRECOMP table (1G..15G affine).
 * 256 doublings + <=64 mixed adds (vs 256 dbl + ~128 add naive).
 * scalar is 32 bytes big-endian. */
__device__ void scalar_mult_G(const uint8_t scalar_be[32], pt_t *R) {
    memset(R, 0, sizeof(pt_t));
    for (int i = 0; i < 64; i++) {
        pt_t tmp;
        pt_double(R, &tmp); pt_double(&tmp, R);   /* ping-pong: 2 dbl, no memcpy */
        pt_double(R, &tmp); pt_double(&tmp, R);   /* 4 doublings total for this nibble */
        int byte_idx = i / 2;
        int nibble = (i & 1) ? (scalar_be[byte_idx] & 0x0F)
                             : (scalar_be[byte_idx] >> 4);
        if (nibble > 0) {
            fe_t px, py;
            fe_set(&px, PRECOMP_GX[nibble - 1]);
            fe_set(&py, PRECOMP_GY[nibble - 1]);
            pt_add_mixed(R, &px, &py, &tmp);
            *R = tmp;
        }
    }
}
/* affine x,y from Jacobian */
__device__ void pt_to_affine(const pt_t *P, fe_t *x_aff, fe_t *y_aff) {
    fe_t z_inv, z2_inv, z3_inv;
    fe_inv(&P->z, &z_inv);
    fe_sqr(&z_inv, &z2_inv);
    fe_mul(&z_inv, &z2_inv, &z3_inv);
    fe_mul(&P->x, &z2_inv, x_aff);
    fe_mul(&P->y, &z3_inv, y_aff);
}
__device__ void pt_to_compressed(const pt_t *P, uint8_t out[33]) {
    fe_t x_aff, y_aff; pt_to_affine(P, &x_aff, &y_aff);
    out[0] = (y_aff.d[0] & 1) ? 0x03 : 0x02;
    fe_to_bytes_be(&x_aff, out + 1);
}
__device__ void pt_to_uncompressed(const pt_t *P, uint8_t out[65]) {
    fe_t x_aff, y_aff; pt_to_affine(P, &x_aff, &y_aff);
    out[0] = 0x04;
    fe_to_bytes_be(&x_aff, out + 1);
    fe_to_bytes_be(&y_aff, out + 33);
}
/* Serialize BOTH compressed (33B) and uncompressed (65B) with a SINGLE
 * field inversion (fe_inv is ~256 sqr/mul, the dominant per-key cost
 * after the scalar mult). Saves one full inversion per key vs calling
 * pt_to_compressed + pt_to_uncompressed separately. */
__device__ void pt_to_both(const pt_t *P, uint8_t comp[33], uint8_t uncomp[65]) {
    fe_t z_inv, z2_inv, z3_inv, x_aff, y_aff;
    fe_inv(&P->z, &z_inv);
    fe_sqr(&z_inv, &z2_inv);
    fe_mul(&z_inv, &z2_inv, &z3_inv);
    fe_mul(&P->x, &z2_inv, &x_aff);
    fe_mul(&P->y, &z3_inv, &y_aff);
    /* compressed */
    comp[0] = (y_aff.d[0] & 1) ? 0x03 : 0x02;
    fe_to_bytes_be(&x_aff, comp + 1);
    /* uncompressed */
    uncomp[0] = 0x04;
    fe_to_bytes_be(&x_aff, uncomp + 1);
    fe_to_bytes_be(&y_aff, uncomp + 33);
}

/* ================================================================
 * RIPEMD-160
 * ================================================================ */
#define ROTL32(x,n) (((x)<<(n))|((x)>>(32-(n))))
#define RMD_F1(x,y,z) ((x)^(y)^(z))
#define RMD_F2(x,y,z) (((x)&(y))|((~(x))&(z)))
#define RMD_F3(x,y,z) (((x)|(~(y)))^(z))
#define RMD_F4(x,y,z) (((x)&(z))|((y)&(~(z))))
#define RMD_F5(x,y,z) ((x)^((y)|(~(z))))
__device__ const uint8_t RMD_RL[80] = {
    0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
    7,4,13,1,10,6,15,3,12,0,9,5,2,14,11,8,
    3,10,14,4,9,15,8,1,2,7,0,6,13,11,5,12,
    1,9,11,10,0,8,12,4,13,3,7,15,14,5,6,2,
    4,0,5,9,7,12,2,10,14,1,3,8,11,6,15,13
};
__device__ const uint8_t RMD_RR[80] = {
    5,14,7,0,9,2,11,4,13,6,15,8,1,10,3,12,
    6,11,3,7,0,13,5,10,14,15,8,12,4,9,1,2,
    15,5,1,3,7,14,6,9,11,8,12,2,10,0,4,13,
    8,6,4,1,3,11,15,0,5,12,2,13,9,7,10,14,
    12,15,10,4,1,5,8,7,6,2,13,14,0,3,9,11
};
__device__ const uint8_t RMD_SL[80] = {
    11,14,15,12,5,8,7,9,11,13,14,15,6,7,9,8,
    7,6,8,13,11,9,7,15,7,12,15,9,11,7,13,12,
    11,13,6,7,14,9,13,15,14,8,13,6,5,12,7,5,
    11,12,14,15,14,15,9,8,9,14,5,6,8,6,5,12,
    9,15,5,11,6,8,13,12,5,12,13,14,11,8,5,6
};
__device__ const uint8_t RMD_SR[80] = {
    8,9,9,11,13,15,15,5,7,7,8,11,14,14,12,6,
    9,13,15,7,12,8,9,11,7,7,12,7,6,15,13,11,
    9,7,15,11,8,6,6,14,12,13,5,14,13,13,7,5,
    15,5,8,11,14,14,6,14,6,9,12,9,12,5,15,8,
    8,5,12,9,12,5,14,6,8,13,6,5,15,13,11,11
};
__device__ const uint32_t RMD_KL[5] = { 0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E };
__device__ const uint32_t RMD_KR[5] = { 0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000 };
__device__ uint32_t rmd_f(int j, uint32_t x, uint32_t y, uint32_t z) {
    if (j < 16) return RMD_F1(x, y, z);
    if (j < 32) return RMD_F2(x, y, z);
    if (j < 48) return RMD_F3(x, y, z);
    if (j < 64) return RMD_F4(x, y, z);
    return RMD_F5(x, y, z);
}
__device__ void ripemd160(const uint8_t *msg, int len, uint8_t hash[20]) {
    uint32_t h0=0x67452301, h1=0xEFCDAB89, h2=0x98BADCFE, h3=0x10325476, h4=0xC3D2E1F0;
    uint8_t buf[64]; memset(buf, 0, 64); memcpy(buf, msg, len); buf[len]=0x80;
    uint64_t bitlen = (uint64_t)len * 8;
    for (int i = 0; i < 8; i++) buf[56 + i] = (uint8_t)(bitlen >> (i * 8));
    uint32_t X[16];
    for (int i = 0; i < 16; i++)
        X[i] = ((uint32_t)buf[i*4]) | ((uint32_t)buf[i*4+1]<<8) | ((uint32_t)buf[i*4+2]<<16) | ((uint32_t)buf[i*4+3]<<24);
    uint32_t al=h0,bl=h1,cl=h2,dl=h3,el=h4, ar=h0,br=h1,cr=h2,dr=h3,er=h4;
    for (int j = 0; j < 80; j++) {
        int round = j / 16;
        uint32_t fl = rmd_f(j, bl, cl, dl);
        uint32_t fr = rmd_f(79 - j, br, cr, dr);
        uint32_t tl = ROTL32(al + fl + X[RMD_RL[j]] + RMD_KL[round], RMD_SL[j]) + el;
        al = el; el = dl; dl = ROTL32(cl, 10); cl = bl; bl = tl;
        uint32_t tr = ROTL32(ar + fr + X[RMD_RR[j]] + RMD_KR[round], RMD_SR[j]) + er;
        ar = er; er = dr; dr = ROTL32(cr, 10); cr = br; br = tr;
    }
    uint32_t t = h1 + cl + dr; h1 = h2 + dl + er; h2 = h3 + el + ar; h3 = h4 + al + br; h4 = h0 + bl + cr; h0 = t;
    for (int i = 0; i < 4; i++) {
        hash[i]      = (uint8_t)(h0 >> (i * 8));
        hash[4 + i]  = (uint8_t)(h1 >> (i * 8));
        hash[8 + i]  = (uint8_t)(h2 >> (i * 8));
        hash[12 + i] = (uint8_t)(h3 >> (i * 8));
        hash[16 + i] = (uint8_t)(h4 >> (i * 8));
    }
}
__device__ void hash160(const uint8_t *data, int len, uint8_t h[20]) {
    uint8_t sha_out[32]; sha256_full(data, len, sha_out); ripemd160(sha_out, 32, h);
}

/* ================================================================
 * RushWallet kernel
 * ================================================================ */
#define MAX_PP_LEN 180          /* max passphrase length on GPU */
#define MAX_TARGETS 8

__constant__ uint8_t  c_targets[MAX_TARGETS][20];
__constant__ int      c_ntargets;

/* result buffer: one slot per match. Each: [cand_index(4)][which(4)] */
struct MatchRec { uint32_t index; uint32_t which; }; /* which: 0=uncomp,1=comp */

/*
 * Candidates packed as: offsets[n+1] (uint32), bytes[]. Thread i handles
 * candidate i: pp = bytes[off[i] .. off[i+1]).
 */
extern "C" __global__ void rushwallet_kernel(
    const uint8_t  *__restrict__ pp_bytes,
    const uint32_t *__restrict__ pp_off,
    uint32_t n,
    MatchRec *out, uint32_t *out_count, uint32_t out_cap)
{
    uint32_t i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;

    uint32_t a = pp_off[i], b = pp_off[i + 1];
    int len = (int)(b - a);
    if (len <= 0 || len > MAX_PP_LEN) return;

    uint8_t msg[MAX_PP_LEN];
    for (int k = 0; k < len; k++) msg[k] = pp_bytes[a + k];

    /* privkey = SHA256(passphrase) */
    uint8_t priv[32];
    sha256_msg(msg, len, priv);

    /* scalar*G */
    pt_t P;
    scalar_mult_G(priv, &P);
    if (fe_is_zero(&P.z)) return;  /* infinity (priv==0 mod n), skip */

    uint8_t pub_u[65], pub_c[33], h160[20];

    /* single field inversion -> both pubkey forms */
    pt_to_both(&P, pub_c, pub_u);

    /* UNCOMPRESSED (primary) */
    hash160(pub_u, 65, h160);
    for (int t = 0; t < c_ntargets; t++) {
        int eq = 1;
        #pragma unroll
        for (int j = 0; j < 20; j++) if (h160[j] != c_targets[t][j]) { eq = 0; break; }
        if (eq) {
            uint32_t slot = atomicAdd(out_count, 1u);
            if (slot < out_cap) { out[slot].index = i; out[slot].which = 0u | (t << 8); }
        }
    }

    /* COMPRESSED (safety net) */
    hash160(pub_c, 33, h160);
    for (int t = 0; t < c_ntargets; t++) {
        int eq = 1;
        #pragma unroll
        for (int j = 0; j < 20; j++) if (h160[j] != c_targets[t][j]) { eq = 0; break; }
        if (eq) {
            uint32_t slot = atomicAdd(out_count, 1u);
            if (slot < out_cap) { out[slot].index = i; out[slot].which = 1u | (t << 8); }
        }
    }
}

/* ================================================================
 * Host driver
 * ================================================================ */
#define CHECK(call) do { cudaError_t e=(call); if(e!=cudaSuccess){ \
    fprintf(stderr,"CUDA error %s:%d: %s\n",__FILE__,__LINE__,cudaGetErrorString(e)); exit(2);} }while(0)

static int hexval(char c){ if(c>='0'&&c<='9')return c-'0'; if(c>='a'&&c<='f')return c-'a'+10; if(c>='A'&&c<='F')return c-'A'+10; return -1; }
static void hex2bin(const char*h, uint8_t*o, int n){ for(int i=0;i<n;i++) o[i]=(uint8_t)((hexval(h[2*i])<<4)|hexval(h[2*i+1])); }

/* ---------------- corpus generation ---------------- */
struct Corpus {
    std::vector<std::string> items;
    std::unordered_set<std::string> seen;
    void add(const std::string &s) {
        if (s.empty() || s.size() > MAX_PP_LEN) return;
        if (seen.insert(s).second) items.push_back(s);
    }
};

static std::string up(const std::string&s){ std::string r=s; for(char&c:r)c=toupper((unsigned char)c); return r; }
static std::string lo(const std::string&s){ std::string r=s; for(char&c:r)c=tolower((unsigned char)c); return r; }
static std::string titlecase(const std::string&s){
    std::string r=s; bool st=true;
    for(char&c:r){ if(st&&isalpha((unsigned char)c)){c=toupper((unsigned char)c);st=false;} else if(!isalnum((unsigned char)c)) st=true; else c=tolower((unsigned char)c);} return r;
}
static std::string capfirst(const std::string&s){ if(s.empty())return s; std::string r=lo(s); r[0]=toupper((unsigned char)r[0]); return r; }

static void add_case_variants(Corpus&c, const std::string&s){
    c.add(s); c.add(lo(s)); c.add(up(s)); c.add(titlecase(s)); c.add(capfirst(s));
}
static void add_repeats(Corpus&c, const std::string&s){
    for(int n=2;n<=6;n++){ std::string r; for(int k=0;k<n;k++){ if(k)r+=" "; r+=s;} c.add(r); }
    /* no-space repeats too */
    for(int n=2;n<=4;n++){ std::string r; for(int k=0;k<n;k++) r+=s; c.add(r); }
}

/* aggressive mangling of a single token (best64-ish, but novel combos) */
static void mangle_token(Corpus&c, const std::string&base){
    std::vector<std::string> forms = { base, lo(base), up(base), capfirst(base), titlecase(base) };
    std::unordered_set<std::string> fs(forms.begin(), forms.end());
    for(auto&f:fs){
        c.add(f);
        /* repetitions with various separators */
        const char* seps[] = {" ", "", "-", ".", "_", "\n", ","};
        for(const char*sep:seps){
            for(int n=2;n<=5;n++){
                std::string r; for(int k=0;k<n;k++){ if(k)r+=sep; r+=f; }
                c.add(r);
            }
        }
        /* trailing punctuation / digits */
        c.add(f+"!"); c.add(f+"."); c.add(f+"?"); c.add(f+"!!!");
        c.add(f+"1"); c.add(f+"123"); c.add(f+"2014"); c.add(f+"3301");
        c.add("3301"+f); c.add(f+" 3301");
    }
    /* leetspeak */
    std::string leet=base;
    for(char&ch:leet){ if(ch=='o'||ch=='O')ch='0'; else if(ch=='i'||ch=='I')ch='1'; else if(ch=='e'||ch=='E')ch='3'; else if(ch=='a'||ch=='A')ch='4'; else if(ch=='s'||ch=='S')ch='5'; else if(ch=='t'||ch=='T')ch='7'; }
    if(leet!=base) c.add(leet);
}

/* cross-product of a small token set into multi-word phrases */
static void combine_tokens(Corpus&c, const std::vector<std::string>&toks, int maxlen){
    /* pairs and triples with space and no-space, in order and reversed */
    int n=toks.size();
    for(int i=0;i<n;i++) for(int j=0;j<n;j++){
        if(i==j) continue;
        c.add(toks[i]+" "+toks[j]);
        c.add(toks[i]+toks[j]);
        if((int)(toks[i].size()+toks[j].size())<maxlen){
            for(int k=0;k<n;k++){ if(k==i||k==j) continue;
                c.add(toks[i]+" "+toks[j]+" "+toks[k]);
            }
        }
    }
}

/* build the targeted corpus for puzzle #30 */
static void build_corpus(Corpus&c) {
    /* base seeds: obscure clue strings (whitepaper, Morse, KryptoKit, Cicada, names) */
    const char* seeds[] = {
        /* whitepaper / Satoshi */
        "Bitcoin: A Peer-to-Peer Electronic Cash System",
        "Bitcoin A Peer-to-Peer Electronic Cash System",
        "A Peer-to-Peer Electronic Cash System",
        "Peer-to-Peer Electronic Cash System",
        "Satoshi Nakamoto", "satoshin@gmx.com", "www.bitcoin.org",
        "read Satoshi's paper", "Read Satoshis paper", "read satoshis paper",
        "Bitcoin", "bitcoin", "Satoshi", "Nakamoto",
        "We define an electronic coin as a chain of digital signatures",
        "The root problem with conventional currency is all the trust that's required to make it work",
        "What is needed is an electronic payment system based on cryptographic proof instead of trust",
        /* KryptoKit slogans */
        "Your Bitcoin Interface", "VIEW SOURCE CODE", "view source code",
        "Bitcoin wallet and tools built right into your browser",
        "Bitcoin wallet and tools built right into your browser.",
        "KryptoKit", "kryptokit", "www.kryptokit.com", "kryptokit.com",
        "RushWallet", "rushwallet", "www.rushwallet.com", "rushwallet.com",
        /* Cicada 3301 */
        "cicada", "Cicada", "3301", "3302", "-3302", "3301KRYPT", "3301 KRYPT", "KRYPT3301",
        "K3R3Y0P1T", "DIMCIATDRL", "DMITRICADL",
        "No man is an island", "For whom the bell tolls", "John Donne",
        /* characters / story */
        "Dmitri", "Nancy", "Enrique", "Tony",
        "Dmitri Nancy Enrique", "Dmitri Enrique Nancy",
        "Dmitri hates Enriques loud keyboard but loves b1tc0in!",
        "Dmitri hates Enrique's loud keyboard but loves b1tc0in!",
        "Dmitri hates Enriques loud keyboard but loves bitcoin!",
        /* decoded audio / pgp meta */
        "WHAT IF THE GAME STARTED WAY BEFORE",
        "MAKING PUZZLES IS MORE FUN THAN WALLETS",
        "IT MIGHT BE OVER BUT THE PUZZLES ARE JUST THE BEGINNING",
        "THE PUZZLES ARE JUST THE BEGINNING",
        "this is just the beginning", "This is just the beginning",
        "seek and you shall find", "Seek and you shall find",
        "Merry Christmas", "merry christmas",
        "There is more than you can see here",
        "There are more than you think there are",
        "Why first and last", "why first and last",
        "where it all started", "Where it all started",
        /* numbers / misc */
        "2784623964023", "5784623964023",
        "CLiCK CLACK", "click clack", "clickclack",
        "babooshka", "MAKERBLOCK", "supercalifragilisticexpialidocious",
        "the honey badger of money", "honey badger of money",
        "you thought this was a clue but its not that easy",
    };
    int ns = sizeof(seeds)/sizeof(seeds[0]);
    for (int i = 0; i < ns; i++) {
        std::string s = seeds[i];
        add_case_variants(c, s);
        if (s.size() <= 30 && s.find(' ') == std::string::npos)
            add_repeats(c, s);
        if (s.size() <= 70) { c.add(s + " " + s); c.add(s + "\n" + s); c.add(s + s); }
        /* trailing punctuation variants */
        c.add(s + "."); c.add(s + "!"); c.add(s + "?");
    }

    /* ---- aggressive mangling of single keywords (novel space) ---- */
    const char* kw[] = {
        "cicada","Cicada","CICADA","3301","3302","KRYPT","krypt","kryptokit","rushwallet",
        "bitcoin","Bitcoin","satoshi","Satoshi","Nakamoto","Dmitri","Nancy","Enrique","Tony",
        "babooshka","MAKERBLOCK","makerblock","keyboard","Enrique","puzzle","puzzles","wallet",
        "brainwallet","Christmas","beginning","island","bell","tolls","Donne","paper","source",
        "interface","honeybadger","badger","money","b1tc0in","clickclack","clack","click",
        "thirty","thirtyone","31","30","first","last","start","started","game","secret","key",
        "Krypt0Kit","RushW4llet","s4toshi","D0nne","K","slogan","Kslogan","viewsource","view",
    };
    int nk=sizeof(kw)/sizeof(kw[0]);
    for(int i=0;i<nk;i++) mangle_token(c, kw[i]);

    /* ---- cross-product of high-signal tokens into phrases ---- */
    std::vector<std::string> toks = {
        "Dmitri","Nancy","Enrique","cicada","3301","krypt","bitcoin","satoshi",
        "rushwallet","kryptokit","keyboard","puzzle","wallet","Christmas","beginning",
    };
    combine_tokens(c, toks, 28);

    /* ---- LARGE-SCALE combinatorics (this is where the GPU pays off) ----
       Build a vocabulary of whitepaper / clue words and emit ordered
       n-tuples with several separators + case schemes. Millions of cands. */
    const char* vocab[] = {
        "Bitcoin","Peer","to","Peer","Electronic","Cash","System","Satoshi","Nakamoto",
        "cicada","3301","3302","KRYPT","krypt","kryptokit","rushwallet","brainwallet",
        "Dmitri","Nancy","Enrique","Tony","keyboard","loud","loves","hates","b1tc0in",
        "puzzle","puzzles","game","beginning","started","first","last","secret","key",
        "island","bell","tolls","Donne","Christmas","Merry","seek","find","source","view",
        "honey","badger","money","babooshka","makerblock","click","clack","thirty","one",
        "Your","interface","read","paper","wallet","trust","proof","coin","chain","hash",
        "the","of","a","is","this","more","than","you","think","where","it","all","start",
    };
    int nv=sizeof(vocab)/sizeof(vocab[0]);
    const char* seps[] = {" ", "", "-", "."};
    int nsep=sizeof(seps)/sizeof(seps[0]);
    /* 2-tuples: nv*nv*nsep with light case schemes */
    for(int i=0;i<nv;i++) for(int j=0;j<nv;j++){
        std::string A=vocab[i], B=vocab[j];
        for(int sp=0;sp<nsep;sp++){
            c.add(A+seps[sp]+B);
            c.add(lo(A)+seps[sp]+lo(B));
            c.add(capfirst(A)+seps[sp]+capfirst(B));
        }
    }
    /* 3-tuples (space only, original case + lower) to bound the count */
    for(int i=0;i<nv;i++) for(int j=0;j<nv;j++) for(int k=0;k<nv;k++){
        std::string s = std::string(vocab[i])+" "+vocab[j]+" "+vocab[k];
        c.add(s);
    }

    /* also Title/lower variants of the multi-word combos already added are
       generated lazily by add via combine, plus seed expansion above. */
}

/* load extra wordlists from files (one phrase per line, verbatim) */
static void load_file(Corpus&c, const char*path){
    FILE*f=fopen(path,"rb"); if(!f) return;
    char line[4096];
    while(fgets(line,sizeof(line),f)){
        size_t L=strlen(line);
        while(L>0 && (line[L-1]=='\n'||line[L-1]=='\r')) line[--L]=0;
        if(L>0){
            std::string s(line, L);
            c.add(s);
            add_case_variants(c, s);
        }
    }
    fclose(f);
}

int main(int argc, char**argv) {
    bool selftest_only=false;
    bool stream_mode=false;
    long bench_n=0;
    long stream_batch=2000000;            /* candidates per GPU launch */
    const char* override_target=NULL;     /* --target-hash160 <40hex> */
    std::vector<const char*> extra_files;
    for(int i=1;i<argc;i++){
        if(!strcmp(argv[i],"--selftest")) selftest_only=true;
        else if(!strcmp(argv[i],"--stream")) stream_mode=true;
        else if(!strcmp(argv[i],"--bench")&&i+1<argc) bench_n=atol(argv[++i]);
        else if(!strcmp(argv[i],"--batch")&&i+1<argc) stream_batch=atol(argv[++i]);
        else if(!strcmp(argv[i],"--target-hash160")&&i+1<argc) override_target=argv[++i];
        else if(!strcmp(argv[i],"-f")&&i+1<argc) extra_files.push_back(argv[++i]);
    }

    /* ---- targets ---- */
    /* index 0: real #30. 1,2: oracles (uncompressed) for self-test confidence */
    const char* tgt_hex[] = {
        "1a503dfb4e93103bd54218ba7d0e65a95bf397eb", /* #30  13Q8hJ... */
        "408aa2a4c5df589979a83316fbafff4da68eb1a3", /* oracle Dmitri Nancy Enrique -> 16tGKq... */
        "943eb3516d30cea4b98a20052548e1601868616d", /* oracle www.rushwallet.com  -> 1EWr7t... */
    };
    const char* tgt_label[] = { "PUZZLE30_13Q8hJ", "ORACLE_DmitriNancyEnrique", "ORACLE_wwwrushwallet" };
    int ntargets = 3;
    uint8_t targets[MAX_TARGETS][20];
    for(int t=0;t<ntargets;t++) hex2bin(tgt_hex[t], targets[t], 20);
    /* override the real target (index 0) with a user-supplied hash160 */
    if(override_target){
        if(strlen(override_target)!=40){
            fprintf(stderr,"--target-hash160 must be exactly 40 hex chars\n"); return 4;
        }
        hex2bin(override_target, targets[0], 20);
        fprintf(stderr,"[target] real target (idx0) = %s\n", override_target);
    }
    CHECK(cudaMemcpyToSymbol(c_targets, targets, ntargets*20));
    CHECK(cudaMemcpyToSymbol(c_ntargets, &ntargets, sizeof(int)));

    /* ---- result buffers (device + host) ---- */
    const uint32_t OUT_CAP = 256;
    MatchRec *d_out; uint32_t *d_out_count;
    CHECK(cudaMalloc(&d_out, OUT_CAP*sizeof(MatchRec)));
    CHECK(cudaMalloc(&d_out_count, sizeof(uint32_t)));
    CHECK(cudaMemset(d_out_count, 0, sizeof(uint32_t)));

    /* ============ SELF-TEST ============ */
    {
        std::vector<std::string> orac = { "Dmitri Nancy Enrique", "www.rushwallet.com" };
        /* pack */
        std::vector<uint32_t> off; std::vector<uint8_t> bytes;
        off.push_back(0);
        for(auto&s:orac){ for(char ch:s) bytes.push_back((uint8_t)ch); off.push_back(bytes.size()); }
        uint32_t n=orac.size();
        uint8_t *d_bytes; uint32_t *d_off;
        CHECK(cudaMalloc(&d_bytes, bytes.size())); CHECK(cudaMalloc(&d_off,(n+1)*4));
        CHECK(cudaMemcpy(d_bytes,bytes.data(),bytes.size(),cudaMemcpyHostToDevice));
        CHECK(cudaMemcpy(d_off,off.data(),(n+1)*4,cudaMemcpyHostToDevice));
        CHECK(cudaMemset(d_out_count,0,sizeof(uint32_t)));
        rushwallet_kernel<<<(n+63)/64,64>>>(d_bytes,d_off,n,d_out,d_out_count,OUT_CAP);
        CHECK(cudaDeviceSynchronize());
        uint32_t cnt=0; CHECK(cudaMemcpy(&cnt,d_out_count,4,cudaMemcpyDeviceToHost));
        MatchRec recs[OUT_CAP];
        if(cnt) CHECK(cudaMemcpy(recs,d_out,std::min(cnt,OUT_CAP)*sizeof(MatchRec),cudaMemcpyDeviceToHost));
        int hits=0;
        for(uint32_t k=0;k<cnt && k<OUT_CAP;k++){
            int t=(recs[k].which>>8)&0xFF, which=recs[k].which&0xFF;
            fprintf(stderr,"[selftest] hit cand=%u target=%s which=%s\n",
                recs[k].index, tgt_label[t], which?"comp":"uncomp");
            if(t>=1 && which==0) hits++;
        }
        cudaFree(d_bytes); cudaFree(d_off);
        if(hits<2){
            fprintf(stderr,"[selftest] FAILED: oracle uncompressed hits=%d (need 2). ABORTING.\n",hits);
            return 3;
        }
        fprintf(stderr,"[selftest] PASSED: both oracles matched on uncompressed path.\n");
        if(selftest_only) return 0;
    }

    /* ============ BENCHMARK ============ */
    if(bench_n>0){
        uint32_t N=(uint32_t)bench_n;
        /* synthetic distinct passphrases, ~20 bytes each */
        std::vector<uint32_t> off(N+1); off[0]=0;
        std::vector<uint8_t> bytes; bytes.reserve((size_t)N*20);
        char tmp[32];
        for(uint32_t i=0;i<N;i++){ int L=snprintf(tmp,sizeof(tmp),"benchpass_%010u",i); for(int k=0;k<L;k++)bytes.push_back((uint8_t)tmp[k]); off[i+1]=bytes.size(); }
        uint8_t *db; uint32_t *dof;
        CHECK(cudaMalloc(&db,bytes.size())); CHECK(cudaMalloc(&dof,(N+1)*4));
        CHECK(cudaMemcpy(db,bytes.data(),bytes.size(),cudaMemcpyHostToDevice));
        CHECK(cudaMemcpy(dof,off.data(),(N+1)*4,cudaMemcpyHostToDevice));
        CHECK(cudaMemset(d_out_count,0,sizeof(uint32_t)));
        cudaEvent_t b0,b1; CHECK(cudaEventCreate(&b0)); CHECK(cudaEventCreate(&b1));
        CHECK(cudaEventRecord(b0));
        rushwallet_kernel<<<(N+63)/64,64>>>(db,dof,N,d_out,d_out_count,OUT_CAP);
        CHECK(cudaEventRecord(b1)); CHECK(cudaEventSynchronize(b1)); CHECK(cudaGetLastError());
        float ms=0; CHECK(cudaEventElapsedTime(&ms,b0,b1));
        fprintf(stderr,"[bench] %u keys in %.1f ms => %.3f M keys/s\n", N, ms, N/(ms/1000.0)/1e6);
        cudaFree(db); cudaFree(dof);
        return 0;
    }

    /* ============ STREAM MODE (generic generator-fed) ============
       Read newline-delimited candidates from stdin in batches and match
       against target index 0. No built-in puzzle corpus. This is the
       mode used by solve_pipeline.sh (hashcat/PRINCE/combinator -> stdin). */
    if(stream_mode){
        const uint32_t BATCH=(uint32_t)stream_batch;
        std::vector<uint8_t> bytes; bytes.reserve((size_t)BATCH*16);
        std::vector<uint32_t> off; off.reserve(BATCH+1);
        uint8_t *d_bytes=NULL; uint32_t *d_off=NULL;
        size_t cap_bytes=0, cap_off=0;
        unsigned long long total=0; int real_hits=0;
        cudaEvent_t s0,s1; CHECK(cudaEventCreate(&s0)); CHECK(cudaEventCreate(&s1));
        double total_ms=0;
        std::vector<std::string> batch_items; batch_items.reserve(BATCH);

        char line[4096];
        bool eof=false;
        while(!eof){
            bytes.clear(); off.clear(); off.push_back(0); batch_items.clear();
            uint32_t n=0;
            while(n<BATCH){
                if(!fgets(line,sizeof(line),stdin)){ eof=true; break; }
                size_t L=strlen(line);
                while(L>0 && (line[L-1]=='\n'||line[L-1]=='\r')) line[--L]=0;
                if(L==0 || L>MAX_PP_LEN) continue;
                for(size_t k=0;k<L;k++) bytes.push_back((uint8_t)line[k]);
                off.push_back((uint32_t)bytes.size());
                batch_items.emplace_back(line, L);
                n++;
            }
            if(n==0) break;
            if(bytes.size()>cap_bytes){ if(d_bytes)cudaFree(d_bytes); cap_bytes=bytes.size()*2; CHECK(cudaMalloc(&d_bytes,cap_bytes)); }
            if((n+1)*4>cap_off){ if(d_off)cudaFree(d_off); cap_off=(n+1)*4*2; CHECK(cudaMalloc(&d_off,cap_off)); }
            CHECK(cudaMemcpy(d_bytes,bytes.data(),bytes.size(),cudaMemcpyHostToDevice));
            CHECK(cudaMemcpy(d_off,off.data(),(n+1)*4,cudaMemcpyHostToDevice));
            CHECK(cudaMemset(d_out_count,0,sizeof(uint32_t)));
            CHECK(cudaEventRecord(s0));
            rushwallet_kernel<<<(n+63)/64,64>>>(d_bytes,d_off,n,d_out,d_out_count,OUT_CAP);
            CHECK(cudaEventRecord(s1)); CHECK(cudaEventSynchronize(s1)); CHECK(cudaGetLastError());
            float ms=0; CHECK(cudaEventElapsedTime(&ms,s0,s1)); total_ms+=ms;
            total+=n;
            uint32_t cnt=0; CHECK(cudaMemcpy(&cnt,d_out_count,4,cudaMemcpyDeviceToHost));
            if(cnt){
                MatchRec recs[OUT_CAP];
                CHECK(cudaMemcpy(recs,d_out,std::min(cnt,OUT_CAP)*sizeof(MatchRec),cudaMemcpyDeviceToHost));
                for(uint32_t k=0;k<cnt && k<OUT_CAP;k++){
                    int t=(recs[k].which>>8)&0xFF, which=recs[k].which&0xFF;
                    if(t!=0) continue; /* ignore oracle echoes */
                    real_hits++;
                    const std::string &pp = batch_items[recs[k].index];
                    fprintf(stderr,"\n*** MATCH [%s] passphrase=<<<%s>>>\n", which?"compressed":"uncompressed", pp.c_str());
                    printf("MATCH\t%s\t%s\n", which?"compressed":"uncompressed", pp.c_str());
                    fflush(stdout);
                }
            }
            if(real_hits>0) break;
            fprintf(stderr,"\r[stream] %llu tried, %.2f M/s   ", total, total_ms>0? total/(total_ms/1000.0)/1e6 : 0.0);
            fflush(stderr);
        }
        if(d_bytes)cudaFree(d_bytes); if(d_off)cudaFree(d_off);
        fprintf(stderr,"\n[stream] DONE: %llu candidates, %.2f M/s avg, real matches=%d\n",
            total, total_ms>0? total/(total_ms/1000.0)/1e6 : 0.0, real_hits);
        return real_hits>0?0:1;
    }

    /* ============ BUILD CORPUS ============ */
    Corpus corpus;
    build_corpus(corpus);
    for(auto p:extra_files) load_file(corpus, p);
    /* also auto-load local wordlists if present (relative to the cwd) */
    load_file(corpus, "wordlist.txt");
    load_file(corpus, "whitepaper_phrases.txt");

    uint32_t N = corpus.items.size();
    fprintf(stderr,"[corpus] %u unique candidates\n", N);

    /* pack into pinned flat buffers */
    std::vector<uint32_t> off(N+1);
    off[0]=0;
    size_t total=0; for(auto&s:corpus.items) total+=s.size();
    for(uint32_t i=0;i<N;i++) off[i+1]=off[i]+corpus.items[i].size();

    uint8_t  *h_bytes; uint32_t *h_off;
    CHECK(cudaHostAlloc(&h_bytes, total?total:1, cudaHostAllocDefault));
    CHECK(cudaHostAlloc(&h_off, (N+1)*4, cudaHostAllocDefault));
    for(uint32_t i=0;i<N;i++) memcpy(h_bytes+off[i], corpus.items[i].data(), corpus.items[i].size());
    memcpy(h_off, off.data(), (N+1)*4);

    /* device buffers (full corpus fits easily; single big launch) */
    uint8_t *d_bytes; uint32_t *d_off;
    CHECK(cudaMalloc(&d_bytes, total?total:1));
    CHECK(cudaMalloc(&d_off, (N+1)*4));
    CHECK(cudaMemset(d_out_count,0,sizeof(uint32_t)));

    cudaEvent_t e0,e1; CHECK(cudaEventCreate(&e0)); CHECK(cudaEventCreate(&e1));
    CHECK(cudaMemcpy(d_bytes,h_bytes,total?total:1,cudaMemcpyHostToDevice));
    CHECK(cudaMemcpy(d_off,h_off,(N+1)*4,cudaMemcpyHostToDevice));

    CHECK(cudaEventRecord(e0));
    rushwallet_kernel<<<(N+63)/64,64>>>(d_bytes,d_off,N,d_out,d_out_count,OUT_CAP);
    CHECK(cudaEventRecord(e1));
    CHECK(cudaEventSynchronize(e1));
    CHECK(cudaGetLastError());
    float ms=0; CHECK(cudaEventElapsedTime(&ms,e0,e1));

    uint32_t cnt=0; CHECK(cudaMemcpy(&cnt,d_out_count,4,cudaMemcpyDeviceToHost));
    fprintf(stderr,"[run] %u keys in %.1f ms => %.2f M keys/s\n", N, ms, N/(ms/1000.0)/1e6);

    /* report matches against #30 (target index 0) */
    int real_hits=0;
    if(cnt){
        MatchRec recs[OUT_CAP];
        CHECK(cudaMemcpy(recs,d_out,std::min(cnt,OUT_CAP)*sizeof(MatchRec),cudaMemcpyDeviceToHost));
        FILE*sol=NULL;
        for(uint32_t k=0;k<cnt && k<OUT_CAP;k++){
            int t=(recs[k].which>>8)&0xFF, which=recs[k].which&0xFF;
            if(t!=0) continue; /* skip oracle echoes (not in corpus anyway) */
            real_hits++;
            const std::string &pp = corpus.items[recs[k].index];
            fprintf(stderr,"\n*** MATCH #30 [%s] passphrase=<<<%s>>>\n", which?"compressed":"uncompressed", pp.c_str());
            if(!sol) sol=fopen("FOUND.txt","a");
            if(sol){
                fprintf(sol,"MATCH #30 which=%s\npassphrase=<<<%s>>>\nhex=",which?"compressed":"uncompressed",pp.c_str());
                for(char ch:pp) fprintf(sol,"%02x",(unsigned char)ch);
                fprintf(sol,"\n---\n"); fflush(sol);
            }
        }
        if(sol) fclose(sol);
    }
    fprintf(stderr,"[run] #30 matches=%d (total recs=%u)\n", real_hits, cnt);

    cudaFree(d_bytes); cudaFree(d_off); cudaFree(d_out); cudaFree(d_out_count);
    cudaFreeHost(h_bytes); cudaFreeHost(h_off);
    return real_hits>0 ? 0 : 1;
}
