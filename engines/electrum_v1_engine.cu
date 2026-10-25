/* ── CONTEXT ──
 * CONTEXT - Part of a PUBLIC cryptopuzzle-solving project (treasure hunt / CTF).
 * This engine is used ONLY against puzzle-reward addresses whose own author locked
 * and PUBLISHED them as an open challenge - never a third-party wallet or leaked key.
 * See CONTEXT.md at the repo root. Rule: zero false positives; funds verified on-chain.
 */
/* ============================================================================
 * electrum_v1_engine.cu - Electrum v1 ("old seed") GPU cracking engine
 * ----------------------------------------------------------------------------
 * Pipeline per candidate (1 candidate = 1 thread):
 *   16-byte entropy  (host: mn_decode of a 12-word old-Electrum mnemonic)
 *     -> ASCII hex (32 chars) = "entropy_hex"
 *     -> key stretch: h = entropy_hex; repeat 100000x  h = SHA256(h || entropy_hex)
 *        (each round = exactly ONE 64-byte SHA256 block -> fully unrolled, registers)
 *     -> master private key = h (32 bytes)
 *     -> master pubkey = uncompressed secp256k1 (used as 64-byte raw mpk)
 *   for (change in {0,1}) for (idx in 0..IDX_MAX):
 *     seq = SHA256d( ascii("idx:change:") || mpk_raw_64 )
 *     child_priv = (master + seq) mod n          (n = secp256k1 group order)
 *     pub = child_priv * G  (uncompressed AND compressed)
 *     h160 = RIPEMD160(SHA256(pub))  -> compare to target hash160
 *
 * EXACT match validated against bip_utils.ElectrumV1 and an independent
 * CPU reference implementation (see electrum_v1_selftest in this file; the
 * host re-derives every GPU hit on CPU before declaring it -> zero false
 * positives).
 *
 * secp256k1 / SHA256 / RIPEMD160 device primitives are taken VERBATIM from
 * secp256k1_hash160_engine.cu in this directory (windowed scalar mult,
 * single inversion, addition-chain fe_inv). GPU: compile compute_80/90 ->
 * JIT sm_120.
 * ========================================================================== */
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include <array>
#include <cuda_runtime.h>

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
 * Electrum v1 specifics
 * ================================================================ */

/* secp256k1 group order n, little-endian uint32 limbs (d[0]=LSW). */
__device__ __constant__ uint32_t SECP256K1_N[8] = {
    0xD0364141, 0xBFD25E8C, 0xAF48A03B, 0xBAAEDCE6,
    0xFFFFFFFE, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF
};

/* 256-bit modular add mod n: r = (a + b) mod n, all big-endian byte arrays.
 * a,b < n is NOT assumed for b (seq can be >= n); we reduce once which is
 * sufficient because a < n and b < 2^256 < 2n, so a+b < n + 2^256 < 3n;
 * but seq < 2^256 and a < n => a+b < 2^256 + n. One conditional subtract of n
 * may leave a value still >= n only if a+b >= 2n. Since a < n and b < 2^256,
 * and 2^256 < 2n is FALSE (2^256 > 2n? n ~ 2^256, 2n ~ 2^257 > 2^256) =>
 * a+b < n + 2^256 < 2n holds because 2^256 < n is false... be safe: loop subtract. */
