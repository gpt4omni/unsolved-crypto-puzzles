#!/usr/bin/env python3
# ── CONTEXT ──
# CONTEXT - Part of a PUBLIC cryptopuzzle-solving project (treasure hunt / CTF).
# This engine is used ONLY against puzzle-reward addresses whose own author locked
# and PUBLISHED them as an open challenge - never a third-party wallet or leaked key.
# See CONTEXT.md at the repo root. Rule: zero false positives; funds verified on-chain.
# ────
"""ETH-mode driver for the shared bip39 passphrase engine (libbip39pass.so).

VARIABLE 12-word mnemonic (from word indices) + EMPTY passphrase
  -> PBKDF2-SHA512 -> BIP32 c_path (default ETH m/44'/60'/0'/0/0)
  -> UNCOMPRESSED pubkey -> keccak256 -> last 20 bytes = ETH address
  -> byte-exact compare to a 20-byte target.

Reuses 90% of the existing engine; only the keccak/ETH output kernel is new.
Mandatory KAT validation (anti-false-negative) before any brute.
Every GPU hit is re-derived on CPU (bip_utils) before being declared.
"""
import ctypes, os, sys, time, hashlib, hmac, struct
from coincurve import PublicKey

HERE = os.path.dirname(os.path.abspath(__file__))
SO = os.path.join(HERE, "libbip39pass.so")
H = 0x80000000
CURVE_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

try:
    from Crypto.Hash import keccak as _keccak
    def keccak256(b):
        k = _keccak.new(digest_bits=256); k.update(b); return k.digest()
except Exception:
    from sha3 import keccak_256
    def keccak256(b):
        return keccak_256(b).digest()


def parse_path(s):
    out = []
    for tok in s.replace("m/", "").split("/"):
        tok = tok.strip()
        if not tok:
            continue
        hard = tok.endswith("'") or tok.lower().endswith("h")
        idx = int(tok.rstrip("'hH"))
        out.append((idx, hard))
    return out


def cpu_eth_addr(mnemonic, path, passphrase=""):
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
    pub = PublicKey.from_secret(k.to_bytes(32, "big")).format(False)[1:]  # 64 bytes x||y
    return keccak256(pub)[-20:]


def load():
    lib = ctypes.CDLL(SO)
    lib.bip39pass_set_path.restype = ctypes.c_int
    lib.bip39pass_set_path.argtypes = [ctypes.POINTER(ctypes.c_uint32),
                                       ctypes.POINTER(ctypes.c_uint8), ctypes.c_int]
    lib.bip39pass_load_wordlist.restype = ctypes.c_int
    lib.bip39pass_load_wordlist.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
    lib.bip39pass_set_eth_target.restype = ctypes.c_int
    lib.bip39pass_set_eth_target.argtypes = [ctypes.c_char_p]
    lib.bip39pass_run_eth_batch.restype = ctypes.c_int
    lib.bip39pass_run_eth_batch.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.c_int]
    return lib


def set_path(lib, path):
    n = len(path)
    lv = (ctypes.c_uint32 * n)(*[p[0] for p in path])
    hd = (ctypes.c_uint8 * n)(*[1 if p[1] else 0 for p in path])
    assert lib.bip39pass_set_path(lv, hd, n) == 0, "set_path failed"


def load_wordlist(lib, words):
    flat = bytearray(2048 * 9)
    lens = bytearray(2048)
    for i, wd in enumerate(words):
        b = wd.encode("ascii")
        flat[i*9:i*9+len(b)] = b
        lens[i] = len(b)
    assert lib.bip39pass_load_wordlist(bytes(flat), bytes(lens)) == 0, "load_wordlist failed"


def set_target(lib, addr_hex):
    t = bytes.fromhex(addr_hex.lower().replace("0x", ""))
    assert len(t) == 20
    assert lib.bip39pass_set_eth_target(t) == 0, "set_eth_target failed"
    return t


def run_eth_batch(lib, idx_rows):
    """idx_rows: list of 12-int lists. Returns matching row index or -1."""
    n = len(idx_rows)
    flat = (ctypes.c_int * (n * 12))()
    p = 0
    for row in idx_rows:
        for v in row:
            flat[p] = v; p += 1
    return lib.bip39pass_run_eth_batch(flat, n)


def wordlist_path():
    return os.path.join(HERE, "lib", "bip39_english.txt")
