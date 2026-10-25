# Open leads: School of Bitcoin

## 1. Obtain the complete whatisthepassphrase.kdbx file and its passphrase (needs a person)

The file was removed from the live course site and is absent from GitHub, the Wayback Machine,
and the original stacker.news thread. One community member is known to have obtained a copy
before it was pulled, but has not opened it themselves. Reaching that person, or the course
author directly, is the only known path to the file's contents; brute-forcing the Argon2d key
derivation is not viable at roughly 5 seconds per guess with no GPU acceleration. This is ranked
first because it is the intended path and the one most likely to also confirm or correct the
bypass path below.

## 2. A fresh reading of the remaining 11 seed words (bounded once a source is found)

Both exhaustive readings tried so far, card-word ordering and the black-character selector, are
negative and should not be repeated. The card's own Wingdings message insists "every clue needed
is on this card," which argues the missing piece is an unrecovered word source on the card or in
the course rather than more search over the same material. Once a credible new word source is
identified, checking it against the oracle takes minutes: the derivation itself is fast, and the
BIP39 checksum filter narrows any ordering search sharply before the address comparison.