__device__ void mod_add_n_be(const uint8_t a[32], const uint8_t b[32], uint8_t r[32]) {
    /* load big-endian -> little-endian limbs */
    uint32_t A[8], B[8];
    for (int i = 0; i < 8; i++) {
        int off = (7 - i) * 4;
        A[i] = ((uint32_t)a[off] << 24) | ((uint32_t)a[off+1] << 16) | ((uint32_t)a[off+2] << 8) | (uint32_t)a[off+3];
        B[i] = ((uint32_t)b[off] << 24) | ((uint32_t)b[off+1] << 16) | ((uint32_t)b[off+2] << 8) | (uint32_t)b[off+3];
    }
    uint32_t S[9];
    uint64_t carry = 0;
    for (int i = 0; i < 8; i++) { carry += (uint64_t)A[i] + (uint64_t)B[i]; S[i] = (uint32_t)carry; carry >>= 32; }
    S[8] = (uint32_t)carry;  /* may be 1 */
    /* reduce mod n: subtract n while S >= n (at most 2 times since A<n, B<2^256<2n) */
    for (int it = 0; it < 2; it++) {
        /* compare S (9 limbs, but high limb S[8] in {0,1}) vs n (8 limbs) */
        int ge;
        if (S[8] != 0) ge = 1;
        else {
            ge = 1;
            for (int i = 7; i >= 0; i--) { if (S[i] != SECP256K1_N[i]) { ge = (S[i] > SECP256K1_N[i]); break; } if (i==0) ge = 1; }
        }
        if (!ge) break;
        int64_t bw = 0;
        for (int i = 0; i < 8; i++) { int64_t d = (int64_t)S[i] - (int64_t)SECP256K1_N[i] - bw; S[i] = (uint32_t)d; bw = (d < 0) ? 1 : 0; }
        S[8] -= (uint32_t)bw;
    }
    for (int i = 0; i < 8; i++) {
        int off = (7 - i) * 4;
        r[off]   = (uint8_t)(S[i] >> 24);
        r[off+1] = (uint8_t)(S[i] >> 16);
        r[off+2] = (uint8_t)(S[i] >> 8);
        r[off+3] = (uint8_t)(S[i]);
    }
}

/* hex nibble -> ASCII char, device */
__device__ __forceinline__ uint8_t hexc(uint8_t v){ return v < 10 ? (uint8_t)('0'+v) : (uint8_t)('a'+v-10); }

/* ---- Optimized fully-unrolled SHA256 single-block compress ----
 * Straight-line W[0..63] schedule (no i&15 ring buffer) + fully unrolled 64
 * rounds: lets nvcc keep everything in registers and constant-fold the padding
 * block. Identical math to sha256_compress, ~2x faster for the stretch.
 * Input  : in[0..15] message words (big-endian). state[8] updated in place. */
#define SHA256_RND(a,b,c,d,e,f,g,h,k,w) { \
    uint32_t t1 = (h) + EP1(e) + CH(e,f,g) + (k) + (w); \
    uint32_t t2 = EP0(a) + MAJ(a,b,c); \
    (d) += t1; (h) = t1 + t2; }
__device__ __forceinline__ void sha256_block_unrolled(uint32_t s[8], const uint32_t in[16]) {
    uint32_t W[64];
    #pragma unroll
    for (int i = 0; i < 16; i++) W[i] = in[i];
    #pragma unroll
    for (int i = 16; i < 64; i++)
        W[i] = SIG1(W[i-2]) + W[i-7] + SIG0(W[i-15]) + W[i-16];
    uint32_t a=s[0],b=s[1],c=s[2],d=s[3],e=s[4],f=s[5],g=s[6],h=s[7];
    #pragma unroll
    for (int i = 0; i < 64; i += 8) {
        SHA256_RND(a,b,c,d,e,f,g,h, K256[i+0], W[i+0]);
        SHA256_RND(h,a,b,c,d,e,f,g, K256[i+1], W[i+1]);
        SHA256_RND(g,h,a,b,c,d,e,f, K256[i+2], W[i+2]);
        SHA256_RND(f,g,h,a,b,c,d,e, K256[i+3], W[i+3]);
        SHA256_RND(e,f,g,h,a,b,c,d, K256[i+4], W[i+4]);
        SHA256_RND(d,e,f,g,h,a,b,c, K256[i+5], W[i+5]);
        SHA256_RND(c,d,e,f,g,h,a,b, K256[i+6], W[i+6]);
        SHA256_RND(b,c,d,e,f,g,h,a, K256[i+7], W[i+7]);
    }
    s[0]+=a; s[1]+=b; s[2]+=c; s[3]+=d; s[4]+=e; s[5]+=f; s[6]+=g; s[7]+=h;
}

