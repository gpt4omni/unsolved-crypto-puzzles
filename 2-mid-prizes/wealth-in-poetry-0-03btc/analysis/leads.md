# Open leads: Wealth in Poetry

## 1. Read the cipher table on the embedded Steganographia photo (hours)

The article embeds a high-resolution photograph (4448x2555) of the title page of Trithemius's
own historical book, Steganographia, shelfmark Jesus College M.7.7. The real Steganographia
contains genuine cipher tables, including tabula recta constructions, and the page the author
chose to photograph is legible enough to potentially read a table from directly. The author
published this image as illustration without flagging it as a candidate key, but it is the one
artifact in the article not yet tested as a numeric-key source, and it fits the pseudonym's own
theme closely enough to be worth the read. Confirmed if a table extracted this way, run through
the calibrated tokenization and any standard derivation, reproduces the escrow address; killed if
the table yields no valid-checksum 12-word phrase after a reasonable range of readings.

## 2. Rule out an old-Electrum (non-BIP39) wallet (hours)

If the real wallet predates BIP39 and uses an old-Electrum seed instead, the large body of
BIP39-based derivation work to date, including all 3 major campaigns in analysis/tested.md, is
off-target even with the correct words and the correct key. Electrum-format derivation scripts
already exist and would need to be re-run against the same 4 example seeds and against any
candidate words the numeric-key work produces.

## 3. Build a certified acceptance test for the derivation code (minutes)

No known-good seed-and-address pair has ever been run through the derivation library to prove it
accepts a correct candidate. Since no solved sibling of this puzzle exists, the fastest fix is a
synthetic test: build a throwaway 12-word phrase, derive its address under each supported path,
then assert the library recognizes that address as a match. This would let every negative above
be re-labeled from uncertified to certified without rerunning any of the underlying search.
