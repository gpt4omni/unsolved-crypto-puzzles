#!/usr/bin/env python3
# ── CONTEXT ──
# CONTEXT - Part of a PUBLIC cryptopuzzle-solving project (treasure hunt / CTF).
# This engine is used ONLY against puzzle-reward addresses whose own author locked
# and PUBLISHED them as an open challenge - never a third-party wallet or leaked key.
# See CONTEXT.md at the repo root. Rule: zero false positives; funds verified on-chain.
# ────
"""Generic BIP39-passphrase GPU streaming driver (libbip39pass.so).

FIXED mnemonic + unknown passphrase. Derives via PBKDF2-SHA512 -> BIP32
(configurable path, default BIP84 m/84'/0'/0'/0/0) -> compressed pubkey
-> hash160 -> compare to a target hash160.

Reads newline-delimited passphrase candidates from --file or stdin (so it
can be fed by hashcat --stdout / PRINCE / combinator). Mandatory oracle
selftest before any sweep; every GPU hit is RE-DERIVED on CPU (coincurve)
before being declared a solution -> zero false positives.

Usage:
  generator | python3 bip39pass_stream.py \
      --mnemonic "<24 words>" --target-hash160 <40hex> [--path 84h/0h/0h/0/0]

Oracle (no args needed for default Corey kitten test): --selftest
"""
import ctypes, os, sys, time, argparse, hashlib, hmac, struct
from coincurve import PublicKey

HERE = os.path.dirname(os.path.abspath(__file__))
SO = os.path.join(HERE, "libbip39pass.so")
PP_STRIDE = 64
H = 0x80000000
CURVE_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

# ---- Corey kitten oracle constants (default selftest) ----
KITTEN_MNEMONIC = ("blossom educate state course sick fresh color divide number "
                   "soap please pull glide weather join grit depart dynamic tenant "
                   "leopard alter piano slight room")
KITTEN_SISTER_H160 = bytes.fromhex("a7b3cbaa248820a495b4dadc1e9a9f0670960db6")

# ---------------- CPU re-derivation (path-configurable) ----------------
def parse_path(s):
    """'84h/0h/0h/0/0' -> [(84,True),(0,True),(0,True),(0,False),(0,False)]"""
    out = []
    for tok in s.replace("m/", "").split("/"):
        tok = tok.strip()
        if not tok:
            continue
        hard = tok.endswith("'") or tok.lower().endswith("h")
        idx = int(tok.rstrip("'hH"))
        out.append((idx, hard))
    return out

def cpu_h160(mnemonic, passphrase, path):
    seed = hashlib.pbkdf2_hmac("sha512", mnemonic.encode("utf-8"),
                               b"mnemonic" + passphrase.encode("utf-8"), 2048, 64)
    I = hmac.new(b"Bitcoin seed", seed, hashlib.sha512).digest()
    k = int.from_bytes(I[:32], "big"); c = I[32:]
    for idx, hard in path:
        ci = idx | H if hard else idx
        if hard:
            data = b"\x00" + k.to_bytes(32, "big") + struct.pack(">I", ci)
        else:
            pub = PublicKey.from_secret(k.to_bytes(32, "big")).format(True)
            data = pub + struct.pack(">I", ci)
        I = hmac.new(c, data, hashlib.sha512).digest()
        k = (int.from_bytes(I[:32], "big") + k) % CURVE_N
        c = I[32:]
    pub = PublicKey.from_secret(k.to_bytes(32, "big")).format(True)
    return hashlib.new("ripemd160", hashlib.sha256(pub).digest()).digest()

# ---------------- GPU lib ----------------
def load():
    lib = ctypes.CDLL(SO)
    lib.bip39pass_init.restype = ctypes.c_int
    lib.bip39pass_init.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p]
    lib.bip39pass_run_batch.restype = ctypes.c_int
    lib.bip39pass_run_batch.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_int),
                                        ctypes.c_int, ctypes.c_int]
    lib.bip39pass_set_path.restype = ctypes.c_int
    lib.bip39pass_set_path.argtypes = [ctypes.POINTER(ctypes.c_uint32),
                                       ctypes.POINTER(ctypes.c_uint8), ctypes.c_int]
    return lib

