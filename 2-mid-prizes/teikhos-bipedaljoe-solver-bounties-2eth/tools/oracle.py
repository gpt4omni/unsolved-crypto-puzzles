#!/usr/bin/env python3
"""
oracle.py -- candidate checker for the TeikhosBounty puzzle family (Johan Nygren, 2018).

Purpose:
    Each TeikhosBounty contract pays its balance to whoever submits the 64-byte
    uncompressed public key Q (no 0x04 prefix) that the contract's creator committed to
    when it was deployed, without ever publishing Q itself. The contract only stores a
    masked ECDSA signature. Given a candidate Q, this script replays the exact on-chain
    check for each contract in the family and reports whether Q would be accepted.

    Two masking variants are used across the family:
      simple:     r = proof1 XOR Q[0:32]         s = proof2 XOR Q[32:64]
      symmetric:  symKey = sym XOR Q              r = proof1 XOR symKey[0:32]
                                                    s = proof2 XOR symKey[32:64]
      keccak512:  base = keccak512(Q)             r = proof1 XOR base[0:32]
                                                    s = proof2 XOR base[32:64]
    In every variant: signer = keccak256(Q)[-20:], msgHash = keccak256(
    "\\x19Ethereum Signed Message:\\n64" + Q), and Q is accepted if recovering a public key
    from (msgHash, r, s) for either ECDSA recovery id yields signer.

    This is a verifier, not a search tool: it checks the candidate you give it. Recovering Q
    for an unsolved contract from nothing is a 256-bit brute force with no known shortcut;
    the only realistic way to obtain a candidate is if Q leaks elsewhere (a signed message,
    a failed on-chain attempt, an author disclosure).

Usage:
    python3 tools/oracle.py --selftest                 # must print SELFTEST OK, exit 0
    python3 tools/oracle.py <64-byte-pubkey-hex>        # checks against every contract
    python3 tools/oracle.py --contract C1 <pubkey-hex>  # checks one contract only
    python3 tools/oracle.py --stdin                     # one pubkey hex per line

Input:
    A 64-byte (128 hex character) uncompressed public key, with or without a 0x04 prefix
    (65 bytes with the prefix is also accepted and the prefix is stripped).

Output:
    "MATCH <tag> <address> recid=<0|1> v=<27|28>" for a hit, "NO MATCH" otherwise.
    Exit 0 on any match, 1 if none.

WARNING:
    This tool only checks a candidate offline. It never broadcasts a transaction. For C1 and
    C2, the contract pays whoever calls it, so a correct public key placed in a public
    mempool transaction is front-runnable; do not submit a real solve without routing it
    through a private relay.

Dependencies:
    stdlib, ecdsa, pycryptodome.
"""

from __future__ import annotations

import argparse
import hashlib
import sys

from Crypto.Hash import keccak as _keccak
from ecdsa import SECP256k1, VerifyingKey
from ecdsa.util import sigdecode_string

SECP256K1_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
ETH_PREFIX = b"\x19Ethereum Signed Message:\n64"

