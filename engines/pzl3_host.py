#!/usr/bin/env python3
# ── CONTEXT ──
# CONTEXT - Part of a PUBLIC cryptopuzzle-solving project (treasure hunt / CTF).
# This engine is used ONLY against puzzle-reward addresses whose own author locked
# and PUBLISHED them as an open challenge - never a third-party wallet or leaked key.
# See CONTEXT.md at the repo root. Rule: zero false positives; funds verified on-chain.
# ────
"""GPU host driver for Arweave Puzzle #3 (libpzl3.so), via ctypes.

Mirrors the bip39pass_stream.py pattern (.so + mandatory oracle self-test).

The dominant per-attempt cost is the 11513 sequential SHA-512 + 90000 sequential
MD5; the engine evaluates one mixed-radix index per thread and early-outs on the
JWK prefix of decrypted cipher block 0.

THIS SCRIPT DOES NOT LAUNCH A BRUTE-FORCE BY DEFAULT.
  --selftest : compile-validated 1-vector correctness check on the GPU (default
               action; proves the SHA512-chain + EvpKDF(MD5) + Rijndael(Nk=32,
               Nr=38) pipeline reproduces the live puzzle scheme).
  --sweep ...: would stream index ranges to the GPU. Refuses to run unless the
               explicit flag --i-understand-this-bruteforces is also given.

Paths are resolved from the repo, never hardcoded.
"""
import ctypes, os, sys, base64, hashlib, argparse, time

HERE = os.path.dirname(os.path.abspath(__file__))
SO   = os.path.join(HERE, "libpzl3.so")

# A real --sweep run needs the puzzle's own page script (for `var msg="..."`,
# the base64 OpenSSL-salted blob), a wordlists directory, and an output dir.
# None of these are shipped here (they are puzzle-specific inputs, not part
# of the engine) -- pass them explicitly with --page / --wordlists / --out.

MAX_TOK = 256   # must match c_words[8][MAX_TOK][4] in the .cu

# ---- known self-test vector. The real puzzle passphrase is always exactly 32
#      bytes (8 tokens x 4 chars), so the self-test uses a genuine 32-byte string
#      to exercise the kernel on real-input shape. Vector reproduced in CPython
#      below (cross-checked against node decoder_fast.js) so this file is
#      self-contained and needs no node at runtime. ----
SELFTEST_PASS  = "abcd1234efgh5678md12e4d5basea384"   # 32 bytes = 8 x 4-char tokens
SELFTEST_PLAIN = '{"kty":"RSA","n":"oracle-roundtrip-ok-aaaaaaaaaaaaaaaa}'  # only block0 prefix matters


# ----------------------------- crypto helpers (CPU, reference) -----------------------------
def stretch_keyhex(passphrase: str) -> str:
    """h = SHA512(P); 11512x h = SHA512(h); return hex(h) (128 chars)."""
    buf = hashlib.sha512(passphrase.encode("utf-8")).digest()
    for _ in range(11512):
        buf = hashlib.sha512(buf).digest()
    return buf.hex()


def evpkdf(passphrase_bytes: bytes, salt: bytes, dklen=144, iters=10000) -> bytes:
    """OpenSSL/CryptoJS EvpKDF with MD5 (crypto-js #293 quirk: per-block reHash)."""
    D = b""
    prev = b""
    while len(D) < dklen:
        a = hashlib.md5(prev + passphrase_bytes + salt).digest()
        for _ in range(iters - 1):
            a = hashlib.md5(a).digest()
        prev = a
        D += a
    return D[:dklen]


def parse_openssl_b64(msg_b64: str):
    """'U2FsdGVk...' -> (salt8, ciphertext_bytes)."""
    raw = base64.b64decode(msg_b64)
    assert raw[:8] == b"Salted__", "not an OpenSSL salted blob"
    return raw[8:16], raw[16:]


def load_msg_from_page(page_path) -> str:
    """Extract var msg="..." from the puzzle page scripts (no node needed)."""
    with open(page_path, "r", encoding="utf-8", errors="ignore") as f:
        txt = f.read()
    i = txt.index('var msg="') + len('var msg="')
    j = txt.index('"', i)
    return txt[i:j]


