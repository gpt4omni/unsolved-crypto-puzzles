/* ── CONTEXT ──
 * CONTEXT - Part of a PUBLIC cryptopuzzle-solving project (treasure hunt / CTF).
 * This engine is used ONLY against puzzle-reward addresses whose own author locked
 * and PUBLISHED them as an open challenge - never a third-party wallet or leaked key.
 * See CONTEXT.md at the repo root. Rule: zero false positives; funds verified on-chain.
 */
/*
 * bruteforce_gpu_full.cu - Complete CUDA BIP39 -> BIP32 -> address pipeline
 *
 * Phase 1: BIP39 checksum verification (SHA-256)
 * Phase 2: Full derivation: PBKDF2-SHA512 -> BIP32 -> secp256k1 -> hash160
 *
 * Compile:
 *   nvcc -gencode arch=compute_80,code=compute_80 -O3 \
 *        -shared -Xcompiler -fPIC -o tools/libbruteforce_gpu_full.so tools/bruteforce_gpu_full.cu
 */

/* ================================================================
 * PART 1: Headers and types
 * ================================================================ */

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <cuda_runtime.h>

/* ================================================================
 * PART 2: SHA-256 (for checksum verification + hash160)
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

/* SHA-256 macros */
#define ROTR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define CH(x, y, z)  (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x)  (ROTR(x, 2)  ^ ROTR(x, 13) ^ ROTR(x, 22))
#define EP1(x)  (ROTR(x, 6)  ^ ROTR(x, 11) ^ ROTR(x, 25))
#define SIG0(x) (ROTR(x, 7)  ^ ROTR(x, 18) ^ ((x) >> 3))
#define SIG1(x) (ROTR(x, 17) ^ ROTR(x, 19) ^ ((x) >> 10))

/* SHA-256 initial hash values */
#define SHA256_H0 0x6a09e667u
#define SHA256_H1 0xbb67ae85u
#define SHA256_H2 0x3c6ef372u
#define SHA256_H3 0xa54ff53au
#define SHA256_H4 0x510e527fu
#define SHA256_H5 0x9b05688cu
#define SHA256_H6 0x1f83d9abu
#define SHA256_H7 0x5be0cd19u

/*
 * sha256_first_byte - SHA-256 of 32-byte entropy, returns first byte of hash.
 * Input: 8 uint32 words (big-endian entropy).
 * One 64-byte block after padding: data(32) + 0x80(1) + zeros(23) + length(8).
 * Uses 16-word circular buffer for message schedule.
 */
