#!/usr/bin/env python3
"""
oracle.py -- candidate checker for the BLM "Welcome to the Brave New World" puzzle.

Purpose:
    The puzzle has two competing target formats (the format itself is unresolved, see
    the README): a BIP39 12-word mnemonic derived under 4 candidate paths, both
    compressed and uncompressed P2PKH; or an old-Electrum (v1) 12-word mnemonic under
    5 address indexes and 2 change values. Given a 12-word candidate, this checks it
    against the escrow address under every one of those readings and reports the first
    exact match, or none. This is a verifier, not a search tool: it checks the
    candidate you give it, it does not generate any.

Usage:
    python3 tools/oracle.py --selftest                 # must print SELFTEST OK
    python3 tools/oracle.py "w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12"
    python3 tools/oracle.py --stdin                     # one 12-word candidate per line

Input:
    A 12-word, space-separated candidate mnemonic on the command line or one per line
    on stdin. Word count other than 12 is rejected without deriving anything.

Output:
    "MATCH <method> <address>" for a hit, "NO MATCH" otherwise. Exit 0 on a match
    (or after a clean --selftest), 1 otherwise.

Dependencies:
    stdlib, ecdsa, base58 (for BIP39/BIP32 P2PKH), bip_utils (for BIP39 checksum
    validation and for the old-Electrum v1 derivation, which bip_utils implements
    natively and which this oracle uses so as not to ship a second copy of the
    1626-word old-Electrum wordlist).
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import struct
import sys

import base58
import ecdsa
from bip_utils import (
    Bip39MnemonicValidator,
    ElectrumV1,
    ElectrumV1MnemonicDecoder,
    ElectrumV1SeedGenerator,
    Secp256k1PrivateKey,
)

TARGET_ADDRESS = "1KfZGvwZxsvSmemoCmEV75uqcNzYBHjkHZ"

# secp256k1 group order, needed for the manual BIP32 child key derivation below.
_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
_HARDENED = 0x80000000

# The 4 BIP39 paths this puzzle's derivation is checked under: the two standard BIP44
# receive-index paths, and the two short, non-standard paths some 2020-era wallets used.
_BIP39_PATHS = {
    "bip39 m/44'/0'/0'/0/0": [_HARDENED + 44, _HARDENED + 0, _HARDENED + 0, 0, 0],
    "bip39 m/44'/0'/0'/0/1": [_HARDENED + 44, _HARDENED + 0, _HARDENED + 0, 0, 1],
    "bip39 m/0/0": [_HARDENED + 0, 0, 0],
    "bip39 m/0'": [_HARDENED + 0, _HARDENED + 0],
}


def _hash160(data: bytes) -> bytes:
    return hashlib.new("ripemd160", hashlib.sha256(data).digest()).digest()


def _p2pkh(pubkey: bytes) -> str:
    payload = b"\x00" + _hash160(pubkey)
    checksum = hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
    return base58.b58encode(payload + checksum).decode()


def _pubkey(privkey: bytes, compressed: bool) -> bytes:
    vk = ecdsa.SigningKey.from_string(privkey, curve=ecdsa.SECP256k1).get_verifying_key()
    x, y = vk.pubkey.point.x(), vk.pubkey.point.y()
    if compressed:
        prefix = b"\x02" if y % 2 == 0 else b"\x03"
        return prefix + x.to_bytes(32, "big")
    return b"\x04" + x.to_bytes(32, "big") + y.to_bytes(32, "big")


def _ckd(key: bytes, chain: bytes, index: int) -> tuple[bytes, bytes]:
    """One step of standard BIP32 private child key derivation."""
    if index >= _HARDENED:
        data = b"\x00" + key + struct.pack(">I", index)
    else:
        data = _pubkey(key, compressed=True) + struct.pack(">I", index)
    digest = hmac.new(chain, data, hashlib.sha512).digest()
    child_key = ((int.from_bytes(digest[:32], "big") + int.from_bytes(key, "big")) % _N).to_bytes(32, "big")
    return child_key, digest[32:]


def _bip39_addresses(mnemonic: str):
    """Yield (method label, address) for every (path, compression) combination."""
    seed = hashlib.pbkdf2_hmac("sha512", mnemonic.encode("utf-8"), b"mnemonic", 2048)
    master = hmac.new(b"Bitcoin seed", seed, hashlib.sha512).digest()
    master_key, master_chain = master[:32], master[32:]
    for label, path in _BIP39_PATHS.items():
        key, chain = master_key, master_chain
        for index in path:
            key, chain = _ckd(key, chain, index)
        for compressed, tag in ((True, "comp"), (False, "uncomp")):
            yield f"{label} {tag}", _p2pkh(_pubkey(key, compressed))


def _electrum_v1_addresses(mnemonic: str):
    """Yield (method label, address) for the 2x5 old-Electrum change/index grid."""
    try:
        entropy = ElectrumV1MnemonicDecoder().Decode(mnemonic)
    except Exception:
        return
    if len(entropy) not in (16, 32):
        return
    seed = ElectrumV1SeedGenerator(mnemonic).Generate()
    priv = Secp256k1PrivateKey.FromBytes(seed)
    wallet = ElectrumV1(priv_key=priv, pub_key=None)
    for change in (0, 1):
        for index in range(5):
            yield f"electrum-v1 change={change} idx={index}", wallet.GetAddress(change, index)


def check(mnemonic: str):
    """Return (method, address) on an exact match against TARGET_ADDRESS, else None."""
    words = mnemonic.split()
    if len(words) != 12:
        return None
    mnemonic = " ".join(words)

    if Bip39MnemonicValidator().IsValid(mnemonic):
        for method, address in _bip39_addresses(mnemonic):
            if address == TARGET_ADDRESS:
                return method, address

    for method, address in _electrum_v1_addresses(mnemonic):
        if address == TARGET_ADDRESS:
            return method, address

    return None


def selftest() -> bool:
    ok = True

    # Raw secp256k1 -> P2PKH vectors (priv=1), independent of any mnemonic scheme.
    uncomp = _p2pkh(_pubkey((1).to_bytes(32, "big"), compressed=False))
    expect_uncomp = "1EHNa6Q4Jz2uvNExL497mE43ikXhwF6kZm"
    print(f"priv=1 uncompressed P2PKH -> {expect_uncomp}: {'OK' if uncomp == expect_uncomp else 'FAIL'}")
    ok = ok and uncomp == expect_uncomp

    comp = _p2pkh(_pubkey((1).to_bytes(32, "big"), compressed=True))
    expect_comp = "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH"
    print(f"priv=1 compressed P2PKH -> {expect_comp}: {'OK' if comp == expect_comp else 'FAIL'}")
    ok = ok and comp == expect_comp

    # Public BIP39 test vector (all-zero entropy, the standard "abandon x11 about"
    # mnemonic used across the BIP39/BIP32 test suites), at m/44'/0'/0'/0/0 compressed.
    kat_mnemonic = ("abandon " * 11 + "about").strip()
    kat_addresses = dict(_bip39_addresses(kat_mnemonic))
    kat_addr = kat_addresses.get("bip39 m/44'/0'/0'/0/0 comp")
    expect_kat = "1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA"
    print(f"BIP39 KAT m/44'/0'/0'/0/0 -> {expect_kat}: {'OK' if kat_addr == expect_kat else 'FAIL'}")
    ok = ok and kat_addr == expect_kat

    # Public old-Electrum (v1) test vector, change=0 index=0.
    elec_mnemonic = "another embrace sense creek careful crush advice glare passion skip awaken childhood"
    elec_addresses = dict(_electrum_v1_addresses(elec_mnemonic))
    elec_addr = elec_addresses.get("electrum-v1 change=0 idx=0")
    expect_elec = "1KCvshw5g3ndGYxQmAxKcTpJV5kbj6Lefo"
    print(f"old-Electrum v1 vector -> {expect_elec}: {'OK' if elec_addr == expect_elec else 'FAIL'}")
    ok = ok and elec_addr == expect_elec

    # Negative control: neither public vector matches the puzzle escrow.
    clean = check(kat_mnemonic) is None and check(elec_mnemonic) is None
    print(f"negative control (public vectors vs escrow) -> no match: {'OK' if clean else 'FAIL'}")
    ok = ok and clean

    if ok:
        print("SELFTEST OK")
    return ok


def _print_result(candidate: str) -> bool:
    hit = check(candidate)
    if hit:
        print(f"MATCH {hit[0]} {hit[1]}")
    else:
        print("NO MATCH")
    return hit is not None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", nargs="?", help="12 space-separated words")
    parser.add_argument("--selftest", action="store_true")
    parser.add_argument("--stdin", action="store_true", help="read candidates, one per line")
    args = parser.parse_args()

    if args.selftest:
        return 0 if selftest() else 1

    if args.stdin:
        any_match = False
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            if _print_result(line):
                any_match = True
        return 0 if any_match else 1

    if args.candidate:
        return 0 if _print_result(args.candidate) else 1

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
