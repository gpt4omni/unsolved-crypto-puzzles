# Negatives ledger: School of Bitcoin

All rows below use the certified oracle (`tools/oracle.py`, certified against the public
BIP39/BIP84 test vector) or the KeePass header-HMAC check (self-verified against the file's own
Argon2d header parameters).

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| "abstract" plus the 11 other BIP39-valid words visible on the card, in reading order, empty passphrase | 10,480 checksum-valid seeds | oracle, GPU-assisted derivation | 0 match | yes: known-answer selftest planted for this target | 2026-07-22 |
| "abstract" plus course video-funnel words (aware, interest, consider, trial, satisfy, loyal), multiple structural variants: funnel at start/end/reversed, "abstract" moved to position 12, funnel without "abstract" | several thousand combinations | oracle | 0 match | yes: same certified oracle | 2026-07-22 |
| The 10 highlighted black characters from the card, plus 16 case and format variants | 16 variants | KeePass header-HMAC check | 0 match | yes: header oracle self-verified against the file's own Argon2d parameters | 2026-07-22 |
| Same string and variants, tested as a BIP39 seed passphrase against "abstract" plus the 11 card words | 167,680 derivations | oracle | 0 match | yes: same certified oracle | 2026-07-22 |
| 88 speech-bubble phrases read directly from the card, run through the exact passphrase-construction rule taught by the course | 88 candidates | KeePass header-HMAC check | 0 match | yes: header oracle self-verified | 2026-07-22 |
| Black-glyph-as-word-selector: pixel-measured position of each of the 10 highlighted characters against the card's word layout | 10 glyphs checked | direct pixel measurement | only 2 of 10 glyphs anchor precisely to a specific word; ruled out as a clean 10-word selector | uncertified (manual measurement, not an oracle run) | 2026-07-22 |
| Full course-site crawl: every slide manifest across 4 lesson tracks (root, money, bitcoin, your-first-bitcoin), about 320 slides total | full site | systematic crawl | no additional hidden slide found beyond the known binary overlay; no client-side validation logic found anywhere | uncertified (crawl completeness check, not an oracle run) | 2026-07-22 |

Cumulative: 1 of 12 seed words confirmed ("abstract"); no candidate assembled from the card or
course content has matched either the escrow address or the KeePass file.