def set_path(lib, path):
    n = len(path)
    lv = (ctypes.c_uint32 * n)(*[p[0] for p in path])
    hd = (ctypes.c_uint8 * n)(*[1 if p[1] else 0 for p in path])
    assert lib.bip39pass_set_path(lv, hd, n) == 0, "set_path failed"

def run_batch(lib, passphrases):
    n = len(passphrases)
    buf = bytearray(n * PP_STRIDE)
    lens = (ctypes.c_int * n)()
    for i, pw in enumerate(passphrases):
        b = pw.encode("utf-8")[:PP_STRIDE]
        buf[i*PP_STRIDE:i*PP_STRIDE+len(b)] = b
        lens[i] = len(b)
    return lib.bip39pass_run_batch(bytes(buf), lens, PP_STRIDE, n)

def oracle_selftest(lib):
    """Corey kitten: empty passphrase -> sister h160; wrong pw -> no match."""
    mb = KITTEN_MNEMONIC.encode()
    set_path(lib, parse_path("84h/0h/0h/0/0"))
    assert lib.bip39pass_init(mb, len(mb), KITTEN_SISTER_H160) == 0
    assert run_batch(lib, [""]) == 0, "ORACLE FAIL: empty passphrase != sister"
    assert run_batch(lib, ["definitely_not_it"]) == -1, "FALSE POSITIVE in oracle"
    sys.stderr.write("[oracle] GPU bip39pass OK: empty->sister; negative control clean\n")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mnemonic", default=KITTEN_MNEMONIC)
    ap.add_argument("--target-hash160", default=None, help="40 hex chars")
    ap.add_argument("--path", default="84h/0h/0h/0/0")
    ap.add_argument("--file", default=None)
    ap.add_argument("--batch", type=int, default=200000)
    ap.add_argument("--bench", type=int, default=0)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    lib = load()
    oracle_selftest(lib)            # mandatory, always
    if args.selftest:
        return 0

    path = parse_path(args.path)
    set_path(lib, path)

    if args.bench:
        mb = args.mnemonic.encode()
        lib.bip39pass_init(mb, len(mb), KITTEN_SISTER_H160)
        cand = ["bench%d" % i for i in range(args.bench)]
        t = time.time(); run_batch(lib, cand); dt = time.time() - t
        sys.stderr.write(f"BENCH: {args.bench:,} in {dt:.2f}s = {args.bench/dt:,.0f}/s\n")
        return 0

    if not args.target_hash160:
        sys.stderr.write("ERROR: --target-hash160 required for a real run\n"); return 2
    target = bytes.fromhex(args.target_hash160)
    assert len(target) == 20
    mb = args.mnemonic.encode()
    assert lib.bip39pass_init(mb, len(mb), target) == 0

    src = open(args.file, "r", encoding="utf-8", errors="ignore") if args.file \
          else open(sys.stdin.fileno(), "r", encoding="utf-8", errors="ignore")
    batch, count, t0, last = [], 0, time.time(), time.time()

    def flush():
        nonlocal count
        if not batch:
            return None
        idx = run_batch(lib, batch)
        if idx != -1:
            return batch[idx]
        count += len(batch)
        return None

    for line in src:
        pw = line.rstrip("\n")
        if len(pw.encode("utf-8")) > PP_STRIDE:
            continue
        batch.append(pw)
        if len(batch) >= args.batch:
            hit = flush()
            if hit is not None:
                return declare(args, path, target, hit)
            batch.clear()
            now = time.time()
            if now - last > 5:
                sys.stderr.write(f"\r[{count:,} tried, {count/(now-t0):,.0f}/s]   "); sys.stderr.flush()
                last = now
    hit = flush()
    if hit is not None:
        return declare(args, path, target, hit)
    sys.stderr.write(f"\nDONE: {count:,} candidates, no match\n")
    return 1

def declare(args, path, target, pw):
    # CPU re-derivation - zero false positive gate
    h = cpu_h160(args.mnemonic, pw, path)
    sys.stderr.write(f"\n!!! GPU MATCH candidate={pw!r}\n")
    if h == target:
        sys.stderr.write(f"CONFIRMED on CPU re-derive. passphrase={pw!r}\n")
        print(f"SOLUTION\t{pw}")
        return 0
    sys.stderr.write(f"WARNING: GPU hit did NOT survive CPU re-derive ({h.hex()} != {target.hex()})\n")
    return 1

if __name__ == "__main__":
    sys.exit(main())
