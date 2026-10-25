# Glossary

Short definitions for terms used across this repository.

**escrow**
The address (or contract) where a puzzle's prize sits, funded by the puzzle's own author, and
paid out to whoever produces the solution the puzzle asks for.

**oracle**
A small program that checks whether a candidate answer is correct by deriving the target
value from it and comparing to the known escrow address or value. It prints MATCH or NO
MATCH and nothing in between.

**witness**
A known-good input, of the same shape as what is being searched for, deliberately run through
a search or a check to confirm the check would actually catch a correct answer if one were
present. Used at the start, middle, and end of a search.

**BIP39**
The standard that turns a list of common words (a mnemonic, usually 12 or 24 words) into a
binary seed, by way of a checksum built into the last word or two and a password-stretching
function (PBKDF2). Most seed-phrase puzzles target a BIP39 mnemonic.

**BIP32**
The standard for deriving a whole tree of keys and addresses from one seed, using a
derivation path such as `m/0/0`.

**BIP38**
A standard for encrypting a single private key with a passphrase, producing a printable
encrypted key that only decrypts back to the original private key with that same passphrase.

**BIP44 / BIP49 / BIP84**
Standard derivation paths built on BIP32 for, respectively, legacy P2PKH addresses (BIP44),
P2SH-wrapped segwit addresses (BIP49), and native segwit (bech32) addresses (BIP84). The same
seed produces different addresses under each path, which is a common trap when checking a
puzzle's escrow.

**brainwallet**
A private key derived directly from a phrase or password by hashing it (typically SHA-256),
with no BIP39 wordlist or checksum involved.

**P2PKH / P2SH / P2WPKH**
Bitcoin output script types. P2PKH (pay to public key hash) is the original address format.
P2SH (pay to script hash) locks funds to the hash of a redeem script, which is only revealed
on spending. P2WPKH is the native segwit equivalent of P2PKH, using bech32 addresses.

**CLTV**
CHECKLOCKTIMEVERIFY: a Bitcoin script opcode that makes an output unspendable until a given
block height or timestamp, used to build time-locked puzzles.

**xpub**
An extended public key: lets anyone derive every public address in a BIP32 tree without
being able to spend from them. Used by some puzzle authors to publish "here is where the
prize addresses come from" without revealing which specific address holds funds.

**hash160**
RIPEMD160(SHA256(x)): the twenty-byte digest that Bitcoin addresses are built from. Comparing
candidate keys to a target address is fastest done on this raw twenty-byte value rather than
on the encoded address string.

**EC-multiply**
Elliptic-curve point multiplication: the step that turns a private key (a large integer) into
a public key (a point on the secp256k1 curve), the last cryptographic step before hashing to
an address.

**SSS**
Shamir's Secret Sharing: a scheme that splits a secret into several shares such that only a
minimum number of them (the threshold) can reconstruct it. Used by puzzles that distribute
partial key material across several channels or people.
