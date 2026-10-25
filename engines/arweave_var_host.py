#!/usr/bin/env python3
"""
arweave_var_host.py - ctypes host for `libarv.so` (arweave_var_engine.cu).

Generalisation of `pzl3_host.py` to the WHOLE Arweave puzzle series: the
passphrase is the concatenation of 1..8 slot tokens of ARBITRARY length
(total <= 111 bytes), instead of PZL3's fixed 8x4 = 32 bytes.

Certification (`--selftest`) is fully self-contained: it builds several
synthetic passphrases of different lengths (exercising the variable-length
path differently than a fixed-size one would), encrypts a known plaintext
block 0 with the exact same scheme on the CPU (SHA-512^11513 stretch ->
EvpKDF(MD5,1e4) -> Rijndael Nk=32/Nr=38 CBC), and checks that the GPU
recovers byte-exact plaintext for every one of them. If any vector fails,
no sweep is allowed to run.

Sweep mode enumerates the mixed-radix product of per-slot wordlists and
reports the winning index; the host then rebuilds the passphrase, which you
then check against your own puzzle's target address before trusting it
(zero false positives requires that final exact check).
"""

import argparse
import base64
import ctypes
import hashlib
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(HERE, "libarv.so")

MAX_TOK = 96
MAX_TLEN = 64
MAX_PASS = 111
NSLOT_MAX = 6


# ---------------------------------------------------------------- page parsing
def page_msg(path):
    html = open(path, encoding="utf-8", errors="replace").read()
    m = re.search(r'var msg\s*=\s*"([^"]+)"', html)
    if not m:
        raise SystemExit("no `var msg=` in " + path)
    return m.group(1)


def salt_and_c0(msg_b64):
    raw = base64.b64decode(msg_b64)
    assert raw[:8] == b"Salted__", raw[:8]
    return raw[8:16], raw[16:32]


# ------------------------------------------------------------- CPU reference
def stretch_keyhex(passphrase: bytes) -> bytes:
    h = hashlib.sha512(passphrase).digest()
    for _ in range(11512):
        h = hashlib.sha512(h).digest()
    return h.hex().encode()


def evpkdf(pw: bytes, salt: bytes, dklen=144, iters=10000) -> bytes:
    out = b""
    prev = b""
    while len(out) < dklen:
        a = hashlib.md5(prev + pw + salt).digest()
        for _ in range(iters - 1):
            a = hashlib.md5(a).digest()
        out += a
        prev = a
    return out[:dklen]


# minimal Rijndael Nk=32 / Nr=38 (CryptoJS keySize=32 quirk) - decrypt one block
def _gmul(a, b):
    p = 0
    for _ in range(8):
        if b & 1:
            p ^= a
        hi = a & 0x80
        a = (a << 1) & 0xFF
        if hi:
            a ^= 0x1B
        b >>= 1
    return p


def _sbox():
    p = q = 1
    sb = [0] * 256
    while True:
        p = p ^ ((p << 1) & 0xFF) ^ (0x1B if p & 0x80 else 0)
        q ^= q << 1
        q ^= q << 2
        q ^= q << 4
        q &= 0xFF
        if q & 0x80:
            q ^= 0x09
        x = q ^ ((q << 1) | (q >> 7)) ^ ((q << 2) | (q >> 6)) ^ ((q << 3) | (q >> 5)) ^ ((q << 4) | (q >> 4))
        sb[p] = (x ^ 0x63) & 0xFF
        if p == 1:
            break
    sb[0] = 0x63
    return sb


SBOX = _sbox()
INV_SBOX = [0] * 256
for _i, _v in enumerate(SBOX):
    INV_SBOX[_v] = _i


def _key_expansion(key):
    nk = len(key) // 4
    nr = nk + 6
    w = [list(key[4 * i:4 * i + 4]) for i in range(nk)]
    rcon = 1
    for i in range(nk, 4 * (nr + 1)):
        t = list(w[i - 1])
        if i % nk == 0:
            t = t[1:] + t[:1]
            t = [SBOX[b] for b in t]
            t[0] ^= rcon
            rcon = _gmul(rcon, 2)
        elif nk > 6 and i % nk == 4:
            t = [SBOX[b] for b in t]
        w.append([w[i - nk][j] ^ t[j] for j in range(4)])
    return w, nr


def rijndael_decrypt_block(block, key):
    w, nr = _key_expansion(key)
    s = list(block)

    def addrk(rnd):
        for c in range(4):
            for r in range(4):
                s[4 * c + r] ^= w[rnd * 4 + c][r]

    addrk(nr)
    for rnd in range(nr - 1, -1, -1):
        # InvShiftRows
        t = list(s)
        for r in range(1, 4):
            for c in range(4):
                s[4 * ((c + r) % 4) + r] = t[4 * c + r]
        # InvSubBytes
        s = [INV_SBOX[b] for b in s]
        addrk(rnd)
        if rnd:
            t = list(s)
            for c in range(4):
                a = t[4 * c:4 * c + 4]
                s[4 * c + 0] = _gmul(a[0], 14) ^ _gmul(a[1], 11) ^ _gmul(a[2], 13) ^ _gmul(a[3], 9)
                s[4 * c + 1] = _gmul(a[0], 9) ^ _gmul(a[1], 14) ^ _gmul(a[2], 11) ^ _gmul(a[3], 13)
                s[4 * c + 2] = _gmul(a[0], 13) ^ _gmul(a[1], 9) ^ _gmul(a[2], 14) ^ _gmul(a[3], 11)
                s[4 * c + 3] = _gmul(a[0], 11) ^ _gmul(a[1], 13) ^ _gmul(a[2], 9) ^ _gmul(a[3], 14)
    return bytes(s)


