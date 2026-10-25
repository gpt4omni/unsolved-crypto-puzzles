"""CPU reference helpers used to validate and re-derive GPU engine hits.

btc_p2pkh.py        -- private key -> P2PKH address (compressed + uncompressed)
bip39_multipath.py  -- BIP39 seed -> address set across a small bank of paths
rushwallet_derive.py -- SHA256(passphrase) -> P2PKH (RushWallet-style brainwallets)

Import as a package (`from lib import btc_p2pkh`) or add this directory to
sys.path and import the modules directly; both work since none of these
modules depend on package-relative imports.
"""
