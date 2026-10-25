# Tested (full negatives ledger)

The summary table in `README.md` shows the highlights; this file is the complete record.
Every row checks candidate passphrases against the fixed 24-word mnemonic under BIP84
`m/84'/0'/0'/0/0`, empty change and index 0, using `tools/oracle.py`'s derivation. Witness
for every row below: a control passphrase (`control_test_pw_42`) was planted in the same
engine run, recovered by the GPU pass, and independently reproduced by a second, separate
tool (btcrecover) on a subset of the corpus. The position of the control within each run
was not separately logged (no head/middle/tail triad recorded), so by this repository's
own standard this is a well-instrumented negative, not a formally exhaustive one.

| Hypothesis | Space (N) | Method | Result | Witness | Rate | Date |
|---|---|---|---|---|---|---|
| Author's own bundled wordlists (skullsecurity, as referenced in his own hints) | 705,613 | CPU derivation, BIP84 index 0 | 0 match | yes: control passphrase recovered | 12,700/s on CPU | 2026-06-13 |
| rockyou.txt raw | 14,343,467 | GPU derivation | 0 match | yes | 315,000/s on a rented GPU | 2026-06-13 |
| rockyou.txt with best64 mangling rules | 1,104,459,484 | GPU derivation | 0 match | yes | 690,000/s on a rented GPU | 2026-06-13 |
| Corey-specific corpus (108 words mined from his Medium articles, GitHub, and employer), raw plus 8 rule sets (best64, leetspeak, T0XlC, toggles3, rockyou-30000, OneRuleToRuleThemAll, d3ad0ne, dive) | 23,735,781 | GPU derivation | 0 match | yes | 690,000/s on a rented GPU | 2026-06-13 |
| Corey in-joke phrases (taglines from his articles), raw plus best64 and OneRuleToRuleThemAll | 2,808,334 | GPU derivation | 0 match | yes | 690,000/s on a rented GPU | 2026-06-13 |
| Two-word thematic combinator, 35 curated words, 6 join styles (none, space, underscore, dash, camelCase, PascalCase) | 7,350 | GPU derivation | 0 match | yes | 690,000/s on a rented GPU | 2026-06-13 |
| Human password lists: probable-v2-top12000, darkweb2017-top10k, xato-top-1M, ncsc-100k, raw and with best64 | 8,967,534 | GPU derivation | 0 match | yes | 690,000/s on a rented GPU | 2026-06-13 |
| Famous quotes plus the full BIP39 wordlist as a single-word passphrase | 29,201 | GPU derivation | 0 match | yes | 690,000/s on a rented GPU | 2026-06-13 |
| The decoded audio-puzzle message ("i am 24 words long and found on path 84") and 32 minimal variants (case, punctuation, spacing, spelled-out path) | 32 | GPU derivation | 0 match | yes | 690,000/s on a rented GPU | 2026-06-13 |
| Alternate BIP84 index paths (change/index 0/1, 1/0, 1'/0/0, 0/2) replayed on the Corey-specific corpus | 432 | GPU derivation | 0 match | yes | 690,000/s on a rented GPU | 2026-06-13 |
| Independent cross-check with a second, separate tool (btcrecover) on the Corey-specific corpus and combinator | 7,454 | CPU, btcrecover | 0 match | yes: recovers the same planted control | 1,000/s on CPU | 2026-06-13 |

Cumulative: 1,155,064,682 candidates tested, 0 matches, across 11 families.

## Other channels checked, not passphrase sweeps

- **Steganography in `clues/kitten.jpeg`**: checked with exiftool (clean metadata),
  binwalk (finds only the JPEG structure, no appended data), and `strings` (compression
  noise only). The image is confirmed to be purely the entropy source for the fixed
  mnemonic; nothing else is hidden in it. Date: 2026-06-13.
- **"Part 3 of 3" of the author's article series**: does not exist. His Medium index lists
  exactly 4 posts (Bitbip, Part 1, the audio puzzle, Part 2) and nothing further, so there
  is no undiscovered article to mine for a passphrase hint. Date: 2026-06-13.
- **The author's separate "Bitcoin Audio Puzzle"**: fully decoded (FSK tones at 1080 and
  1260 Hz, demodulated with minimodem, yielding a Bitcoin transaction with an OP_RETURN
  message). The message describes a 24-word seed on BIP84, the same structure as this
  puzzle, but is not itself a usable passphrase (tested as one above, row 9).
