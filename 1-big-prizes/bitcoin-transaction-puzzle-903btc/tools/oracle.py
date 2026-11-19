#!/usr/bin/env python3
"""
oracle.py -- candidate checker for the Bitcoin Transaction Puzzle (#1-160).

A candidate is one integer k. For puzzle #n the funded key is a single integer in
[2^(n-1), 2^n), so the checker derives the compressed secp256k1 public key of k,
hashes it to a P2PKH address, and compares it to every still-funded escrow in
data/open_puzzles.csv (the ranges partition the space, so at most one can match).

Usage:
    python3 oracle.py --selftest          # certifies the derivation, prints SELFTEST OK
    python3 oracle.py <key>               # decimal or 0x-hex integer; MATCH / NO MATCH
    python3 oracle.py --stdin             # one integer candidate per line, matches only
"""
import csv
import hashlib
import os
import sys

import base58
from ecdsa import SECP256k1, SigningKey

HERE = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(HERE, "..", "data", "open_puzzles.csv")

# Certification vector: puzzle #1's private key is 1 and its funded-then-solved
# address is the compressed-pubkey P2PKH of scalar 1.
SELFTEST_KEY = 1
SELFTEST_ADDRESS = "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH"


def load_targets():
    targets = {}
    with open(CSV_PATH, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            targets[row["address"]] = int(row["puzzle"])
    return targets


try:
    from Crypto.Hash import RIPEMD160
    def ripemd160(data):
        h = RIPEMD160.new()
        h.update(data)
        return h.digest()
except ImportError:
    def ripemd160(data):
        h = hashlib.new("ripemd160")
        h.update(data)
        return h.digest()


def hash160(data):
    return ripemd160(hashlib.sha256(data).digest())


def p2pkh_of(k):
    point = SigningKey.from_secret_exponent(k, curve=SECP256k1).verifying_key.pubkey.point
    x = point.x().to_bytes(32, "big")
    prefix = b"\x03" if point.y() & 1 else b"\x02"
    payload = b"\x00" + hash160(prefix + x)
    checksum = hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
    return base58.b58encode(payload + checksum).decode()


def parse_key(token):
    token = token.strip()
    try:
        k = int(token, 16) if token.lower().startswith("0x") else int(token)
    except ValueError:
        return None
    return k if 0 < k < SECP256k1.order else None


def check(k, targets):
    addr = p2pkh_of(k)
    n = targets.get(addr)
    return (n, addr) if n is not None else (None, addr)


def selftest():
    addr = p2pkh_of(SELFTEST_KEY)
    assert addr == SELFTEST_ADDRESS, f"mismatch: {addr} != {SELFTEST_ADDRESS}"
    print("SELFTEST OK")


def main():
    targets = load_targets()
    args = sys.argv[1:]
    if not args or args[0] == "--selftest":
        selftest()
        return 0
    if args[0] == "--stdin":
        for line in sys.stdin:
            k = parse_key(line)
            if k is None:
                continue
            n, addr = check(k, targets)
            if n is not None:
                print(f"MATCH puzzle #{n} key={k} {addr}")
        return 0
    k = parse_key(args[0])
    if k is None:
        print("usage: oracle.py <decimal-or-0x-hex integer>", file=sys.stderr)
        return 2
    n, addr = check(k, targets)
    if n is None:
        print(f"NO MATCH {addr}")
        return 1
    print(f"MATCH puzzle #{n} key={k} {addr}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
