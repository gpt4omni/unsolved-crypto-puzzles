# Zden Level HALV (312,500 sats, [OPEN])

Zden (Zdenek Haluska), whose earlier puzzle LVL.5 is documented elsewhere in this repository,
published Level HALV on 2024-04-20, the day of Bitcoin's fourth halving: a single grayscale
image of an oscilloscope-style waveform, with a private key encoded somewhere in its 59
oscillating lobes. I measured the geometry stably across 3 independent passes: lobe count,
each lobe's shape (circle or diamond), and the amplitude pattern. Every specific reading of
that geometry I have tried, including a 500-million-derivation checksum sweep, has produced
zero matches. The image's own measured information content, about 118 bits, falls short of
the 256 bits a private key needs: the identified gap is that limit, not a lack of search
effort, and no hint has been published for this specific puzzle, unlike every other long-open
puzzle in the
same series.

## At a glance

| | |
|---|---|
| Author | Zden (Zdenek Haluska), [crypto.haluska.sk](https://crypto.haluska.sk/), [@Zd3N on X](https://twitter.com/Zd3N) |
| Published | 2024-04-20 ([tweet](https://twitter.com/Zd3N/status/1781475361160663236)) |
| Prize | 312,500 sats (about $197 at BTC = $63,000, 2026-08-16) |
| Chain | bitcoin |
| Escrow | `1crypto24HCr178iMcKd5iUi5D4rsg1nK` ([explorer](https://mempool.space/address/1crypto24HCr178iMcKd5iUi5D4rsg1nK)) |
| Last on-chain check | 2026-10-24: re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | OPEN |
| Puzzle type | geometry, raw-private-key |
| Target format | a 256-bit private key as direct hex, P2PKH |
| Certified oracle | yes: `tools/oracle.py --selftest` (certified against a standard public vector, private key 1; the puzzle's own waveform reading is not certified, see below) |
| What remains | an author hint (none published yet for this specific puzzle) or a richer reading of the image than the geometry currently supports |
| Series | Zden's crypto.haluska.sk puzzle series (LVL5, LTC, Codex, Demobit, Janus and others) |

## The puzzle as published

The puzzle is a single image, `cryptoHALV.png`, posted 2024-04-20: "Level HALV - my new
crypto puzzle to celebrate the fourth Bitcoin Halving." The same post, on the author's own
site, adds: "This level is way easier than LVL 5. It shouldn't take long until it's solved."
Unlike every other long-open puzzle in the same series, no follow-up hint has ever been
published for HALV specifically. Full quotes with links are in
[clues/author-posts.md](clues/author-posts.md).

## What is understood

### Mechanism

The image is a sampled waveform of 59 oscillating lobes. Each lobe carries one clean,
measured channel: its apex shape, either a circle (wide, rounded tip) or a diamond (narrow,
pointed tip), measured by the width of the apex itself, a feature that stays constant
regardless of the lobe's amplitude. Read left to right this gives a stable 59-symbol
sequence, reproduced identically across 3 independent measurement passes:
`DODDODDDDDOODDDOODDDDDDDDDDDDDODOODODOOODDDDDOODDDDDODDDODO`
(`data/lobe-shape-sequence.csv`). The waveform's amplitude follows a fixed pattern tied
directly to the halving theme itself (it halves every 8 lobes), so it carries no independent
information beyond what the theme already implies. No color, angle or sign channel is present
in this image, unlike some of the author's other puzzles in the same series. The measured
information capacity of the image, combining the shape channel with what little independent
signal the amplitude progression carries, is about 118 bits, against the 256 bits a private
key needs.

### Derivation and oracle

```
python3 tools/oracle.py --selftest
python3 tools/oracle.py "<64 hex chars>"
```

`MATCH <address> (<compressed|uncompressed>)` on a hit, `NO MATCH` otherwise, exit 0 or 1.
This oracle checks a finished 32-byte key candidate against the escrow; it does not implement
the still-open waveform-to-key reading itself.

### Certified against

`tools/oracle.py --selftest` reproduces the address for private key 1 (the generator point),
a standard vector reproduced in Bitcoin educational material, unrelated to this puzzle. This
certifies the derivation pipeline (secp256k1, hash160, base58check) used by the oracle.

### Established facts

1. I confirmed the escrow is funded and unspent as of 2026-08-16 (checked via
   [mempool.space](https://mempool.space)), from a single funding transaction on 2024-04-18.
2. I found the published image pixel-identical across every known hosting location, and no
   source image larger than the published one (950 by 950 pixels) anywhere.
3. All 59 rendered lobe strokes peak at the same pixel value in this monochrome image,
   confirming there is no separate color, angle or sign channel to read.

## What has been tested

Full ledger in [analysis/tested.md](analysis/tested.md). Summary:

| Hypothesis | Volume | Result |
|---|---|---|
| The shape sequence itself is the key, under 8 encodings | 202 derivations | 0 match |
| The halving-step value carries data, 7 numeric bases | about 47 derivations | 0 match |
| Puzzle-themed brainwallet phrases | about 110 phrases | 0 match |
| A convention borrowed from an earlier solved puzzle in the series | 12 candidate streams | 0 printable output |
| 1-symbol wildcard against the WIF checksum | over 500 million derivations | 0 valid WIF |

All of the above predate this folder's certified oracle; every row is reported as candidates
consumed, not as a witnessed negative in this project's strict sense.

## Open leads, ranked

1. **A hint published by the author** (needs a person). Every other long-open puzzle in this
   series eventually received one; HALV has not. Full details in
   [analysis/leads.md](analysis/leads.md).
2. **Certify the oracle with a known-good vector** (minutes; done in this folder already).

## Files in this folder

| Path | What it is |
|---|---|
| `clues/cryptoHALV.png` | the puzzle image as published, byte-exact |
| `clues/author-posts.md` | dated quotes from the announcement, with links |
| `data/lobe-shape-sequence.csv` | the measured circle/diamond reading for all 59 lobes |
| `analysis/tested.md` | the complete negatives ledger |
| `analysis/leads.md` | full notes behind the 2 ranked leads |
| `tools/oracle.py` | candidate checker, certified against a standard public vector |

## Sources

- Zden, original announcement, X, 2024-04-20: https://twitter.com/Zd3N/status/1781475361160663236
- Zden's puzzle site: https://crypto.haluska.sk/
