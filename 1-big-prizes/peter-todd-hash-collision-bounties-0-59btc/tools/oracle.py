#!/usr/bin/env python3
"""
oracle.py -- predicate checker for Peter Todd's hash-collision bounty scripts.

Purpose:
    Every bounty script pays whoever supplies 2 distinct stack items a, b with
    HASH(a) == HASH(b): a full, exact collision of the named hash function. There
    is no derivation to compute here, and no search this script could run, since
    a genuine full collision of SHA-256 or RIPEMD-160 has never been published.
    This script only verifies whether a given candidate pair actually satisfies
    a given bounty's on-chain predicate, byte for byte.

Usage:
    python3 tools/oracle.py --selftest
    python3 tools/oracle.py "<hash_name> <a_hex> <b_hex>"
    python3 tools/oracle.py --stdin

    <hash_name> is one of: sha256, ripemd160, hash160, hash256, sha1 (sha1 is the
    already-claimed sibling, kept only so the predicate can be certified against
    a real payout).

Input:
    A candidate as "<hash_name> <a_hex> <b_hex>" on the command line, or one per
    line on stdin. a_hex and b_hex are hex-encoded byte strings.

Output:
    "MATCH <hash_name> <address>" if a != b and HASH(a) == HASH(b), "NO MATCH"
    otherwise. Exit 0 on any match, 1 if none.

Dependencies:
    stdlib, pycryptodome (for RIPEMD-160).
"""

from __future__ import annotations

import argparse
import hashlib
import sys

from Crypto.Hash import RIPEMD160

# name -> (address, 8-byte redeem script hex). All 5 share one template, differing
# only in the hash opcode byte. SHA1 is a reference: claimed 2023-02-22, not part
# of the live prize; kept to certify the predicate against a real payout.
SCRIPTS = {
    "sha256":    ("35Snmmy3uhaer2gTboc81ayCip4m9DT4ko", "6e879169a87ca887"),
    "ripemd160": ("3KyiQEGqqdb4nqfhUzGKN6KPhXmQsLNpay", "6e879169a67ca687"),
    "hash160":   ("39VXyuoc6SXYKp9TcAhoiN1mb4ns6z3Yu6", "6e879169a97ca987"),
    "hash256":   ("3DUQQvz4t57Jy7jxE86kyFcNpKtURNf1VW", "6e879169aa7caa87"),
    "sha1":      ("37k7toV1Nv4DfmQbmZ8KuZDQCYK9x5KpzP", "6e879169a77ca787"),
}

OPS = {
    0x6E: "OP_2DUP", 0x87: "OP_EQUAL", 0x91: "OP_NOT", 0x69: "OP_VERIFY",
    0x7C: "OP_SWAP", 0xA6: "OP_RIPEMD160", 0xA7: "OP_SHA1", 0xA8: "OP_SHA256",
    0xA9: "OP_HASH160", 0xAA: "OP_HASH256",
}

HASH_OPCODE_NAME = {
    "sha256": "OP_SHA256", "ripemd160": "OP_RIPEMD160", "hash160": "OP_HASH160",
    "hash256": "OP_HASH256", "sha1": "OP_SHA1",
}

# The exact SHAttered PDF-prefix pair that claimed the SHA-1 sibling on-chain:
# txid 9ec2a0db0c4c3423a6b2c3cb2a26fc626b037121b4b5f3f57b08916196ff14e0, block
# 777856, 2023-02-22, spending 37k7toV1Nv4DfmQbmZ8KuZDQCYK9x5KpzP. Read directly
# from the scriptSig via mempool.space, 2026-08-16.
WITNESS_SHA1_A_HEX = (
    "255044462d312e330a25e2e3cfd30a0a0a312030206f626a0a3c3c2f57696474682032"
    "203020522f4865696768742033203020522f547970652034203020522f537562747970"
    "652035203020522f46696c7465722036203020522f436f6c6f7253706163652037203020"
    "522f4c656e6774682038203020522f42697473506572436f6d706f6e656e7420383e3e0a"
    "73747265616d0affd8fffe00245348412d3120697320646561642121212121852fec092339759c"
    "39b1a1c63c4c97e1fffe017f46dc93a6b67e013b029aaa1db2560b45ca67d688c7f84b8c4c791fe02b3df"
    "614f86db1690901c56b45c1530afedfb76038e972722fe7ad728f0e4904e046c230570fe9d413"
    "98abe12ef5bc942be33542a4802d98b5d70f2a332ec37fac3514e74ddc0f2cc1a874cd0c78305a"
    "21566461309789606bd0bf3f98cda8044629a1"
)
WITNESS_SHA1_B_HEX = (
    "255044462d312e330a25e2e3cfd30a0a0a312030206f626a0a3c3c2f57696474682032"
    "203020522f4865696768742033203020522f547970652034203020522f537562747970"
    "652035203020522f46696c7465722036203020522f436f6c6f7253706163652037203020"
    "522f4c656e6774682038203020522f42697473506572436f6d706f6e656e7420383e3e0a"
    "73747265616d0affd8fffe00245348412d3120697320646561642121212121852fec092339759c"
    "39b1a1c63c4c97e1fffe017346dc9166b67e118f029ab621b2560ff9ca67cca8c7f85ba84c79030c2b3de2"
    "18f86db3a90901d5df45c14f26fedfb3dc38e96ac22fe7bd728f0e45bce046d23c570feb141398bb"
    "552ef5a0a82be331fea48037b8b5d71f0e332edf93ac3500eb4ddc0decc1a864790c782c76215660d"
    "d309791d06bd0af3f98cda4bc4629b1"
)


