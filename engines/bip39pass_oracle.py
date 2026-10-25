#!/usr/bin/env python3
# ── CONTEXT ──
# CONTEXT - Part of a PUBLIC cryptopuzzle-solving project (treasure hunt / CTF).
# This engine is used ONLY against puzzle-reward addresses whose own author locked
# and PUBLISHED them as an open challenge - never a third-party wallet or leaked key.
# See CONTEXT.md at the repo root. Rule: zero false positives; funds verified on-chain.
# ────
"""Oracle selftest for the shared BIP39-passphrase GPU engine (libbip39pass.so).

Corey kitten oracle: with the FIXED kitten mnemonic and BIP84 m/84'/0'/0'/0/0,
the EMPTY passphrase must derive the public "sister" address
bc1q57euh23y3qs2f9d5mtwpax5lqecfvrdkqce82a (h160 a7b3...0db6).
A wrong passphrase must NOT match (negative control).

Exit 0 = oracle green; nonzero = engine broken, do NOT trust any sweep.
"""
import ctypes, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SO = os.path.join(HERE, "libbip39pass.so")

MNEMONIC = ("blossom educate state course sick fresh color divide number soap "
            "please pull glide weather join grit depart dynamic tenant leopard "
            "alter piano slight room")
SISTER_H160 = bytes.fromhex("a7b3cbaa248820a495b4dadc1e9a9f0670960db6")
PP_STRIDE = 64

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

def run_batch(lib, passphrases):
    n = len(passphrases)
    buf = bytearray(n * PP_STRIDE)
    lens = (ctypes.c_int * n)()
    for i, pw in enumerate(passphrases):
        b = pw.encode("utf-8")[:PP_STRIDE]
        buf[i*PP_STRIDE:i*PP_STRIDE+len(b)] = b
        lens[i] = len(b)
    return lib.bip39pass_run_batch(bytes(buf), lens, PP_STRIDE, n)

def main():
    lib = load()
    mb = MNEMONIC.encode()
    # default path is BIP84 m/84'/0'/0'/0/0 - exactly the Corey oracle path.
    assert lib.bip39pass_init(mb, len(mb), SISTER_H160) == 0, "init failed"
    idx = run_batch(lib, [""])
    assert idx == 0, f"ORACLE FAIL: empty passphrase did not match sister (idx={idx})"
    idx2 = run_batch(lib, ["definitely_not_the_passphrase"])
    assert idx2 == -1, f"FALSE POSITIVE: wrong passphrase matched (idx={idx2})"
    print("BIP39PASS ORACLE OK: empty->sister h160 matched; negative control clean")
    return 0

if __name__ == "__main__":
    sys.exit(main())