def rijndael_encrypt_block(block, key):
    """Forward cipher, used only to build synthetic self-test vectors
    (encrypt a known plaintext block so the GPU has something real to
    decrypt and we know the expected answer)."""
    w, nr = _key_expansion(key)
    s = list(block)

    def addrk(rnd):
        for c in range(4):
            for r in range(4):
                s[4 * c + r] ^= w[rnd * 4 + c][r]

    addrk(0)
    for rnd in range(1, nr):
        s = [SBOX[b] for b in s]
        t = list(s)
        for r in range(1, 4):
            for c in range(4):
                s[4 * c + r] = t[4 * ((c + r) % 4) + r]
        t = list(s)
        for c in range(4):
            a = t[4 * c:4 * c + 4]
            s[4 * c + 0] = _gmul(a[0], 2) ^ _gmul(a[1], 3) ^ a[2] ^ a[3]
            s[4 * c + 1] = a[0] ^ _gmul(a[1], 2) ^ _gmul(a[2], 3) ^ a[3]
            s[4 * c + 2] = a[0] ^ a[1] ^ _gmul(a[2], 2) ^ _gmul(a[3], 3)
            s[4 * c + 3] = _gmul(a[0], 3) ^ a[1] ^ a[2] ^ _gmul(a[3], 2)
        addrk(rnd)
    s = [SBOX[b] for b in s]
    t = list(s)
    for r in range(1, 4):
        for c in range(4):
            s[4 * c + r] = t[4 * ((c + r) % 4) + r]
    addrk(nr)
    return bytes(s)


def cpu_block0(passphrase: bytes, salt: bytes, c0: bytes) -> bytes:
    keyhex = stretch_keyhex(passphrase)
    d = evpkdf(keyhex, salt)
    key, iv = d[:128], d[128:144]
    dec = rijndael_decrypt_block(c0, key)
    return bytes(x ^ y for x, y in zip(dec, iv))


# ------------------------------------------------------------------- ctypes
def load_lib():
    lib = ctypes.CDLL(LIB)
    lib.arv_init.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
    lib.arv_init.restype = ctypes.c_int
    lib.arv_set_wordlists.argtypes = [ctypes.c_char_p, ctypes.c_char_p,
                                      ctypes.POINTER(ctypes.c_int), ctypes.c_int]
    lib.arv_set_wordlists.restype = ctypes.c_int
    lib.arv_run_index_range.argtypes = [ctypes.c_uint64, ctypes.c_uint64,
                                        ctypes.c_int, ctypes.c_int]
    lib.arv_run_index_range.restype = ctypes.c_longlong
    lib.arv_selftest.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p,
                                 ctypes.c_char_p, ctypes.c_char_p]
    lib.arv_selftest.restype = ctypes.c_int
    return lib


# Synthetic self-test vectors: three passphrase lengths spanning the range
# this engine supports (<= 111 bytes), so the variable-length path is
# actually exercised at more than one size. These are NOT real puzzle
# answers -- they are arbitrary strings used only to build a known
# (salt, ciphertext-block-0, plaintext-block-0) triple on the CPU.
SELFTEST_VECTORS = [
    ("short",  b"RasputinWilhelmAlekhine"),                                    # 23 bytes
    ("medium", b"*48GCEErisUmberCastlePicasso"),                               # 28 bytes
    ("long",   b"Vivaldi227PermanentArnheimBulgakov1157Ulysses143176176209"),  # 57 bytes
]
SELFTEST_PLAIN = b'{"kty":"RSA","n":"oracle-roundtrip-ok-aaaaaaaaaaaaaaaa}'  # only block0 prefix matters


def _make_vector(passphrase: bytes, salt: bytes):
    """Encrypt SELFTEST_PLAIN's block 0 under this scheme for `passphrase`,
    return (c0, expected_plain0)."""
    keyhex = stretch_keyhex(passphrase)
    d = evpkdf(keyhex, salt)
    key, iv = d[:128], d[128:144]
    plain0 = SELFTEST_PLAIN[:16]
    pt_xor = bytes(a ^ b for a, b in zip(plain0, iv))
    c0 = rijndael_encrypt_block(pt_xor, key)
    return c0, plain0