__device__ __forceinline__ uint8_t sha256_first_byte(uint32_t ent[8]) {
    uint32_t W[16];

    /* Message block: 32 bytes data + padding */
    W[0]  = ent[0]; W[1]  = ent[1]; W[2]  = ent[2]; W[3]  = ent[3];
    W[4]  = ent[4]; W[5]  = ent[5]; W[6]  = ent[6]; W[7]  = ent[7];
    W[8]  = 0x80000000u;
    W[9]  = 0; W[10] = 0; W[11] = 0;
    W[12] = 0; W[13] = 0; W[14] = 0;
    W[15] = 256u;  /* message length in bits */

    /* Initialize state */
    uint32_t a = SHA256_H0, b = SHA256_H1, c = SHA256_H2, d = SHA256_H3;
    uint32_t e = SHA256_H4, f = SHA256_H5, g = SHA256_H6, h = SHA256_H7;

    /* Rounds 0-15: no message schedule */
    #pragma unroll
    for (int i = 0; i < 16; i++) {
        uint32_t t1 = h + EP1(e) + CH(e, f, g) + K256[i] + W[i];
        uint32_t t2 = EP0(a) + MAJ(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }

    /* Rounds 16-63: with message schedule */
    #pragma unroll
    for (int i = 16; i < 64; i++) {
        W[i & 15] = SIG1(W[(i - 2) & 15]) + W[(i - 7) & 15]
                   + SIG0(W[(i - 15) & 15]) + W[i & 15];
        uint32_t t1 = h + EP1(e) + CH(e, f, g) + K256[i] + W[i & 15];
        uint32_t t2 = EP0(a) + MAJ(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }

    /* First byte of hash = high byte of (H0 + a) */
    return (uint8_t)((SHA256_H0 + a) >> 24);
}

/*
 * sha256_compress - compress one 64-byte block into state.
 */
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

/*
 * sha256_full - SHA-256 for arbitrary input up to 128 bytes.
 * Output: 32 bytes big-endian.
 * Handles padding. For 33-byte compressed pubkeys this is one block.
 */
__device__ __noinline__ void sha256_full(const uint8_t *msg, int len, uint8_t hash[32]) {
    uint32_t state[8] = {
        SHA256_H0, SHA256_H1, SHA256_H2, SHA256_H3,
        SHA256_H4, SHA256_H5, SHA256_H6, SHA256_H7
    };

    uint8_t buf[192];
    for (int i = 0; i < len; i++) buf[i] = msg[i];

    /* Padding */
    buf[len] = 0x80;
    int pad_start = len + 1;

    /* Calculate total padded length (multiple of 64) */
    int total;
    if (len < 56) {
        total = 64;
    } else if (len < 120) {
        total = 128;
    } else {
        total = 192;
    }

    for (int i = pad_start; i < total; i++) buf[i] = 0;

    /* Length in bits as big-endian 64-bit in last 8 bytes */
    uint64_t bitlen = (uint64_t)len * 8;
    buf[total - 8] = (uint8_t)(bitlen >> 56);
    buf[total - 7] = (uint8_t)(bitlen >> 48);
    buf[total - 6] = (uint8_t)(bitlen >> 40);
    buf[total - 5] = (uint8_t)(bitlen >> 32);
    buf[total - 4] = (uint8_t)(bitlen >> 24);
    buf[total - 3] = (uint8_t)(bitlen >> 16);
    buf[total - 2] = (uint8_t)(bitlen >>  8);
    buf[total - 1] = (uint8_t)(bitlen);

    /* Process 64-byte blocks */
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

    /* Output big-endian */
    for (int i = 0; i < 8; i++) {
        hash[i * 4 + 0] = (uint8_t)(state[i] >> 24);
        hash[i * 4 + 1] = (uint8_t)(state[i] >> 16);
        hash[i * 4 + 2] = (uint8_t)(state[i] >>  8);
        hash[i * 4 + 3] = (uint8_t)(state[i]);
    }
}


/* ================================================================
 * PART 3: SHA-512
 * ================================================================ */

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

/* SHA-512 initial hash values */
#define SHA512_H0 0x6a09e667f3bcc908ULL
#define SHA512_H1 0xbb67ae8584caa73bULL
#define SHA512_H2 0x3c6ef372fe94f82bULL
#define SHA512_H3 0xa54ff53a5f1d36f1ULL
#define SHA512_H4 0x510e527fade682d1ULL
#define SHA512_H5 0x9b05688c2b3e6c1fULL
#define SHA512_H6 0x1f83d9abfb41bd6bULL
#define SHA512_H7 0x5be0cd19137e2179ULL

/* SHA-512 macros (64-bit) */
#define ROTR64(x,n) (((x)>>(n))|((x)<<(64-(n))))
#define CH64(x,y,z) (((x)&(y))^(~(x)&(z)))
#define MAJ64(x,y,z) (((x)&(y))^((x)&(z))^((y)&(z)))
#define EP064(x) (ROTR64(x,28)^ROTR64(x,34)^ROTR64(x,39))
#define EP164(x) (ROTR64(x,14)^ROTR64(x,18)^ROTR64(x,41))
#define SIG064(x) (ROTR64(x,1)^ROTR64(x,8)^((x)>>7))
#define SIG164(x) (ROTR64(x,19)^ROTR64(x,61)^((x)>>6))

/*
 * SHA-512 round macro - avoids function call overhead, used by unrolled compress.
 */
#define SHA512_ROUND(a,b,c,d,e,f,g,h,Wi,Ki) do { \
    uint64_t t1 = (h) + EP164(e) + CH64(e,f,g) + (Ki) + (Wi); \
    uint64_t t2 = EP064(a) + MAJ64(a,b,c); \
    (h) = (g); (g) = (f); (f) = (e); (e) = (d) + t1; \
    (d) = (c); (c) = (b); (b) = (a); (a) = t1 + t2; \
} while(0)

/* Message schedule step for rounds 16-79 */
#define SHA512_WSTEP(W, i) \
    W[(i) & 15] = SIG164(W[((i) - 2) & 15]) + W[((i) - 7) & 15] \
                + SIG064(W[((i) - 15) & 15]) + W[(i) & 15]

/*
 * sha512_compress - one-block compression. Split loop: rounds 0-15 (no schedule)
 * and 16-79 (with message schedule). Eliminates branch in hot path.
 */
__device__ __forceinline__ void sha512_compress(uint64_t state[8], const uint64_t block[16]) {
    uint64_t W[16];
    #pragma unroll
    for (int i = 0; i < 16; i++) W[i] = block[i];

    uint64_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint64_t e = state[4], f = state[5], g = state[6], h = state[7];

    /* Rounds 0-15: W already loaded, no schedule computation */
    #pragma unroll
    for (int i = 0; i < 16; i++) {
        SHA512_ROUND(a,b,c,d,e,f,g,h, W[i], K512[i]);
    }

    /* Rounds 16-79: compute message schedule on the fly */
    #pragma unroll
    for (int i = 16; i < 80; i++) {
        SHA512_WSTEP(W, i);
        SHA512_ROUND(a,b,c,d,e,f,g,h, W[i & 15], K512[i]);
    }

    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

/*
 * sha512_compress_hmac64 - Specialized SHA-512 compress for HMAC of 64-byte messages.
 * Block format is always: msg[0..7] || 0x8000000000000000 || 0(×6) || 1536
 * This covers ALL PBKDF2 hot-loop iterations (inner & outer) and all HMAC outer hashes.
 * Hardcoding W[8..15] enables compiler constant-folding in schedule rounds 8-23.
 */
__device__ __forceinline__ void sha512_compress_hmac64(uint64_t state[8], const uint64_t msg[8]) {
    uint64_t W[16];
    #pragma unroll
    for (int i = 0; i < 8; i++) W[i] = msg[i];
    W[8]  = 0x8000000000000000ULL;
    W[9]  = 0ULL; W[10] = 0ULL; W[11] = 0ULL;
    W[12] = 0ULL; W[13] = 0ULL; W[14] = 0ULL;
    W[15] = 1536ULL;  /* (128+64)*8 bits */

    uint64_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint64_t e = state[4], f = state[5], g = state[6], h = state[7];

    /* Rounds 0-15 */
    #pragma unroll
    for (int i = 0; i < 16; i++) {
        SHA512_ROUND(a,b,c,d,e,f,g,h, W[i], K512[i]);
    }

    /* Rounds 16-79: with message schedule */
    #pragma unroll
    for (int i = 16; i < 80; i++) {
        SHA512_WSTEP(W, i);
        SHA512_ROUND(a,b,c,d,e,f,g,h, W[i & 15], K512[i]);
    }

    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

/* Helper: convert byte array to big-endian uint64 words */
__device__ __forceinline__ void bytes_to_be64(const uint8_t *src, uint64_t *dst, int n64) {
    for (int i = 0; i < n64; i++) {
        dst[i] = ((uint64_t)src[i * 8    ] << 56) | ((uint64_t)src[i * 8 + 1] << 48) |
                 ((uint64_t)src[i * 8 + 2] << 40) | ((uint64_t)src[i * 8 + 3] << 32) |
                 ((uint64_t)src[i * 8 + 4] << 24) | ((uint64_t)src[i * 8 + 5] << 16) |
                 ((uint64_t)src[i * 8 + 6] <<  8) | ((uint64_t)src[i * 8 + 7]);
    }
}

/* Helper: convert big-endian uint64 words to byte array */
__device__ __forceinline__ void be64_to_bytes(const uint64_t *src, uint8_t *dst, int n64) {
    for (int i = 0; i < n64; i++) {
        dst[i * 8    ] = (uint8_t)(src[i] >> 56); dst[i * 8 + 1] = (uint8_t)(src[i] >> 48);
        dst[i * 8 + 2] = (uint8_t)(src[i] >> 40); dst[i * 8 + 3] = (uint8_t)(src[i] >> 32);
        dst[i * 8 + 4] = (uint8_t)(src[i] >> 24); dst[i * 8 + 5] = (uint8_t)(src[i] >> 16);
        dst[i * 8 + 6] = (uint8_t)(src[i] >>  8); dst[i * 8 + 7] = (uint8_t)(src[i]);
    }
}

/* Helper: compress a 128-byte block given as bytes into state */
__device__ __forceinline__ void sha512_compress_bytes(uint64_t state[8], const uint8_t block[128]) {
    uint64_t blk[16];
    bytes_to_be64(block, blk, 16);
    sha512_compress(state, blk);
}

/*
 * sha512_hash - full SHA-512 for messages up to 256 bytes.
 * Handles multi-block padding. Big-endian output (64 bytes).
 */
__device__ __noinline__ void sha512_hash(const uint8_t *msg, int len, uint8_t hash[64]) {
    uint64_t state[8] = {
        SHA512_H0, SHA512_H1, SHA512_H2, SHA512_H3,
        SHA512_H4, SHA512_H5, SHA512_H6, SHA512_H7
    };

    /* Build padded buffer.
       SHA-512 block = 128 bytes. Padding: msg + 0x80 + zeros + 16-byte big-endian length.
       Need total to be multiple of 128, with at least 17 bytes for padding. */
    uint8_t buf[384];
    for (int i = 0; i < len; i++) buf[i] = msg[i];
    buf[len] = 0x80;

    /* Padded total length */
    int total = ((len + 17 + 127) / 128) * 128;

    for (int i = len + 1; i < total; i++) buf[i] = 0;

    /* Length in bits: 128-bit big-endian (upper 64 bits zero for our sizes) */
    uint64_t bitlen = (uint64_t)len * 8;
    for (int i = 0; i < 8; i++) buf[total - 1 - i] = (uint8_t)(bitlen >> (i * 8));

    /* Process 128-byte blocks */
    for (int off = 0; off < total; off += 128) {
        uint64_t block[16];
        bytes_to_be64(buf + off, block, 16);
        sha512_compress(state, block);
    }

    /* Output big-endian */
    be64_to_bytes(state, hash, 8);
}


/* ================================================================
 * PART 4: HMAC-SHA512
 * ================================================================ */

/*
 * hmac_sha512 - standard HMAC-SHA512.
 * Uses precomputed inner/outer states for efficiency.
 * key_len <= 128 for BIP39/BIP32 usage. msg_len up to ~256 bytes.
 *
 * Algorithm:
 * 1. If key_len > 128: key = SHA-512(key), key_len = 64
 * 2. Pad key with zeros to 128 bytes
 * 3. ipad = key XOR 0x36 (128 bytes), opad = key XOR 0x5c (128 bytes)
 * 4. inner = SHA-512(ipad || msg)
 * 5. result = SHA-512(opad || inner_hash)
 */
__device__ __noinline__ void hmac_sha512(const uint8_t *key, int key_len,
                            const uint8_t *msg, int msg_len,
                            uint8_t out[64])
{
    uint8_t kbuf[128];
    memset(kbuf, 0, 128);
    if (key_len > 128) {
        sha512_hash(key, key_len, kbuf);
    } else {
        memcpy(kbuf, key, key_len);
    }

    /* Compute istate: SHA-512 compress of (key XOR ipad) */
    uint8_t ipad[128];
    for (int i = 0; i < 128; i++) ipad[i] = kbuf[i] ^ 0x36;
    uint64_t istate[8] = { SHA512_H0, SHA512_H1, SHA512_H2, SHA512_H3,
                           SHA512_H4, SHA512_H5, SHA512_H6, SHA512_H7 };
    sha512_compress_bytes(istate, ipad);

    /* Compute ostate: SHA-512 compress of (key XOR opad) */
    uint8_t opad_buf[128];
    for (int i = 0; i < 128; i++) opad_buf[i] = kbuf[i] ^ 0x5c;
    uint64_t ostate[8] = { SHA512_H0, SHA512_H1, SHA512_H2, SHA512_H3,
                           SHA512_H4, SHA512_H5, SHA512_H6, SHA512_H7 };
    sha512_compress_bytes(ostate, opad_buf);

    /* Inner hash: compress(istate, msg || padding)
       Total message length for inner SHA-512 = 128 (ipad) + msg_len.
       For msg_len <= 111, this fits in one additional 128-byte block. */
    uint64_t inner[8];
    memcpy(inner, istate, 64);

    uint8_t ibuf[128];
    memset(ibuf, 0, 128);
    memcpy(ibuf, msg, msg_len);
    ibuf[msg_len] = 0x80;
    uint64_t ilen = ((uint64_t)128 + msg_len) * 8;
    for (int i = 0; i < 8; i++) ibuf[127 - i] = (uint8_t)(ilen >> (i * 8));
    sha512_compress_bytes(inner, ibuf);

    /* Outer hash: compress(ostate, inner_hash || hmac_pad)
       inner_hash is already in inner[8] as uint64 - use sha512_compress_hmac64 */
    uint64_t outer[8];
    #pragma unroll
    for (int i = 0; i < 8; i++) outer[i] = ostate[i];
    sha512_compress_hmac64(outer, inner);

    be64_to_bytes(outer, out, 8);
}

/*
 * hmac_sha512_precomputed - HMAC-SHA512 with precomputed inner/outer states.
 * istate = sha512_compress(IV, key_padded XOR 0x36)
 * ostate = sha512_compress(IV, key_padded XOR 0x5c)
 * msg_len up to 111 bytes (fits in one additional block after ipad).
 */
__device__ void hmac_sha512_precomputed(const uint64_t istate[8], const uint64_t ostate[8],
                                         const uint8_t *msg, int msg_len,
                                         uint8_t out[64])
{
    /* Inner: continue from istate with msg + padding.
       istate already consumed the 128-byte ipad block.
       Now process: msg || 0x80 || zeros || length in one 128-byte block.
       Total SHA-512 input length = 128 + msg_len. */
    uint64_t st[8];
    memcpy(st, istate, 64);

    uint8_t blk[128];
    memset(blk, 0, 128);
    memcpy(blk, msg, msg_len);
    blk[msg_len] = 0x80;
    uint64_t bitlen = ((uint64_t)128 + (uint64_t)msg_len) * 8;
    for (int i = 0; i < 8; i++) blk[127 - i] = (uint8_t)(bitlen >> (i * 8));
    sha512_compress_bytes(st, blk);

    /* Outer: compress(ostate, inner_hash || hmac_pad)
       st already contains the inner hash as uint64 - use sha512_compress_hmac64 */
    uint64_t inner_save[8];
    #pragma unroll
    for (int i = 0; i < 8; i++) { inner_save[i] = st[i]; st[i] = ostate[i]; }
    sha512_compress_hmac64(st, inner_save);

    be64_to_bytes(st, out, 8);
}


/* ================================================================
 * PART 5: PBKDF2-HMAC-SHA512 (optimized: uint64 hot loop)
 * ================================================================ */

/*
 * pbkdf2_sha512 - PBKDF2 with HMAC-SHA512, optimized for GPU.
 * Hot loop (2047 iterations) works entirely in uint64_t - no byte conversions.
 * Only U1 (variable-length salt) uses byte→uint64 conversion.
 */
__device__ __noinline__ void pbkdf2_sha512(const uint8_t *password, int pass_len,
                               const uint8_t *salt, int salt_len,
                               int rounds, uint8_t output[64])
{
    /* Step 1: Prepare HMAC key → uint64, compute istate/ostate.
       Scoped to let compiler free kbuf/key64/ipad64/opad64 registers after. */
    uint64_t istate[8], ostate[8];
    {
        uint8_t kbuf[128];
        memset(kbuf, 0, 128);
        if (pass_len > 128) {
            sha512_hash(password, pass_len, kbuf);
        } else {
            memcpy(kbuf, password, pass_len);
        }
        uint64_t key64[16];
        bytes_to_be64(kbuf, key64, 16);

        uint64_t ipad64[16], opad64[16];
        #pragma unroll
        for (int i = 0; i < 16; i++) {
            ipad64[i] = key64[i] ^ 0x3636363636363636ULL;
            opad64[i] = key64[i] ^ 0x5c5c5c5c5c5c5c5cULL;
        }

        istate[0] = SHA512_H0; istate[1] = SHA512_H1; istate[2] = SHA512_H2; istate[3] = SHA512_H3;
        istate[4] = SHA512_H4; istate[5] = SHA512_H5; istate[6] = SHA512_H6; istate[7] = SHA512_H7;
        sha512_compress(istate, ipad64);

        ostate[0] = SHA512_H0; ostate[1] = SHA512_H1; ostate[2] = SHA512_H2; ostate[3] = SHA512_H3;
        ostate[4] = SHA512_H4; ostate[5] = SHA512_H5; ostate[6] = SHA512_H6; ostate[7] = SHA512_H7;
        sha512_compress(ostate, opad64);
    }

    /* Step 2: U1 inner = HMAC_inner(salt || INT(1)). Scoped to free si_buf/blk. */
    uint64_t st[8];
    {
        int si_len = salt_len + 4;
        uint8_t si_buf[128];
        memset(si_buf, 0, 128);
        memcpy(si_buf, salt, salt_len);
        si_buf[salt_len]     = 0;
        si_buf[salt_len + 1] = 0;
        si_buf[salt_len + 2] = 0;
        si_buf[salt_len + 3] = 1;
        si_buf[si_len] = 0x80;
        uint64_t si_bits = ((uint64_t)128 + si_len) * 8;
        for (int i = 0; i < 8; i++) si_buf[127 - i] = (uint8_t)(si_bits >> (i * 8));

        uint64_t blk[16];
        bytes_to_be64(si_buf, blk, 16);
        #pragma unroll
        for (int i = 0; i < 8; i++) st[i] = istate[i];
        sha512_compress(st, blk);
    }

    /* U1 outer hash: compress(ostate, inner || hmac_pad) - use specialized version */
    uint64_t U[8];
    #pragma unroll
    for (int i = 0; i < 8; i++) { U[i] = st[i]; st[i] = ostate[i]; }
    sha512_compress_hmac64(st, U);

    /* result = U1 = outer hash */
    uint64_t result[8];
    #pragma unroll
    for (int i = 0; i < 8; i++) { U[i] = st[i]; result[i] = st[i]; }

    /* Step 3: Hot loop U2..U_rounds.
       Uses sha512_compress_hmac64 - no blk[16] array needed.
       Each iteration: inner = compress(istate, U || pad), outer = compress(ostate, inner || pad).
       The pad (0x80..0 || 1536) is hardcoded inside sha512_compress_hmac64. */
    for (int j = 1; j < rounds; j++) {
        /* Inner: compress(istate, U || hmac_pad) */
        #pragma unroll
        for (int i = 0; i < 8; i++) st[i] = istate[i];
        sha512_compress_hmac64(st, U);
        /* Outer: compress(ostate, inner || hmac_pad) */
        #pragma unroll
        for (int i = 0; i < 8; i++) { U[i] = st[i]; st[i] = ostate[i]; }
        sha512_compress_hmac64(st, U);
        /* U = outer result, accumulate into result */
        #pragma unroll
        for (int i = 0; i < 8; i++) { U[i] = st[i]; result[i] ^= st[i]; }
    }

    /* Convert result to bytes (big-endian) */
    be64_to_bytes(result, output, 8);
}


/* ================================================================
 * PART 6: secp256k1 field arithmetic
 * ================================================================ */

/* 256-bit field element, little-endian uint32 limbs (d[0] = least significant) */
typedef struct { uint32_t d[8]; } fe_t;

/* Jacobian point: (X, Y, Z), affine = (X/Z^2, Y/Z^3). Infinity: Z = 0. */
typedef struct { fe_t x, y, z; } pt_t;

/* Field modulus p = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
   LE limbs: */
__device__ const uint32_t SECP256K1_P[8] = {
    0xFFFFFC2F, 0xFFFFFFFE, 0xFFFFFFFF, 0xFFFFFFFF,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF
};

/* Group order n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
   LE limbs: */
__device__ const uint32_t SECP256K1_N[8] = {
    0xD0364141, 0xBFD25E8C, 0xAF48A03B, 0xBAAEDCE6,
    0xFFFFFFFE, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF
};

/* Generator G.x LE limbs */
__device__ const uint32_t SECP256K1_GX[8] = {
    0x16F81798, 0x59F2815B, 0x2DCE28D9, 0x029BFCDB,
    0xCE870B07, 0x55A06295, 0xF9DCBBAC, 0x79BE667E
};

/* Generator G.y LE limbs */
__device__ const uint32_t SECP256K1_GY[8] = {
    0xFB10D4B8, 0x9C47D08F, 0xA6855419, 0xFD17B448,
    0x0E1108A8, 0x5DA4FBFC, 0x26A3C465, 0x483ADA77
};

/* Precomputed table: nG for n=1..15, affine coordinates, LE uint32 limbs */
/* Used for 4-bit windowed scalar multiplication */
__device__ uint32_t PRECOMP_GX[15][8] = {
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

__device__ uint32_t PRECOMP_GY[15][8] = {
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

__device__ void fe_set_zero(fe_t *r) {
    for (int i = 0; i < 8; i++) r->d[i] = 0;
}

__device__ void fe_set_one(fe_t *r) {
    r->d[0] = 1;
    for (int i = 1; i < 8; i++) r->d[i] = 0;
}

__device__ void fe_copy(fe_t *r, const fe_t *a) {
    for (int i = 0; i < 8; i++) r->d[i] = a->d[i];
}

__device__ void fe_set(fe_t *r, const uint32_t v[8]) {
    for (int i = 0; i < 8; i++) r->d[i] = v[i];
}

__device__ void fe_set_int(fe_t *r, uint32_t v) {
    r->d[0] = v;
    for (int i = 1; i < 8; i++) r->d[i] = 0;
}

__device__ int fe_is_zero(const fe_t *a) {
    uint32_t z = 0;
    for (int i = 0; i < 8; i++) z |= a->d[i];
    return z == 0;
}

/*
 * fe_add - addition mod p.
 * If result >= p after addition, subtract p.
 */
__device__ void fe_add(const fe_t *a, const fe_t *b, fe_t *r) {
    uint64_t carry = 0;
    for (int i = 0; i < 8; i++) {
        carry += (uint64_t)a->d[i] + (uint64_t)b->d[i];
        r->d[i] = (uint32_t)carry;
        carry >>= 32;
    }
    /* If carry or r >= p, subtract p */
    if (carry || (r->d[7] > SECP256K1_P[7]) ||
        (r->d[7] == SECP256K1_P[7] && r->d[6] >= SECP256K1_P[6])) {
        uint32_t t[8];
        int64_t borrow = 0;
        for (int i = 0; i < 8; i++) {
            int64_t d = (int64_t)r->d[i] - (int64_t)SECP256K1_P[i] - borrow;
            t[i] = (uint32_t)d;
            borrow = (d < 0) ? 1 : 0;
        }
        if (carry || borrow == 0) {
            for (int i = 0; i < 8; i++) r->d[i] = t[i];
        }
    }
}

/*
 * fe_sub - subtraction mod p.
 * If result underflows, add p.
 */
__device__ void fe_sub(const fe_t *a, const fe_t *b, fe_t *r) {
    int64_t borrow = 0;
    for (int i = 0; i < 8; i++) {
        int64_t d = (int64_t)a->d[i] - (int64_t)b->d[i] - borrow;
        r->d[i] = (uint32_t)d;
        borrow = (d < 0) ? 1 : 0;
    }
    if (borrow) {
        uint64_t carry = 0;
        for (int i = 0; i < 8; i++) {
            carry += (uint64_t)r->d[i] + (uint64_t)SECP256K1_P[i];
            r->d[i] = (uint32_t)carry;
            carry >>= 32;
        }
    }
}

/*
 * fe_mul - multiplication mod p using schoolbook 8x8 multiply + secp256k1 reduction.
 *
 * Reduction strategy: p = 2^256 - C where C = 0x1000003D1.
 * After 512-bit multiply producing r[0..15]:
 *   result = r[0..7] + r[8..15] * C
 * Since C = 2^32 + 977:
 *   r_hi * C = r_hi * 977 + r_hi << 32
 * May need second reduction. Final conditional subtract of p.
 */
__device__ void fe_mul(const fe_t *a, const fe_t *b, fe_t *res) {
    uint32_t r[16];
    for (int i = 0; i < 16; i++) r[i] = 0;

    /* Schoolbook 8x8 multiply */
    for (int i = 0; i < 8; i++) {
        uint64_t carry = 0;
        for (int j = 0; j < 8; j++) {
            uint64_t t = (uint64_t)a->d[i] * (uint64_t)b->d[j] + (uint64_t)r[i + j] + carry;
            r[i + j] = (uint32_t)t;
            carry = t >> 32;
        }
        r[i + 8] = (uint32_t)carry;
    }

    /* First reduction: s = r_lo + r_hi * (2^32 + 977) */
    uint32_t s[10];
    uint64_t c = 0;

    /* r_lo + r_hi * 977 */
    for (int i = 0; i < 8; i++) {
        c += (uint64_t)r[i] + (uint64_t)r[i + 8] * 977ULL;
        s[i] = (uint32_t)c;
        c >>= 32;
    }
    s[8] = (uint32_t)c;
    s[9] = 0;

    /* + r_hi << 32 (shift r[8..15] left by one limb, add to s[1..9]) */
    c = 0;
    for (int i = 1; i <= 8; i++) {
        c += (uint64_t)s[i] + (uint64_t)r[7 + i];
        s[i] = (uint32_t)c;
        c >>= 32;
    }
    s[9] = (uint32_t)c;

    /* Second reduction: overflow in s[8..9] */
    uint64_t ov = ((uint64_t)s[9] << 32) | (uint64_t)s[8];
    uint64_t ov977 = ov * 977ULL;
    c = (uint64_t)s[0] + (uint32_t)ov977;
    s[0] = (uint32_t)c;
    c >>= 32;
    c += (uint64_t)s[1] + (ov977 >> 32) + (ov & 0xFFFFFFFFULL);
    s[1] = (uint32_t)c;
    c >>= 32;
    c += (uint64_t)s[2] + (ov >> 32);
    s[2] = (uint32_t)c;
    c >>= 32;
    for (int i = 3; i < 8 && c; i++) {
        c += (uint64_t)s[i];
        s[i] = (uint32_t)c;
        c >>= 32;
    }

    /* Handle carry from second reduction */
    if (c) {
        uint64_t cc = 0x3D1ULL;
        for (int i = 0; i < 8; i++) {
            cc += (uint64_t)s[i];
            s[i] = (uint32_t)cc;
            cc >>= 32;
            if (i == 0) cc += 1; /* the 2^32 part of C */
        }
    }

    /* Conditional subtract p */
    uint32_t t[8];
    int64_t bw = 0;
    for (int i = 0; i < 8; i++) {
        int64_t d = (int64_t)s[i] - (int64_t)SECP256K1_P[i] - bw;
        t[i] = (uint32_t)d;
        bw = (d < 0) ? 1 : 0;
    }
    if (!bw) {
        for (int i = 0; i < 8; i++) res->d[i] = t[i];
    } else {
        for (int i = 0; i < 8; i++) res->d[i] = s[i];
    }
}

/* fe_sqr - squaring mod p (uses fe_mul) */
__device__ void fe_sqr(const fe_t *a, fe_t *r) {
    fe_mul(a, a, r);
}

/*
 * fe_inv - inversion using Fermat's little theorem: a^(p-2) mod p.
 * p-2 = FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2D
 * Binary exponentiation. p-2 in LE limbs:
 *   {0xFFFFFC2D, 0xFFFFFFFE, 0xFFFFFFFF, ..., 0xFFFFFFFF}
 */
__device__ __noinline__ void fe_inv(const fe_t *a, fe_t *r) {
    fe_t base;
    fe_copy(&base, a);
    fe_set_int(r, 1);

    uint32_t exp_le[8] = {
        0xFFFFFC2D, 0xFFFFFFFE, 0xFFFFFFFF, 0xFFFFFFFF,
        0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF
    };

    /* Process bits from MSB (bit 255) to LSB (bit 0) */
    for (int bit = 255; bit >= 0; bit--) {
        fe_t tmp;
        fe_sqr(r, &tmp);
        memcpy(r, &tmp, sizeof(fe_t));
        int limb = bit / 32;
        int pos = bit % 32;
        if ((exp_le[limb] >> pos) & 1) {
            fe_mul(r, &base, &tmp);
            memcpy(r, &tmp, sizeof(fe_t));
        }
    }
}

/* Convert 32 big-endian bytes to field element (LE limbs).
   bytes[0] is most significant, d[7] is most significant limb. */
__device__ void fe_from_bytes_be(const uint8_t bytes[32], fe_t *r) {
    for (int i = 0; i < 8; i++) {
        int off = (7 - i) * 4;
        r->d[i] = ((uint32_t)bytes[off] << 24) |
                  ((uint32_t)bytes[off + 1] << 16) |
                  ((uint32_t)bytes[off + 2] << 8) |
                  ((uint32_t)bytes[off + 3]);
    }
}

/* Convert field element (LE limbs) to 32 big-endian bytes */
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
 * PART 7: secp256k1 point operations (Jacobian coordinates)
 *
 * Point at infinity: Z = 0.
 * ================================================================ */

__device__ void pt_set_infinity(pt_t *P) {
    fe_set_zero(&P->x);
    fe_set_one(&P->y);
    fe_set_zero(&P->z);
}

__device__ int pt_is_infinity(const pt_t *P) {
    return fe_is_zero(&P->z);
}

/*
 * pt_double - point doubling for a=0 (secp256k1).
 *
 * Formula:
 *   if Y1==0: return infinity
 *   A = Y1^2, B = 4*X1*A, C = 8*A^2
 *   D = 3*X1^2
 *   X3 = D^2 - 2*B
 *   Y3 = D*(B - X3) - C
 *   Z3 = 2*Y1*Z1
 */
__device__ __noinline__ void pt_double(const pt_t *P, pt_t *R) {
    if (fe_is_zero(&P->y) || fe_is_zero(&P->z)) {
        memset(R, 0, sizeof(pt_t));
        return;
    }

    fe_t A, B, C, D, tmp, tmp2;

    fe_sqr(&P->y, &A);                                         /* A = Y1^2 */
    fe_mul(&P->x, &A, &tmp);
    fe_add(&tmp, &tmp, &tmp2);
    fe_add(&tmp2, &tmp2, &B);                                  /* B = 4*X1*A */
    fe_sqr(&A, &tmp);
    fe_add(&tmp, &tmp, &tmp2);
    fe_add(&tmp2, &tmp2, &tmp);
    fe_add(&tmp, &tmp, &C);                                    /* C = 8*A^2 */
    fe_sqr(&P->x, &tmp);
    fe_add(&tmp, &tmp, &tmp2);
    fe_add(&tmp2, &tmp, &D);                                   /* D = 3*X1^2 */

    fe_sqr(&D, &tmp);                                          /* D^2 */
    fe_add(&B, &B, &tmp2);
    fe_sub(&tmp, &tmp2, &R->x);                                /* X3 = D^2 - 2*B */

    fe_sub(&B, &R->x, &tmp);
    fe_mul(&D, &tmp, &tmp2);
    fe_sub(&tmp2, &C, &R->y);                                  /* Y3 = D*(B-X3) - C */

    fe_mul(&P->y, &P->z, &tmp);
    fe_add(&tmp, &tmp, &R->z);                                 /* Z3 = 2*Y1*Z1 */
}

/*
 * pt_add_mixed - add Jacobian P + affine (x2, y2).
 * Mixed addition: affine point has Z=1.
 *
 * if P is infinity: R = (x2, y2, 1); return
 * Z1sq = Z1^2, Z1cu = Z1*Z1sq
 * U2 = x2*Z1sq, S2 = y2*Z1cu
 * H = U2 - X1, Rv = S2 - Y1
 * if H==0: if Rv==0 return double, else return infinity
 * HH = H^2, HHH = H*HH, U1HH = X1*HH
 * X3 = Rv^2 - HHH - 2*U1HH
 * Y3 = Rv*(U1HH - X3) - Y1*HHH
 * Z3 = Z1*H
 */
__device__ __noinline__ void pt_add_mixed(const pt_t *P, const fe_t *x2, const fe_t *y2, pt_t *R) {
    if (fe_is_zero(&P->z)) {
        fe_copy(&R->x, x2);
        fe_copy(&R->y, y2);
        fe_set_int(&R->z, 1);
        return;
    }

    fe_t Z1sq, Z1cu, U2, S2, H, Rv, HH, HHH, U1HH, tmp, tmp2;

    fe_sqr(&P->z, &Z1sq);
    fe_mul(&P->z, &Z1sq, &Z1cu);
    fe_mul(x2, &Z1sq, &U2);
    fe_mul(y2, &Z1cu, &S2);
    fe_sub(&U2, &P->x, &H);
    fe_sub(&S2, &P->y, &Rv);

    if (fe_is_zero(&H)) {
        if (fe_is_zero(&Rv)) {
            pt_double(P, R);
            return;
        }
        memset(R, 0, sizeof(pt_t));
        return;
    }

    fe_sqr(&H, &HH);
    fe_mul(&H, &HH, &HHH);
    fe_mul(&P->x, &HH, &U1HH);

    /* X3 = Rv^2 - HHH - 2*U1HH */
    fe_sqr(&Rv, &tmp);
    fe_sub(&tmp, &HHH, &R->x);
    fe_add(&U1HH, &U1HH, &tmp2);
    fe_sub(&R->x, &tmp2, &R->x);

    /* Y3 = Rv*(U1HH - X3) - Y1*HHH */
    fe_sub(&U1HH, &R->x, &tmp);
    fe_mul(&Rv, &tmp, &R->y);
    fe_mul(&P->y, &HHH, &tmp);
    fe_sub(&R->y, &tmp, &R->y);

    /* Z3 = Z1 * H */
    fe_mul(&P->z, &H, &R->z);
}

/*
 * scalar_mult_G - compute scalar * G using 4-bit windowed method.
 * scalar is 32 bytes big-endian (private key).
 * Uses precomputed table PRECOMP_GX/GY[0..14] = [1*G..15*G] in affine.
 * Processes 4 bits at a time: 64 windows of 4 doublings + conditional add.
 * Total: 256 doublings + up to 64 additions (vs ~128 additions with naive).
 */
__device__ __noinline__ void scalar_mult_G(const uint8_t scalar_be[32], pt_t *R) {
    /* Start with point at infinity */
    memset(R, 0, sizeof(pt_t));

    /* Process from highest nibble (bits 255-252) to lowest (bits 3-0).
       scalar_be[0] has the most significant byte.
       Nibble i (0..63): bits (255-4i)..(252-4i)
       byte = i/2, shift = (i&1)?0:4 */
    for (int i = 0; i < 64; i++) {
        /* 4 doublings */
        pt_t tmp;
        pt_double(R, &tmp); memcpy(R, &tmp, sizeof(pt_t));
        pt_double(R, &tmp); memcpy(R, &tmp, sizeof(pt_t));
        pt_double(R, &tmp); memcpy(R, &tmp, sizeof(pt_t));
        pt_double(R, &tmp); memcpy(R, &tmp, sizeof(pt_t));

        /* Extract 4-bit window */
        int byte_idx = i / 2;
        int nibble = (i & 1) ? (scalar_be[byte_idx] & 0x0F)
                              : (scalar_be[byte_idx] >> 4);

        if (nibble > 0) {
            /* Add PRECOMP[nibble-1] = nibble*G */
            fe_t px, py;
            fe_set(&px, PRECOMP_GX[nibble - 1]);
            fe_set(&py, PRECOMP_GY[nibble - 1]);
            pt_add_mixed(R, &px, &py, &tmp);
            memcpy(R, &tmp, sizeof(pt_t));
        }
    }
}

/*
 * pt_to_compressed - convert Jacobian point to compressed pubkey (33 bytes).
 * Compute Z_inv = fe_inv(Z), Z2_inv = Z_inv^2, Z3_inv = Z2_inv * Z_inv
 * x = X * Z2_inv, y = Y * Z3_inv
 * out[0] = 0x02 if y is even (y.d[0] & 1 == 0), else 0x03
 * out[1..32] = fe_to_bytes_be(x)
 */
__device__ __noinline__ void pt_to_compressed(const pt_t *P, uint8_t out[33]) {
    fe_t z_inv, z2_inv, z3_inv, x_aff, y_aff;

    fe_inv(&P->z, &z_inv);
    fe_sqr(&z_inv, &z2_inv);
    fe_mul(&z_inv, &z2_inv, &z3_inv);

    fe_mul(&P->x, &z2_inv, &x_aff);
    fe_mul(&P->y, &z3_inv, &y_aff);

    out[0] = (y_aff.d[0] & 1) ? 0x03 : 0x02;
    fe_to_bytes_be(&x_aff, out + 1);
}


/* ================================================================
 * PART 8: RIPEMD-160
 * ================================================================ */

#define ROTL32(x,n) (((x)<<(n))|((x)>>(32-(n))))

/* Round functions */
#define RMD_F1(x,y,z) ((x)^(y)^(z))
#define RMD_F2(x,y,z) (((x)&(y))|((~(x))&(z)))
#define RMD_F3(x,y,z) (((x)|(~(y)))^(z))
#define RMD_F4(x,y,z) (((x)&(z))|((y)&(~(z))))
#define RMD_F5(x,y,z) ((x)^((y)|(~(z))))

/* RIPEMD-160 lookup tables */
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

__device__ const uint32_t RMD_KL[5] = {
    0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E
};

__device__ const uint32_t RMD_KR[5] = {
    0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000
};

/* RIPEMD-160 round function dispatch */
__device__ uint32_t rmd_f(int j, uint32_t x, uint32_t y, uint32_t z) {
    if (j < 16) return RMD_F1(x, y, z);
    if (j < 32) return RMD_F2(x, y, z);
    if (j < 48) return RMD_F3(x, y, z);
    if (j < 64) return RMD_F4(x, y, z);
    return RMD_F5(x, y, z);
}

/*
 * ripemd160 - RIPEMD-160 hash.
 * For our use case, msg is always 32 bytes (SHA-256 output). One 64-byte block.
 *
 * Uses two parallel computation paths (left and right).
 * Left uses f1,f2,f3,f4,f5 for rounds 0-4.
 * Right uses f5,f4,f3,f2,f1 for rounds 0-4.
 *
 * Each step: T = ROTL32(a + f(b,c,d) + msg[word_sel[j]] + K, rot[j]) + e
 *            a=e; e=d; d=ROTL32(c,10); c=b; b=T
 *
 * Final: t=h1+cl+dr; h1=h2+dl+er; h2=h3+el+ar; h3=h4+al+br; h4=h0+bl+cr; h0=t
 */
__device__ __noinline__ void ripemd160(const uint8_t *msg, int len, uint8_t hash[20]) {
    uint32_t h0 = 0x67452301, h1 = 0xEFCDAB89, h2 = 0x98BADCFE;
    uint32_t h3 = 0x10325476, h4 = 0xC3D2E1F0;

    /* Pad message to 64-byte block */
    uint8_t buf[64];
    memset(buf, 0, 64);
    memcpy(buf, msg, len);
    buf[len] = 0x80;

    /* Length in bits (little-endian, 8 bytes at offset 56) */
    uint64_t bitlen = (uint64_t)len * 8;
    for (int i = 0; i < 8; i++) buf[56 + i] = (uint8_t)(bitlen >> (i * 8));

    /* Parse block into 16 little-endian 32-bit words */
    uint32_t X[16];
    for (int i = 0; i < 16; i++) {
        X[i] = ((uint32_t)buf[i * 4]) |
               ((uint32_t)buf[i * 4 + 1] << 8) |
               ((uint32_t)buf[i * 4 + 2] << 16) |
               ((uint32_t)buf[i * 4 + 3] << 24);
    }

    /* Left path */
    uint32_t al = h0, bl = h1, cl = h2, dl = h3, el = h4;
    /* Right path */
    uint32_t ar = h0, br = h1, cr = h2, dr = h3, er = h4;

    for (int j = 0; j < 80; j++) {
        int round = j / 16;

        /* Left round function (f1,f2,f3,f4,f5) */
        uint32_t fl = rmd_f(j, bl, cl, dl);

        /* Right round function (reversed: f5,f4,f3,f2,f1) */
        uint32_t fr = rmd_f(79 - j, br, cr, dr);

        /* Left step */
        uint32_t tl = ROTL32(al + fl + X[RMD_RL[j]] + RMD_KL[round], RMD_SL[j]) + el;
        al = el; el = dl; dl = ROTL32(cl, 10); cl = bl; bl = tl;

        /* Right step */
        uint32_t tr = ROTL32(ar + fr + X[RMD_RR[j]] + RMD_KR[round], RMD_SR[j]) + er;
        ar = er; er = dr; dr = ROTL32(cr, 10); cr = br; br = tr;
    }

    /* Final addition */
    uint32_t t = h1 + cl + dr;
    h1 = h2 + dl + er;
    h2 = h3 + el + ar;
    h3 = h4 + al + br;
    h4 = h0 + bl + cr;
    h0 = t;

    /* Output little-endian */
    for (int i = 0; i < 4; i++) {
        hash[i]      = (uint8_t)(h0 >> (i * 8));
        hash[4 + i]  = (uint8_t)(h1 >> (i * 8));
        hash[8 + i]  = (uint8_t)(h2 >> (i * 8));
        hash[12 + i] = (uint8_t)(h3 >> (i * 8));
        hash[16 + i] = (uint8_t)(h4 >> (i * 8));
    }
}


/* ================================================================
 * PART 9: BIP32 derivation
 * ================================================================ */

/*
 * hash160 - SHA-256 then RIPEMD-160 of data (33-byte compressed pubkey).
 */
__device__ __noinline__ void hash160(const uint8_t *data, int len, uint8_t hash[20]) {
    uint8_t sha_out[32];
    sha256_full(data, len, sha_out);
    ripemd160(sha_out, 32, hash);
}

/*
 * scalar_add_mod_n - add two 256-bit big-endian numbers modulo secp256k1 order n.
 * result = (a + b) mod n. All arrays are 32 bytes big-endian.
 */
__device__ void scalar_add_mod_n(const uint8_t a[32], const uint8_t b[32], uint8_t result[32]) {
    uint16_t carry = 0;
    uint8_t sum[32];
    for (int i = 31; i >= 0; i--) {
        uint16_t s = (uint16_t)a[i] + (uint16_t)b[i] + carry;
        sum[i] = (uint8_t)s;
        carry = s >> 8;
    }

    /* n in big-endian bytes */
    static const uint8_t n_be[32] = {
        0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF,
        0xFF,0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFE,
        0xBA,0xAE,0xDC,0xE6, 0xAF,0x48,0xA0,0x3B,
        0xBF,0xD2,0x5E,0x8C, 0xD0,0x36,0x41,0x41
    };

    /* Check if carry or sum >= n */
    int gte = 0;
    if (carry) {
        gte = 1;
    } else {
        for (int i = 0; i < 32; i++) {
            if (sum[i] > n_be[i]) { gte = 1; break; }
            if (sum[i] < n_be[i]) break;
        }
    }

    if (gte) {
        int16_t borrow = 0;
        for (int i = 31; i >= 0; i--) {
            int16_t diff = (int16_t)sum[i] - (int16_t)n_be[i] - borrow;
            if (diff < 0) { diff += 256; borrow = 1; } else { borrow = 0; }
            result[i] = (uint8_t)diff;
        }
    } else {
        memcpy(result, sum, 32);
    }
}

/*
 * bip32_from_seed - derive master key and chain code from 64-byte seed.
 * HMAC-SHA512(key="Bitcoin seed" (12 bytes), data=seed) -> key(32) + chain(32)
 */
__device__ void bip32_from_seed(const uint8_t seed[64], uint8_t key[32], uint8_t chain[32]) {
    uint8_t out[64];
    hmac_sha512((const uint8_t *)"Bitcoin seed", 12, seed, 64, out);
    memcpy(key, out, 32);
    memcpy(chain, out + 32, 32);
}

/*
 * bip32_derive_hardened - derive hardened child key.
 * data = 0x00 || key(32 bytes) || ser32(index | 0x80000000) = 37 bytes
 * HMAC-SHA512(key=chain, data=data) -> IL(32) || IR(32)
 * child_key = (parse256(IL) + parse256(key)) mod n
 * child_chain = IR
 */
__device__ __noinline__ void bip32_derive_hardened(const uint8_t key[32], const uint8_t chain[32],
                                       uint32_t index,
                                       uint8_t child_key[32], uint8_t child_chain[32])
{
    uint8_t data[37];
    data[0] = 0x00;
    memcpy(data + 1, key, 32);
    uint32_t idx = index | 0x80000000u;
    data[33] = (uint8_t)(idx >> 24);
    data[34] = (uint8_t)(idx >> 16);
    data[35] = (uint8_t)(idx >> 8);
    data[36] = (uint8_t)(idx);

    uint8_t out[64];
    hmac_sha512(chain, 32, data, 37, out);

    scalar_add_mod_n(out, key, child_key);
    memcpy(child_chain, out + 32, 32);
}

/*
 * bip32_derive_normal - derive normal (non-hardened) child key.
 * Compute public key: P = key * G, compress to 33 bytes
 * data = compressed_pubkey(33 bytes) || ser32(index) = 37 bytes
 * HMAC-SHA512(key=chain, data=data) -> IL || IR
 * child_key = (parse256(IL) + parse256(key)) mod n
 * child_chain = IR
 */
__device__ __noinline__ void bip32_derive_normal(const uint8_t key[32], const uint8_t chain[32],
                                     uint32_t index,
                                     uint8_t child_key[32], uint8_t child_chain[32])
{
    pt_t P;
    scalar_mult_G(key, &P);

    uint8_t pubkey[33];
    pt_to_compressed(&P, pubkey);

    uint8_t data[37];
    memcpy(data, pubkey, 33);
    data[33] = (uint8_t)(index >> 24);
    data[34] = (uint8_t)(index >> 16);
    data[35] = (uint8_t)(index >> 8);
    data[36] = (uint8_t)(index);

    uint8_t out[64];
    hmac_sha512(chain, 32, data, 37, out);

    scalar_add_mod_n(out, key, child_key);
    memcpy(child_chain, out + 32, 32);
}

/* Configurable BIP32 derivation path (default BIP84 m/84'/0'/0'/0/0).
 * c_path[i] = child index; c_path_hard[i]!=0 => hardened.
 * c_path_len = number of levels. Set via bip39pass_set_path(); default
 * below (BIP84 external chain, first address) used if never called. */
__constant__ uint32_t c_path[8]      = {84u, 0u, 0u, 0u, 0u, 0u, 0u, 0u};
__constant__ uint8_t  c_path_hard[8] = {1u,  1u, 1u, 0u, 0u, 0u, 0u, 0u};
__constant__ int      c_path_len     = 5;

/*
 * full_derive - complete BIP32 derivation: seed -> c_path (default BIP84
 * m/84'/0'/0'/0/0) -> compressed pubkey -> hash160.
 */
__device__ __noinline__ void full_derive(const uint8_t seed[64], uint8_t h160[20]) {
    /* master from seed, then walk the configurable c_path (default BIP84). */
    uint8_t k[32], c[32];
    bip32_from_seed(seed, k, c);

    for (int lvl = 0; lvl < c_path_len; lvl++) {
        uint8_t nk[32], nc[32];
        if (c_path_hard[lvl])
            bip32_derive_hardened(k, c, c_path[lvl], nk, nc);
        else
            bip32_derive_normal(k, c, c_path[lvl], nk, nc);
        for (int i = 0; i < 32; i++) { k[i] = nk[i]; c[i] = nc[i]; }
    }

    /* Final public key, compress, hash160 (P2WPKH/P2PKH share hash160). */
    pt_t pub;
    scalar_mult_G(k, &pub);

    uint8_t pubkey[33];
    pt_to_compressed(&pub, pubkey);

    hash160(pubkey, 33, h160);
}


/* ================================================================
 * PART 9b: Keccak-256 (Ethereum) + ETH address derivation
 *
 * Keccak-f[1600], rate 1088 bits = 136 bytes, capacity 512.
 * Ethereum uses ORIGINAL Keccak padding (0x01 ... 0x80), NOT SHA3 (0x06).
 * Input here is always 64 bytes (uncompressed pubkey x||y) -> one block
 * (64 < 136). ETH address = keccak256(x||y)[12:32] (last 20 bytes).
 * ================================================================ */

__device__ __constant__ uint64_t KECCAK_RC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL,
    0x8000000080008000ULL, 0x000000000000808bULL, 0x0000000080000001ULL,
    0x8000000080008081ULL, 0x8000000000008009ULL, 0x000000000000008aULL,
    0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL,
    0x8000000000008003ULL, 0x8000000000008002ULL, 0x8000000000000080ULL,
    0x000000000000800aULL, 0x800000008000000aULL, 0x8000000080008081ULL,
    0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};
__device__ __constant__ int KECCAK_ROT[25] = {
     0, 1, 62, 28, 27,
    36, 44, 6, 55, 20,
     3, 10, 43, 25, 39,
    41, 45, 15, 21, 8,
    18, 2, 61, 56, 14
};

#define KROTL64(x,n) (((x) << (n)) | ((x) >> (64 - (n))))

__device__ __noinline__ void keccak_f1600(uint64_t s[25]) {
    for (int round = 0; round < 24; round++) {
        uint64_t C[5], D[5];
        #pragma unroll
        for (int x = 0; x < 5; x++)
            C[x] = s[x] ^ s[x+5] ^ s[x+10] ^ s[x+15] ^ s[x+20];
        #pragma unroll
        for (int x = 0; x < 5; x++)
            D[x] = C[(x+4)%5] ^ KROTL64(C[(x+1)%5], 1);
        #pragma unroll
        for (int x = 0; x < 5; x++)
            for (int y = 0; y < 25; y += 5)
                s[y + x] ^= D[x];
        /* Rho + Pi */
        uint64_t B[25];
        #pragma unroll
        for (int x = 0; x < 5; x++)
            for (int y = 0; y < 5; y++) {
                int idx = x + 5*y;
                int r = KECCAK_ROT[idx];
                int newidx = y + 5*((2*x + 3*y) % 5);
                B[newidx] = (r == 0) ? s[idx] : KROTL64(s[idx], r);
            }
        /* Chi */
        #pragma unroll
        for (int y = 0; y < 25; y += 5)
            for (int x = 0; x < 5; x++)
                s[y+x] = B[y+x] ^ ((~B[y+((x+1)%5)]) & B[y+((x+2)%5)]);
        /* Iota */
        s[0] ^= KECCAK_RC[round];
    }
}

/* keccak256 of a message of length len (<= 135 bytes, single block here). */
__device__ __noinline__ void keccak256(const uint8_t *msg, int len, uint8_t out[32]) {
    uint8_t block[136];
    memset(block, 0, 136);
    for (int i = 0; i < len; i++) block[i] = msg[i];
    block[len] = 0x01;          /* Keccak (Ethereum) padding start */
    block[135] |= 0x80;         /* padding end (rate 136) */

    uint64_t s[25];
    #pragma unroll
    for (int i = 0; i < 25; i++) s[i] = 0;
    /* absorb single block: state[i] ^= little-endian lane from block */
    for (int i = 0; i < 17; i++) {
        uint64_t lane = 0;
        for (int b = 0; b < 8; b++)
            lane |= ((uint64_t)block[i*8 + b]) << (8*b);
        s[i] ^= lane;
    }
    keccak_f1600(s);
    /* squeeze 32 bytes (lanes 0..3, little-endian) */
    for (int i = 0; i < 4; i++)
        for (int b = 0; b < 8; b++)
            out[i*8 + b] = (uint8_t)(s[i] >> (8*b));
}

/*
 * pt_to_uncompressed_xy - affine x||y (64 bytes, big-endian each) from Jacobian.
 */
__device__ __noinline__ void pt_to_uncompressed_xy(const pt_t *P, uint8_t out[64]) {
    fe_t z_inv, z2_inv, z3_inv, x_aff, y_aff;
    fe_inv(&P->z, &z_inv);
    fe_sqr(&z_inv, &z2_inv);
    fe_mul(&z_inv, &z2_inv, &z3_inv);
    fe_mul(&P->x, &z2_inv, &x_aff);
    fe_mul(&P->y, &z3_inv, &y_aff);
    fe_to_bytes_be(&x_aff, out);
    fe_to_bytes_be(&y_aff, out + 32);
}

/*
 * eth_derive - seed -> c_path -> uncompressed pubkey -> keccak256 -> last 20B.
 * Mirrors full_derive but emits an Ethereum address instead of hash160.
 */
__device__ __noinline__ void eth_derive(const uint8_t seed[64], uint8_t addr[20]) {
    uint8_t k[32], c[32];
    bip32_from_seed(seed, k, c);
    for (int lvl = 0; lvl < c_path_len; lvl++) {
        uint8_t nk[32], nc[32];
        if (c_path_hard[lvl])
            bip32_derive_hardened(k, c, c_path[lvl], nk, nc);
        else
            bip32_derive_normal(k, c, c_path[lvl], nk, nc);
        for (int i = 0; i < 32; i++) { k[i] = nk[i]; c[i] = nc[i]; }
    }
    pt_t pub;
    scalar_mult_G(k, &pub);
    uint8_t xy[64];
    pt_to_uncompressed_xy(&pub, xy);
    uint8_t kh[32];
    keccak256(xy, 64, kh);
    for (int i = 0; i < 20; i++) addr[i] = kh[i + 12];
}


/* ================================================================
 * PART 10: English BIP39 wordlist storage
 * ================================================================ */

/* Global device memory, filled by host via gpu_init_wordlist */
__device__ uint8_t d_wordlist[2048 * 9];  /* each word zero-padded to 9 bytes */
__device__ uint8_t d_wordlen[2048];        /* length of each word */

/*
 * build_mnemonic - concatenate English words separated by spaces.
 * Returns total length of mnemonic string.
 */
__device__ int build_mnemonic(const uint32_t indices[24], uint8_t *out) {
    int pos = 0;
    for (int w = 0; w < 24; w++) {
        if (w > 0) out[pos++] = ' ';
        int wi = indices[w];
        int wl = d_wordlen[wi];
        for (int c = 0; c < wl; c++) out[pos++] = d_wordlist[wi * 9 + c];
    }
    return pos;
}


/* ================================================================
 * PART 11: Target hash in constant memory
 * ================================================================ */

__constant__ uint8_t c_target_hash[20];

/* ================================================================
 * COREY PUZZLE: fixed kitten mnemonic + variable passphrase kernel
 * ================================================================ */
__constant__ char c_mnemonic[160];
__constant__ int  c_mnemonic_len;

extern "C" __global__ __launch_bounds__(64, 8) void check_passphrases(
    const uint8_t *d_pp, const int *d_pp_len, int pp_stride, int n,
    int *d_match)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= n) return;

    int plen = d_pp_len[tid];
    uint8_t salt[128];
    salt[0]='m'; salt[1]='n'; salt[2]='e'; salt[3]='m';
    salt[4]='o'; salt[5]='n'; salt[6]='i'; salt[7]='c';
    const uint8_t *pp = d_pp + (size_t)tid * pp_stride;
    for (int i = 0; i < plen; i++) salt[8 + i] = pp[i];
    int salt_len = 8 + plen;

    uint8_t seed[64];
    pbkdf2_sha512((const uint8_t *)c_mnemonic, c_mnemonic_len,
                  salt, salt_len, 2048, seed);

    uint8_t h160[20];
    full_derive(seed, h160);

    int match = 1;
    #pragma unroll
    for (int i = 0; i < 20; i++) {
        if (h160[i] != c_target_hash[i]) { match = 0; break; }
    }
    if (match) atomicExch(d_match, tid);
}

#include <stdlib.h>

extern "C" int corey_init(const char *mnemonic, int mlen, const uint8_t target_h160[20]) {
    char mbuf[160];
    memset(mbuf, 0, sizeof(mbuf));
    if (mlen > 159) return -1;
    memcpy(mbuf, mnemonic, mlen);
    cudaError_t e;
    e = cudaMemcpyToSymbol(c_mnemonic, mbuf, sizeof(mbuf)); if (e) return (int)e;
    e = cudaMemcpyToSymbol(c_mnemonic_len, &mlen, sizeof(int)); if (e) return (int)e;
    e = cudaMemcpyToSymbol(c_target_hash, target_h160, 20); if (e) return (int)e;
    return 0;
}

extern "C" int corey_run_batch(const uint8_t *h_pp, const int *h_pp_len,
                               int pp_stride, int n) {
    uint8_t *d_pp = NULL; int *d_pp_len = NULL; int *d_match = NULL;
    size_t pp_bytes = (size_t)n * pp_stride;
    cudaMalloc(&d_pp, pp_bytes);
    cudaMalloc(&d_pp_len, (size_t)n * sizeof(int));
    cudaMalloc(&d_match, sizeof(int));
    int neg = -1;
    cudaMemcpy(d_pp, h_pp, pp_bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_pp_len, h_pp_len, (size_t)n * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_match, &neg, sizeof(int), cudaMemcpyHostToDevice);

    int threads = 64;
    int blocks = (n + threads - 1) / threads;
    check_passphrases<<<blocks, threads>>>(d_pp, d_pp_len, pp_stride, n, d_match);
    cudaDeviceSynchronize();

    int match = -1;
    cudaMemcpy(&match, d_match, sizeof(int), cudaMemcpyDeviceToHost);
    cudaFree(d_pp); cudaFree(d_pp_len); cudaFree(d_match);
    return match;
}

/* ================================================================
 * Generic shared ABI (alias of corey_*). The Corey kitten puzzle and
 * any other FIXED-mnemonic + unknown-passphrase target use these.
 * ================================================================ */

/* Set a custom BIP32 path. levels[] = child indices, hardened[] = 1/0 per
 * level (hardened indices are the bare number, not +0x80000000). len<=8.
 * If never called, the default BIP84 m/84'/0'/0'/0/0 path applies. */
extern "C" int bip39pass_set_path(const uint32_t *levels, const uint8_t *hardened, int len) {
    if (len < 1 || len > 8) return -1;
    uint32_t lv[8]; uint8_t hd[8];
    memset(lv, 0, sizeof(lv)); memset(hd, 0, sizeof(hd));
    for (int i = 0; i < len; i++) { lv[i] = levels[i]; hd[i] = hardened[i] ? 1 : 0; }
    cudaError_t e;
    e = cudaMemcpyToSymbol(c_path, lv, sizeof(lv));      if (e) return (int)e;
    e = cudaMemcpyToSymbol(c_path_hard, hd, sizeof(hd)); if (e) return (int)e;
    e = cudaMemcpyToSymbol(c_path_len, &len, sizeof(int)); if (e) return (int)e;
    return 0;
}

extern "C" int bip39pass_init(const char *mnemonic, int mlen, const uint8_t target_h160[20]) {
    return corey_init(mnemonic, mlen, target_h160);
}
extern "C" int bip39pass_run_batch(const uint8_t *h_pp, const int *h_pp_len,
                                   int pp_stride, int n) {
    return corey_run_batch(h_pp, h_pp_len, pp_stride, n);
}

/* ================================================================
 * ETH MODE: VARIABLE 12-word mnemonic (from indices) + EMPTY passphrase
 *           -> PBKDF2 -> c_path -> uncompressed pubkey -> keccak256 -> ETH addr
 *
 * Distinct from the BTC hash160 path above (guarded by its own kernel +
 * symbols). Used by LogicBeach "Powerful Moss" (and any ETH BIP39 target).
 * c_target_eth holds a 20-byte Ethereum address (lowercase, raw bytes).
 * Word indices are fed as int32[n * WORDS_PER_MNEMONIC].
 * ================================================================ */

#define ETH_WORDS 12
__constant__ uint8_t c_target_eth[20];

/* Load the 2048-word English BIP39 list onto the device (each word zero-padded
 * to 9 bytes). words_flat = 2048*9 bytes, lens = 2048 bytes. */
extern "C" int bip39pass_load_wordlist(const uint8_t *words_flat, const uint8_t *lens) {
    cudaError_t e;
    e = cudaMemcpyToSymbol(d_wordlist, words_flat, 2048 * 9); if (e) return (int)e;
    e = cudaMemcpyToSymbol(d_wordlen, lens, 2048);            if (e) return (int)e;
    return 0;
}

extern "C" int bip39pass_set_eth_target(const uint8_t target_eth[20]) {
    cudaError_t e = cudaMemcpyToSymbol(c_target_eth, target_eth, 20);
    return (int)e;
}

extern "C" __global__ __launch_bounds__(64, 8) void check_mnemonics_eth(
    const int *d_idx, int n, int *d_match)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= n) return;

    uint32_t indices[24];
    const int *src = d_idx + (size_t)tid * ETH_WORDS;
    #pragma unroll
    for (int w = 0; w < ETH_WORDS; w++) indices[w] = (uint32_t)src[w];

    /* build_mnemonic expects indices[24]; only the first ETH_WORDS are used. */
    uint8_t mnem[160];
    int pos = 0;
    for (int w = 0; w < ETH_WORDS; w++) {
        if (w > 0) mnem[pos++] = ' ';
        int wi = indices[w];
        int wl = d_wordlen[wi];
        for (int c = 0; c < wl; c++) mnem[pos++] = d_wordlist[wi * 9 + c];
    }

    /* empty passphrase -> salt is exactly "mnemonic" (8 bytes) */
    uint8_t salt[8];
    salt[0]='m'; salt[1]='n'; salt[2]='e'; salt[3]='m';
    salt[4]='o'; salt[5]='n'; salt[6]='i'; salt[7]='c';

    uint8_t seed[64];
    pbkdf2_sha512(mnem, pos, salt, 8, 2048, seed);

    uint8_t addr[20];
    eth_derive(seed, addr);

    int match = 1;
    #pragma unroll
    for (int i = 0; i < 20; i++) {
        if (addr[i] != c_target_eth[i]) { match = 0; break; }
    }
    if (match) atomicExch(d_match, tid);
}

