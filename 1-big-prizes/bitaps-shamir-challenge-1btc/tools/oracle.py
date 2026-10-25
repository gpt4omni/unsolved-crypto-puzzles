#!/usr/bin/env python3
"""
oracle.py -- reconstruction checker for the Bitaps Shamir secret-sharing challenge.

Purpose:
    Bitaps published 2 of the 3 mnemonic shares needed to reconstruct a 12-word
    BIP39 secret split with a 3-of-5 Shamir threshold over GF(256). Each share is
    itself a 12-word phrase, with its Shamir index embedded in the 4 bits BIP39
    normally reserves for the checksum. Given a candidate third share, this script
    combines it with the two published shares, reconstructs the 16-byte secret,
    re-encodes it as a 12-word mnemonic with its true BIP39 checksum, derives the
    BIP84 m/84'/0'/0'/0/0 address, and compares it to the challenge address.

    This is a reconstruction oracle, not a solver: it needs a real third share to
    test. It cannot search for one, because the space of possible shares is the
    same size as the space of possible 16-byte secrets.

Usage:
    python3 tools/oracle.py --selftest
    python3 tools/oracle.py "word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12"
    python3 tools/oracle.py --stdin

Input:
    A 12-word, space-separated candidate third share on the command line or one
    per line on stdin. The two published shares are built into this script.

Output:
    "MATCH <address>" for a hit, "NO MATCH" otherwise (including when the input is
    not 12 known BIP39 words, or reuses one of the two known share indexes). Exit
    0 on any match, 1 if none.

Dependencies:
    stdlib, bip_utils.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import random
import sys

from bip_utils import Bip39SeedGenerator, Bip44Changes, Bip84, Bip84Coins

TARGET_ADDRESS = "bc1qyjwa0tf0en4x09magpuwmt2smpsrlaxwn85lh6"

# The 2 of 3 shares Bitaps published on bitaps.com/mnemonic/challenge, 2020-06-19
# (https://web.archive.org/web/20230328022959/https://bitaps.com/mnemonic/challenge).
SHARE_1 = "session cigar grape merry useful churn fatal thought very any arm unaware"
SHARE_2 = "clock fresh security field caution effort gorilla speed plastic common tomato echo"

# ---------------------------------------------------------------------------
# GF(256) arithmetic, reducing polynomial 0x11B (the same field AES uses). This
# is the field bitaps-com/jsbtc's shamir_secret_sharing.js splits each byte in.
# ---------------------------------------------------------------------------

_EXP = [0] * 255
_LOG = [0] * 256


def _build_tables() -> None:
    poly = 1
    for i in range(255):
        _EXP[i] = poly
        _LOG[poly] = i
        poly = (poly << 1) ^ poly  # generator element 3, not 2: 2 is not primitive under 0x11B
        if poly & 0x100:
            poly ^= 0x11B


_build_tables()


def gf_mul(a: int, b: int) -> int:
    if a == 0 or b == 0:
        return 0
    return _EXP[(_LOG[a] + _LOG[b]) % 255]


def gf_div(a: int, b: int) -> int:
    if a == 0:
        return 0
    return _EXP[(_LOG[a] - _LOG[b]) % 255]


def gf_pow(a: int, n: int) -> int:
    result = 1
    for _ in range(n):
        result = gf_mul(result, a)
    return result


def _lagrange_at_zero(points: list[tuple[int, int]]) -> int:
    result = 0
    for j, (xj, yj) in enumerate(points):
        term = yj
        for m, (xm, _ym) in enumerate(points):
            if m == j:
                continue
            term = gf_mul(term, gf_div(xm, xj ^ xm))
        result ^= term
    return result


def restore_secret(shares_by_index: dict[int, bytes]) -> bytes:
    """Lagrange-interpolate every byte position at x=0. Works with any number of
    points >= 2; only >= threshold points reconstruct the true secret."""
    length = len(next(iter(shares_by_index.values())))
    out = bytearray()
    for i in range(length):
        points = [(x, shares_by_index[x][i]) for x in shares_by_index]
        out.append(_lagrange_at_zero(points))
    return bytes(out)


def split_secret(secret: bytes, indexes: list[int], threshold: int, rng: random.Random) -> dict[int, bytes]:
    """Reference splitter used only by the self-test, to build a synthetic 3-of-5
    puzzle independent of the real challenge and confirm the round trip."""
    shares = {x: bytearray() for x in indexes}
    for b in secret:
        coeffs = [b] + [rng.randint(0, 255) for _ in range(threshold - 1)]
        for x in indexes:
            y = 0
            for i, c in enumerate(coeffs):
                y ^= gf_mul(c, gf_pow(x, i))
            shares[x].append(y)
    return {x: bytes(v) for x, v in shares.items()}


# ---------------------------------------------------------------------------
# BIP39 12-word mnemonic <-> (16-byte entropy, embedded Shamir index)
# ---------------------------------------------------------------------------

def _wordlist() -> tuple[list[str], dict[str, int]]:
    import bip_utils as _bu

    path = os.path.join(os.path.dirname(_bu.__file__), "bip", "bip39", "wordlist", "english.txt")
    words = [w.strip() for w in open(path, encoding="utf-8") if w.strip()]
    return words, {w: i for i, w in enumerate(words)}


_WORDS, _WORD_INDEX = _wordlist()


def decode_share(mnemonic: str) -> tuple[bytes, int] | None:
    """12-word share -> (16-byte entropy, embedded Shamir index 0-15). None if the
    input is not exactly 12 words from the BIP39 English wordlist."""
    words = mnemonic.split()
    if len(words) != 12 or any(w not in _WORD_INDEX for w in words):
        return None
    bits = "".join(format(_WORD_INDEX[w], "011b") for w in words)
    entropy = int(bits[:128], 2).to_bytes(16, "big")
    index = int(bits[128:], 2)
    return entropy, index


def encode_secret_mnemonic(entropy: bytes) -> str:
    """16-byte entropy -> 12-word BIP39 mnemonic with its true checksum (this is
    for the reconstructed SECRET, never for a share, whose last 4 bits are an
    index instead)."""
    bits = format(int.from_bytes(entropy, "big"), "0128b")
    checksum = hashlib.sha256(entropy).digest()[0] >> 4
    bits += format(checksum, "04b")
    return " ".join(_WORDS[int(bits[i : i + 11], 2)] for i in range(0, 132, 11))


def derive_address(mnemonic: str) -> str:
    seed = Bip39SeedGenerator(mnemonic).Generate()
    acc = (
        Bip84.FromSeed(seed, Bip84Coins.BITCOIN)
        .Purpose()
        .Coin()
        .Account(0)
        .Change(Bip44Changes.CHAIN_EXT)
    )
    return acc.AddressIndex(0).PublicKey().ToAddress()


def check(candidate_third_share: str) -> tuple[bool, str | None]:
    decoded = decode_share(candidate_third_share)
    if decoded is None:
        return False, None
    entropy3, index3 = decoded

    known: dict[int, bytes] = {}
    for share in (SHARE_1, SHARE_2):
        e, x = decode_share(share)
        known[x] = e

    if index3 == 0 or index3 in known:
        return False, None  # index 0 is reserved for the secret; a repeat is not a 3rd share

    known[index3] = entropy3
    secret_entropy = restore_secret(known)
    secret_mnemonic = encode_secret_mnemonic(secret_entropy)
    addr = derive_address(secret_mnemonic)
    return addr == TARGET_ADDRESS, addr


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

def selftest() -> bool:
    ok = True

    vector = ("abandon " * 11 + "about").strip()
    expected = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    addr = derive_address(vector)
    found = addr == expected
    print(f"public BIP84 test vector -> {expected}: {'OK' if found else 'FAIL'}")
    ok = ok and found

    e1, x1 = decode_share(SHARE_1)
    e2, x2 = decode_share(SHARE_2)
    sane = x1 > 0 and x2 > 0 and x1 != x2
    print(f"the 2 published shares decode to distinct indexes x1={x1} x2={x2}: {'OK' if sane else 'FAIL'}")
    ok = ok and sane

    two_share_guess = restore_secret({x1: e1, x2: e2})
    two_share_addr = derive_address(encode_secret_mnemonic(two_share_guess))
    insufficient = two_share_addr != TARGET_ADDRESS
    print(f"the 2 published shares alone (threshold is 3) do not derive the target: {'OK' if insufficient else 'FAIL'}")
    ok = ok and insufficient

    rng = random.Random(2020)
    secret_entropy = bytes(rng.randint(0, 255) for _ in range(16))
    secret_mnemonic = encode_secret_mnemonic(secret_entropy)
    expected_addr = derive_address(secret_mnemonic)
    share_indexes = rng.sample(range(1, 16), 3)
    synthetic_shares = split_secret(secret_entropy, share_indexes, threshold=3, rng=rng)
    rebuilt = restore_secret(synthetic_shares)
    roundtrip = rebuilt == secret_entropy and derive_address(encode_secret_mnemonic(rebuilt)) == expected_addr
    print(f"synthetic 3-of-5 split/reconstruct round trip (own harness, not the real challenge): {'OK' if roundtrip else 'FAIL'}")
    ok = ok and roundtrip

    rejected = check(SHARE_1) == (False, None)
    print(f"a candidate that reuses a known share index is rejected: {'OK' if rejected else 'FAIL'}")
    ok = ok and rejected

    if ok:
        print("SELFTEST OK")
    return ok


def _print_result(candidate: str) -> bool:
    matched, addr = check(candidate)
    if matched:
        print(f"MATCH {addr}")
    else:
        print("NO MATCH")
    return matched


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", nargs="?", help="12 space-separated words: a candidate third share")
    parser.add_argument("--stdin", action="store_true", help="read candidates, one per line")
    parser.add_argument("--selftest", action="store_true", help="run the certification vector")
    args = parser.parse_args()

    if args.selftest:
        return 0 if selftest() else 1

    if args.stdin:
        any_hit = False
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            any_hit = _print_result(line) or any_hit
        return 0 if any_hit else 1

    if not args.candidate:
        parser.print_help()
        return 0

    return 0 if _print_result(args.candidate) else 1


if __name__ == "__main__":
    sys.exit(main())
