#!/usr/bin/env python3
"""
oracle.py -- candidate checker for RushWallet/KryptoKit brainwallet contest, puzzle #30.

Purpose:
    Given a candidate passphrase, reproduce the contest's own client-side derivation
    (read directly from the archived contest.js) and compare the resulting address
    byte-exact to the escrow address. The passphrase is hashed VERBATIM: no trim, no
    case folding, no normalization. The contest used an uncompressed public key.

Usage:
    python3 tools/oracle.py --selftest                 # must print SELFTEST OK
    python3 tools/oracle.py "candidate passphrase"
    python3 tools/oracle.py --stdin                     # one candidate per line

Input:
    A single candidate passphrase on the command line (taken verbatim, including
    leading/trailing spaces if you quote them) or one per line on stdin.

Output:
    "MATCH <address>" for a hit, "NO MATCH" otherwise. Exit 0 on any match, 1 if none.

Dependencies:
    stdlib, ecdsa, base58.
"""

from __future__ import annotations

import argparse
import hashlib
import sys

import base58
import ecdsa

TARGET_ADDRESS = "13Q8hJqagtd77ojTJcEZPjTz2sBFSsYxyj"

# Public, on-chain-verifiable vectors: passphrases claimed by OTHER solvers on 3 sibling
# brainwallets of the same 2014 contest (puzzles #17 and #28) and by the contest host itself
# ("www.rushwallet.com" was one of the 30 contest addresses). All 3 use the same derivation
# as #30: SHA-256(passphrase) as the private key, uncompressed public key, P2PKH.
SELFTEST_VECTORS = {
    "Dmitri Nancy Enrique": "16tGKq48tGq3Td1wcDoQRuWtPtXoEfZpBC",
    "Dmitri Enrique Nancy": "14yaVUgstpqavPEFtyit3wEWsyumysqxZV",
    "www.rushwallet.com": "1EWr7tvs8efFu15nvuL4RezVVoHFpxH2nF",
}


def derive_address(passphrase: str) -> str | None:
    priv = hashlib.sha256(passphrase.encode("utf-8")).digest()
    n = int.from_bytes(priv, "big")
    if n == 0 or n >= ecdsa.SECP256k1.order:
        return None
    vk = ecdsa.SigningKey.from_string(priv, curve=ecdsa.SECP256k1).get_verifying_key()
    pub_uncompressed = b"\x04" + vk.to_string()
    h160 = hashlib.new("ripemd160", hashlib.sha256(pub_uncompressed).digest()).digest()
    return base58.b58encode_check(b"\x00" + h160).decode()


def check(passphrase: str) -> tuple[bool, str | None]:
    addr = derive_address(passphrase)
    if addr is None:
        return False, None
    return addr == TARGET_ADDRESS, addr


def selftest() -> bool:
    ok = True
    for passphrase, expected in SELFTEST_VECTORS.items():
        addr = derive_address(passphrase)
        found = addr == expected
        print(f"{passphrase!r} -> {expected}: {'OK' if found else 'FAIL'}")
        ok = ok and found

    matched, addr = check("Dmitri Nancy Enrique")
    clean = not matched
    print(f"negative control (a known sibling passphrase vs #30's escrow) -> no match: {'OK' if clean else 'FAIL'}")
    ok = ok and clean

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
    parser.add_argument("candidate", nargs="?", help="candidate passphrase, taken verbatim")
    parser.add_argument("--stdin", action="store_true", help="read candidates, one per line")
    parser.add_argument("--selftest", action="store_true", help="run the certification vectors")
    args = parser.parse_args()

    if args.selftest:
        return 0 if selftest() else 1

    if args.stdin:
        any_hit = False
        for line in sys.stdin:
            line = line.rstrip("\n")
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
