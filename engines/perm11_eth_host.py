#!/usr/bin/env python3
# ── CONTEXT ──
# CONTEXT - Part of a PUBLIC cryptopuzzle-solving project (treasure hunt / CTF).
# This engine is used ONLY against puzzle-reward addresses whose own author locked
# and PUBLISHED them as an open challenge - never a third-party wallet or leaked key.
# See CONTEXT.md at the repo root. Rule: zero false positives; funds verified on-chain.
# ────
"""Host driver for check_perm11_eth (libbip39pass.so).

ORDER SEARCH: a set of 11 BIP39 words is locked, its ORDER is not.
Space = 11! orders x 128 valid twelfth words = 5 108 300 800 mnemonics.

The GPU generates every candidate from its own global index -- the host sends
only the 11 word indices, the target address and (base, count). Nothing else
crosses PCIe.

    g          = base + tid
    perm_index = g // 128     -> Lehmer decode, most-significant digit first,
                                 i.e. the same lexicographic order as
                                 itertools.permutations(fixed11)
    hi7        = g %  128     -> the 7 entropy bits of word 12
    word12     = (hi7 << 4) | (sha256(entropy16)[0] >> 4)

Subcommands
    selftest   run the 7-witness KAT (see kat() below) + the PBKDF2 counter check
    bench      measure throughput over a bounded number of seconds
    shard      scan [base, base+count) for a real target

Every GPU hit is re-derived on CPU here before being printed: zero false positive.
"""
import argparse
import ctypes
import hashlib
import math
import os
import random
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SO = os.path.join(HERE, "libbip39pass.so")
DEFAULT_WORDLIST = os.path.join(HERE, "lib", "bip39_english.txt")

PERM11_TOTAL = math.factorial(11) * 128          # 5 108 300 800
ETH_PATH = "m/44'/60'/0'/0/0"
SENTINEL = (1 << 64) - 1

# ----------------------------------------------------------------------------
# CPU reference (bip_utils + eth_utils) -- the oracle the GPU must reproduce
# ----------------------------------------------------------------------------
from bip_utils import Bip32Slip10Secp256k1                     # noqa: E402
from eth_utils import keccak                                   # noqa: E402


def load_wordlist(path):
    words = open(path).read().split()
    assert len(words) == 2048, "bad wordlist: %d words" % len(words)
    return words


def cpu_eth_addr(mnemonic, path=ETH_PATH):
    seed = hashlib.pbkdf2_hmac("sha512", mnemonic.encode(), b"mnemonic", 2048)
    k = Bip32Slip10Secp256k1.FromSeed(seed).DerivePath(path)
    pub = k.PublicKey().RawUncompressed().ToBytes()[-64:]
    return "0x" + keccak(pub)[-20:].hex()


def perm_rank(base_list, perm):
    """Lexicographic rank of `perm` among permutations of `base_list`.
    Inverse of the GPU's Lehmer decode."""
    pool = list(base_list)
    r = 0
    n = len(pool)
    for i, x in enumerate(perm):
        d = pool.index(x)
        r += d * math.factorial(n - 1 - i)
        pool.pop(d)
    return r


def perm_unrank(base_list, rank):
    """Lehmer decode, most-significant digit first (mirrors the kernel)."""
    pool = list(base_list)
    n = len(pool)
    out = []
    r = rank
    for i in range(n):
        f = math.factorial(n - 1 - i)
        d = r // f
        r -= d * f
        out.append(pool.pop(d))
    return out


def mnemonic_from_g(fixed11, g, words):
    """Rebuild on CPU exactly what the kernel builds for global index g."""
    idx = {w: i for i, w in enumerate(words)}
    perm_index, hi7 = divmod(g, 128)
    perm = perm_unrank(fixed11, perm_index)
    prefix = 0
    for w in perm:
        prefix = (prefix << 11) | idx[w]
    ent = ((prefix << 7) | hi7).to_bytes(16, "big")
    cs = hashlib.sha256(ent).digest()[0] >> 4
    w12 = words[(hi7 << 4) | cs]
    return " ".join(perm + [w12])