/* Run one batch of n mnemonics (each ETH_WORDS int indices). Returns the
 * matching row index, or -1. Caller must have loaded the wordlist, set the
 * path (e.g. 44'/60'/0'/0/0), and set the ETH target. */
extern "C" int bip39pass_run_eth_batch(const int *h_idx, int n) {
    int *d_idx = NULL; int *d_match = NULL;
    size_t idx_bytes = (size_t)n * ETH_WORDS * sizeof(int);
    cudaMalloc(&d_idx, idx_bytes);
    cudaMalloc(&d_match, sizeof(int));
    int neg = -1;
    cudaMemcpy(d_idx, h_idx, idx_bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_match, &neg, sizeof(int), cudaMemcpyHostToDevice);

    int threads = 64;
    int blocks = (n + threads - 1) / threads;
    check_mnemonics_eth<<<blocks, threads>>>(d_idx, n, d_match);
    cudaDeviceSynchronize();

    int match = -1;
    cudaMemcpy(&match, d_match, sizeof(int), cudaMemcpyDeviceToHost);
    cudaFree(d_idx); cudaFree(d_match);
    return match;
}

/* ---------------------------------------------------------------
 * ETH MODE, MULTI-TARGET.
 * Same derivation as check_mnemonics_eth, but compares against up to
 * ETH_MAX_TARGETS 20-byte addresses so that synthetic WITNESSES travel the
 * exact same path as the real target inside one run (a negative is only
 * trusted if a planted witness in the same run would have been found).
 * d_match[t] receives the row index of the (last) row matching target t,
 * or stays -1. Host: bip39pass_set_eth_targets() then
 * bip39pass_run_eth_batch_multi().
 * --------------------------------------------------------------- */
