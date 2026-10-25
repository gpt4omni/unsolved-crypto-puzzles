#!/usr/bin/env python3
"""
derive.py -- generic candidate derivation CLI for unsolved-crypto-puzzles.

Purpose:
    Turn a candidate (a BIP39 mnemonic, a brainwallet phrase, a raw hex private key, a
    repeated SHA-256, or a script for a P2SH address) into the Bitcoin or Ethereum address(es)
    it produces, so it can be compared against a puzzle's escrow. Every subcommand accepts
    --target <address> and prints MATCH or NO MATCH (exit 0 on MATCH, exit 1 otherwise),
    so it can be used directly as an oracle inside a puzzle folder's tools/oracle.py.

Usage (run from the repository root or anywhere; no relative imports needed):
    python3 tools/derive.py bip39 "<12 or 24 words>" [--passphrase <p>] [--lang en]
                             [--path bip44|bip49|bip84|eth|<explicit path>] [--count N]
                             [--target <address>]
    python3 tools/derive.py brainwallet "<text>" [--target <address>]
    python3 tools/derive.py hexkey <64-hex-privkey> [--target <address>]
    python3 tools/derive.py sha256n "<text>" --rounds N
    python3 tools/derive.py hash160script <hex-script> [--target <address>]

Input:
    Command-line arguments only. No files are read.

Output:
    One derived value or address per line to stdout. With --target, a final line
    "MATCH" or "NO MATCH" and a matching process exit code.

Self-check (three vectors, must all pass):
    python3 tools/derive.py bip39 "abandon abandon abandon abandon abandon abandon abandon \\
        abandon abandon abandon abandon about" --path bip84
        -> bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu
    python3 tools/derive.py bip39 "abandon abandon abandon abandon abandon abandon abandon \\
        abandon abandon abandon abandon about" --path bip44
        -> 1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA
    python3 tools/derive.py bip39 "abandon abandon abandon abandon abandon abandon abandon \\
        abandon abandon abandon abandon about" --path eth
        -> 0x9858EfFD232B4033E47d90003D41EC34EcaEda94
"""

import argparse
import hashlib
import sys

import base58
import ecdsa
from ecdsa import SigningKey, SECP256k1

try:
    from Crypto.Hash import RIPEMD160
    def ripemd160(data: bytes) -> bytes:
        h = RIPEMD160.new()
        h.update(data)
        return h.digest()
except ImportError:  # pragma: no cover
    def ripemd160(data: bytes) -> bytes:
        h = hashlib.new("ripemd160")
        h.update(data)
        return h.digest()

from bip_utils import (
    Bip39SeedGenerator,
    Bip39MnemonicValidator,
    Bip39Languages,
    Bip44,
    Bip49,
    Bip84,
    Bip44Coins,
    Bip49Coins,
    Bip84Coins,
    Bip44Changes,
    Bip32Slip10Secp256k1,
)

LANG_MAP = {
    "en": Bip39Languages.ENGLISH,
    "fr": Bip39Languages.FRENCH,
    "it": Bip39Languages.ITALIAN,
    "es": Bip39Languages.SPANISH,
}


def hash160(data: bytes) -> bytes:
    return ripemd160(hashlib.sha256(data).digest())


def sha256(data: bytes) -> bytes:
    return hashlib.sha256(data).digest()


def b58check_encode(payload: bytes, version: bytes) -> str:
    data = version + payload
    checksum = sha256(sha256(data))[:4]
    return base58.b58encode(data + checksum).decode()


def p2pkh_address(pubkey_bytes: bytes, version: bytes = b"\x00") -> str:
    return b58check_encode(hash160(pubkey_bytes), version)


def p2sh_address(script_bytes: bytes, version: bytes = b"\x05") -> str:
    return b58check_encode(hash160(script_bytes), version)