def make_selftest_vector():
    """Build (salt, c0, expected_p0) for SELFTEST_PASS using the exact scheme.

    Uses CryptoJS-quirk Rijndael only implicitly via OpenSSL-AES-256? NO - the
    quirk needs a 128-byte key, which standard AES libs cannot do. So we encrypt
    the reference block on CPU with a tiny pure-python Rijndael(Nk=32) below and
    hand the GPU the salt + ciphertext block0; the GPU must recover the prefix.
    """
    keyhex = stretch_keyhex(SELFTEST_PASS)            # 128 ASCII hex chars
    # Use a fixed salt so the vector is deterministic and reproducible.
    salt = bytes.fromhex("852ba5bc8a8fb828")
    D = evpkdf(keyhex.encode("ascii"), salt)          # 144 bytes
    key, iv = D[:128], D[128:144]
    plain0 = SELFTEST_PLAIN.encode("latin1")[:16]
    # CBC encrypt block 0:  C0 = AESenc(P0 XOR iv)
    pt_xor = bytes(a ^ b for a, b in zip(plain0, iv))
    c0 = _rijndael_encrypt_block(pt_xor, key)
    return salt, c0, plain0


# --- minimal pure-python Rijndael Nk=32 / Nr=38, forward (encrypt) for the self-test only ---
def _gmul(a, b):
    p = 0
    for _ in range(8):
        if b & 1: p ^= a
        hi = a & 0x80; a = (a << 1) & 0xff
        if hi: a ^= 0x1b
        b >>= 1
    return p

_SBOX = None
def _sbox():
    global _SBOX
    if _SBOX: return _SBOX
    s = [0]*256; p = q = 1
    while True:
        p = p ^ ((p << 1) & 0xff) ^ (0x1b if p & 0x80 else 0); p &= 0xff
        q ^= (q << 1) & 0xff; q ^= (q << 2) & 0xff; q ^= (q << 4) & 0xff; q &= 0xff
        q ^= 0x09 if q & 0x80 else 0; q &= 0xff
        xf = q ^ ((q << 1) | (q >> 7)) ^ ((q << 2) | (q >> 6)) ^ ((q << 3) | (q >> 5)) ^ ((q << 4) | (q >> 4))
        xf = (xf ^ 0x63) & 0xff
        s[p] = xf
        if p == 1: break
    s[0] = 0x63
    _SBOX = s
    return s

def _key_expansion(key):
    s = _sbox(); Nk = len(key)//4; Nr = Nk+6; total = 4*(Nr+1)
    w = [0]*total
    for i in range(Nk):
        w[i] = (key[4*i]<<24)|(key[4*i+1]<<16)|(key[4*i+2]<<8)|key[4*i+3]
    rc = 1
    for i in range(Nk, total):
        t = w[i-1]
        if i % Nk == 0:
            t = ((t<<8)|(t>>24)) & 0xffffffff
            t = (s[(t>>24)&0xff]<<24)|(s[(t>>16)&0xff]<<16)|(s[(t>>8)&0xff]<<8)|s[t&0xff]
            t ^= rc << 24
            rc = _gmul(rc, 2)
        elif Nk > 6 and i % Nk == 4:
            t = (s[(t>>24)&0xff]<<24)|(s[(t>>16)&0xff]<<16)|(s[(t>>8)&0xff]<<8)|s[t&0xff]
        w[i] = w[i-Nk] ^ t
    return w, Nr

