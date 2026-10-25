#!/usr/bin/env python3
"""
oracle.py -- candidate checker for Crypto Puzzles (2018), Puzzle #2.

The puzzle publishes no address directly. The answer is a 64-character hex private
key; the escrow address is the Ethereum address derived from it: secp256k1 public
key, Keccak-256 of the uncompressed public key, last 20 bytes. No BIP39, no
passphrase, no derivation path.

Usage:
    python3 oracle.py --selftest          # certifies the transform, prints SELFTEST OK
    python3 oracle.py "<64 hex chars>"    # MATCH / NO MATCH, exit 0/1
    python3 oracle.py --stdin             # one 64-hex candidate per line, prints matches only

Certified against the solved sibling in the same 2018 series, Puzzle #1: the private
key shown on that puzzle's own "solution" video derives to the address that received
and later paid out its own 0.05 ETH prize in 2018. That prize was claimed and spent
by an unrelated third party 8 years ago; nothing here is a live secret.
"""
import sys

from ecdsa import SigningKey, SECP256k1
from Crypto.Hash import keccak

TARGET = "0x1fa8be9de5bbfe047c72db8e8e3257128f7661ad"  # Puzzle #2 escrow

# Puzzle #1's own published solution, from its "Crypto Puzzle 1 Solved!" video.
KNOWN_ANSWER = "4487FC620AD0C4C67E80BE342B2EA1F5A3DC482BE6FB9C2451007322EA8BE35F"
KNOWN_ADDRESS = "0xc99a54eea6036115f913a13d6606e935bca47a8f"


def eth_address(privkey_hex):
    """Derive the checksummed-free (lowercase) Ethereum address for a 64-hex private key."""
    text = privkey_hex.strip().lower()
    if text.startswith("0x"):
        text = text[2:]
    key_bytes = bytes.fromhex(text)
    if len(key_bytes) != 32:
        return None
    sk = SigningKey.from_string(key_bytes, curve=SECP256k1)
    pub = sk.get_verifying_key().to_string()  # 64 bytes, X || Y, no prefix
    h = keccak.new(digest_bits=256)
    h.update(pub)
    return "0x" + h.digest()[-20:].hex()


def check(candidate):
    try:
        return eth_address(candidate)
    except Exception:
        return None


def selftest():
    addr = check(KNOWN_ANSWER)
    assert addr == KNOWN_ADDRESS, f"transform mismatch: {addr} != {KNOWN_ADDRESS}"
    print("SELFTEST OK")


def main():
    args = sys.argv[1:]
    if not args:
        print('usage: oracle.py --selftest | "<64 hex chars>" | --stdin')
        sys.exit(2)

    if args[0] == "--selftest":
        selftest()
        sys.exit(0)

    if args[0] == "--stdin":
        matched = False
        for line in sys.stdin:
            candidate = line.strip()
            if not candidate:
                continue
            addr = check(candidate)
            if addr == TARGET:
                print(f"MATCH {candidate}")
                matched = True
        sys.exit(0 if matched else 1)

    addr = check(args[0])
    if addr == TARGET:
        print(f"MATCH {addr}")
        sys.exit(0)
    print("NO MATCH")
    sys.exit(1)


if __name__ == "__main__":
    main()