def privkey_to_pubkeys(priv_int: int):
    """Return (compressed_pubkey_bytes, uncompressed_pubkey_bytes) for a private key integer."""
    sk = SigningKey.from_secret_exponent(priv_int, curve=SECP256k1)
    vk = sk.verifying_key
    x = vk.pubkey.point.x()
    y = vk.pubkey.point.y()
    uncompressed = b"\x04" + x.to_bytes(32, "big") + y.to_bytes(32, "big")
    prefix = b"\x02" if y % 2 == 0 else b"\x03"
    compressed = prefix + x.to_bytes(32, "big")
    return compressed, uncompressed


def wif_encode(priv_int: int, compressed: bool, version: bytes = b"\x80") -> str:
    payload = priv_int.to_bytes(32, "big")
    if compressed:
        payload += b"\x01"
    return b58check_encode(payload, version)


def cmd_bip39(args) -> str:
    lang = LANG_MAP.get(args.lang, Bip39Languages.ENGLISH)
    validator = Bip39MnemonicValidator(lang=lang)
    is_valid = validator.IsValid(args.mnemonic)
    print(f"# mnemonic checksum valid: {is_valid}")

    seed_bytes = Bip39SeedGenerator(args.mnemonic, lang).Generate(args.passphrase or "")

    results = []
    if args.path == "bip44":
        ctx = Bip44.FromSeed(seed_bytes, Bip44Coins.BITCOIN)
        base_ctx = ctx.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT)
        for i in range(args.count):
            addr = base_ctx.AddressIndex(i).PublicKey().ToAddress()
            print(addr)
            results.append(addr)
    elif args.path == "bip49":
        ctx = Bip49.FromSeed(seed_bytes, Bip49Coins.BITCOIN)
        base_ctx = ctx.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT)
        for i in range(args.count):
            addr = base_ctx.AddressIndex(i).PublicKey().ToAddress()
            print(addr)
            results.append(addr)
    elif args.path == "bip84":
        ctx = Bip84.FromSeed(seed_bytes, Bip84Coins.BITCOIN)
        base_ctx = ctx.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT)
        for i in range(args.count):
            addr = base_ctx.AddressIndex(i).PublicKey().ToAddress()
            print(addr)
            results.append(addr)
    elif args.path == "eth":
        ctx = Bip44.FromSeed(seed_bytes, Bip44Coins.ETHEREUM)
        base_ctx = ctx.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT)
        for i in range(args.count):
            addr = base_ctx.AddressIndex(i).PublicKey().ToAddress()
            print(addr)
            results.append(addr)
    else:
        # explicit path, e.g. m/44'/0'/0'/0/0
        bip32_ctx = Bip32Slip10Secp256k1.FromSeed(seed_bytes)
        derived = bip32_ctx.DerivePath(args.path)
        addr = p2pkh_address(derived.PublicKey().RawCompressed().ToBytes())
        print(addr)
        results.append(addr)

    return results[0] if results else None


def cmd_brainwallet(args) -> list:
    digest = sha256(args.text.encode("utf-8"))
    priv_int = int.from_bytes(digest, "big")
    compressed_pub, uncompressed_pub = privkey_to_pubkeys(priv_int)

    addr_uncompressed = p2pkh_address(uncompressed_pub)
    addr_compressed = p2pkh_address(compressed_pub)
    wif_uncompressed = wif_encode(priv_int, compressed=False)
    wif_compressed = wif_encode(priv_int, compressed=True)

    print(f"privkey_hex: {digest.hex()}")
    print(f"address_uncompressed: {addr_uncompressed}")
    print(f"address_compressed: {addr_compressed}")
    print(f"wif_uncompressed: {wif_uncompressed}")
    print(f"wif_compressed: {wif_compressed}")

    return [addr_uncompressed, addr_compressed]