#define ETH_MAX_TARGETS 16
__constant__ uint8_t c_eth_targets[ETH_MAX_TARGETS * 20];
__constant__ int     c_eth_ntargets = 0;

extern "C" int bip39pass_set_eth_targets(const uint8_t *targets_flat, int ntargets) {
    if (ntargets < 1 || ntargets > ETH_MAX_TARGETS) return -1;
    cudaError_t e;
    e = cudaMemcpyToSymbol(c_eth_targets, targets_flat, (size_t)ntargets * 20); if (e) return (int)e;
    e = cudaMemcpyToSymbol(c_eth_ntargets, &ntargets, sizeof(int));             if (e) return (int)e;
    return 0;
}

extern "C" __global__ __launch_bounds__(64, 8) void check_mnemonics_eth_multi(
    const int *d_idx, int n, int *d_match)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= n) return;

    const int *src = d_idx + (size_t)tid * ETH_WORDS;
    uint8_t mnem[160];
    int pos = 0;
    for (int w = 0; w < ETH_WORDS; w++) {
        if (w > 0) mnem[pos++] = ' ';
        int wi = src[w];
        int wl = d_wordlen[wi];
        for (int c = 0; c < wl; c++) mnem[pos++] = d_wordlist[wi * 9 + c];
    }
    uint8_t salt[8];
    salt[0]='m'; salt[1]='n'; salt[2]='e'; salt[3]='m';
    salt[4]='o'; salt[5]='n'; salt[6]='i'; salt[7]='c';

    uint8_t seed[64];
    pbkdf2_sha512(mnem, pos, salt, 8, 2048, seed);
    uint8_t addr[20];
    eth_derive(seed, addr);

    for (int t = 0; t < c_eth_ntargets; t++) {
        const uint8_t *tg = c_eth_targets + t * 20;
        int match = 1;
        #pragma unroll
        for (int i = 0; i < 20; i++) {
            if (addr[i] != tg[i]) { match = 0; break; }
        }
        if (match) atomicExch(d_match + t, tid);
    }
}

