#!/usr/bin/env python3
"""
Brainwallet passphrase -> P2PKH address, RushWallet derivation.

    privkey = SHA256(utf8(passphrase))
    pubkey  = UNCOMPRESSED secp256k1 point (0x04 || X || Y)
    address = base58check(0x00 || RIPEMD160(SHA256(pubkey)))

RushWallet (2014) used UNCOMPRESSED addresses; derive() also returns the
compressed variant as a safety net for puzzles that used it instead.

Derivation validated against 3 public oracles below (independently
reproducible against RushWallet's own contest.js and www.rushwallet.com).
"""
import hashlib, base58, sys
from ecdsa import SECP256k1, SigningKey

# Oracles for self-test (passphrase -> uncompressed address)
ORACLES = {
    "Dmitri Nancy Enrique": "16tGKq48tGq3Td1wcDoQRuWtPtXoEfZpBC",
    "Dmitri Enrique Nancy": "14yaVUgstpqavPEFtyit3wEWsyumysqxZV",
    "www.rushwallet.com":   "1EWr7tvs8efFu15nvuL4RezVVoHFpxH2nF",
}

def sha256(b): return hashlib.sha256(b).digest()
def ripemd160(b):
    h = hashlib.new('ripemd160'); h.update(b); return h.digest()

def derive(pp):
    """Return (uncompressed_addr, compressed_addr) or (None,None) on bad key."""
    if isinstance(pp, str):
        pp = pp.encode('utf-8')
    priv = sha256(pp)
    n = int.from_bytes(priv, 'big')
    if n == 0 or n >= SECP256k1.order:
        return (None, None)
    vk = SigningKey.from_string(priv, curve=SECP256k1).get_verifying_key()
    s = vk.to_string()
    addr_u = base58.b58encode_check(b'\x00'+ripemd160(sha256(b'\x04'+s))).decode()
    x, y = s[:32], s[32:]
    pc = (b'\x02' if y[-1] % 2 == 0 else b'\x03') + x
    addr_c = base58.b58encode_check(b'\x00'+ripemd160(sha256(pc))).decode()
    return (addr_u, addr_c)

def selftest():
    for pp, exp in ORACLES.items():
        u, c = derive(pp)
        assert u == exp, f"ORACLE FAIL {pp!r}: {u} != {exp}"
    print("[selftest] derivation validated on 3 public oracles OK")
    return True

def find_match(passphrase, target_uncompressed=None, target_compressed=None):
    """Check one candidate passphrase against one or both target addresses.
    Returns 'uncompressed', 'compressed', or None."""
    u, c = derive(passphrase)
    if target_uncompressed and u == target_uncompressed:
        return "uncompressed"
    if target_compressed and c == target_compressed:
        return "compressed"
    return None

if __name__ == "__main__":
    ok = selftest()
    if len(sys.argv) > 2:
        pp, target = sys.argv[1], sys.argv[2]
        which = find_match(pp, target, target)
        if which:
            print(f"MATCH [{which}] passphrase={pp!r}")
            sys.exit(0)
        print(f"no match for passphrase={pp!r} against {target}")
        sys.exit(1)
    print("usage: rushwallet_derive.py <passphrase> <target_address>")
    sys.exit(0 if ok else 1)
