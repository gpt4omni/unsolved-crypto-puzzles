# Negatives ledger, RushWallet contest #30

Method for every row: candidate passphrase taken verbatim, SHA-256, uncompressed
secp256k1 public key, P2PKH address, compared byte-exact to `13Q8hJqagtd77ojTJcEZPjTz2sBFSsYxyj`.
Oracle certified against 3 known passphrase/address pairs from sibling brainwallets in the
same contest (`tools/oracle.py --selftest`), so zero false positives are possible: a match
can only be declared on exact address equality.

One caveat applies to every row below: the oracle itself is certified, but no known-good
passphrase was planted inside the actual corpus streams at head, middle and tail before
each run. That means these negatives are not witnessed in the strict sense of this
project's own standard; they are honestly reported as candidates consumed with 0 hits,
not as a certified-exhaustive sweep of each corpus.

| Hypothesis | Candidates | Result | Date |
|---|---|---|---|
| Structured passphrases built from the video/contest's own text (Dmitri phrase variants, whitepaper title and sections, KryptoKit slogans, Cicada/John Donne references, coin numbers, x2 to x6 repetitions, case variants) | about 3,000 | 0 match | 2026 (round 1-2) |
| rockyou.txt, 5 case variants each (as-is, lower, UPPER, Title, capitalized-first) | 14,344,391 lines to 37,523,253 candidates | 0 match | 2026 (round 2) |
| Dedicated brainwallet dictionaries: bitcoin-brainwallet.lst and milw0rm | 478,946 lines to 2,292,116 candidates | 0 match | 2026 (round 2) |
| Full King James Bible, one verse per line | 60,100 lines to 725,198 candidates | 0 match | 2026 (round 2) |
| Canonical-source exact windows (Bitcoin whitepaper, KryptoKit press release, John Donne's "Meditation XVII", the genesis-block text, name masks, repetition masks), case and punctuation preserved | 1,959,326 candidates | 0 match | 2026 (round 2) |
| Song lyrics, most-viewed 301,000-song slice of a genius-song-lyrics corpus | 12,000,079 lines to 52,299,649 candidates | 0 match | 2026 (round 3) |
| OCR text from video frames (original, RuTube, HQ and 720p sources) plus 20 community guesses from the BitcoinTalk thread | about 1,588 OCR lines plus 20 guesses, about 501,600 to 509,399 candidates with variants | 0 match | 2026 (round 3) |
| Quotes-500K corpus (huggingface `jstet/quotes-500k`, 499,709 quotes), 5 case variants (as-is, lower, UPPER, Title, capitalized-first) plus surface normalizations (strip, unquote, trailing-punctuation removal, attribution-dash removal, crossed with case variants) | 499,709 lines to 3,376,547 candidates | 0 match | 2026-08-22 (round 4) |

Cumulative: about 95 million candidates across the rounds above, `FOUND` list empty every
time.

Round 4 note (2026-08-22): unlike rounds 1-3, this round is WITNESSED. A fast sweeper
(`work-rushwallet30/fast_sweep.py`, coincurve + pycryptodome, h160 byte-compare) was first
validated against all three certification vectors plus the negative control, then the three
public sibling passphrases were planted at head, middle and tail of the actual stream and
all three were recovered through the same code path during the run (2.0M candidates in the
case-variant pass at ~103k/s on 12 cores; 3.38M cumulative with the normalization pass).
This upgrades the round-4 negative from "candidates consumed" to a certified exhaustive
sweep of the corpus-as-dumped, modulo the standard caveat that the corpus file replaces
embedded newlines with spaces.

## Media channels checked, not brute-forced

- QR codes across 443 video frames: 4 QR payloads decoded; one is the passphrase for a
  different, already-claimed puzzle (#19), the rest are dust/tip addresses. None is #30's.
- OCR across 4 video sources at up to 720p (221 + 370 + 116 + 443 frames): recovers known
  passphrases for other, already-solved puzzles in the contest (#16, #18, #20) when tested
  against their own addresses, so the OCR and text-recovery pipeline itself is shown
  working; it recovers nothing that solves #30 at this resolution.
- Audio: the Morse tone is a single 1000 Hz layer, no secondary DTMF signal, fully
  re-decoded from scratch; nothing further is extractable from the audio track itself.
- No video source above 720p is currently reachable: both known YouTube video IDs for the
  original upload are dead (`sr8lBrtd9U4`, `Mbu9dD8ahgE`); a Wayback Machine index lookup
  for the video content itself (not the page) returns no archived stream, only the HTML
  page.

## Explicitly demoted, not an open lead

- The Cicada 3301 references surrounding this contest (a rail-fence cipher fragment, a PGP
  signature, the number "3302"): the PGP signature uses a non-standard header, "3302" is
  not prime (unlike the real Cicada 3301 group's own use of 3301, which is), and an
  associated image circulated with this material was found to be fabricated. Treated as
  contest flavor, not a channel to search.
| Full genius-song-lyrics corpus tail plus re-test of the top slice (`Dr3dre/Genius-song-lyrics-cleaned`, about 5.1M songs; English-language filter, per-song line dedupe), case variants plus surface normalizations, checksum-free GPU brainwallet engine | 149,913,074 lyric lines from 3,374,198 English songs to 456,693,751 candidates | 0 match | 2026-08-23 (round 5) |

Round 5 note (2026-08-23): witnessed at both levels. Before the run, the GPU checker
(`engines/secp256k1_hash160_engine.cu`, stream mode) passed its built-in selftest (the
same 2 public sibling passphrases, through the identical kernel path used for candidates)
and an end-to-end positive control: with the target overridden to a known witness's
hash160, feeding that witness produced a MATCH. Coverage is proven by counter equality:
the engine consumed exactly the 456,693,751 candidates fed, on one rented L40S at a
sustained 13.78M/s (about $0.50). Scope limits, counted rather than hidden: 1,095,140
lyric lines longer than the engine's 180-byte input limit were skipped and counted;
non-English songs (about 11 percent of the corpus) were excluded by the dataset's
language field; duplicate lines within a song were collapsed before expansion.