/* out_match must hold ETH_MAX_TARGETS ints; each is set to the matching row
 * index for that target or -1. Returns 0 or a CUDA error code. */
extern "C" int bip39pass_run_eth_batch_multi(const int *h_idx, int n, int *out_match) {
    int *d_idx = NULL; int *d_match = NULL;
    size_t idx_bytes = (size_t)n * ETH_WORDS * sizeof(int);
    cudaError_t e;
    e = cudaMalloc(&d_idx, idx_bytes);                        if (e) return (int)e;
    e = cudaMalloc(&d_match, ETH_MAX_TARGETS * sizeof(int));  if (e) { cudaFree(d_idx); return (int)e; }
    int neg[ETH_MAX_TARGETS];
    for (int i = 0; i < ETH_MAX_TARGETS; i++) neg[i] = -1;
    cudaMemcpy(d_idx, h_idx, idx_bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_match, neg, sizeof(neg), cudaMemcpyHostToDevice);

    int threads = 64;
    int blocks = (n + threads - 1) / threads;
    check_mnemonics_eth_multi<<<blocks, threads>>>(d_idx, n, d_match);
    e = cudaDeviceSynchronize();
    if (e) { cudaFree(d_idx); cudaFree(d_match); return (int)e; }

    cudaMemcpy(out_match, d_match, sizeof(neg), cudaMemcpyDeviceToHost);
    cudaFree(d_idx); cudaFree(d_match);
    return 0;
}

