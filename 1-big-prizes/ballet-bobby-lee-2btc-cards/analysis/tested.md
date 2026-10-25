# Tested hypotheses, full ledger

Summary table is in the README. This file has the full detail behind each row.

## 1. Cross-card passphrase reuse

Hypothesis: the passphrase published for AA012381 (`594Y-L2RW-4ME7-2XVX-9B41`,
photo-confirmed legible on that card's scratch-off face) also decrypts AA009926's
exposed encrypted WIF (`6PnQmAyBky9ZXJyZBv9QSGRUXkKh9HfnVsZWPn4YtcwoKy5vufUgfA3Ld7`).

This is the only test that could actually be run: AA012381's own encrypted WIF is the
half that is missing on that card, so its passphrase cannot be tested against its own
address. Testing it cross-card, against AA009926, at least rules out passphrase reuse
across cards.

Method: `tools/oracle.py "<AA009926 encrypted WIF> <candidate> 1JxWyNrkgYvgsHu8hVQZqTXEB9RftRGP5m"`
for 5 candidate forms.

| Candidate passphrase form | Result |
|---|---|
| `594Y-L2RW-4ME7-2XVX-9B41` (as published) | NO MATCH |
| `594YL2RW4ME72XVX9B41` (no dashes) | NO MATCH |
| lowercase, with dashes | NO MATCH |
| lowercase, no dashes | NO MATCH |
| `335Y-K745-C8WT-4D2W-80WP` (the AA007448 oracle passphrase, as a control) | NO MATCH |

Result: 5 candidates tested, 0 match. Method: BIP38 EC-multiply decrypt then P2PKH
address compare, byte-exact. Witness: yes, the oracle certification vector (AA007448)
is re-derived correctly by the same code path in the same run (`tools/oracle.py --selftest`).
Rate: n/a, 5 candidates run individually. Date: 2026-08-16 (re-run from the private
research folder's 2026-06-17 result; identical outcome).

This negative has a fixed scope: it shows passphrases are not shared or derivable
between cards from these 5 forms, and is expected, since Ballet passphrases are
generated independently per card. It does not touch the residual space of either
card's own missing half.

## 2. Image forensics on the 4 published card photographs

Hypothesis: the hidden half of a card (AA009926's passphrase, AA012381's encrypted
WIF) leaked into the published photograph through EXIF metadata, an embedded file
appended to the JPEG, or a legible trace surviving under contrast enhancement.

Method: `exiftool` on all 4 files (`AA007448-puzzle.jpg`, `AA009926-puzzle.jpg`,
`AA009926-revealed.jpg`, `AA012381-puzzle.jpg`); `binwalk` plus a manual scan for
bytes trailing the JPEG end-of-image marker; region crops of the passphrase
scratch-off strip (AA009926) and the tamper-sticker panel (AA012381) with
autocontrast and 2 to 3x upscaling.

Result:
- `exiftool`: no GPS, comment, or maker-note secrets on any of the 4 files; only a
  camera ICC color profile.
- `binwalk` and the trailing-byte scan: 0 embedded files, 0 trailing bytes on any
  file. All 4 are plain JPEGs.
- Region crops: the hidden half of each card is physically on the face that was
  never photographed (see the two-face structure in the README). No reflection,
  residue, or thumbnail leak of the missing content was found on the photographed
  face of either card.

Scope: 0 of the 20 passphrase characters recoverable for AA009926; 0 of the 58
encrypted-WIF characters recoverable for AA012381. Witness: this check is a direct
observation on the 4 files (file sizes, exiftool output, binwalk output are each
independently reproducible by re-running the same command), not a search with a
possible false negative, so no separate witness input is needed. Date: 2026-06-17
(private research), file byte sizes re-verified 2026-08-16.

## 3. Later disclosure of passphrase characters or positions

Hypothesis: Bobby Lee or Ballet revealed additional passphrase characters, digit
positions, or hints in the years after the July 2020 announcement.

Method: read the official Ballet rules page, the original announcement tweet, a
follow-up tweet posted about 5 months later, and one participant write-up found
publicly.

Result: no specific characters or positions were ever given; the challenge terms are
unchanged since 2020 beyond noting that the prize value has grown with the bitcoin
price. Witness: n/a, this is a direct reading of the 3 named sources, not a search.
Date: 2026-06-17.

## 4. Ballet RNG or manufacturing weakness

Hypothesis: a published vulnerability disclosure, theft report, or manufacturing
defect narrows the passphrase entropy below its nominal ~100 bits.

Method: search for public vulnerability disclosures, theft reports, and WalletScrutiny
or similar third-party audits referencing Ballet REAL cards.

Result: none found. Ballet states the passphrase is generated from dice-roll entropy
in a Las Vegas facility, with manufacturing data destroyed after printing; no serial
number to passphrase correlation exists in the 2 known (serial, passphrase) pairs
(the serial digits do not appear as a substring of either passphrase). Witness: n/a,
absence-of-disclosure search. Date: 2026-06-17.

## 5. Raw brute force of the passphrase or the hidden encrypted WIF

Not run as a search; this is an arithmetic bound, not a swept space.

AA009926 (recover the passphrase): 5 groups of 4 characters from an alphabet of
approximately 32 symbols observed to include `0`, `1`, `L` and exclude `I`, `O`
(so it is not Crockford base32), giving about 100 bits (32^20 is approximately
1.27e30). Each guess costs one full scrypt computation (N=16384, r=8, p=8) to derive
the passfactor, plus one cheap elliptic-curve step. At an optimistic 1e6 scrypt
operations per second, exhausting this space would take more than 1e16 years.

AA012381 (recover the hidden encrypted WIF): even with the passphrase already known,
the EC-multiply private key needs `seedb`, a 24-byte (192-bit) value encrypted only
inside the missing back-face blob; recovering it blind is a 192-bit search, also not
compute-feasible.

Both bounds are stated as scope, not as a run: `bounded-compute` is not the
classification I give either card in `puzzle.json`; both are `external-info`.
