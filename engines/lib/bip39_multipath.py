#!/usr/bin/env python3
"""BIP39 tokenization + checksum + multi-path address derivation.

Given a BIP39 seed, derives the P2PKH address set across a small bank of
common paths (master key, a few BIP44-style depths) in both compressed and
uncompressed form, so a candidate mnemonic can be checked against a target
address without committing to one specific derivation path up front.
"""
import re, unicodedata, hashlib, hmac, struct
import ecdsa, base58

H = 0x80000000
CURVE_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

import os
_D = os.path.dirname(__file__)
BW = open(os.path.join(_D, "bip39_english.txt")).read().split()
BIP39 = set(BW)
W2I = {w: i for i, w in enumerate(BW)}

def norm(t):
    return unicodedata.normalize('NFC', re.sub(r"[^A-Za-z]", "", t)).lower()

def checksum_ok_idxs(idxs):
    """idxs = 12 BIP39 indices. Check 12-word checksum."""
    val = 0
    for x in idxs:
        val = (val << 11) | x
    ent = (val >> 4).to_bytes(16, "big")
    return (hashlib.sha256(ent).digest()[0] >> 4) == (val & 0xF)

def valid_mnemonic(words):
    if len(words) != 12:
        return False
    if not all(w in BIP39 for w in words):
        return False
    return checksum_ok_idxs([W2I[w] for w in words])

# ---- derivation (self-contained, no bip_utils overhead) ----
def hash160(d): return hashlib.new('ripemd160', hashlib.sha256(d).digest()).digest()
def p2pkh(pub):
    payload = b'\x00' + hash160(pub)
    return base58.b58encode(payload + hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]).decode()
def priv_to_pub(priv, c=True):
    sk = ecdsa.SigningKey.from_string(priv, curve=ecdsa.SECP256k1)
    vk = sk.get_verifying_key()
    x, y = vk.pubkey.point.x(), vk.pubkey.point.y()
    if c: return (b'\x02' if y % 2 == 0 else b'\x03') + x.to_bytes(32, 'big')
    return b'\x04' + x.to_bytes(32, 'big') + y.to_bytes(32, 'big')
def bip32_m(seed):
    I = hmac.new(b"Bitcoin seed", seed, hashlib.sha512).digest()
    return I[:32], I[32:]
def ckd(k, c, i):
    data = (b'\x00' + k if i >= H else priv_to_pub(k)) + struct.pack('>I', i)
    I = hmac.new(c, data, hashlib.sha512).digest()
    return ((int.from_bytes(I[:32], 'big') + int.from_bytes(k, 'big')) % CURVE_N).to_bytes(32, 'big'), I[32:]
def derive(seed, idxs):
    k, c = bip32_m(seed)
    for i in idxs:
        k, c = ckd(k, c, i)
    return k

# path set covering the required derivations
PATHS = [
    [H+44, H+0, H+0, 0, 0], [H+44, H+0, H+0, 0, 1], [H+44, H+0, H+0, 0, 2], [H+44, H+0, H+0, 0, 3],
    [0, 0], [0], [H+0, 0], [H+44, H+0, H+0],
    [H+44, H+0, H+0, 1, 0],
]

def addr_set_from_seed(seed):
    """All addresses from a BIP32 master seed across PATHS + master, comp+uncomp."""
    out = set()
    mk, mc = bip32_m(seed)
    for comp in (True, False):
        out.add(p2pkh(priv_to_pub(mk, comp)))
    for path in PATHS:
        try:
            k = derive(seed, path)
            for comp in (True, False):
                out.add(p2pkh(priv_to_pub(k, comp)))
        except Exception:
            pass
    return out

from mnemonic import Mnemonic
_mnemo = Mnemonic("english")
def bip39_seed(mnemonic, passphrase=""):
    return _mnemo.to_seed(mnemonic, passphrase)

def check_mnemonic(words, target, passphrase=""):
    """words list (already valid), target = P2PKH address to match.
    Returns a matching path string, or None."""
    mn = " ".join(words)
    seed = _mnemo.to_seed(mn, passphrase)
    if target in addr_set_from_seed(seed):
        # identify which path produced it
        mk, mc = bip32_m(seed)
        for comp in (True, False):
            if p2pkh(priv_to_pub(mk, comp)) == target:
                return f"master comp={comp}"
        for path in PATHS:
            k = derive(seed, path)
            for comp in (True, False):
                if p2pkh(priv_to_pub(k, comp)) == target:
                    return f"path={path} comp={comp}"
    return None


def _selftest():
    """Standard BIP39 test vector: 11x 'abandon' + 'about', empty passphrase.
    m/44'/0'/0'/0/0 compressed must be the well-known
    1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA (the default vector used by, e.g.,
    the Ian Coleman BIP39 tool)."""
    mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    words = mnemonic.split()
    assert valid_mnemonic(words), "checksum failed on the standard test vector"
    seed = bip39_seed(mnemonic)
    expect_seed = ("5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5f"
                   "c19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4")
    assert seed.hex() == expect_seed, "PBKDF2 seed mismatch"
    target = "1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA"
    got = check_mnemonic(words, target)
    assert got == "path=[2147483692, 2147483648, 2147483648, 0, 0] comp=True", got
    print("[selftest] bip39_multipath OK: seed + m/44'/0'/0'/0/0 match the "
          "standard abandon...about vector")
    return True


if __name__ == "__main__":
    import sys
    sys.exit(0 if _selftest() else 1)