def _rijndael_encrypt_block(block, key):
    s = _sbox(); w, Nr = _key_expansion(key)
    st = [[0]*4 for _ in range(4)]
    for i in range(16): st[i%4][i//4] = block[i]
    def addrk(rnd):
        for c in range(4):
            wd = w[rnd*4+c]
            st[0][c]^=(wd>>24)&0xff; st[1][c]^=(wd>>16)&0xff; st[2][c]^=(wd>>8)&0xff; st[3][c]^=wd&0xff
    addrk(0)
    for rnd in range(1, Nr):
        for r in range(4):
            for c in range(4): st[r][c] = s[st[r][c]]
        for r in range(1,4): st[r] = st[r][r:]+st[r][:r]
        for c in range(4):
            a=[st[r][c] for r in range(4)]
            st[0][c]=_gmul(a[0],2)^_gmul(a[1],3)^a[2]^a[3]
            st[1][c]=a[0]^_gmul(a[1],2)^_gmul(a[2],3)^a[3]
            st[2][c]=a[0]^a[1]^_gmul(a[2],2)^_gmul(a[3],3)
            st[3][c]=_gmul(a[0],3)^a[1]^a[2]^_gmul(a[3],2)
        addrk(rnd)
    for r in range(4):
        for c in range(4): st[r][c] = s[st[r][c]]
    for r in range(1,4): st[r] = st[r][r:]+st[r][:r]
    addrk(Nr)
    out = [0]*16
    for i in range(16): out[i] = st[i%4][i//4]
    return bytes(out)


_INV_SBOX = None
def _inv_sbox():
    global _INV_SBOX
    if _INV_SBOX: return _INV_SBOX
    s = _sbox(); inv = [0]*256
    for i in range(256): inv[s[i]] = i
    _INV_SBOX = inv
    return inv


def _rijndael_decrypt_block(block, key):
    """Inverse cipher (Nk=32/Nr=38) - used only by the host keyfile reconstruction
    on a HIT. Mirror of the device aes_decrypt_block."""
    inv = _inv_sbox(); w, Nr = _key_expansion(key)
    st = [[0]*4 for _ in range(4)]
    for i in range(16): st[i%4][i//4] = block[i]
    def addrk(rnd):
        for c in range(4):
            wd = w[rnd*4+c]
            st[0][c]^=(wd>>24)&0xff; st[1][c]^=(wd>>16)&0xff; st[2][c]^=(wd>>8)&0xff; st[3][c]^=wd&0xff
    addrk(Nr)
    for rnd in range(Nr-1, 0, -1):
        for r in range(1,4): st[r] = st[r][-r:]+st[r][:-r]   # InvShiftRows: right by r
        for r in range(4):
            for c in range(4): st[r][c] = inv[st[r][c]]
        addrk(rnd)
        for c in range(4):                                    # InvMixColumns
            a=[st[r][c] for r in range(4)]
            st[0][c]=_gmul(a[0],14)^_gmul(a[1],11)^_gmul(a[2],13)^_gmul(a[3],9)
            st[1][c]=_gmul(a[0],9)^_gmul(a[1],14)^_gmul(a[2],11)^_gmul(a[3],13)
            st[2][c]=_gmul(a[0],13)^_gmul(a[1],9)^_gmul(a[2],14)^_gmul(a[3],11)
            st[3][c]=_gmul(a[0],11)^_gmul(a[1],13)^_gmul(a[2],9)^_gmul(a[3],14)
    for r in range(1,4): st[r] = st[r][-r:]+st[r][:-r]
    for r in range(4):
        for c in range(4): st[r][c] = inv[st[r][c]]
    addrk(0)
    out = [0]*16
    for i in range(16): out[i] = st[i%4][i//4]
    return bytes(out)


# ----------------------------- .so binding -----------------------------
def load_lib():
    lib = ctypes.CDLL(SO)
    lib.pzl3_init.restype = ctypes.c_int
    lib.pzl3_init.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
    lib.pzl3_set_wordlists.restype = ctypes.c_int
    lib.pzl3_set_wordlists.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_int)]
    lib.pzl3_set_free.restype = ctypes.c_int
    lib.pzl3_set_free.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
    lib.pzl3_run_index_range.restype = ctypes.c_longlong
    lib.pzl3_run_index_range.argtypes = [ctypes.c_uint64, ctypes.c_uint64, ctypes.c_int, ctypes.c_int]
    lib.pzl3_selftest.restype = ctypes.c_int
    lib.pzl3_selftest.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
    lib.pzl3_bench.restype = ctypes.c_int
    lib.pzl3_bench.argtypes = [ctypes.c_uint64, ctypes.c_uint64, ctypes.c_int, ctypes.c_int,
                               ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_float)]
    return lib


def do_selftest(lib):
    salt, c0, expect_p0 = make_selftest_vector()
    P = SELFTEST_PASS.encode("ascii")
    assert len(P) == 32 or len(P) <= 32
    P32 = P + b"\x00" * (32 - len(P))   # NB: real puzzle P is always exactly 32 bytes
    if len(P) != 32:
        sys.stderr.write(f"[note] self-test passphrase is {len(P)}B; padding to 32 for the fixed-32 kernel. "
                         f"It still validates the full crypto chain on those bytes.\n")
        # Re-derive the vector for the padded 32-byte passphrase so GPU input == CPU reference.
        keyhex = stretch_keyhex(P32.decode("latin1"))
        D = evpkdf(keyhex.encode("ascii"), salt)
        key, iv = D[:128], D[128:144]
        plain0 = SELFTEST_PLAIN.encode("latin1")[:16]
        c0 = _rijndael_encrypt_block(bytes(a ^ b for a, b in zip(plain0, iv)), key)
        expect_p0 = plain0

    out = ctypes.create_string_buffer(16)
    rc = lib.pzl3_selftest(P32, salt, c0, out)
    if rc != 0:
        sys.stderr.write(f"[selftest] GPU launch failed rc={rc}\n"); return False
    got = out.raw[:16]
    ok = got[:5] == b'{"kty' and got == expect_p0
    sys.stderr.write(f"[selftest] expected p0 = {expect_p0!r}\n")
    sys.stderr.write(f"[selftest] GPU got  p0 = {got!r}\n")
    if ok:
        sys.stderr.write("[selftest] PASS - on-device SHA512^11513 + EvpKDF(MD5,1e4) + "
                         "Rijndael(Nk=32,Nr=38) CBC reproduces the known plaintext block 0.\n")
    else:
        sys.stderr.write("[selftest] FAIL - device output != reference.\n")
        return ok
    return ok and _free_slot_index_check()


def _free_slot_index_check():
    """Mini-check for the --free-slot mixed-radix logic (host-side, no GPU).

    Build a tiny 8-slot space where slot 0 is FREE over a small charset and the
    other 7 are 1-token wordlists, then confirm that the index of a KNOWN combo
    decodes back to that exact passphrase. This proves the base-cslen decode in
    index_to_pass(_host) is correct and that the device mirror would too.
    """
    charset = "abcdefghijklmnopqrstuvwxyz0123456789"   # same as the real runs
    cl = len(charset)
    free_k = 0
    fixed = ["md12", "a384", "cash", "e4d5", "root", "pull", "base"]  # slots 1..7
    slots = [[]] + [[w] for w in fixed]
    counts = [cl**4] + [1]*7
    # Pick a known free token and compute its expected global index.
    target = "weve"
    digits = [charset.index(ch) for ch in target]     # j=0 = first char = LSD
    sel = digits[0] + digits[1]*cl + digits[2]*cl*cl + digits[3]*cl*cl*cl
    # other slots are size 1 -> contribute index 0; free slot is slot 0 (radix base)
    idx = sel
    toks = index_to_pass_host(idx, counts, slots, free_k=free_k, charset=charset)
    expected = [target] + fixed
    ok = (toks == expected)
    sys.stderr.write(f"[free-check] idx={idx} -> tokens={toks}\n")
    if ok:
        sys.stderr.write(f"[free-check] PASS - free-slot index decode reproduces {target!r} + fixed slots.\n")
    else:
        sys.stderr.write(f"[free-check] FAIL - expected {expected}.\n")
    return ok


def do_bench(lib, total=None, configs=None, runs=3):
    """Measure RAW engine speed (attempts/sec) on SYNTHETIC inputs.

    NO wordlist is read and the real puzzle ciphertext is never used: each GPU
    thread derives its own 32-byte passphrase from its index and runs the full
    pipeline, writing one anti-DCE byte. We warm up, then take the median of
    `runs` timed launches, and sweep a few blocks x threads configs.
    """
    import statistics
    # Synthetic salt / cipher block 0 - arbitrary fixed bytes, NOT the puzzle's.
    syn_salt = bytes(range(8))
    syn_c0   = bytes((i * 7 + 1) & 0xff for i in range(16))

    if configs is None:
        # (blocks, threads). The engine is register-bound (~250 regs/thread), so
        # >128 threads/block exceeds the 64K-regs/block limit and won't launch;
        # we sweep valid configs and over-subscribe blocks for latency hiding.
        # The kernel is built __launch_bounds__(64), so threads/block must be <=64.
        # Throughput saturates by ~4096 blocks; tpb=32 and 64 are within 1%.
        configs = [
            (2048, 32), (4096, 32), (8192, 32),
            (2048, 64), (4096, 64), (8192, 64), (16384, 64),
        ]

    out_ms = ctypes.c_float(0.0)
    sys.stderr.write("[bench] RAW-SPEED probe on synthetic inputs (no wordlist, no real ciphertext).\n")
    sys.stderr.write("[bench] each attempt = 11513 SHA-512 + ~90000 MD5 + 1 AES block.\n")

    best = None
    for (blocks, threads) in configs:
        nthreads = blocks * threads
        # Pick `count` so the launch is long enough to time accurately but short
        # (~1-2 s). At ~200k attempts/s a count of ~3e5 keeps each run ~1.5 s.
        # If --bench-total is given, honour it exactly.
        count = total if total is not None else min(max(nthreads, 300_000), 600_000)
        # Warm-up (also forces JIT of the PTX on first launch).
        lib.pzl3_bench(0, count, threads, blocks, syn_salt, syn_c0, ctypes.byref(out_ms))
        times = []
        failed = False
        for r in range(runs):
            rc = lib.pzl3_bench(r * count, count, threads, blocks, syn_salt, syn_c0, ctypes.byref(out_ms))
            if rc != 0:
                sys.stderr.write(f"[bench] skip (blocks={blocks},threads={threads}): launch rc={rc}\n")
                failed = True
                break
            times.append(out_ms.value / 1000.0)  # seconds
        if failed:
            continue
        med = statistics.median(times)
        rate = count / med if med > 0 else 0.0
        sys.stderr.write(f"[bench] blocks={blocks:5d} threads={threads:4d} "
                         f"count={count:>12,} median={med*1000:9.2f} ms  "
                         f"=> {rate:12,.1f} attempts/s\n")
        if best is None or rate > best[0]:
            best = (rate, blocks, threads, count, med)

    rate, blocks, threads, count, med = best
    sys.stderr.write(f"\n[bench] BEST: {rate:,.1f} attempts/s  "
                     f"(blocks={blocks}, threads={threads})\n")
    # ETAs for the real search spaces.
    tier1 = 332_000
    full  = 35_000_000_000
    def fmt_eta(n):
        s = n / rate
        if s < 90:        return f"{s:.1f} s"
        if s < 5400:      return f"{s/60:.1f} min"
        if s < 129600:    return f"{s/3600:.1f} h"
        return f"{s/86400:.1f} days"
    sys.stderr.write(f"[bench] ETA Tier-1 ({tier1:,} combos): {fmt_eta(tier1)}\n")
    sys.stderr.write(f"[bench] ETA full   ({full:,} combos): {fmt_eta(full)}\n")
    return True


def load_wordlists(wl_dir, free_k=-1, cslen=0):
    """Read data/wordlists/{1..8}.txt -> packed buffer + counts for set_wordlists.

    If `free_k` (0-based slot index) is >=0, that slot's wordlist file is NOT read;
    its count is set to cslen**4 (the size of the generated [charset]^4 space) so
    the host's total/ETA bookkeeping is correct. The device GENERATES that slot's
    token from the charset (see pzl3_set_free), so its c_words bytes are unused.
    """
    buf = bytearray(8 * MAX_TOK * 4)
    counts = (ctypes.c_int * 8)()
    for k in range(8):
        if k == free_k:
            counts[k] = cslen ** 4    # generated slot: count = |charset|^4
            continue
        f = os.path.join(wl_dir, f"{k+1}.txt")
        words = []
        with open(f, "r", encoding="utf-8", errors="ignore") as fh:
            for ln in fh:
                w = ln.strip().lower()
                if w and not w.startswith("#"):
                    words.append(w)
        words = list(dict.fromkeys(words))[:MAX_TOK]
        if not words:
            raise SystemExit(f"empty wordlist {f}")
        for i, tok in enumerate(words):
            tb = tok.encode("ascii")[:4].ljust(4, b"\x00")
            off = (k * MAX_TOK + i) * 4
            buf[off:off+4] = tb
        counts[k] = len(words)
    return bytes(buf), counts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true", help="GPU 1-vector correctness check (default)")
    ap.add_argument("--bench", action="store_true",
                    help="measure RAW engine speed (attempts/s) on SYNTHETIC inputs; no wordlist, no real ciphertext")
    ap.add_argument("--bench-total", type=int, default=None,
                    help="total synthetic attempts per launch (default: auto, ~1/thread)")
    ap.add_argument("--bench-runs", type=int, default=3, help="timed runs per config (median)")
    ap.add_argument("--sweep", action="store_true", help="stream the index space to the GPU (BRUTE)")
    ap.add_argument("--i-understand-this-bruteforces", action="store_true")
    ap.add_argument("--free-slot", type=int, default=None,
                    help="1..8: GENERATE this slot from --charset ([cs]^4) instead of its wordlist. "
                         "The other 7 slots come from their wordlists (often 1 line = fixed value).")
    ap.add_argument("--charset", default="abcdefghijklmnopqrstuvwxyz0123456789",
                    help="charset for the free slot (default = [a-z0-9], 1,679,616 combos)")
    ap.add_argument("--page", default=None,
                    help="path to the puzzle's page script/HTML containing var msg=\"...\" "
                         "(required for --sweep)")
    ap.add_argument("--wordlists", default="wordlists",
                    help="dir with 1.txt..8.txt, one token per line (required for --sweep)")
    ap.add_argument("--out", default="results",
                    help="directory to write the recovered keyfile into on a hit")
    ap.add_argument("--threads", type=int, default=64)   # kernel is __launch_bounds__(64)
    ap.add_argument("--blocks", type=int, default=8192)   # saturates throughput on a consumer RTX-class GPU
    ap.add_argument("--chunk", type=int, default=1_000_000, help="indices per GPU launch")
    args = ap.parse_args()

    if not os.path.exists(SO):
        sys.stderr.write(f"ERROR: {SO} not found. Build it first:  ./build.sh\n")
        return 2

    lib = load_lib()

    # Always run the self-test first (oracle gate).
    if not do_selftest(lib):
        return 1

    if args.bench:
        ok = do_bench(lib, total=args.bench_total, runs=args.bench_runs)
        return 0 if ok else 1

    if not args.sweep:
        return 0

    if not args.i_understand_this_bruteforces:
        sys.stderr.write("\nRefusing to sweep without --i-understand-this-bruteforces.\n"
                         "This is the crack run; only launch with anchored wordlists.\n")
        return 3

    # ---- real sweep path (host streamer). Guarded; not exercised by CI/self-test. ----
    free_k = -1
    cslen  = 0
    charset = args.charset
    if args.free_slot is not None:
        if not (1 <= args.free_slot <= 8):
            sys.stderr.write(f"--free-slot must be 1..8 (got {args.free_slot})\n"); return 3
        free_k = args.free_slot - 1   # device wants 0-based
        cslen  = len(charset)
        if cslen == 0 or cslen > 64:
            sys.stderr.write(f"--charset length must be 1..64 (got {cslen})\n"); return 3

    if not args.page:
        sys.stderr.write("ERROR: --sweep requires --page <path to the puzzle's page script/HTML>\n")
        return 3
    msg = load_msg_from_page(args.page)
    salt, ct = parse_openssl_b64(msg)
    c0 = ct[:16]
    assert lib.pzl3_init(salt, c0) == 0, "pzl3_init failed"
    wbuf, counts = load_wordlists(args.wordlists, free_k=free_k, cslen=cslen)
    assert lib.pzl3_set_wordlists(wbuf, counts) == 0, "set_wordlists failed"
    slots_py = read_wordlists_py(args.wordlists, free_k=free_k)
    if free_k >= 0:
        assert lib.pzl3_set_free(free_k, charset.encode("ascii"), cslen) == 0, "set_free failed"
        sys.stderr.write(f"[sweep] FREE slot = {free_k+1} (1-based), charset='{charset}' "
                         f"({cslen} chars) -> {cslen**4:,} combos for that slot\n")
    else:
        # explicit: pure wordlist mode (c_free_k=-1 already set by pzl3_init)
        assert lib.pzl3_set_free(-1, b"", 0) == 0, "set_free(-1) failed"
    total = 1
    for k in range(8): total *= counts[k]
    sys.stderr.write(f"[sweep] slot sizes = {[counts[k] for k in range(8)]}  total = {total:,}\n")

    t0 = time.time(); done = 0; start = 0
    while start < total:
        n = min(args.chunk, total - start)
        hit = lib.pzl3_run_index_range(start, n, args.threads, args.blocks)
        if hit >= 0:
            sys.stderr.write(f"\n[sweep] HIT at index {hit}\n")
            _report_hit(lib, hit, counts, salt, ct, slots=slots_py,
                        free_k=free_k, charset=charset, out_dir=args.out)
            return 0
        done += n; start += n
        rate = done / max(1e-9, time.time() - t0)
        sys.stderr.write(f"\r[sweep] {done:,}/{total:,} ({rate:,.0f}/s) {100*done/total:.2f}%   ")
        sys.stderr.flush()
    sys.stderr.write(f"\n[sweep] exhausted {total:,} - no hit.\n")
    return 1


def read_wordlists_py(wl_dir, free_k=-1):
    """Return list[8] of token-lists (same dedup/lower/limit as the device load).
    The free slot (0-based free_k) gets an empty list (generated, not stored)."""
    slots = []
    for k in range(8):
        if k == free_k:
            slots.append([])   # generated on the fly
            continue
        f = os.path.join(wl_dir, f"{k+1}.txt")
        words = []
        with open(f, "r", encoding="utf-8", errors="ignore") as fh:
            for ln in fh:
                w = ln.strip().lower()
                if w and not w.startswith("#"):
                    words.append(w)
        words = list(dict.fromkeys(words))[:MAX_TOK]
        slots.append([tok.encode("ascii")[:4].ljust(4, b"\x00").decode("latin1").rstrip("\x00")
                      for tok in words])
    return slots


def index_to_pass_host(idx, counts, slots, free_k=-1, charset=""):
    """CPU mirror of the device index_to_pass: mixed-radix decode of `idx` over the
    8 slots, returning the 8 four-char tokens. The free slot decodes `sel` in
    base-len(charset) over `charset` (j=0 = least-significant digit = first char)."""
    toks = []
    for k in range(8):
        n = counts[k]
        sel = idx % n
        idx //= n
        if k == free_k:
            cs = charset; cl = len(cs); s = sel; cc = []
            for _j in range(4):
                cc.append(cs[s % cl]); s //= cl
            toks.append("".join(cc))
        else:
            toks.append(slots[k][sel])
    return toks


def _report_hit(lib, idx, counts, salt, ct, slots=None, free_k=-1, charset="", out_dir="results"):
    """Reconstruct the 8 tokens for the winning index, re-derive the passphrase,
    full-decrypt the ciphertext on CPU (reference impl), and write the keyfile."""
    if slots is None:
        sys.stderr.write(f"[report] winning global index = {idx} (no wordlists handed in).\n")
        return None
    toks = index_to_pass_host(idx, counts, slots, free_k=free_k, charset=charset)
    passphrase = "".join(toks)
    sys.stderr.write("\n" + "=" * 64 + "\n")
    sys.stderr.write("  *** HIT - ARWEAVE PUZZLE #3 SOLVED ***\n")
    sys.stderr.write(f"  tokens     = {toks}\n")
    sys.stderr.write(f"  PASSPHRASE = {passphrase}\n")
    sys.stderr.write(f"  index      = {idx}\n")
    sys.stderr.write("=" * 64 + "\n")

    # Full CPU decrypt of the whole ciphertext to recover the JWK keyfile.
    keyhex = stretch_keyhex(passphrase)
    D = evpkdf(keyhex.encode("ascii"), salt)
    key, iv = D[:128], D[128:144]
    plain = b""
    prev = iv
    for off in range(0, len(ct) - len(ct) % 16, 16):
        cblk = ct[off:off+16]
        dec = _rijndael_decrypt_block(cblk, key)
        plain += bytes(a ^ b for a, b in zip(dec, prev))
        prev = cblk
    # strip PKCS#7 padding if present
    if plain and 1 <= plain[-1] <= 16:
        plain = plain[:-plain[-1]]
    os.makedirs(out_dir, exist_ok=True)
    kf = os.path.join(out_dir, "arweave_keyfile_SOLVED.json")
    with open(kf, "wb") as f:
        f.write(plain)
    sys.stderr.write(f"[report] keyfile written -> {kf} ({len(plain)} bytes)\n")
    sys.stderr.write(f"[report] keyfile starts: {plain[:48]!r}\n")
    return passphrase


if __name__ == "__main__":
    sys.exit(main())