# The 5 contracts in the TeikhosBounty family (creator 0x4c5D24A7Ca972aeA90Cc040DA6770A13Fc7D4d9A,
# author Johan Nygren / resilience-me, EIP-935). proof1/proof2 (and sym1/sym2 for the symmetric
# variant) are read directly from each contract's storage; reconfirmed on-chain 2026-08-16.
CONTRACTS = {
    "AEC7": {
        "address": "0xaec7e8c221c3fd24e75c996e32289235fd899ebf",
        "variant": "simple",
        "eth": "1.0",
        "status": "dead: authenticate() has no value-exit opcode in its runtime, proven at the bytecode level; no payout is possible for anyone even with the right key",
        "proof1": "94cd5137c63cf80cdd176a2a6285572cc076f2fbea67c8b36e65065be7bc34ec",
        "proof2": "9f6463aadf1a8aed68b99aa14538f16d67bf586a4bdecb904d56d5edb2cfb13a",
    },
    "C1": {
        "address": "0x17e5e0910b9185b0ede564dcbf074ca910ad56a4",
        "variant": "simple",
        "eth": "1.0",
        "status": "open, pays the caller (front-run risk)",
        "proof1": "381c185bf75548b134adc3affd0cc13e66b16feb125486322fa5f47cb80a5bf0",
        "proof2": "5f9d1d2152eae0513a4814bd8e6b0dd3ac8f6310c0494c03e9aa08bcd867c352",
    },
    "C2": {
        "address": "0xd7c6d542f3dcdceda845112b8fd567b8f8655805",
        "variant": "symmetric",
        "eth": "0.5",
        "status": "open, pays the caller (front-run risk)",
        "proof1": "ed29e99f5c7349716e9ebf9e5e2db3e9d1c59ebbb6e17479da01beab4fff151e",
        "proof2": "9e559605af06d5f08bb2e8bdc2957623b8ba05af02e84380eec39387125ea03b",
        "sym1": "b8aaf33942600fd11ffe2acf242b2b34530ab95751e0e970d8de148e0b90f6b6",
        "sym2": "a8854ce60dc7f77ae8773e4de3a12679a066ff3e710a44c7e24737aad547e19f",
    },
    "9732": {
        "address": "0x973c2178b09225d1de3ab037d40b3f24af696255",
        "variant": "keccak512",
        "eth": "0.5",
        "status": "open, commit-reveal payout (not directly front-runnable); variant recorded as keccak512 by analogy with its twin 735B, not independently re-derived from source in this session",
        "proof1": "7b5f8ddd34df50d24e492bbee1a888122c1579e898eaeb6e0673156a1b97c24b",
        "proof2": "26d64a34756bd684766dce3e6a8e8695a14a2b16d001559f4ae3a0849ac127fe",
    },
    "735B": {
        "address": "0x735ba26f91e1275fa4b504649b19ef74739fe7e7",
        "variant": "keccak512",
        "eth": "0.5",
        "status": "solved and paid out 2026-06-21",
        "proof1": "ad683919450048215e7c10c3dc3ffca5939ec8f48c057cfe385c7c6f8b754aa7",
        "proof2": "4ce337445bdc24ee86d6c2460073e5b307ae54cdef4b196c660d5ee03f878e81",
    },
}

# The real public key I recovered and submitted to solve 735B, kept here only as the
# self-test's known-good vector. It is public: it was broadcast in the winning authenticate()
# transaction and is visible in that transaction's calldata on any block explorer.
KNOWN_SOLUTION_735B = (
    "ca6a98ceec61e213d9a0a8fdc0a6d5d9ed7566f5f4cfd24871fb9316feb6e1eb2367489f54a0cd4"
    "111f4c5356eb744d299a7521296786223c70947c8c36940c6"
)


def keccak(data: bytes, bits: int = 256) -> bytes:
    h = _keccak.new(digest_bits=bits)
    h.update(data)
    return h.digest()


def _xor(a: bytes, b: bytes) -> bytes:
    return bytes(x ^ y for x, y in zip(a, b))


def _normalize_pubkey(pubkey_hex: str) -> bytes:
    pubkey_hex = pubkey_hex.strip().lower().replace("0x", "")
    pubkey = bytes.fromhex(pubkey_hex)
    if len(pubkey) == 65 and pubkey[0] == 0x04:
        pubkey = pubkey[1:]
    if len(pubkey) != 64:
        raise ValueError(f"public key must be 64 bytes (128 hex chars), got {len(pubkey)}")
    return pubkey


def _derive_rs(pubkey: bytes, spec: dict) -> tuple[bytes, bytes]:
    proof1 = bytes.fromhex(spec["proof1"])
    proof2 = bytes.fromhex(spec["proof2"])
    variant = spec["variant"]
    if variant == "simple":
        return _xor(proof1, pubkey[:32]), _xor(proof2, pubkey[32:])
    if variant == "symmetric":
        sym1 = bytes.fromhex(spec["sym1"])
        sym2 = bytes.fromhex(spec["sym2"])
        sym_key = _xor(sym1, pubkey[:32]) + _xor(sym2, pubkey[32:])
        return _xor(proof1, sym_key[:32]), _xor(proof2, sym_key[32:])
    if variant == "keccak512":
        base = keccak(pubkey, 512)
        return _xor(proof1, base[:32]), _xor(proof2, base[32:])
    raise ValueError(f"unknown variant: {variant}")


