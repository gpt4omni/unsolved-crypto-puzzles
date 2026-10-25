#!/usr/bin/env python3
"""
oracle.py -- BIP38 candidate checker for the Ballet / Bobby Lee 2 BTC card challenge.

Purpose:
    Given a Ballet REAL card's BIP38-encrypted WIF and a candidate passphrase, decrypt
    it, derive the P2PKH address, and compare it byte-exact against the card's escrow
    address. This is a verifier, not a search tool: it checks the pair you give it, it
    does not generate any.

    Each Ballet card carries two secrets: a BIP38-encrypted WIF (printed under a
    tamper-evident sticker) and a passphrase (printed under scratch-off material).
    Both must come from the SAME card. The pipeline auto-detects BIP38 non-EC (blob
    prefix 0x0142) and EC-multiply (0x0143) encryption; the two open Ballet cards use
    EC-multiply.

Usage:
    python3 tools/oracle.py --selftest                          # must print SELFTEST OK
    python3 tools/oracle.py "<encrypted_wif> <passphrase> <address>"   # one candidate
    python3 tools/oracle.py --stdin                             # one "wif pass addr" per line

Input:
    A candidate as "<encrypted_wif> <passphrase> <address>" (space separated) on the
    command line or one per line on stdin.

Output:
    "MATCH <address> WIF=<wif> priv_hex=<hex>" on a hit, "NO MATCH" otherwise.
    Exit 0 on any match, 1 if none.

Dependencies:
    stdlib, base58, bip_utils.
"""

from __future__ import annotations

import argparse
import sys

import base58
from bip_utils import (
    Bip38Decrypter,
    Secp256k1PrivateKey,
    Secp256k1PublicKey,
    P2PKHAddrEncoder,
    WifEncoder,
    WifPubKeyModes,
    CoinsConf,
)

_WIF_VER = CoinsConf.BitcoinMainNet.ParamByKey("wif_net_ver")
_P2PKH_VER = CoinsConf.BitcoinMainNet.ParamByKey("p2pkh_net_ver")

# Certification vector: the solved sibling card AA007448 (funded 2020-07-24, swept
# 2020-07-31 by a third-party solver). Not part of the live prize; kept here only so
# --selftest has a known-good pair to reproduce byte for byte.
ORACLE_VECTOR = {
    "name": "AA007448",
    "address": "1LL6Xy92LwGDRfQP9fBU7f1477cEKctr7c",
    "encrypted_wif": "6PnWfKaBfDW6mFFhhFsbNRHnVgojUhdf2b5NXP3FfwXiQ69MxEzVK2J4cH",
    "passphrase": "335Y-K745-C8WT-4D2W-80WP",
    "decrypted_wif": "L2mrYyo5a6rpyQdC88UitNeH5n1rAqPcq8Qv5gwtQE8KTvW3ZTeH",
    "priv_hex": "a5b9247400b7e31e54481f14828ced3a538af280e9eeb1229196c3cb5e7ecdde",
}


def _is_ec(encrypted_wif: str) -> bool:
    """Inspect the 2-byte BIP38 prefix: 0x0142 = non-EC, 0x0143 = EC-multiply."""
    raw = base58.b58decode_check(encrypted_wif)
    return raw[1] == 0x43


def decrypt(encrypted_wif: str, passphrase: str):
    """BIP38 decrypt -> (priv_bytes, pub_mode). Raises on a wrong passphrase."""
    if _is_ec(encrypted_wif):
        return Bip38Decrypter.DecryptEc(encrypted_wif, passphrase)
    return Bip38Decrypter.DecryptNoEc(encrypted_wif, passphrase)


def _wif_mode(pub_mode):
    return (
        WifPubKeyModes.COMPRESSED
        if pub_mode.name == "COMPRESSED"
        else WifPubKeyModes.UNCOMPRESSED
    )


def priv_to_p2pkh(priv_bytes: bytes, pub_mode) -> str:
    """Derive the P2PKH address honoring the BIP38 compression flag."""
    priv = Secp256k1PrivateKey.FromBytes(priv_bytes)
    pub = priv.PublicKey()
    if pub_mode.name == "COMPRESSED":
        pub_bytes = pub.RawCompressed().ToBytes()
    else:
        pub_bytes = pub.RawUncompressed().ToBytes()
    pub_obj = Secp256k1PublicKey.FromBytes(pub_bytes)
    return P2PKHAddrEncoder.EncodeKey(pub_obj, net_ver=_P2PKH_VER)


def attempt(encrypted_wif: str, passphrase: str, expected_address: str) -> tuple[bool, dict]:
    """Return (matched, info). matched is True only on a byte-exact address match."""
    try:
        priv_bytes, pub_mode = decrypt(encrypted_wif, passphrase)
    except Exception as e:  # noqa: BLE001  any decrypt failure = wrong passphrase
        return False, {"error": f"{type(e).__name__}: {e}"}
    derived = priv_to_p2pkh(priv_bytes, pub_mode)
    wif = WifEncoder.Encode(priv_bytes, _WIF_VER, _wif_mode(pub_mode))
    matched = derived == expected_address
    return matched, {
        "wif": wif,
        "priv_hex": priv_bytes.hex(),
        "compression": pub_mode.name,
        "derived_address": derived,
        "expected_address": expected_address,
    }


def selftest() -> bool:
    ok = True

    matched, info = attempt(
        ORACLE_VECTOR["encrypted_wif"], ORACLE_VECTOR["passphrase"], ORACLE_VECTOR["address"]
    )
    found = matched and info.get("derived_address") == ORACLE_VECTOR["address"]
    print(f'AA007448: decrypt+derive -> {ORACLE_VECTOR["address"]}: {"OK" if found else "FAIL"}')
    ok = ok and found

    wif_ok = matched and info.get("wif") == ORACLE_VECTOR["decrypted_wif"]
    print(f'AA007448: re-encoded WIF -> {ORACLE_VECTOR["decrypted_wif"]}: {"OK" if wif_ok else "FAIL"}')
    ok = ok and wif_ok

    hex_ok = matched and info.get("priv_hex") == ORACLE_VECTOR["priv_hex"]
    print(f'AA007448: private key hex -> {ORACLE_VECTOR["priv_hex"]}: {"OK" if hex_ok else "FAIL"}')
    ok = ok and hex_ok

    wrong, _ = attempt(
        ORACLE_VECTOR["encrypted_wif"], "0000-0000-0000-0000-0000", ORACLE_VECTOR["address"]
    )
    clean = not wrong
    print(f"negative control (wrong passphrase) -> no match: {'OK' if clean else 'FAIL'}")
    ok = ok and clean

    if ok:
        print("SELFTEST OK")
    return ok


def _print_result(candidate: str) -> bool:
    parts = candidate.split()
    if len(parts) != 3:
        print(f"NO MATCH (malformed candidate, expected 3 fields): {candidate!r}")
        return False
    enc, passphrase, addr = parts
    matched, info = attempt(enc, passphrase, addr)
    if matched:
        print(f"MATCH {info['derived_address']} WIF={info['wif']} priv_hex={info['priv_hex']}")
    else:
        print("NO MATCH")
    return matched


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "candidate", nargs="?", help='"<encrypted_wif> <passphrase> <address>", space separated'
    )
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