def g_from(fixed11, perm, hi7):
    return perm_rank(fixed11, perm) * 128 + hi7


# ----------------------------------------------------------------------------
# GPU binding
# ----------------------------------------------------------------------------
class Engine:
    def __init__(self, words, so=SO):
        self.lib = ctypes.CDLL(so)
        L = self.lib
        L.bip39pass_set_path.restype = ctypes.c_int
        L.bip39pass_set_path.argtypes = [ctypes.POINTER(ctypes.c_uint32),
                                         ctypes.POINTER(ctypes.c_uint8), ctypes.c_int]
        L.bip39pass_load_wordlist.restype = ctypes.c_int
        L.bip39pass_load_wordlist.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
        L.bip39pass_set_eth_target.restype = ctypes.c_int
        L.bip39pass_set_eth_target.argtypes = [ctypes.c_char_p]
        L.bip39pass_run_perm11_eth.restype = ctypes.c_int
        L.bip39pass_run_perm11_eth.argtypes = [ctypes.POINTER(ctypes.c_int),
                                               ctypes.c_uint64, ctypes.c_uint64,
                                               ctypes.POINTER(ctypes.c_uint64)]
        L.bip39pass_perm11_reset_counter.restype = ctypes.c_int
        L.bip39pass_perm11_get_counter.restype = ctypes.c_int
        L.bip39pass_perm11_get_counter.argtypes = [ctypes.POINTER(ctypes.c_uint64)]
        L.bip39pass_perm11_set_batch.restype = ctypes.c_int
        L.bip39pass_perm11_set_batch.argtypes = [ctypes.c_uint64]
        L.bip39pass_perm11_get_batch.restype = ctypes.c_uint64

        self.words = words
        self.idx = {w: i for i, w in enumerate(words)}

        # wordlist -> device
        flat = bytearray(2048 * 9)
        lens = bytearray(2048)
        for i, wd in enumerate(words):
            b = wd.encode("ascii")
            flat[i * 9:i * 9 + len(b)] = b
            lens[i] = len(b)
        assert L.bip39pass_load_wordlist(bytes(flat), bytes(lens)) == 0

        # m/44'/60'/0'/0/0
        lv = (ctypes.c_uint32 * 5)(44, 60, 0, 0, 0)
        hd = (ctypes.c_uint8 * 5)(1, 1, 1, 0, 0)
        assert L.bip39pass_set_path(lv, hd, 5) == 0

    def set_target(self, addr_hex):
        t = bytes.fromhex(addr_hex.lower().replace("0x", ""))
        assert len(t) == 20
        assert self.lib.bip39pass_set_eth_target(t) == 0

    def set_batch(self, b):
        assert self.lib.bip39pass_perm11_set_batch(ctypes.c_uint64(b)) == 0

    def get_batch(self):
        return int(self.lib.bip39pass_perm11_get_batch())

    def reset_counter(self):
        assert self.lib.bip39pass_perm11_reset_counter() == 0

    def counter(self):
        c = ctypes.c_uint64(0)
        assert self.lib.bip39pass_perm11_get_counter(ctypes.byref(c)) == 0
        return int(c.value)

    def run(self, fixed11, base, count):
        arr = (ctypes.c_int * 11)(*[self.idx[w] for w in fixed11])
        out = ctypes.c_uint64(SENTINEL)
        rc = self.lib.bip39pass_run_perm11_eth(arr, ctypes.c_uint64(base),
                                               ctypes.c_uint64(count),
                                               ctypes.byref(out))
        if rc != 0:
            raise RuntimeError("CUDA error %d" % rc)
        return int(out.value)