def do_selftest(lib):
    ok_all = True
    for name, pw in SELFTEST_VECTORS:
        salt = hashlib.sha256(pw).digest()[:8]   # deterministic synthetic salt
        c0, exp = _make_vector(pw, salt)
        out = ctypes.create_string_buffer(16)
        rc = lib.arv_selftest(pw, len(pw), salt, c0, out)
        got = out.raw[:16]
        ok = (rc == 0 and got == exp)
        ok_all &= ok
        sys.stderr.write(f"[selftest] {name} len={len(pw):2d} rc={rc} "
                         f"{'PASS' if ok else 'FAIL'}  gpu={got!r} cpu={exp!r}\n")
    if ok_all:
        sys.stderr.write("[selftest] ALL PASS - variable-length SHA512^11513 + EvpKDF(MD5,1e4)"
                         " + Rijndael(Nk=32,Nr=38) reproduced at 3 different passphrase lengths.\n")
    return ok_all


# ------------------------------------------------------------------- sweep
def read_slots(wl_dir):
    slots = []
    k = 1
    while True:
        p = os.path.join(wl_dir, f"{k}.txt")
        if not os.path.exists(p):
            break
        toks = []
        for line in open(p, encoding="utf-8"):
            t = line.rstrip("\n").rstrip("\r")
            if t == "" and toks:
                continue
            b = t.encode("utf-8")
            if len(b) > MAX_TLEN:
                raise SystemExit(f"slot {k}: token {t!r} longer than MAX_TLEN={MAX_TLEN}")
            toks.append(b)
        if not toks:
            raise SystemExit(f"slot {k}: empty wordlist")
        if len(toks) > MAX_TOK:
            raise SystemExit(f"slot {k}: {len(toks)} tokens > MAX_TOK={MAX_TOK}")
        slots.append(toks)
        k += 1
    if not slots:
        raise SystemExit("no <n>.txt wordlists in " + wl_dir)
    return slots


def pack(slots):
    words = bytearray(NSLOT_MAX * MAX_TOK * MAX_TLEN)
    tlens = bytearray(NSLOT_MAX * MAX_TOK)
    counts = (ctypes.c_int * NSLOT_MAX)()
    for k in range(NSLOT_MAX):
        toks = slots[k] if k < len(slots) else [b""]
        counts[k] = len(toks)
        for i, t in enumerate(toks):
            off = (k * MAX_TOK + i) * MAX_TLEN
            words[off:off + len(t)] = t
            tlens[k * MAX_TOK + i] = len(t)
    return bytes(words), bytes(tlens), counts


def index_to_pass(idx, slots):
    out = b""
    for k in range(len(slots)):
        n = len(slots[k])
        out += slots[k][idx % n]
        idx //= n
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--sweep", action="store_true")
    ap.add_argument("--i-understand-this-bruteforces", action="store_true")
    ap.add_argument("--page", required=False, help="puzzle HTML page to attack")
    ap.add_argument("--wordlists", help="dir with 1.txt..N.txt (one token per line)")
    ap.add_argument("--threads", type=int, default=64)
    ap.add_argument("--blocks", type=int, default=16384)
    ap.add_argument("--chunk", type=int, default=2_000_000)
    ap.add_argument("--start", type=int, default=0)
    args = ap.parse_args()

    lib = load_lib()
    if not args.sweep:
        return 0 if do_selftest(lib) else 1

    if not args.i_understand_this_bruteforces:
        sys.stderr.write("refusing to sweep without --i-understand-this-bruteforces\n")
        return 3
    if not do_selftest(lib):
        sys.stderr.write("selftest FAILED - refusing to sweep\n")
        return 4

    salt, c0 = salt_and_c0(page_msg(args.page))
    if lib.arv_init(salt, c0) != 0:
        raise SystemExit("arv_init failed")
    slots = read_slots(args.wordlists)
    words, tlens, counts = pack(slots)
    if lib.arv_set_wordlists(words, tlens, counts, len(slots)) != 0:
        raise SystemExit("arv_set_wordlists failed")

    total = 1
    for s in slots:
        total *= len(s)
    lens = [len(s) for s in slots]
    sys.stderr.write(f"[sweep] slots={lens} total={total:,} page={os.path.basename(args.page)}\n")
    sample = index_to_pass(0, slots)
    sys.stderr.write(f"[sweep] index 0 -> {sample!r} ({len(sample)}B)\n")

    t0 = time.time()
    done = args.start
    while done < total:
        n = min(args.chunk, total - done)
        hit = lib.arv_run_index_range(done, n, args.threads, args.blocks)
        done += n
        el = time.time() - t0
        rate = (done - args.start) / el if el else 0
        eta = (total - done) / rate if rate else 0
        sys.stderr.write(f"\r[sweep] {done:,}/{total:,}  {rate:,.0f}/s  ETA {eta/60:.1f} min   ")
        sys.stderr.flush()
        if hit >= 0:
            pw = index_to_pass(hit, slots)
            sys.stderr.write(f"\n*** DEVICE HIT idx={hit} passphrase={pw!r}\n")
            print(pw.decode("utf-8", "replace"))
            return 0
    sys.stderr.write(f"\n[sweep] complete, no block-0 JWK prefix in {total:,} candidates.\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