def disasm(hex_script: str) -> str:
    return " ".join(OPS.get(b, f"0x{b:02x}") for b in bytes.fromhex(hex_script))


def _hash(name: str, data: bytes) -> bytes:
    if name == "sha1":
        return hashlib.sha1(data).digest()
    if name == "sha256":
        return hashlib.sha256(data).digest()
    if name == "ripemd160":
        return RIPEMD160.new(data).digest()
    if name == "hash160":
        return RIPEMD160.new(hashlib.sha256(data).digest()).digest()
    if name == "hash256":
        return hashlib.sha256(hashlib.sha256(data).digest()).digest()
    raise ValueError(f"unknown hash name: {name}")


def check(candidate: str) -> tuple[bool, str | None, str | None]:
    """Returns (match, hash_name, address)."""
    parts = candidate.split()
    if len(parts) != 3:
        return False, None, None
    hash_name, a_hex, b_hex = parts[0].lower(), parts[1], parts[2]
    if hash_name not in SCRIPTS:
        return False, None, None
    try:
        a, b = bytes.fromhex(a_hex), bytes.fromhex(b_hex)
    except ValueError:
        return False, hash_name, None
    if a == b:
        return False, hash_name, None  # OP_2DUP OP_EQUAL OP_NOT OP_VERIFY rejects equal inputs
    if _hash(hash_name, a) != _hash(hash_name, b):
        return False, hash_name, None
    return True, hash_name, SCRIPTS[hash_name][0]


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

def selftest() -> bool:
    ok = True

    template_ok = True
    for name, (_addr, redeem_hex) in SCRIPTS.items():
        asm = disasm(redeem_hex)
        tokens = asm.split()
        shape = (
            len(bytes.fromhex(redeem_hex)) == 8
            and tokens[:4] == ["OP_2DUP", "OP_EQUAL", "OP_NOT", "OP_VERIFY"]
            and tokens[4] == HASH_OPCODE_NAME[name]
            and tokens[5] == "OP_SWAP"
            and tokens[6] == HASH_OPCODE_NAME[name]
            and tokens[7] == "OP_EQUAL"
        )
        if not shape:
            template_ok = False
            print(f"  template check failed for {name}: {asm}")
    print(f"all 5 scripts are the same 8-byte full-collision template, no truncation opcode: {'OK' if template_ok else 'FAIL'}")
    ok = ok and template_ok

    a = bytes.fromhex(WITNESS_SHA1_A_HEX)
    b = bytes.fromhex(WITNESS_SHA1_B_HEX)
    distinct = a != b
    print(f"real SHAttered pair: a != b (320 bytes each): {'OK' if distinct else 'FAIL'}")
    ok = ok and distinct

    collide = hashlib.sha1(a).digest() == hashlib.sha1(b).digest()
    print(f"real SHAttered pair: sha1(a) == sha1(b): {'OK' if collide else 'FAIL'}")
    ok = ok and collide

    matched, hash_name, addr = check(f"sha1 {WITNESS_SHA1_A_HEX} {WITNESS_SHA1_B_HEX}")
    claimed_ok = matched and addr == SCRIPTS["sha1"][0]
    print(f"oracle reproduces the real 2023-02-22 SHA-1 claim (txid 9ec2a0db..., block 777856): {'OK' if claimed_ok else 'FAIL'}")
    ok = ok and claimed_ok

    equal_rejected = check(f"sha256 {WITNESS_SHA1_A_HEX} {WITNESS_SHA1_A_HEX}") == (False, "sha256", None)
    print(f"a == b is rejected even though H(a) == H(a) trivially: {'OK' if equal_rejected else 'FAIL'}")
    ok = ok and equal_rejected

    no_collision = check("sha256 68656c6c6f 776f726c64") == (False, "sha256", None)
    print(f"distinct non-colliding inputs (\"hello\" vs \"world\", SHA-256) are rejected: {'OK' if no_collision else 'FAIL'}")
    ok = ok and no_collision

    if ok:
        print("SELFTEST OK")
    return ok


def _print_result(candidate: str) -> bool:
    matched, hash_name, addr = check(candidate)
    if matched:
        print(f"MATCH {hash_name} {addr}")
    else:
        print("NO MATCH")
    return matched


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", nargs="?", help='"<hash_name> <a_hex> <b_hex>"')
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