/* ================================================================
 * BTC WORD-BRUTE MODE: VARIABLE 12-word mnemonic ENUMERATED ON-DEVICE from
 *   per-position candidate lists -> on-device BIP39 checksum (÷16) -> PBKDF2
 *   -> c_path (default BIP84 m/84'/0'/0'/0/0) -> hash160 -> compare to up to
 *   16 target hash160 (match ANY = win).
 *
 * Used to solve a timelocked P2SH puzzle where each word position had a
 * short list of candidates instead of a single fixed word. The host passes
 * ONLY the compact candidate lists; the GPU enumerates the full mixed-radix
 * product internally (no giant host transfer). Every GPU hit is RE-DERIVED
 * on CPU (bip_utils) before being declared -> zero false positives.
 * Additive to this shared engine; touches no existing symbol.
 * ================================================================ */

#define BTC_WORDS 12
#define BTC_MAX_TARGETS 16

__device__   uint16_t d_btc_cand[12 * 2048];   /* candidate word-indices, flattened per position */
__constant__ int      c_btc_count[12];         /* # candidates per position */
__constant__ int      c_btc_off[12];           /* offset of position p within d_btc_cand */
__constant__ uint8_t  c_btc_targets[BTC_MAX_TARGETS * 20];
__constant__ int      c_btc_ntargets;

/* BIP39 checksum for a 12-word mnemonic given by word indices.
 * 12*11 = 132 bits = 128-bit entropy + 4-bit checksum;
 * checksum == top 4 bits of SHA256(entropy16). */
__device__ __forceinline__ int btc_valid_checksum(const uint32_t idx[BTC_WORDS]) {
    uint8_t bits[17];
    #pragma unroll
    for (int i = 0; i < 17; i++) bits[i] = 0;
    int bitpos = 0;
    for (int w = 0; w < BTC_WORDS; w++) {
        uint32_t v = idx[w] & 0x7FFu;             /* 11 bits, MSB first */
        for (int b = 10; b >= 0; b--) {
            if ((v >> b) & 1u) bits[bitpos >> 3] |= (uint8_t)(0x80u >> (bitpos & 7));
            bitpos++;
        }
    }
    uint8_t cs = (uint8_t)((bits[16] >> 4) & 0x0F);   /* bits 128..131 */
    uint8_t h[32];
    sha256_full(bits, 16, h);
    return (int)(((h[0] >> 4) & 0x0F) == cs);
}

extern "C" __global__ __launch_bounds__(64, 8) void check_mnemonics_btc(
    unsigned long long base, unsigned long long end,
    unsigned long long total, unsigned long long *d_match)
{
    unsigned long long tid = base + (unsigned long long)blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= end || tid >= total) return;

    /* mixed-radix decode: least-significant radix = position 11 */
    uint32_t idx[BTC_WORDS];
    unsigned long long t = tid;
    for (int p = BTC_WORDS - 1; p >= 0; p--) {
        unsigned long long cnt = (unsigned long long)c_btc_count[p];
        int sel = (int)(t % cnt);
        t /= cnt;
        idx[p] = (uint32_t)d_btc_cand[c_btc_off[p] + sel];
    }

    if (!btc_valid_checksum(idx)) return;

    uint8_t mnem[160];
    int pos = 0;
    for (int w = 0; w < BTC_WORDS; w++) {
        if (w > 0) mnem[pos++] = ' ';
        int wi = idx[w];
        int wl = d_wordlen[wi];
        for (int c = 0; c < wl; c++) mnem[pos++] = d_wordlist[wi * 9 + c];
    }

    uint8_t salt[8] = {'m','n','e','m','o','n','i','c'};
    uint8_t seed[64];
    pbkdf2_sha512(mnem, pos, salt, 8, 2048, seed);

    uint8_t h160[20];
    full_derive(seed, h160);

    for (int ti = 0; ti < c_btc_ntargets; ti++) {
        const uint8_t *tgt = c_btc_targets + (size_t)ti * 20;
        int m = 1;
        #pragma unroll
        for (int i = 0; i < 20; i++) if (h160[i] != tgt[i]) { m = 0; break; }
        if (m) { atomicMin(d_match, tid); return; }
    }
}

/* Load candidate lists. cand_flat = concatenated per-position uint16 word-index
 * lists (length total_cand), counts[12], offs[12]. */
extern "C" int btc_load_candidates(const uint16_t *cand_flat, int total_cand,
                                   const int *counts, const int *offs) {
    if (total_cand < 1 || total_cand > 12 * 2048) return -100;
    cudaError_t e;
    e = cudaMemcpyToSymbol(d_btc_cand, cand_flat, (size_t)total_cand * sizeof(uint16_t));
    if (e) return (int)e;
    e = cudaMemcpyToSymbol(c_btc_count, counts, 12 * sizeof(int)); if (e) return (int)e;
    e = cudaMemcpyToSymbol(c_btc_off, offs, 12 * sizeof(int));     if (e) return (int)e;
    return 0;
}

extern "C" int btc_set_targets(const uint8_t *targets_flat, int ntargets) {
    if (ntargets < 1 || ntargets > BTC_MAX_TARGETS) return -1;
    cudaError_t e;
    e = cudaMemcpyToSymbol(c_btc_targets, targets_flat, (size_t)ntargets * 20); if (e) return (int)e;
    e = cudaMemcpyToSymbol(c_btc_ntargets, &ntargets, sizeof(int));             if (e) return (int)e;
    return 0;
}

/* Run one chunk [base, end) of the mixed-radix enumeration. Writes the matching
 * global index to *out_match (ULLONG_MAX if none in this chunk). Return: 0 ok,
 * else CUDA error code. Caller chunks so (end-base)/64 stays a modest grid. */
extern "C" int btc_run_chunk(unsigned long long base, unsigned long long end,
                             unsigned long long total, unsigned long long *out_match) {
    unsigned long long *d_match = NULL;
    cudaError_t e = cudaMalloc(&d_match, sizeof(unsigned long long));
    if (e) return (int)e;
    unsigned long long sentinel = ~0ULL;
    cudaMemcpy(d_match, &sentinel, sizeof(sentinel), cudaMemcpyHostToDevice);

    unsigned long long span = (end > base) ? (end - base) : 0ULL;
    int threads = 64;
    unsigned long long blocks = (span + threads - 1) / threads;
    if (blocks == 0) blocks = 1;
    check_mnemonics_btc<<<(unsigned int)blocks, threads>>>(base, end, total, d_match);
    e = cudaDeviceSynchronize();
    if (e) { cudaFree(d_match); return (int)e; }

    cudaMemcpy(out_match, d_match, sizeof(unsigned long long), cudaMemcpyDeviceToHost);
    cudaFree(d_match);
    return 0;
}

/* ================================================================
 * BTC WORD-BRUTE, CHECKSUM-AWARE (packed warps, no divergence).
 *
 * When position 12 (the last word) is brute-forced over the full 2048
 * values, DO NOT enumerate those 2048 values directly: the 4 low-order
 * bits of word 12 ARE the BIP39 checksum, so for a given prefix (words
 * 1..11) plus the 7 entropy bits of word 12, word 12 is COMPUTED, not
 * chosen. We therefore enumerate positions 0..10 x 128 (the 7 bits):
 * exactly the checksum-valid mnemonics, and EVERY thread derives (full
 * warps, no divergence) -> ~6.5x the filtering kernel, which wasted 15/16
 * of its work to warp divergence.
 *
 * total_ck = (product of c_btc_count[0..10]) x 128. Uses c_btc_count[0..10]
 * and c_btc_off[0..10]; position 11 is ignored (word 12 spans all 2048).
 * ================================================================ */