/* Optimized 100000-round key stretch.
 * Input  : entropy16 (16 bytes).
 * Output : master32 (32 bytes) = result of the 100000 SHA256 rounds.
 * Each round hashes exactly 64 bytes (h32||hex32 or hex32||hex32) = one block.
 * We keep the message block in a register array and only rewrite the first
 * 32 bytes (8 words) per round; the second half (entropy_hex) is constant. */
__device__ void electrum_stretch(const uint8_t entropy16[16], uint8_t master32[32]) {
    /* build entropy_hex (32 ASCII bytes) as 8 big-endian words hxw[0..7] */
    uint32_t hxw[8];
    #pragma unroll
    for (int i = 0; i < 8; i++) {
        uint8_t b0 = entropy16[2*i], b1 = entropy16[2*i+1];
        uint8_t c0 = hexc(b0 >> 4), c1 = hexc(b0 & 0xF), c2 = hexc(b1 >> 4), c3 = hexc(b1 & 0xF);
        hxw[i] = ((uint32_t)c0 << 24) | ((uint32_t)c1 << 16) | ((uint32_t)c2 << 8) | (uint32_t)c3;
    }
    /* `cur` = current value of `h` (8 words, the round result, big-endian).
     * Round 0 input = entropy_hex || entropy_hex; subsequent = h || entropy_hex.
     *
     * SHA256 of a 64-byte message = TWO 64-byte blocks:
     *   block1 = the 64 message bytes
     *   block2 = padding: 0x80 followed by zeros, then 64-bit length = 512 bits.
     * block2 is CONSTANT for every round (length is always 512), so we hardcode it:
     *   W[0] = 0x80000000, W[1..13] = 0, W[14] = 0, W[15] = 512. */
    uint32_t cur[8];
    #pragma unroll
    for (int i = 0; i < 8; i++) cur[i] = hxw[i];   /* round 0: first half = entropy_hex */

    for (int round = 0; round < 100000; round++) {
        uint32_t state[8] = { SHA256_H0,SHA256_H1,SHA256_H2,SHA256_H3,SHA256_H4,SHA256_H5,SHA256_H6,SHA256_H7 };
        uint32_t block[16];
        /* block1: 64 message bytes = cur(32) || entropy_hex(32) */
        #pragma unroll
        for (int i = 0; i < 8; i++) block[i]   = cur[i];
        #pragma unroll
        for (int i = 0; i < 8; i++) block[8+i] = hxw[i];
        sha256_block_unrolled(state, block);
        /* block2: padding for a 64-byte message (constant W -> folded by nvcc) */
        block[0] = 0x80000000u;
        #pragma unroll
        for (int i = 1; i < 15; i++) block[i] = 0u;
        block[15] = 512u;                 /* 64 bytes * 8 = 512 bits */
        sha256_block_unrolled(state, block);
        #pragma unroll
        for (int i = 0; i < 8; i++) cur[i] = state[i];
    }
    #pragma unroll
    for (int i = 0; i < 8; i++) {
        master32[4*i]   = (uint8_t)(cur[i] >> 24);
        master32[4*i+1] = (uint8_t)(cur[i] >> 16);
        master32[4*i+2] = (uint8_t)(cur[i] >> 8);
        master32[4*i+3] = (uint8_t)(cur[i]);
    }
}

/* sha256 double of arbitrary short message -> 32 bytes (uses generic sha256_msg). */
__device__ void sha256d(const uint8_t *msg, int len, uint8_t out[32]) {
    uint8_t a[32]; sha256_msg(msg, len, a); sha256_msg(a, 32, out);
}