def cmd_hexkey(args) -> list:
    hexkey = args.hexkey.strip().lower()
    if len(hexkey) != 64:
        print(f"error: expected 64 hex characters, got {len(hexkey)}", file=sys.stderr)
        sys.exit(2)
    priv_int = int(hexkey, 16)
    compressed_pub, uncompressed_pub = privkey_to_pubkeys(priv_int)

    addr_uncompressed = p2pkh_address(uncompressed_pub)
    addr_compressed = p2pkh_address(compressed_pub)
    wif_uncompressed = wif_encode(priv_int, compressed=False)
    wif_compressed = wif_encode(priv_int, compressed=True)

    print(f"address_uncompressed: {addr_uncompressed}")
    print(f"address_compressed: {addr_compressed}")
    print(f"wif_uncompressed: {wif_uncompressed}")
    print(f"wif_compressed: {wif_compressed}")

    return [addr_uncompressed, addr_compressed]


def cmd_sha256n(args) -> str:
    data = args.text.encode("utf-8")
    digest = data
    for _ in range(args.rounds):
        digest = hashlib.sha256(digest).digest()
    print(digest.hex())
    return digest.hex()


def cmd_hash160script(args) -> str:
    script_bytes = bytes.fromhex(args.hexscript.strip())
    addr = p2sh_address(script_bytes)
    print(addr)
    return addr


def main():
    parser = argparse.ArgumentParser(
        description="Generic derivation CLI for unsolved-crypto-puzzles candidates."
    )
    parser.add_argument("--target", default=None, help="expected address/value; prints MATCH/NO MATCH")
    sub = parser.add_subparsers(dest="command", required=True)

    p_bip39 = sub.add_parser("bip39", help="BIP39 mnemonic to addresses")
    p_bip39.add_argument("mnemonic", help="space-separated mnemonic words")
    p_bip39.add_argument("--passphrase", default="", help="BIP39 passphrase (default: none)")
    p_bip39.add_argument("--lang", default="en", choices=sorted(LANG_MAP.keys()))
    p_bip39.add_argument(
        "--path",
        default="bip84",
        help="bip44 | bip49 | bip84 | eth | an explicit path such as m/84'/0'/0'/0/0",
    )
    p_bip39.add_argument("--count", type=int, default=1, help="number of addresses to derive")
    p_bip39.add_argument("--target", default=None, help="expected address; prints MATCH/NO MATCH")

    p_brain = sub.add_parser("brainwallet", help="text -> sha256 -> P2PKH addresses and WIFs")
    p_brain.add_argument("text", help="the brainwallet phrase")
    p_brain.add_argument("--target", default=None, help="expected address; prints MATCH/NO MATCH")

    p_hex = sub.add_parser("hexkey", help="hex private key -> addresses")
    p_hex.add_argument("hexkey", help="64 hex character private key")
    p_hex.add_argument("--target", default=None, help="expected address; prints MATCH/NO MATCH")

    p_sha = sub.add_parser("sha256n", help="text -> sha256 applied n times -> hex")
    p_sha.add_argument("text", help="input text")
    p_sha.add_argument("--rounds", type=int, required=True, help="number of SHA-256 rounds")
    p_sha.add_argument("--target", default=None, help="expected hex digest; prints MATCH/NO MATCH")

    p_h160 = sub.add_parser("hash160script", help="hex script -> P2SH address")
    p_h160.add_argument("hexscript", help="hex-encoded redeem script")
    p_h160.add_argument("--target", default=None, help="expected address; prints MATCH/NO MATCH")

    args = parser.parse_args()

    if args.command == "bip39":
        result = cmd_bip39(args)
        candidates = [result] if result else []
    elif args.command == "brainwallet":
        candidates = cmd_brainwallet(args)
    elif args.command == "hexkey":
        candidates = cmd_hexkey(args)
    elif args.command == "sha256n":
        candidates = [cmd_sha256n(args)]
    elif args.command == "hash160script":
        candidates = [cmd_hash160script(args)]
    else:
        parser.error("unknown command")
        return

    if args.target is not None:
        target = args.target.strip()
        if any(c and c.strip().lower() == target.lower() for c in candidates):
            print("MATCH")
            sys.exit(0)
        else:
            print("NO MATCH")
            sys.exit(1)


if __name__ == "__main__":
    main()