# ----------------------------------------------------------------------------
# KAT / self-test
# ----------------------------------------------------------------------------
# This 11-word set comes from a real order-search puzzle: 11 BIP39 words
# were known but their order was locked. Any 11 distinct BIP39 words work
# here, since the KAT below only checks GPU/CPU self-consistency, not a
# real target address.
KAT_SET = ["divide", "tonight", "torch", "galaxy", "song", "soul",
           "weapon", "give", "safe", "broken", "network"]


def kat(eng, fixed11, seed=20260726, span=120_000):
    """6 witnesses + negative control, each covering a distinct failure mode."""
    rng = random.Random(seed)
    words = eng.words
    fixed11 = list(fixed11)

    # a random middle permutation, reused for the hi7=0 / hi7=127 pair
    mid_perm = fixed11[:]
    rng.shuffle(mid_perm)
    other_perm = fixed11[:]
    rng.shuffle(other_perm)

    BATCH = 50_000                       # small batch to exercise the host loop
    sub_base = 2_000_000_000             # arbitrary mid-range base
    sub_base -= sub_base % 128           # (any base works; kernel is index-driven)

    cases = []
    # 1. very first index of the whole space -> catches a +/-1 decode shift
    cases.append(("W1 g=0 (very first)", 0, 0, span, None))
    # 2. very last index -> catches a truncated range / 32-bit overflow
    cases.append(("W2 g=11!*128-1 (very last)", PERM11_TOTAL - 1,
                  PERM11_TOTAL - span, span, None))
    # 3a. last index of sub-batch #1
    cases.append(("W3 last index of sub-batch 1", sub_base + BATCH - 1,
                  sub_base, 3 * BATCH, BATCH))
    # 3b. first index of sub-batch #2
    cases.append(("W4 first index of sub-batch 2", sub_base + BATCH,
                  sub_base, 3 * BATCH, BATCH))
    # 4. hi7 = 0 and hi7 = 127 on the SAME permutation -> all 128 w12 covered
    gp0 = g_from(fixed11, mid_perm, 0)
    gp127 = g_from(fixed11, mid_perm, 127)
    cases.append(("W5 hi7=0   (random perm A)", gp0, gp0 - span // 2, span, None))
    cases.append(("W6 hi7=127 (same perm A)", gp127, gp127 - span // 2, span, None))
    print("=" * 78)
    print("KAT check_perm11_eth  --  11-word set: %s" % " ".join(fixed11))
    print("target = ETH address of the witness, path %s, byte-exact comparison" % ETH_PATH)
    print("=" * 78)

    ok = True
    rows = []
    for name, g, base, count, batch in cases:
        base = max(0, base)
        if base + count > PERM11_TOTAL:
            base = PERM11_TOTAL - count
        assert base <= g < base + count, "witness outside range"

        mnem = mnemonic_from_g(fixed11, g, words)
        addr = cpu_eth_addr(mnem)
        eng.set_batch(batch if batch else 1 << 22)
        eng.set_target(addr)

        t0 = time.time()
        found = eng.run(fixed11, base, count)
        dt = time.time() - t0

        status = "OK " if found == g else "FAIL"
        if found != g:
            ok = False
        rows.append([name, str(g), mnem, addr,
                     (str(found) if found != SENTINEL else "NONE"),
                     "[%d,%d)" % (base, base + count),
                     str(batch if batch else 4194304),
                     "PASS" if found == g else "FAIL"])
        print("[%s] %-32s" % (status, name))
        print("        g expected = %-12d  g returned = %s" %
              (g, found if found != SENTINEL else "NONE"))
        print("        range      = [%d, %d)  sub-batch=%s  (%.2fs)" %
              (base, base + count, batch if batch else "default", dt))
        print("        mnemonic  = %s" % mnem)
        print("        addr      = %s" % addr)
        if found != SENTINEL and found != g:
            print("        !! the kernel returned the mnemonic: %s" %
                  mnemonic_from_g(fixed11, found, words))
        # zero-false-positive re-derivation on CPU
        if found != SENTINEL:
            back = cpu_eth_addr(mnemonic_from_g(fixed11, found, words))
            print("        CPU re-derive of the returned index = %s  %s" %
                  (back, "== target" if back == addr else "!= target  <<< FALSE POSITIVE"))
            if back != addr:
                ok = False
        print()

    # ---- NEGATIVE CONTROL: dummy target => 0 hit, and EXACTLY count PBKDF2 rounds.
    # A kernel that "matches" everything is as broken as one that matches
    # nothing; the counter additionally proves no thread silently drops out.
    print("-" * 78)
    dummy = "0x" + "de" * 20
    eng.set_target(dummy)
    for i, (batch, count) in enumerate(((33_333, 500_000), (1 << 22, 300_000), (7, 701))):
        eng.set_batch(batch)
        eng.reset_counter()
        t0 = time.time()
        found = eng.run(fixed11, 1_234_567_890, count)
        n = eng.counter()
        good = (n == count and found == SENTINEL)
        if not good:
            ok = False
        print("[%s] NEG%d dummy target %s : hits=%s  PBKDF2 counter %d/%d  (sub-batch=%d, %.2fs)"
              % ("OK " if good else "FAIL", i + 1, dummy[:10] + "...",
                 "0" if found == SENTINEL else "1 <<< FALSE POSITIVE",
                 n, count, batch, time.time() - t0))
        rows.append(["NEG%d negative control (dummy target)" % (i + 1), "-", "-", dummy,
                     "NONE" if found == SENTINEL else str(found),
                     "[%d,%d)" % (1_234_567_890, 1_234_567_890 + count),
                     str(batch),
                     "PASS (0 hit, %d/%d PBKDF2)" % (n, count) if good else "FAIL"])
    print("-" * 78)
    print("KAT VERDICT: %s" % ("ALL WITNESSES OK" if ok else "FAIL"))

    if KAT_TSV:
        with open(KAT_TSV, "w") as f:
            f.write("witness\texpected_index\tmnemonic\teth_address\treturned_index"
                    "\tscanned_range\tsub_batch\tverdict\n")
            for r in rows:
                f.write("\t".join(r) + "\n")
        print("witnesses.tsv -> %s" % KAT_TSV)
    return ok


KAT_TSV = None


# ----------------------------------------------------------------------------
def bench(eng, fixed11, seconds=60.0, batch=1 << 22):
    """Bounded throughput measurement on an unreachable target."""
    eng.set_target("0x" + "de" * 20)
    eng.set_batch(batch)
    # warm-up (JIT / clocks)
    eng.run(fixed11, 0, batch)
    eng.reset_counter()
    t0 = time.time()
    done = 0
    base = 1_000_000_000
    while time.time() - t0 < seconds:
        eng.run(fixed11, base + done, batch)
        done += batch
    dt = time.time() - t0
    n = eng.counter()
    assert n == done, "counter mismatch during bench: %d != %d" % (n, done)
    rate = done / dt
    print("bench: %d derivations in %.1fs  =>  %.0f/s  (%.3f Mder/s)"
          % (done, dt, rate, rate / 1e6))
    print("       full space 11!*128 = %d" % PERM11_TOTAL)
    print("       1 GPU: %.2f h" % (PERM11_TOTAL / rate / 3600))
    return rate


# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["selftest", "bench", "shard"])
    ap.add_argument("--words", default=",".join(KAT_SET),
                    help="the 11 fixed words, comma separated")
    ap.add_argument("--wordlist", default=DEFAULT_WORDLIST)
    ap.add_argument("--target", default=None, help="target ETH address (shard)")
    ap.add_argument("--base", type=int, default=0)
    ap.add_argument("--count", type=int, default=0)
    ap.add_argument("--batch", type=int, default=1 << 22)
    ap.add_argument("--seconds", type=float, default=60.0)
    ap.add_argument("--out", default=None, help="write hits here (shard)")
    ap.add_argument("--progress", default=None, help="progress log file (shard)")
    ap.add_argument("--counter-proof", default=None, help="counter proof file (shard)")
    ap.add_argument("--chunk", type=int, default=120_000_000,
                    help="candidates per progress step (shard)")
    ap.add_argument("--tsv", default=None, help="witnesses.tsv (selftest)")
    a = ap.parse_args()
    global KAT_TSV
    KAT_TSV = a.tsv

    words = load_wordlist(a.wordlist)
    fixed11 = a.words.split(",")
    assert len(fixed11) == 11 and len(set(fixed11)) == 11, "need 11 distinct words"
    for w in fixed11:
        assert w in words, "not a BIP39 word: %s" % w

    eng = Engine(words)

    if a.cmd == "selftest":
        sys.exit(0 if kat(eng, fixed11) else 1)

    if a.cmd == "bench":
        bench(eng, fixed11, a.seconds, a.batch)
        return

    # ---- shard ----
    assert a.target, "--target required"
    count = a.count or (PERM11_TOTAL - a.base)
    assert a.base >= 0 and a.base + count <= PERM11_TOTAL, "shard out of range"
    eng.set_target(a.target)
    eng.set_batch(a.batch)
    eng.reset_counter()

    prog = open(a.progress, "a", buffering=1) if a.progress else None

    def log(msg):
        line = "%s  %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg)
        print(line, flush=True)
        if prog:
            prog.write(line + "\n")

    log("START base=%d count=%d (%.4f%% of the space) target=%s sub-batch=%d"
        % (a.base, count, 100.0 * count / PERM11_TOTAL, a.target, a.batch))
    log("       words = %s" % " ".join(fixed11))
    log("       so    = %s" % SO)

    t0 = time.time()
    found = SENTINEL
    done = 0
    step = a.chunk                      # size of one progress step
    while done < count:
        span = min(step, count - done)
        r = eng.run(fixed11, a.base + done, span)
        done += span
        if r != SENTINEL:
            found = r
            break
        el = time.time() - t0
        rate = done / max(el, 1e-9)
        eta = (count - done) / max(rate, 1e-9)
        log("PROGRESS base=%d done=%d/%d (%.3f%%) rate=%.0f/s elapsed=%.0fs eta=%.0fs"
            % (a.base + done, done, count, 100.0 * done / count, rate, el, eta))

    dt = time.time() - t0
    n = eng.counter()
    log("END %d PBKDF2 in %.1fs (%.0f/s)" % (n, dt, n / max(dt, 1e-9)))
    if a.counter_proof:
        with open(a.counter_proof, "w") as f:
            f.write("pbkdf2_counter_executed = %d\n" % n)
            f.write("counter_expected        = %d\n" % count)
            f.write("exhaustive              = %s\n" % ("YES" if n == count else "NO"))
            f.write("duration_s              = %.1f\n" % dt)
            f.write("rate_der_per_s          = %.0f\n" % (n / max(dt, 1e-9)))
    if found == SENTINEL:
        # anti-false-negative: the shard is only 'exhausted' if the counter matches
        exhausted = (n == count)
        log("RESULT: NO_HIT  exhausted=%s  (%d/%d PBKDF2)"
            % ("YES" if exhausted else "NO <<< COVERAGE GAP", n, count))
        sys.exit(0 if exhausted else 2)
    mnem = mnemonic_from_g(fixed11, found, words)
    addr = cpu_eth_addr(mnem)
    good = addr.lower() == a.target.lower()
    log("RESULT: HIT g=%d" % found)
    log("  mnemonic : %s" % mnem)
    log("  CPU re-derive : %s  (%s)" % (addr, "CONFIRMED" if good else "FALSE POSITIVE"))
    if a.out:
        with open(a.out, "a") as f:
            f.write("%d\t%s\t%s\t%s\n" % (found, mnem, addr, "OK" if good else "FP"))
    sys.exit(0 if good else 3)


if __name__ == "__main__":
    main()