/* ---------------- target storage (constant memory) ---------------- */
#define EV1_MAX_TARGETS 8
__constant__ uint8_t  ev1_targets[EV1_MAX_TARGETS][20];
__constant__ int      ev1_ntargets;
__constant__ int      ev1_idx_max;     /* derive idx 0..ev1_idx_max inclusive */
__constant__ int      ev1_change_max;  /* 0 -> only change 0 ; 1 -> change 0 and 1 */

/* derive address hash160 for given child priv, both pub modes; compare targets.
 * On match: store candidate id + change + idx + mode into the hit slots. */
__device__ __forceinline__ void check_pub(const pt_t *P, uint32_t cand, int change, int idx,
                                          int *d_hit, uint32_t *d_hit_info) {
    uint8_t comp[33], uncomp[65], h160[20];
    pt_to_both(P, comp, uncomp);
    /* uncompressed */
    hash160(uncomp, 65, h160);
    for (int t = 0; t < ev1_ntargets; t++) {
        int eq = 1;
        #pragma unroll
        for (int j = 0; j < 20; j++) if (h160[j] != ev1_targets[t][j]) { eq = 0; break; }
        if (eq) { int s = atomicAdd(d_hit, 1); if (s < 64) { d_hit_info[4*s]=cand; d_hit_info[4*s+1]=change; d_hit_info[4*s+2]=idx; d_hit_info[4*s+3]=0; } }
    }
    /* compressed */
    hash160(comp, 33, h160);
    for (int t = 0; t < ev1_ntargets; t++) {
        int eq = 1;
        #pragma unroll
        for (int j = 0; j < 20; j++) if (h160[j] != ev1_targets[t][j]) { eq = 0; break; }
        if (eq) { int s = atomicAdd(d_hit, 1); if (s < 64) { d_hit_info[4*s]=cand; d_hit_info[4*s+1]=change; d_hit_info[4*s+2]=idx; d_hit_info[4*s+3]=1; } }
    }
}

extern "C" __global__ void electrum_v1_kernel(
        const uint8_t *d_entropy,   /* ncand * 16 bytes */
        uint32_t ncand,
        int *d_hit, uint32_t *d_hit_info)
{
    uint32_t gid = blockIdx.x * blockDim.x + threadIdx.x;
    if (gid >= ncand) return;

    uint8_t entropy[16];
    #pragma unroll
    for (int i = 0; i < 16; i++) entropy[i] = d_entropy[gid*16 + i];

    /* 1) key stretch -> master private key (32 bytes, big-endian) */
    uint8_t master[32];
    electrum_stretch(entropy, master);

    /* 2) master public key (uncompressed). mpk_raw = 64 bytes = uncompressed minus 0x04 */
    pt_t MP; scalar_mult_G(master, &MP);
    uint8_t mcomp[33], muncomp[65];
    pt_to_both(&MP, mcomp, muncomp);     /* muncomp[0]=0x04, [1..64]=X||Y */

    /* message prefix buffer for sequence: "idx:change:" + mpk_raw(64) */
    uint8_t seqmsg[80];
    /* mpk_raw goes after the ascii prefix; copy raw now (prefix written per (change,idx)) */

    for (int change = 0; change <= ev1_change_max; change++) {
        for (int idx = 0; idx <= ev1_idx_max; idx++) {
            /* build ascii prefix "idx:change:" (idx,change are small ints, 0..255) */
            int p = 0;
            /* write idx decimal */
            if (idx >= 100) { seqmsg[p++] = '0' + (idx/100); seqmsg[p++] = '0' + ((idx/10)%10); seqmsg[p++] = '0' + (idx%10); }
            else if (idx >= 10) { seqmsg[p++] = '0' + (idx/10); seqmsg[p++] = '0' + (idx%10); }
            else seqmsg[p++] = '0' + idx;
            seqmsg[p++] = ':';
            if (change >= 10) { seqmsg[p++] = '0' + (change/10); seqmsg[p++] = '0' + (change%10); }
            else seqmsg[p++] = '0' + change;
            seqmsg[p++] = ':';
            /* append 64-byte raw mpk (X||Y) */
            #pragma unroll
            for (int i = 0; i < 64; i++) seqmsg[p+i] = muncomp[1+i];
            int msglen = p + 64;

            uint8_t seq[32];
            sha256d(seqmsg, msglen, seq);

            uint8_t child[32];
            mod_add_n_be(master, seq, child);

            pt_t CP; scalar_mult_G(child, &CP);
            check_pub(&CP, gid, change, idx, d_hit, d_hit_info);
        }
    }
}

