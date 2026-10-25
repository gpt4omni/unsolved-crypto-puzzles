#!/usr/bin/env python3
"""
structured_candidates.py -- 2-share algebraic models for the Bitaps challenge.

Purpose:
    With only 2 of 3 Shamir points, a degree-2 polynomial is underdetermined by one
    GF(256) value per byte. Some extra assumptions make that value unique, or unique
    per byte from a 2-valued choice (N = 2^16). This script builds those candidate
    secrets, derives BIP84 m/84'/0'/0'/0/0, and compares to the escrow.

    It is not a search of the 125-bit residual. Families larger than 2^16 are refused.

Usage:
    python3 tools/structured_candidates.py --selftest
    python3 tools/structured_candidates.py --scan
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import os
import random
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("oracle", os.path.join(HERE, "oracle.py"))
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)

E1, X1 = oracle.decode_share(oracle.SHARE_1)
E2, X2 = oracle.decode_share(oracle.SHARE_2)


def to_addr(secret: bytes) -> str:
    return oracle.derive_address(oracle.encode_secret_mnemonic(secret))


def encode_share(entropy: bytes, index: int) -> str:
    bits = format(int.from_bytes(entropy, "big"), "0128b") + format(index, "04b")
    return " ".join(oracle._WORDS[int(bits[i : i + 11], 2)] for i in range(0, 132, 11))


def a2_zero(e1=E1, e2=E2, x1=X1, x2=X2) -> bytes:
    return oracle.restore_secret({x1: e1, x2: e2})


def a1_zero(e1=E1, e2=E2, x1=X1, x2=X2) -> bytes:
    p1, p2 = oracle.gf_pow(x1, 2), oracle.gf_pow(x2, 2)
    denom = p1 ^ p2
    out = bytearray()
    for i in range(16):
        a2 = oracle.gf_div(e1[i] ^ e2[i], denom)
        out.append(e1[i] ^ oracle.gf_mul(a2, p1))
    return bytes(out)


def a1_eq_a2(e1=E1, e2=E2, x1=X1, x2=X2) -> bytes:
    out = bytearray()
    for i in range(16):
        t1 = x1 ^ oracle.gf_pow(x1, 2)
        t2 = x2 ^ oracle.gf_pow(x2, 2)
        a = oracle.gf_div(e1[i] ^ e2[i], t1 ^ t2)
        out.append(e1[i] ^ oracle.gf_mul(a, t1))
    return bytes(out)


def a1_eq_s(e1=E1, e2=E2, x1=X1, x2=X2) -> bytes:
    out = bytearray()
    p1, p2 = oracle.gf_pow(x1, 2), oracle.gf_pow(x2, 2)
    for i in range(16):
        c1, c2 = 1 ^ x1, 1 ^ x2
        lhs = oracle.gf_mul(e1[i], p2) ^ oracle.gf_mul(e2[i], p1)
        rhs = oracle.gf_mul(c1, p2) ^ oracle.gf_mul(c2, p1)
        out.append(oracle.gf_div(lhs, rhs) if rhs else 0)
    return bytes(out)


def a2_eq_s(e1=E1, e2=E2, x1=X1, x2=X2) -> bytes:
    out = bytearray()
    for i in range(16):
        c1 = 1 ^ oracle.gf_pow(x1, 2)
        c2 = 1 ^ oracle.gf_pow(x2, 2)
        lhs = oracle.gf_mul(e1[i], x2) ^ oracle.gf_mul(e2[i], x1)
        rhs = oracle.gf_mul(c1, x2) ^ oracle.gf_mul(c2, x1)
        out.append(oracle.gf_div(lhs, rhs) if rhs else 0)
    return bytes(out)


def a2_const(c: int, e1=E1, e2=E2, x1=X1, x2=X2) -> bytes:
    dx, dx2 = x1 ^ x2, oracle.gf_pow(x1, 2) ^ oracle.gf_pow(x2, 2)
    out = bytearray()
    for i in range(16):
        a1 = oracle.gf_div(e1[i] ^ e2[i] ^ oracle.gf_mul(c, dx2), dx)
        out.append(e1[i] ^ oracle.gf_mul(a1, x1) ^ oracle.gf_mul(c, oracle.gf_pow(x1, 2)))
    return bytes(out)


def mix(sa: bytes, sb: bytes, mask: int) -> bytes:
    return bytes(sa[i] if (mask >> i) & 1 else sb[i] for i in range(16))


def selftest() -> bool:
    ok = True
    rng = random.Random(7)
    secret = bytes(rng.randint(1, 255) for _ in range(16))
    e1 = bytearray()
    e2 = bytearray()
    for b in secret:
        a2 = rng.randint(1, 255)
        while a2 == b:
            a2 = rng.randint(1, 255)
        e1.append(b ^ oracle.gf_mul(a2, oracle.gf_pow(X1, 2)))
        e2.append(b ^ oracle.gf_mul(a2, oracle.gf_pow(X2, 2)))
    rec = a1_zero(bytes(e1), bytes(e2), X1, X2)
    found = rec == secret
    print(f"a1=0 solver recovers a synthetic split: {'OK' if found else 'FAIL'}")
    ok = ok and found

    sa = bytes(range(16))
    sb = bytes(range(16, 32))
    mix_ok = (
        mix(sa, sb, 0) == sb
        and mix(sa, sb, (1 << 16) - 1) == sa
        and mix(sa, sb, 1)[0] == sa[0]
        and mix(sa, sb, 1)[1] == sb[1]
    )
    print(f"mixed-mask enumerator head/tail/bit0: {'OK' if mix_ok else 'FAIL'}")
    ok = ok and mix_ok

    enc = encode_share(E1, 7)
    dec = oracle.decode_share(enc)
    roundtrip = dec == (E1, 7)
    print(f"share encode/decode round trip: {'OK' if roundtrip else 'FAIL'}")
    ok = ok and roundtrip

    if ok:
        print("SELFTEST OK")
    return ok


def scan() -> int:
    hits = 0
    n = 0
    t0 = time.perf_counter()

    uniques = [
        a2_zero(),
        a1_zero(),
        a1_eq_a2(),
        a1_eq_s(),
        a2_eq_s(),
        bytes(a ^ b for a, b in zip(E1, E2)),
        E1,
        E2,
        hashlib.sha256(E1 + E2).digest()[:16],
        hashlib.sha256(oracle.SHARE_1.encode()).digest()[:16],
        hashlib.sha256(oracle.SHARE_2.encode()).digest()[:16],
        a2_zero()[::-1],
        a1_zero()[::-1],
        a1_eq_a2()[::-1],
    ]
    for secret in uniques:
        n += 1
        if to_addr(secret) == oracle.TARGET_ADDRESS:
            hits += 1
            print("MATCH unique-model")
            return 0

    consistent = 0
    p1, p2 = oracle.gf_pow(X1, 2), oracle.gf_pow(X2, 2)
    for a1 in range(256):
        for a2 in range(256):
            ok = True
            secret = bytearray()
            for i in range(16):
                s1 = E1[i] ^ oracle.gf_mul(a1, X1) ^ oracle.gf_mul(a2, p1)
                s2 = E2[i] ^ oracle.gf_mul(a1, X2) ^ oracle.gf_mul(a2, p2)
                if s1 != s2:
                    ok = False
                    break
                secret.append(s1)
            if ok:
                consistent += 1
                n += 1
                if to_addr(bytes(secret)) == oracle.TARGET_ADDRESS:
                    hits += 1
                    print("MATCH constant-coeff")
                    return 0
    print(f"constant (a1,a2) pairs algebraically consistent: {consistent}")

    dx, dx2 = X1 ^ X2, oracle.gf_pow(X1, 2) ^ oracle.gf_pow(X2, 2)
    for a1 in range(256):
        secret = bytearray()
        for i in range(16):
            a2 = oracle.gf_div(E1[i] ^ E2[i] ^ oracle.gf_mul(a1, dx), dx2)
            secret.append(E1[i] ^ oracle.gf_mul(a1, X1) ^ oracle.gf_mul(a2, oracle.gf_pow(X1, 2)))
        n += 1
        if to_addr(bytes(secret)) == oracle.TARGET_ADDRESS:
            hits += 1
            print("MATCH fixed-a1")
            return 0
    for a2 in range(256):
        secret = bytearray()
        for i in range(16):
            a1 = oracle.gf_div(E1[i] ^ E2[i] ^ oracle.gf_mul(a2, dx2), dx)
            secret.append(E1[i] ^ oracle.gf_mul(a1, X1) ^ oracle.gf_mul(a2, oracle.gf_pow(X1, 2)))
        n += 1
        if to_addr(bytes(secret)) == oracle.TARGET_ADDRESS:
            hits += 1
            print("MATCH fixed-a2")
            return 0

    unused = [x for x in range(1, 16) if x not in (X1, X2)]
    constructed = [
        bytes([fill] * 16) for fill in (0, 1, 255, X1, X2)
    ] + [
        E1,
        E2,
        bytes(a ^ b for a, b in zip(E1, E2)),
        hashlib.sha256(E1 + E2).digest()[:16],
        hashlib.sha256((oracle.SHARE_1 + oracle.SHARE_2).encode()).digest()[:16],
        bytes.fromhex("249dd7ad2fccea67977d4078edad50d8603ff4ce")[:16],
    ]
    for amt in (371, 5220, 2403, 8781, 100000000):
        constructed.append(amt.to_bytes(16, "big"))
        constructed.append(amt.to_bytes(16, "little"))
    for entropy in constructed:
        for x3 in unused:
            n += 1
            matched, _addr = oracle.check(encode_share(entropy, x3))
            if matched:
                hits += 1
                print("MATCH constructed-share")
                return 0

    for ia in range(1, 16):
        for ib in range(ia + 1, 16):
            n += 1
            if to_addr(oracle.restore_secret({ia: E1, ib: E2})) == oracle.TARGET_ADDRESS:
                hits += 1
                print("MATCH index-pair")
                return 0

    families = [
        (a2_zero(), a1_zero()),
        (a2_zero(), a1_eq_a2()),
        (a2_zero(), a1_eq_s()),
        (a1_zero(), a2_eq_s()),
        (a2_const(0), a2_const(1)),
        (a2_const(1), a2_const(255)),
    ]
    for sa, sb in families:
        for mask in range(1 << 16):
            n += 1
            if to_addr(mix(sa, sb, mask)) == oracle.TARGET_ADDRESS:
                hits += 1
                print("MATCH mixed-mask")
                return 0

    dt = time.perf_counter() - t0
    print(f"{n} candidates, {hits} match. Rate: {n/dt:.0f}/s. Date: run locally.")
    return 1 if hits == 0 else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--selftest", action="store_true")
    parser.add_argument("--scan", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        return 0 if selftest() else 1
    if args.scan:
        return scan()
    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