def check(pubkey_hex: str, spec: dict) -> dict:
    """Replay the on-chain authenticate() check for one contract. Returns a result dict."""
    pubkey = _normalize_pubkey(pubkey_hex)
    signer = keccak(pubkey, 256)[-20:]
    msg_hash = keccak(ETH_PREFIX + pubkey, 256)
    r, s = _derive_rs(pubkey, spec)
    r_int, s_int = int.from_bytes(r, "big"), int.from_bytes(s, "big")

    result = {"ok": False, "signer": "0x" + signer.hex()}
    if not (0 < r_int < SECP256K1_N and 0 < s_int < SECP256K1_N):
        result["reason"] = "r or s out of range"
        return result

    try:
        candidates = VerifyingKey.from_public_key_recovery_with_digest(
            r + s, msg_hash, SECP256k1, hashfunc=hashlib.sha256, sigdecode=sigdecode_string
        )
    except Exception as exc:
        result["reason"] = f"recovery failed: {exc}"
        return result

    for recid, vk in enumerate(candidates):
        point = vk.pubkey.point
        recovered_q = point.x().to_bytes(32, "big") + point.y().to_bytes(32, "big")
        recovered_addr = keccak(recovered_q, 256)[-20:]
        if recovered_addr == signer:
            result.update(ok=True, recid=recid, v=27 + recid, reason="MATCH")
            return result
    result["reason"] = "no recovered key matches signer"
    return result


def run_selftest() -> int:
    spec = CONTRACTS["735B"]
    result = check(KNOWN_SOLUTION_735B, spec)
    print(
        f"[selftest] 735B known solution (the real public key submitted in the winning "
        f"authenticate() transaction, 2026-06-21): {result}"
    )
    if not result["ok"] or result.get("v") != 27:
        print("SELFTEST FAILED: known-good 735B public key did not reproduce the recorded match")
        return 1

    wrong_pubkey = KNOWN_SOLUTION_735B[:-2] + ("00" if KNOWN_SOLUTION_735B[-2:] != "00" else "11")
    wrong_result = check(wrong_pubkey, spec)
    print(f"[selftest] known-wrong public key (last byte flipped): {wrong_result}")
    if wrong_result["ok"]:
        print("SELFTEST FAILED: a known-wrong public key matched")
        return 1

    print(
        "[selftest] scope: certifies the full on-chain check (XOR unmask, keccak, ECDSA "
        "public-key recovery) against the real, already-public solution for 735B. C1 and C2 "
        "use the simple/symmetric variants, exercised by the same code path with different "
        "target data; no independent known-good vector exists for those two variants because "
        "no one has solved a simple- or symmetric-variant contract in this family."
    )
    print("SELFTEST OK")
    return 0


def main():
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("pubkey", nargs="?", help="64-byte public key, hex, optional 0x04 prefix")
    parser.add_argument("--contract", choices=sorted(CONTRACTS), help="check one contract only")
    parser.add_argument("--selftest", action="store_true")
    parser.add_argument("--stdin", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        sys.exit(run_selftest())

    targets = {args.contract: CONTRACTS[args.contract]} if args.contract else CONTRACTS

    def check_all(pubkey_hex: str) -> bool:
        any_match = False
        for tag, spec in targets.items():
            try:
                result = check(pubkey_hex, spec)
            except ValueError as exc:
                print(f"NO MATCH ({exc})")
                return False
            if result["ok"]:
                any_match = True
                print(f"MATCH {tag} {spec['address']} recid={result['recid']} v={result['v']}")
        return any_match

    if args.stdin:
        any_match = False
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            if check_all(line):
                any_match = True
        sys.exit(0 if any_match else 1)

    if not args.pubkey:
        parser.print_usage()
        sys.exit(1)

    matched = check_all(args.pubkey)
    if not matched:
        print("NO MATCH")
    sys.exit(0 if matched else 1)


if __name__ == "__main__":
    main()