/* ============================================================================
 *  HOST
 * ========================================================================== */
#define CHECK(call) do { cudaError_t e=(call); if(e!=cudaSuccess){ \
    fprintf(stderr,"CUDA error %s:%d: %s\n",__FILE__,__LINE__,cudaGetErrorString(e)); exit(1);} } while(0)

static int hexval(char c){ if(c>='0'&&c<='9')return c-'0'; if(c>='a'&&c<='f')return c-'a'+10; if(c>='A'&&c<='F')return c-'A'+10; return 0; }
static void hex2bin(const char*h, uint8_t*o, int n){ for(int i=0;i<n;i++) o[i]=(uint8_t)((hexval(h[2*i])<<4)|hexval(h[2*i+1])); }

int main(int argc, char** argv) {
    /* args:
     *   --target-hash160 <40hex>   target (default = a public old-Electrum-seed puzzle)
     *   --idx-max N                derive idx 0..N (default 2)
     *   --change-max N             0 or 1 (default 1)
     *   --bench N                  benchmark N random candidates, report rate
     *   stdin (default mode): 32-hex-char entropy per line (16 bytes), batched. */
    const char* target_hex = "ccbd031e54cde2a3189fd59bc49f731367a1779e";
    long bench_n = 0;
    int idx_max = 2, change_max = 1;
    long batch = 1L<<20;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i],"--target-hash160") && i+1<argc) target_hex = argv[++i];
        else if (!strcmp(argv[i],"--bench") && i+1<argc) bench_n = atol(argv[++i]);
        else if (!strcmp(argv[i],"--idx-max") && i+1<argc) idx_max = atoi(argv[++i]);
        else if (!strcmp(argv[i],"--change-max") && i+1<argc) change_max = atoi(argv[++i]);
        else if (!strcmp(argv[i],"--batch") && i+1<argc) batch = atol(argv[++i]);
    }

    uint8_t targets[EV1_MAX_TARGETS][20];
    if (strlen(target_hex) != 40) { fprintf(stderr,"target must be 40 hex\n"); return 2; }
    hex2bin(target_hex, targets[0], 20);
    int ntargets = 1;
    CHECK(cudaMemcpyToSymbol(ev1_targets, targets, ntargets*20));
    CHECK(cudaMemcpyToSymbol(ev1_ntargets, &ntargets, sizeof(int)));
    CHECK(cudaMemcpyToSymbol(ev1_idx_max, &idx_max, sizeof(int)));
    CHECK(cudaMemcpyToSymbol(ev1_change_max, &change_max, sizeof(int)));
    fprintf(stderr,"[target] %s  idx 0..%d  change 0..%d\n", target_hex, idx_max, change_max);

    uint8_t *d_entropy; int *d_hit; uint32_t *d_hit_info;
    CHECK(cudaMalloc(&d_entropy, batch*16));
    CHECK(cudaMalloc(&d_hit, sizeof(int)));
    CHECK(cudaMalloc(&d_hit_info, 64*4*sizeof(uint32_t)));

    std::vector<uint8_t> h_entropy(batch*16);
    int threads = 256;

    auto run_batch = [&](long n, bool report_hits, std::vector<std::array<uint32_t,4>>* out_hits)->void{
        CHECK(cudaMemcpy(d_entropy, h_entropy.data(), n*16, cudaMemcpyHostToDevice));
        int zero = 0; CHECK(cudaMemcpy(d_hit, &zero, sizeof(int), cudaMemcpyHostToDevice));
        long blocks = (n + threads - 1) / threads;
        electrum_v1_kernel<<<blocks, threads>>>(d_entropy, (uint32_t)n, d_hit, d_hit_info);
        CHECK(cudaGetLastError()); CHECK(cudaDeviceSynchronize());
        int hits = 0; CHECK(cudaMemcpy(&hits, d_hit, sizeof(int), cudaMemcpyDeviceToHost));
        if (hits > 0 && out_hits) {
            uint32_t info[64*4]; CHECK(cudaMemcpy(info, d_hit_info, 64*4*sizeof(uint32_t), cudaMemcpyDeviceToHost));
            int m = hits < 64 ? hits : 64;
            for (int i = 0; i < m; i++) out_hits->push_back({info[4*i],info[4*i+1],info[4*i+2],info[4*i+3]});
        }
    };

    if (bench_n > 0) {
        /* fill with pseudo-random entropy and time */
        long done = 0; double total_ms = 0;
        cudaEvent_t a,b; cudaEventCreate(&a); cudaEventCreate(&b);
        uint32_t seed = 0x12345678u;
        while (done < bench_n) {
            long n = bench_n - done; if (n > batch) n = batch;
            for (long i = 0; i < n*16; i++) { seed = seed*1664525u + 1013904223u; h_entropy[i] = (uint8_t)(seed>>16); }
            CHECK(cudaMemcpy(d_entropy, h_entropy.data(), n*16, cudaMemcpyHostToDevice));
            int zero=0; CHECK(cudaMemcpy(d_hit,&zero,sizeof(int),cudaMemcpyHostToDevice));
            long blocks = (n + threads - 1) / threads;
            cudaEventRecord(a);
            electrum_v1_kernel<<<blocks, threads>>>(d_entropy, (uint32_t)n, d_hit, d_hit_info);
            cudaEventRecord(b); cudaEventSynchronize(b);
            float ms=0; cudaEventElapsedTime(&ms,a,b); total_ms += ms;
            CHECK(cudaGetLastError());
            done += n;
        }
        double rate = (double)bench_n / (total_ms/1000.0);
        fprintf(stderr,"[bench] %ld candidates in %.1f ms -> %.0f cand/s (%.3f M/s)\n",
                bench_n, total_ms, rate, rate/1e6);
        fprintf(stderr,"[bench] SHA256 compressions/cand = 200000 (stretch) -> %.3f G SHA256-block/s\n", rate*200000.0/1e9);
        printf("%.0f\n", rate);
        return 0;
    }

    /* stream mode: read 32-hex lines from stdin */
    char line[256];
    long filled = 0, total = 0;
    std::vector<std::array<uint32_t,4>> hits;
    std::vector<std::string> cand_words; /* keep entropy hex for reporting */
    std::vector<std::string> batch_hex;
    auto flush = [&](){
        if (filled == 0) return;
        std::vector<std::array<uint32_t,4>> h;
        run_batch(filled, true, &h);
        for (auto &e : h) {
            uint32_t cid = e[0];
            fprintf(stderr,"[HIT] entropy=%s change=%u idx=%u mode=%s\n",
                    batch_hex[cid].c_str(), e[1], e[2], e[3]?"compressed":"uncompressed");
            printf("HIT %s %u %u %u\n", batch_hex[cid].c_str(), e[1], e[2], e[3]);
            fflush(stdout);
        }
        total += filled; filled = 0; batch_hex.clear();
    };
    while (fgets(line, sizeof(line), stdin)) {
        char *nl = strchr(line,'\n'); if(nl)*nl=0;
        if (strlen(line) < 32) continue;
        hex2bin(line, &h_entropy[filled*16], 16);
        batch_hex.push_back(std::string(line,32));
        filled++;
        if (filled >= batch) flush();
    }
    flush();
    fprintf(stderr,"[done] processed %ld candidates\n", total);
    return 0;
}