/* Launch bounds are configurable: __launch_bounds__(64,8) caps this kernel
 * at 128 registers and forces spills (local memory) since it is register-
 * heavy (PBKDF2 + EC). Override at compile time:
 * -DBTC_CK_LB='__launch_bounds__(64,4)' etc. */
#ifndef BTC_CK_TPB
#define BTC_CK_TPB 64
#endif
#ifndef BTC_CK_BPM
#define BTC_CK_BPM 8
#endif

extern "C" __global__ __launch_bounds__(BTC_CK_TPB, BTC_CK_BPM) void check_mnemonics_btc_ck(
    unsigned long long base, unsigned long long end,
    unsigned long long total, unsigned long long *d_match)
{
    unsigned long long tid = base + (unsigned long long)blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= end || tid >= total) return;

    /* least-significant radix = e7 (7 entropy bits of word 12), then positions 10..0 */
    unsigned long long t = tid;
    int e7 = (int)(t & 127ULL);
    t >>= 7;
    uint32_t idx[12];
    for (int p = 10; p >= 0; p--) {
        unsigned long long cnt = (unsigned long long)c_btc_count[p];
        int sel = (int)(t % cnt);
        t /= cnt;
        idx[p] = (uint32_t)d_btc_cand[c_btc_off[p] + sel];
    }

    /* 128-bit entropy = words idx[0..10] (121 bits) + e7 (7 bits) */
    uint8_t ent[16];
    #pragma unroll
    for (int i = 0; i < 16; i++) ent[i] = 0;
    int bp = 0;
    for (int w = 0; w < 11; w++) {
        uint32_t v = idx[w] & 0x7FFu;
        for (int b = 10; b >= 0; b--) {
            if ((v >> b) & 1u) ent[bp >> 3] |= (uint8_t)(0x80u >> (bp & 7));
            bp++;
        }
    }
    for (int b = 6; b >= 0; b--) {
        if ((e7 >> b) & 1) ent[bp >> 3] |= (uint8_t)(0x80u >> (bp & 7));
        bp++;
    }
    /* bp == 128 */
    uint8_t h[32];
    sha256_full(ent, 16, h);
    int cs = (h[0] >> 4) & 0x0F;
    idx[11] = (uint32_t)((e7 << 4) | cs);      /* 0..2047, checksum-valid word 12 */

    uint8_t mnem[160];
    int pos = 0;
    for (int w = 0; w < 12; w++) {
        if (w > 0) mnem[pos++] = ' ';
        int wi = idx[w];
        int wl = d_wordlen[wi];
        for (int c = 0; c < wl; c++) mnem[pos++] = d_wordlist[wi * 9 + c];
    }
    uint8_t salt[8] = {'m','n','e','m','o','n','i','c'};
    uint8_t seed[64];
    pbkdf2_sha512(mnem, pos, salt, 8, 2048, seed);
    uint8_t h160[20];
    full_derive(seed, h160);

    for (int ti = 0; ti < c_btc_ntargets; ti++) {
        const uint8_t *tgt = c_btc_targets + (size_t)ti * 20;
        int m = 1;
        #pragma unroll
        for (int i = 0; i < 20; i++) if (h160[i] != tgt[i]) { m = 0; break; }
        if (m) { atomicMin(d_match, tid); return; }
    }
}

extern "C" int btc_run_chunk_ck(unsigned long long base, unsigned long long end,
                                unsigned long long total, unsigned long long *out_match) {
    unsigned long long *d_match = NULL;
    cudaError_t e = cudaMalloc(&d_match, sizeof(unsigned long long));
    if (e) return (int)e;
    unsigned long long sentinel = ~0ULL;
    cudaMemcpy(d_match, &sentinel, sizeof(sentinel), cudaMemcpyHostToDevice);
    unsigned long long span = (end > base) ? (end - base) : 0ULL;
    int threads = 64;
    unsigned long long blocks = (span + threads - 1) / threads;
    if (blocks == 0) blocks = 1;
    check_mnemonics_btc_ck<<<(unsigned int)blocks, threads>>>(base, end, total, d_match);
    e = cudaDeviceSynchronize();
    if (e) { cudaFree(d_match); return (int)e; }
    cudaMemcpy(out_match, d_match, sizeof(unsigned long long), cudaMemcpyDeviceToHost);
    cudaFree(d_match);
    return 0;
}

/* ================================================================
 * PERM11 ETH MODE: ORDER SEARCH over a FIXED set of 11 words.
 *
 * Problem: a set of 11 BIP39 words is locked, but their ORDER is not.
 * Space = 11! orders x 128 checksum-valid twelfth words = 5,108,300,800.
 * Passing all 12 indices from the host would cost 245 GB of PCIe transfer,
 * so we GENERATE everything on the GPU from the single global index.
 *
 *   g           = base + tid                (0 .. 11!*128 - 1)
 *   perm_index  = g / 128                   (0 .. 39,916,799)
 *   hi7         = g % 128                   (7 entropy bits of word 12)
 *
 * 1. perm_index -> permutation via the factorial number system (Lehmer
 *    code), most-significant digit first => SAME lexicographic order as
 *    Python's itertools.permutations(fixed11).
 * 2. prefix121 = 11 indices of 11 bits each; entropy128 = (prefix121 << 7) | hi7.
 * 3. cs = SHA256(entropy128)[0] >> 4; word12 = (hi7 << 4) | cs.
 *    => exactly 128 VALID mnemonics per permutation, zero PBKDF2 wasted
 *    on an invalid checksum (full warps, no divergence).
 * 4. PBKDF2-SHA512 2048 (salt "mnemonic") -> eth_derive (c_path) -> compare
 *    byte-exact to c_target_eth.
 * 5. On a hit, write the GLOBAL INDEX g (atomicMin) so the mnemonic can be
 *    re-derived on the CPU, plus a flag.
 *
 * Reuses sha256_full / pbkdf2_sha512 / eth_derive / d_wordlist; adds no
 * symbol that conflicts with the existing ones.
 * ================================================================ */

#define PERM11_N      11
#define PERM11_TOTAL  5109350400ULL   /* 11! * 128 */

/* Anti-false-negative counter: number of PBKDF2 rounds actually launched.
 * Aggregated per warp (1 atomicAdd / warp) => negligible cost. */
__device__ unsigned long long d_perm11_pbkdf2 = 0ULL;

/* c_perm11_fact[i] = (10 - i)!  -- factorial-number-system radix, most-significant digit first. */
__constant__ uint32_t c_perm11_fact[PERM11_N] = {
    3628800u, 362880u, 40320u, 5040u, 720u, 120u, 24u, 6u, 2u, 1u, 1u
};

extern "C" __global__ __launch_bounds__(64, 8) void check_perm11_eth(
    const int *d_fixed11, unsigned long long base, unsigned long long count,
    int *d_match, unsigned long long *d_match_idx)
{
    unsigned long long tid = (unsigned long long)blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= count) return;
    const unsigned long long g = base + tid;

    const unsigned long long perm_index = g >> 7;         /* g / 128 */
    const uint32_t           hi7        = (uint32_t)(g & 127ULL);

    /* --- 1. Lehmer decode (most-significant digit first) ---
     * The "pool" of remaining elements is an 11-bit MASK, not an array:
     * no dynamically-indexed local array => zero extra spill (the kernel
     * is already register-tight because of mnem[160]).
     * fact[i] = (10 - i)!  -- fully unrolled, so these are immediate constants. */
    uint32_t w[PERM11_N];
    uint32_t used = 0u;
    uint32_t r = (uint32_t)perm_index;          /* perm_index < 11! < 2^26 */
    #pragma unroll
    for (int i = 0; i < PERM11_N; i++) {
        const uint32_t f = c_perm11_fact[i];
        int d = (int)(r / f);
        r -= (uint32_t)d * f;
        /* select the d-th still-free element (Lehmer index) */
        int pos = -1;
        #pragma unroll
        for (int k = 0; k < PERM11_N; k++) {
            if (pos < 0 && !((used >> k) & 1u)) {
                if (d == 0) pos = k; else d--;
            }
        }
        used |= (1u << pos);
        w[i] = (uint32_t)d_fixed11[pos];        /* global, 11 ints, L1-resident */
    }

    /* --- 2. 128-bit entropy = 11x11 bits then hi7 --- */
    uint8_t ent[16];
    #pragma unroll
    for (int i = 0; i < 16; i++) ent[i] = 0;
    int bitpos = 0;
    for (int i = 0; i < PERM11_N; i++) {
        const uint32_t v = w[i] & 0x7FFu;
        for (int b = 10; b >= 0; b--) {
            if ((v >> b) & 1u) ent[bitpos >> 3] |= (uint8_t)(0x80u >> (bitpos & 7));
            bitpos++;
        }
    }
    for (int b = 6; b >= 0; b--) {                       /* bitpos 121..127 */
        if ((hi7 >> b) & 1u) ent[bitpos >> 3] |= (uint8_t)(0x80u >> (bitpos & 7));
        bitpos++;
    }

    /* --- 3. checksum -> 12th word (always valid by construction) --- */
    uint8_t h[32];
    sha256_full(ent, 16, h);
    const uint32_t w12 = (hi7 << 4) | (uint32_t)((h[0] >> 4) & 0x0Fu);

    /* --- 4. mnemonic -> PBKDF2 -> ETH --- */
    uint8_t mnem[160];
    int pos = 0;
    for (int i = 0; i < PERM11_N; i++) {
        if (i > 0) mnem[pos++] = ' ';
        const int wi = (int)w[i];
        const int wl = d_wordlen[wi];
        for (int c = 0; c < wl; c++) mnem[pos++] = d_wordlist[wi * 9 + c];
    }
    mnem[pos++] = ' ';
    {
        const int wl = d_wordlen[w12];
        for (int c = 0; c < wl; c++) mnem[pos++] = d_wordlist[w12 * 9 + c];
    }

    /* counter aggregated per warp (a single atomicAdd per active warp) */
    {
        const unsigned mask = __activemask();
        const int lane   = threadIdx.x & 31;
        const int leader = __ffs(mask) - 1;
        if (lane == leader) atomicAdd(&d_perm11_pbkdf2, (unsigned long long)__popc(mask));
    }

    uint8_t salt[8] = {'m','n','e','m','o','n','i','c'};
    uint8_t seed[64];
    pbkdf2_sha512(mnem, pos, salt, 8, 2048, seed);

    uint8_t addr[20];
    eth_derive(seed, addr);

    int match = 1;
    #pragma unroll
    for (int i = 0; i < 20; i++) if (addr[i] != c_target_eth[i]) { match = 0; break; }
    if (match) {
        atomicMin(d_match_idx, g);      /* GLOBAL index, not the local tid */
        atomicExch(d_match, 1);
    }
}

/* ---- DEBUG hooks / CPU<->GPU cross-check (1 thread, off the hot path) ----
 * dbg_perm11: returns what the device ACTUALLY builds for index g:
 *   out[0..19]   = ETH address
 *   out[20..35]  = 16-byte entropy
 *   out[36..37]  = w12 (little endian)
 *   out[38]      = mnemonic length
 *   out[39..]    = mnemonic ASCII
 *   out[220..231]= the 12 word indices (uint16 LE)
 */
extern "C" __global__ void dbg_perm11_eth(const int *d_fixed11,
                                          unsigned long long g, uint8_t *out) {
    if (threadIdx.x || blockIdx.x) return;
    const unsigned long long perm_index = g >> 7;
    const uint32_t hi7 = (uint32_t)(g & 127ULL);
    uint32_t w[PERM11_N];
    uint32_t used = 0u;
    uint32_t r = (uint32_t)perm_index;
    for (int i = 0; i < PERM11_N; i++) {
        const uint32_t f = c_perm11_fact[i];
        int d = (int)(r / f);
        r -= (uint32_t)d * f;
        int pos = -1;
        for (int k = 0; k < PERM11_N; k++)
            if (pos < 0 && !((used >> k) & 1u)) { if (d == 0) pos = k; else d--; }
        used |= (1u << pos);
        w[i] = (uint32_t)d_fixed11[pos];
    }
    uint8_t ent[16];
    for (int i = 0; i < 16; i++) ent[i] = 0;
    int bitpos = 0;
    for (int i = 0; i < PERM11_N; i++) {
        const uint32_t v = w[i] & 0x7FFu;
        for (int b = 10; b >= 0; b--) {
            if ((v >> b) & 1u) ent[bitpos >> 3] |= (uint8_t)(0x80u >> (bitpos & 7));
            bitpos++;
        }
    }
    for (int b = 6; b >= 0; b--) {
        if ((hi7 >> b) & 1u) ent[bitpos >> 3] |= (uint8_t)(0x80u >> (bitpos & 7));
        bitpos++;
    }
    uint8_t h[32];
    sha256_full(ent, 16, h);
    const uint32_t w12 = (hi7 << 4) | (uint32_t)((h[0] >> 4) & 0x0Fu);
    uint8_t mnem[160];
    int pos2 = 0;
    for (int i = 0; i < PERM11_N; i++) {
        if (i > 0) mnem[pos2++] = ' ';
        const int wi = (int)w[i];
        const int wl = d_wordlen[wi];
        for (int c = 0; c < wl; c++) mnem[pos2++] = d_wordlist[wi * 9 + c];
    }
    mnem[pos2++] = ' ';
    { const int wl = d_wordlen[w12];
      for (int c = 0; c < wl; c++) mnem[pos2++] = d_wordlist[w12 * 9 + c]; }
    uint8_t salt[8] = {'m','n','e','m','o','n','i','c'};
    uint8_t seed[64];
    pbkdf2_sha512(mnem, pos2, salt, 8, 2048, seed);
    uint8_t addr[20];
    eth_derive(seed, addr);
    for (int i = 0; i < 20; i++) out[i] = addr[i];
    for (int i = 0; i < 16; i++) out[20 + i] = ent[i];
    out[36] = (uint8_t)(w12 & 0xFF); out[37] = (uint8_t)(w12 >> 8);
    out[38] = (uint8_t)pos2;
    for (int i = 0; i < pos2 && i < 160; i++) out[39 + i] = mnem[i];
    for (int i = 0; i < PERM11_N; i++) {
        out[220 + 2 * i] = (uint8_t)(w[i] & 0xFF);
        out[221 + 2 * i] = (uint8_t)(w[i] >> 8);
    }
    out[242] = (uint8_t)(w12 & 0xFF); out[243] = (uint8_t)(w12 >> 8);
}

