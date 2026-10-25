#!/usr/bin/env python3
"""
oracle.py -- candidate checker for the Corey Phillips kitten passphrase puzzle.

Purpose:
    The 24-word BIP39 mnemonic behind this puzzle is fixed and public: it is
    deterministically derived from the published image clues/kitten.jpeg
    (sha256 of the base64 of the file bytes, fed to BIP39's entropyToMnemonic).
    The only unknown is the BIP39 passphrase (the "25th word"). This script
    derives the BIP84 P2WPKH address for a candidate passphrase and compares it
    to the target address.

Usage:
    python3 tools/oracle.py --selftest          # must print SELFTEST OK and exit 0
    python3 tools/oracle.py "<candidate passphrase>"   # prints MATCH or NO MATCH
    python3 tools/oracle.py --stdin              # one candidate per line, prints matches only

Input:
    A candidate BIP39 passphrase string (used exactly as given; no normalization,
    since a passphrase is case- and space-sensitive by design).

Output:
    "MATCH <address>" on a hit, "NO MATCH" otherwise. Exit 0 on match, 1 otherwise.

Mechanism (from the author's own published solution, mirrored in clues/author-posts.md):
    kitten.jpeg -> base64 -> sha256 -> BIP39 entropyToMnemonic (24 words, fixed)
                -> seed = PBKDF2-HMAC-SHA512(mnemonic, "mnemonic" + passphrase, 2048)
                -> BIP32 m/84'/0'/0'/0/0 -> compressed pubkey -> HASH160 -> bech32 P2WPKH

Self-test vector:
    empty passphrase "" must derive the sister address bc1q57euh23y3qs2f9d5mtwpax5lqecfvrdkqce82a
    (the author's own worked example in the community hint repo), not the puzzle target.
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import struct
import sys

from ecdsa import SigningKey, SECP256k1

# The 24-word mnemonic is FIXED and fully public: it is reproduced deterministically
# from the published image (see --derive-mnemonic below, or clues/kitten.jpeg).
MNEMONIC = (
    "blossom educate state course sick fresh color divide number soap please pull "
    "glide weather join grit depart dynamic tenant leopard alter piano slight room"
)
MNEMONIC_BYTES = MNEMONIC.encode("utf-8")

TARGET = "bc1qcyrndzgy036f6ax370g8zyvlw86ulawgt0246r"
SISTER = "bc1q57euh23y3qs2f9d5mtwpax5lqecfvrdkqce82a"  # empty passphrase, oracle calibration only

CURVE_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
HARDENED = 0x80000000
PATH = [84 + HARDENED, 0 + HARDENED, 0 + HARDENED, 0, 0]  # m/84'/0'/0'/0/0

CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"


# ---------------------------------------------------------------------------
# bech32 (BIP173), written out so this file has no dependency beyond ecdsa
# ---------------------------------------------------------------------------

def _bech32_polymod(values):
    gen = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    chk = 1
    for v in values:
        b = chk >> 25
        chk = ((chk & 0x1FFFFFF) << 5) ^ v
        for i in range(5):
            chk ^= gen[i] if ((b >> i) & 1) else 0
    return chk


def _bech32_hrp_expand(hrp):
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]


def _bech32_create_checksum(hrp, data):
    values = _bech32_hrp_expand(hrp) + data
    polymod = _bech32_polymod(values + [0, 0, 0, 0, 0, 0]) ^ 1
    return [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]


def _bech32_encode(hrp, data):
    combined = data + _bech32_create_checksum(hrp, data)
    return hrp + "1" + "".join(CHARSET[d] for d in combined)


def _convertbits(data, frombits, tobits, pad=True):
    acc = 0
    bits = 0
    ret = []
    maxv = (1 << tobits) - 1
    for value in data:
        acc = (acc << frombits) | value
        bits += frombits
        while bits >= tobits:
            bits -= tobits
            ret.append((acc >> bits) & maxv)
    if pad and bits:
        ret.append((acc << (tobits - bits)) & maxv)
    return ret


def p2wpkh_address(h160: bytes) -> str:
    return _bech32_encode("bc", [0] + _convertbits(h160, 8, 5))


# ---------------------------------------------------------------------------
# BIP32 derivation (secp256k1, hardened and non-hardened steps)
# ---------------------------------------------------------------------------

def _pubkey_compressed(secret_int: int) -> bytes:
    sk = SigningKey.from_secret_exponent(secret_int, curve=SECP256k1)
    point = sk.verifying_key.pubkey.point
    x = point.x()
    y = point.y()
    prefix = b"\x02" if y % 2 == 0 else b"\x03"
    return prefix + x.to_bytes(32, "big")


def _hash160(data: bytes) -> bytes:
    try:
        h = hashlib.new("ripemd160")
        h.update(hashlib.sha256(data).digest())
        return h.digest()
    except ValueError:
        from Crypto.Hash import RIPEMD160
        h = RIPEMD160.new()
        h.update(hashlib.sha256(data).digest())
        return h.digest()


def seed_from_passphrase(passphrase: str) -> bytes:
    salt = b"mnemonic" + passphrase.encode("utf-8")
    return hashlib.pbkdf2_hmac("sha512", MNEMONIC_BYTES, salt, 2048, 64)


def derive_h160(seed: bytes) -> bytes:
    I = hmac.new(b"Bitcoin seed", seed, hashlib.sha512).digest()
    k = int.from_bytes(I[:32], "big")
    c = I[32:]
    for i in PATH:
        if i >= HARDENED:
            data = b"\x00" + k.to_bytes(32, "big") + struct.pack(">I", i)
        else:
            data = _pubkey_compressed(k) + struct.pack(">I", i)
        I = hmac.new(c, data, hashlib.sha512).digest()
        k = (int.from_bytes(I[:32], "big") + k) % CURVE_N
        c = I[32:]
    return _hash160(_pubkey_compressed(k))


def address_for(passphrase: str) -> str:
    return p2wpkh_address(derive_h160(seed_from_passphrase(passphrase)))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def selftest() -> bool:
    ok = True

    a_empty = address_for("")
    match_sister = a_empty == SISTER
    print(f'address(""): {a_empty}')
    print(f"== SISTER ({SISTER}): {'OK' if match_sister else 'FAIL'}")
    ok = ok and match_sister

    a_control = address_for("control_test_pw_42")
    not_target = a_control != TARGET
    print(f'address("control_test_pw_42"): {a_control}')
    print(f"negative control (unrelated passphrase != target): {'OK' if not_target else 'FAIL'}")
    ok = ok and not_target

    if ok:
        print("SELFTEST OK")
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", nargs="?", help="candidate BIP39 passphrase")
    parser.add_argument("--stdin", action="store_true", help="read candidates, one per line")
    parser.add_argument("--selftest", action="store_true", help="run the certification vector")
    args = parser.parse_args()

    if args.selftest:
        return 0 if selftest() else 1

    if args.stdin:
        any_hit = False
        for line in sys.stdin:
            cand = line.rstrip("\n")
            if not cand:
                continue
            addr = address_for(cand)
            if addr == TARGET:
                any_hit = True
                print(f"MATCH {addr}  candidate={cand!r}")
        return 0 if any_hit else 1

    if args.candidate is None:
        parser.print_help()
        return 0

    addr = address_for(args.candidate)
    if addr == TARGET:
        print(f"MATCH {addr}")
        return 0
    print("NO MATCH")
    return 1


if __name__ == "__main__":
    sys.exit(main())
