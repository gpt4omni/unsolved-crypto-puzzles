# Negatives ledger, cryptoArtGAN Act 1 puzzle

No checker for this puzzle is shipped in this folder (see the README): the candidate
generator and permutation sweeper that produced the counts below were run outside this
repository and are not included here in reproducible form. Every row is reported as
candidates consumed, with the calibration note stated once here rather than repeated per row.

Calibration note: the permutation sweeper used for these runs is reported to be calibrated
against a different, already-solved puzzle by the same artist ("Winter Solstice"), where it
returns exactly one hit, the real mnemonic, at the correct derivation path. I have not
personally reproduced that calibration inside this folder.

| Hypothesis | Scope | Volume | Result |
|---|---|---|---|
| "The 11 anomalies are the 11 rows with Type = Glitch" | `data/bitgans-attributes.csv` only | 513 rows | refuted for this table: Type = Glitch appears 67 times, not 11 (skullGAN 40, roboGAN 11, glitchGAN 8, cryptoGAN 4, whaleGAN 1, spookyGAN 1, bitGAN 1, xxxxxGAN 1); no split by sub-collection gives exactly 11 except the roboGAN rows, tested separately below. This table spans several series; the cryptoArtGAN / Act 1 series itself has only 8 rows in it, so this negative is scoped to the catalogue, not to the true 512-piece Act 1 series |
| About 50 candidate 11-word sets (essence word, BIP39 word at the token's index, BIP39 word at index minus 1, SLIP-39-to-BIP-39 index swap) across several orderings, 14 derivation paths, and all 128 checksum-valid 12th words | reported | about 22.5 million addresses derived | 0 match |
| 9 specific 11-word sets, each swept over all 11! = 39,916,800 orderings: the 11 Fibonacci-numbered bitGANs, the first 11 tokens numbered 445 to 512, the 11 roboGAN rows with Type = Glitch, the 11 misspelled "glitch" rows (1 "Gltich" plus 10 "G1itch"), and 11 anomalies from an on-chain "HiddenType" trait | reported | 9 x 39,916,800 orderings | 0 match |

## Structural facts, verified directly against the table in this folder

- The Essence column lists standard BIP39 words in alphabetical order across roughly the
  first 57 rows of the table, with exactly one break: the row numbered 21 ("Beanie
  skullGAN") carries the word "bean," out of order between "act" and "actor." This ordering
  does not hold across the rest of the table. Not yet used as a selection rule.
- The Type column contains 1 misspelling, "Gltich" (row numbered 73). The Title column
  separately contains 10 occurrences of "G1itch" as leetspeak, on 10 different roboGAN and
  cryptoGAN pieces, each with a binary-looking token number (for example "G1itch1ng roboGAN
  (000111)"). These 11 rows together are the "11 misspelled glitch rows" set in the table
  above: already swept over all 11! orderings, 0 hits.