extern "C" int bip39pass_dbg_perm11(const int *fixed11, unsigned long long g,
                                    uint8_t *out256) {
    int *d_f = NULL; uint8_t *d_o = NULL;
    cudaMalloc(&d_f, PERM11_N * sizeof(int));
    cudaMalloc(&d_o, 1024);
    cudaMemset(d_o, 0, 1024);
    cudaMemcpy(d_f, fixed11, PERM11_N * sizeof(int), cudaMemcpyHostToDevice);
    dbg_perm11_eth<<<1, 1>>>(d_f, g, d_o);
    cudaError_t e = cudaDeviceSynchronize();
    cudaMemcpy(out256, d_o, 1024, cudaMemcpyDeviceToHost);
    cudaFree(d_f); cudaFree(d_o);
    return (int)e;
}

/* dbg_eth_idx: ETH address for 12 given indices (tests the derivation TAIL only). */
extern "C" __global__ void dbg_eth_idx(const int *d_idx, uint8_t *out) {
    if (threadIdx.x || blockIdx.x) return;
    uint8_t mnem[160];
    int pos = 0;
    for (int w = 0; w < 12; w++) {
        if (w > 0) mnem[pos++] = ' ';
        const int wi = d_idx[w];
        const int wl = d_wordlen[wi];
        for (int c = 0; c < wl; c++) mnem[pos++] = d_wordlist[wi * 9 + c];
    }
    uint8_t salt[8] = {'m','n','e','m','o','n','i','c'};
    uint8_t seed[64];
    pbkdf2_sha512(mnem, pos, salt, 8, 2048, seed);
    uint8_t addr[20];
    eth_derive(seed, addr);
    for (int i = 0; i < 20; i++) out[i] = addr[i];
    for (int i = 0; i < 64; i++) out[20 + i] = seed[i];
    out[84] = (uint8_t)pos;
    for (int i = 0; i < pos && i < 160; i++) out[85 + i] = mnem[i];

    /* intermediate steps, to isolate a regression */
    uint8_t k[32], c[32];
    bip32_from_seed(seed, k, c);
    for (int lvl = 0; lvl < c_path_len; lvl++) {
        uint8_t nk[32], nc[32];
        if (c_path_hard[lvl]) bip32_derive_hardened(k, c, c_path[lvl], nk, nc);
        else                  bip32_derive_normal(k, c, c_path[lvl], nk, nc);
        for (int i = 0; i < 32; i++) { k[i] = nk[i]; c[i] = nc[i]; }
    }
    { uint8_t mk[32], mc[32]; bip32_from_seed(seed, mk, mc);
      for (int i = 0; i < 32; i++) { out[512 + i] = mk[i]; out[544 + i] = mc[i]; }
      uint8_t ak[32], ac[32];
      for (int i = 0; i < 32; i++) { ak[i] = mk[i]; ac[i] = mc[i]; }
      for (int lvl = 0; lvl < c_path_len; lvl++) {
          uint8_t nk[32], nc[32];
          if (c_path_hard[lvl]) bip32_derive_hardened(ak, ac, c_path[lvl], nk, nc);
          else                  bip32_derive_normal(ak, ac, c_path[lvl], nk, nc);
          for (int i = 0; i < 32; i++) { ak[i] = nk[i]; ac[i] = nc[i]; }
          for (int i = 0; i < 32; i++) out[576 + lvl * 32 + i] = ak[i];
      } }
    pt_t pub; scalar_mult_G(k, &pub);
    uint8_t xy[64]; pt_to_uncompressed_xy(&pub, xy);
    uint8_t kh[32]; keccak256(xy, 64, kh);
    uint8_t comp[33]; pt_to_compressed(&pub, comp);
    /* keccak witness: keccak256("") must equal c5d2460186f7...470 */
    uint8_t kz[32]; keccak256(xy, 0, kz);
    for (int i = 0; i < 32; i++) out[245 + i] = k[i];
    for (int i = 0; i < 64; i++) out[277 + i] = xy[i];
    for (int i = 0; i < 32; i++) out[341 + i] = kh[i];
    for (int i = 0; i < 33; i++) out[373 + i] = comp[i];
    for (int i = 0; i < 32; i++) out[406 + i] = kz[i];
    out[438] = (uint8_t)c_path_len;
    for (int i = 0; i < 8; i++) {
        out[439 + i] = (uint8_t)(c_path[i] & 0xFF);
        out[447 + i] = c_path_hard[i];
    }
}

extern "C" int bip39pass_dbg_eth_idx(const int *idx12, uint8_t *out256) {
    int *d_i = NULL; uint8_t *d_o = NULL;
    cudaMalloc(&d_i, 12 * sizeof(int));
    cudaMalloc(&d_o, 1024);
    cudaMemset(d_o, 0, 1024);
    cudaMemcpy(d_i, idx12, 12 * sizeof(int), cudaMemcpyHostToDevice);
    dbg_eth_idx<<<1, 1>>>(d_i, d_o);
    cudaError_t e = cudaDeviceSynchronize();
    cudaMemcpy(out256, d_o, 1024, cudaMemcpyDeviceToHost);
    cudaFree(d_i); cudaFree(d_o);
    return (int)e;
}

/* Resets the PBKDF2 counter to zero. */
extern "C" int bip39pass_perm11_reset_counter(void) {
    unsigned long long z = 0ULL;
    return (int)cudaMemcpyToSymbol(d_perm11_pbkdf2, &z, sizeof(z));
}

/* Reads the count of PBKDF2 rounds actually executed. */
extern "C" int bip39pass_perm11_get_counter(unsigned long long *out) {
    return (int)cudaMemcpyFromSymbol(out, d_perm11_pbkdf2, sizeof(*out));
}

/* Sub-batch size (threads per launch). Adjustable for sub-batch boundary
 * tests; default 1<<22 = 4,194,304. */
static unsigned long long g_perm11_batch = (1ULL << 22);
extern "C" int bip39pass_perm11_set_batch(unsigned long long b) {
    if (b == 0ULL) return -1;
    g_perm11_batch = b;
    return 0;
}
extern "C" unsigned long long bip39pass_perm11_get_batch(void) { return g_perm11_batch; }

/*
 * bip39pass_run_perm11_eth - sweeps [base, base+count) in sub-batches.
 *
 * A SINGLE device allocation for the whole range (no cudaMalloc/cudaFree per
 * batch). Writes the global index of the hit to *match_idx_out, or
 * ULLONG_MAX if none. Stops as soon as a sub-batch finds a hit (the hit is
 * the minimal index of that sub-batch; there is only one key per address
 * anyway).
 *
 * Host prerequisites: bip39pass_load_wordlist(), bip39pass_set_path(44'/60'/0'/0/0),
 * bip39pass_set_eth_target(). Return 0 = OK, else a CUDA error code.
 */
extern "C" int bip39pass_run_perm11_eth(const int *fixed11, unsigned long long base,
                                        unsigned long long count,
                                        unsigned long long *match_idx_out) {
    if (match_idx_out) *match_idx_out = ~0ULL;
    if (count == 0ULL) return 0;

    int                *d_fixed11 = NULL;
    int                *d_match   = NULL;
    unsigned long long *d_midx    = NULL;
    cudaError_t e;

    e = cudaMalloc(&d_fixed11, PERM11_N * sizeof(int));       if (e) goto done;
    e = cudaMalloc(&d_match,   sizeof(int));                  if (e) goto done;
    e = cudaMalloc(&d_midx,    sizeof(unsigned long long));   if (e) goto done;

    e = cudaMemcpy(d_fixed11, fixed11, PERM11_N * sizeof(int), cudaMemcpyHostToDevice);
    if (e) goto done;
    {
        int zero = 0; unsigned long long sentinel = ~0ULL;
        e = cudaMemcpy(d_match, &zero, sizeof(zero), cudaMemcpyHostToDevice);   if (e) goto done;
        e = cudaMemcpy(d_midx, &sentinel, sizeof(sentinel), cudaMemcpyHostToDevice);
        if (e) goto done;
    }

    {
        const int threads = 64;
        unsigned long long done_n = 0ULL;
        while (done_n < count) {
            unsigned long long span = count - done_n;
            if (span > g_perm11_batch) span = g_perm11_batch;
            unsigned long long blocks = (span + threads - 1ULL) / threads;

            check_perm11_eth<<<(unsigned int)blocks, threads>>>(
                d_fixed11, base + done_n, span, d_match, d_midx);
            e = cudaDeviceSynchronize();
            if (e) goto done;

            int hit = 0;
            e = cudaMemcpy(&hit, d_match, sizeof(hit), cudaMemcpyDeviceToHost);
            if (e) goto done;
            done_n += span;
            if (hit) break;
        }
    }

    if (match_idx_out) {
        e = cudaMemcpy(match_idx_out, d_midx, sizeof(unsigned long long),
                       cudaMemcpyDeviceToHost);
    }

done:
    if (d_fixed11) cudaFree(d_fixed11);
    if (d_match)   cudaFree(d_match);
    if (d_midx)    cudaFree(d_midx);
    return (int)e;
}


/* ---------------------------------------------------------------
 * BTC MODE, MULTI-TARGET, index rows.
 * Rows of ETH_WORDS (=12) word indices -> PBKDF2 (empty passphrase) -> c_path
 * (bip39pass_set_path, e.g. 44'/0'/0'/0/0) -> hash160(compressed pubkey) ->
 * compared against c_btc_targets (btc_set_targets, <= BTC_MAX_TARGETS).
 * d_match[t] = row index (last one) matching target t, else -1.
 * BTC mirror of check_mnemonics_eth_multi: same witnesses in the same run.
 * --------------------------------------------------------------- */
extern "C" __global__ __launch_bounds__(64, 8) void check_mnemonics_btc_multi(
    const int *d_idx, int n, int *d_match)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= n) return;
    const int *src = d_idx + (size_t)tid * ETH_WORDS;
    uint8_t mnem[160]; int pos = 0;
    for (int w = 0; w < ETH_WORDS; w++) {
        if (w > 0) mnem[pos++] = ' ';
        int wi = src[w]; int wl = d_wordlen[wi];
        for (int c = 0; c < wl; c++) mnem[pos++] = d_wordlist[wi * 9 + c];
    }
    uint8_t salt[8] = {'m','n','e','m','o','n','i','c'};
    uint8_t seed[64];
    pbkdf2_sha512(mnem, pos, salt, 8, 2048, seed);
    uint8_t h160[20];
    full_derive(seed, h160);
    for (int t = 0; t < c_btc_ntargets; t++) {
        const uint8_t *tg = c_btc_targets + (size_t)t * 20;
        int match = 1;
        #pragma unroll
        for (int i = 0; i < 20; i++) { if (h160[i] != tg[i]) { match = 0; break; } }
        if (match) atomicExch(d_match + t, tid);
    }
}

extern "C" int bip39pass_run_btc_batch_multi(const int *h_idx, int n, int *out_match) {
    int *d_idx = NULL; int *d_match = NULL;
    size_t idx_bytes = (size_t)n * ETH_WORDS * sizeof(int);
    cudaError_t e;
    e = cudaMalloc(&d_idx, idx_bytes);                        if (e) return (int)e;
    e = cudaMalloc(&d_match, BTC_MAX_TARGETS * sizeof(int));  if (e) { cudaFree(d_idx); return (int)e; }
    int neg[BTC_MAX_TARGETS]; for (int i = 0; i < BTC_MAX_TARGETS; i++) neg[i] = -1;
    cudaMemcpy(d_idx, h_idx, idx_bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_match, neg, sizeof(neg), cudaMemcpyHostToDevice);
    int threads = 64; int blocks = (n + threads - 1) / threads;
    check_mnemonics_btc_multi<<<blocks, threads>>>(d_idx, n, d_match);
    e = cudaDeviceSynchronize();
    if (e) { cudaFree(d_idx); cudaFree(d_match); return (int)e; }
    cudaMemcpy(out_match, d_match, sizeof(neg), cudaMemcpyDeviceToHost);
    cudaFree(d_idx); cudaFree(d_match);
    return 0;
}
