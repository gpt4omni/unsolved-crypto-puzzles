# Negatives ledger: Wealth in Poetry

Every row below is marked uncertified. The derivation code (BIP44/49/84, raw BIP32 paths, master
key, old Electrum) has no known-good acceptance test: no solved sibling of this puzzle exists,
and no synthetic seed-and-address pair was ever run through it to prove it would accept a correct
answer. Under this repository's own convention, these counts describe search coverage, not proven
exhaustion.

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| Numeric-key enumeration: coordinate formats (all conventions) across 20+ landmarks, in-article numbers, transforms, signed coordinates, multi-leg concatenated coordinates, across phone/GPS/cumulative/direct methods, 6 direct carriers plus 264 anchor-relative carriers, position and BIP39-index mapping, lengths 12 to 24, 0 or 1-based indexing | 541 numeric keys, about 300,000 derivations | address comparison, compressed and uncompressed | 0 match | uncertified | 2026-08-02 |
| Derivation-family sweep on the 4 clean example seeds (GPS, the broken WITCH example, PHONE, and one Electrum-v2 candidate): BIP44/49/84 multi-account, raw BIP32 paths, master key, old Electrum v1 and v2, both key compressions, plus wildcard on every seed position | about 500,000 addresses derived | address comparison | 0 match | uncertified | 2026-08-02 |
| Passphrase (25th word) sweep on the 4 clean seeds: 182 curated article-derived terms, full-phrase candidates including the null-cipher message and cross-seed phrases, brute-force over article words, BIP39 words and phrases, wildcard times passphrase | about 78,000 derivations | address comparison | 0 match | uncertified | 2026-08-02 |
| Structural and alternative readings: sliding-window BIP39 scan, old-Electrum scan, generalized nth-letter null-cipher, structural carriers (blockquotes, bold text, references section), Trithemius cipher and tabula recta | not individually logged | manual and automated scan | all negative | uncertified | 2026-08-02 |
| MHTML forensics: 33 MIME parts parsed byte by byte for appended data, hidden PNG/JPEG chunks, EXIF/XMP anomalies, zero-width characters, exploitable data attributes | 33 parts | byte-level parsing | no hidden channel found; EXIF/XMP show only Medium's own stock-photo credits | uncertified | 2026-08-02 |
| Image steganography on full-resolution originals pulled from the CDN | 11 images, up to 4448x2555 | LSB analysis on lossless formats | pure noise (bit ratio about 0.4995 to 0.5004), 0 WIF or hex64 strings recovered from any bit plane | uncertified | 2026-08-02 |
| Direct WIF/hex scan of the raw article file | 125 base58-like substrings matched | BIP38/WIF checksum check | 0 pass the checksum, all traced to base64-encoded image data | uncertified | 2026-08-02 |
| Stylometric steganalysis: token surprisal and contrastive substitution scoring across the full 2,360-word narrative (563 BIP39 words, 23.9 percent density) | full narrative | two transformer language models of different sizes, each scoring insertion likelihood | BIP39 words statistically indistinguishable from ordinary words; no detectable insertion fingerprint | uncertified | 2026-08-02 |

The structural constraint that the published GPS formula, applied to the full narrative, leaves 2
of 12 word slots with zero valid BIP39 options confirms the published example is a demonstration,
not the real key, independent of the oracle-certification question above.
