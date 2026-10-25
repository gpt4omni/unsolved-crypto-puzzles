# School of Bitcoin: 1 Million Sats In This Image (1,000,000 sats, [OPEN])

School of Bitcoin, the team behind a free online Bitcoin course, posted a puzzle image on
stacker.news in 2025 challenging readers to recover a BIP39 seed and claim 1,000,000 sats. The
image layers several decodable channels (two QR codes, a Morse-coded message, a Wingdings-coded
hint, and ten highlighted black characters), and the course site itself hides a bonus slide that
reveals the seed's first word, "abstract." The intended path locks further hints behind a KeePass
file protected by a memory-hard key derivation, but a faster bypass exists: assembling the
12-word seed directly from BIP39 words scattered across the card and the course. I confirmed the
first word and ruled out every reading of the card's own hints as a direct word list; the KeePass
file itself has been out of reach since it was pulled from the live site.

## At a glance

| | |
|---|---|
| Author | School of Bitcoin, [X](https://x.com/schoolofbitcoin) |
| Published | announced on [stacker.news](https://stacker.news/items/908283), 2025-03-09 |
| Prize | 1,000,000 sats (about $630 at BTC = $63,000, 2026-08-16) |
| Chain | bitcoin |
| Escrow | `bc1qcsdfkaqgy9ux668vmzflzqsyg0qtspncymt5ed` ([explorer](https://mempool.space/address/bc1qcsdfkaqgy9ux668vmzflzqsyg0qtspncymt5ed)) |
| Last on-chain check | 2026-10-24: re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | OPEN |
| Puzzle type | bip39-seed, image-stego, password-pages |
| Target format | BIP39 12 words, word 1 = "abstract", possible passphrase, BIP84 `m/84'/0'/0'/0/0` |
| Certified oracle | yes: `tools/oracle.py --selftest` (certified against the public BIP39/BIP84 test vector) |
| What remains | words 2 through 12; the KeePass passphrase content; both bypass and intended paths are open |
| Series | none |

## The puzzle as published

The puzzle image (stacker.news [item 908283](https://stacker.news/items/908283), posted by a
third party linking the author's own image at m.stacker.news/81280) encodes a blue QR code that
links directly to the mempool.space page for the escrow address, a Morse-coded message reading
"10 things needed for the address to see prize," and a Wingdings-coded hint reading "it is the
black characters you want," pointing to 10 highlighted characters on the card. On the course site,
schoolofbitcoin.com, a hidden bonus slide in lesson 1 leads through a redirect to a binary-encoded
overlay that decodes to: "You found a clue to the hidden treasure of 1 FULL BITCOIN! :) abstract."
A downloadable file, `whatisthepassphrase.kdbx`, was once served from the course site and has
since been removed; a community member obtained a copy before the removal but has not opened it.

## What is understood

### Mechanism

The target is a BIP39 12-word seed, first word "abstract," possibly with a BIP39 passphrase,
deriving to `m/84'/0'/0'/0/0`. Two paths lead there. The intended path opens the KeePass file
using a passphrase built from a rule the course itself teaches: a short nonsensical phrase, all
lowercase, letters joined without spaces, every "o" doubled, every "k" capitalized, with a
numeric suffix; the course's own source code confirms the suffix used for a Bitcoin-themed
passphrase is `##3`, distinct from the `##1` in the course's worked example. The file, at 2,613
bytes, is larger than a single answer and likely holds further hints rather than the prize
directly. The bypass path assembles the 12 words directly from BIP39 words visible on the card
and in the course, without needing the passphrase at all.

### Derivation and oracle

```
python3 tools/oracle.py --selftest
python3 tools/oracle.py "abstract w2 w3 ... w12"
python3 tools/oracle.py "abstract w2 w3 ... w12" --passphrase "..."
```

The oracle derives the first receiving address for a 12-word candidate under BIP44, BIP49 and
BIP84, account 0, with an optional passphrase, and compares each to the escrow address.

### Certified against

The oracle reproduces the public BIP39/BIP84 test vector (12 words, all-zero entropy) at
`m/84'/0'/0'/0/0`, reproduced 2026-08-16. No solved sibling of this puzzle exists.

### Established facts

1. Word 1 of the seed is "abstract," recovered from a hidden bonus slide in lesson 1 of the free
   course, reached through a slide-selector control not otherwise linked.
2. The blue QR code on the card decodes to the mempool.space page for the escrow address; the
   Morse and Wingdings channels both decode to instructions rather than seed words directly.
3. The `whatisthepassphrase.kdbx` file uses Argon2d with parameters that make each guess take
   about 5 seconds and give no meaningful GPU acceleration, so its passphrase must be reasoned
   out rather than searched for.
4. A full crawl of the course site (320-plus slides across 4 lesson tracks) found no further
   hidden slide beyond the known binary overlay, and no client-side validation logic anywhere.

## What has been tested

Full ledger in [analysis/tested.md](analysis/tested.md). Summary:

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| "abstract" plus the 11 other BIP39 words visible on the card, reading order, empty passphrase | 10,480 checksum-valid seeds | oracle, GPU-assisted | 0 match | yes: known-answer selftest planted for this target | 2026-07-22 |
| "abstract" plus course video-funnel words, multiple structural variants | several thousand | oracle | 0 match | yes: same certified oracle | 2026-07-22 |
| The 10 highlighted black characters, and 16 case/format variants, tested as the KeePass passphrase | 16 variants | KeePass header check | 0 match | yes: header-HMAC oracle self-verified | 2026-07-22 |
| Same string and variants, tested as a BIP39 seed passphrase | 167,680 derivations | oracle | 0 match | yes: same certified oracle | 2026-07-22 |
| 88 speech-bubble phrases from the card, run through the exact passphrase-construction rule | 88 candidates | KeePass header check | 0 match | yes: header-HMAC oracle self-verified | 2026-07-22 |

## Open leads, ranked

1. **Obtain the complete `whatisthepassphrase.kdbx` file and its passphrase** (needs a person).
   The file was removed from the live site and is absent from any archive; the only known path is
   contacting the community member who has a copy but never opened it, or the course author
   directly.
2. **A fresh reading of the remaining 11 seed words, not a re-run of card ordering or
   black-character brutes** (bounded, minutes to test once found). Both of those readings are
   exhausted; the card's own claim that "every clue needed is on this card" argues the missing
   piece is an unrecovered word source, not more search.

## Files in this folder

| Path | What it is |
|---|---|
| `clues/author-posts.md` | the puzzle image's decoded channels and the course clue quotes, with sources |
| `analysis/tested.md` | the complete negatives ledger |
| `analysis/leads.md` | full notes behind the ranked leads |
| `tools/oracle.py` | candidate checker, certified against the public BIP39/BIP84 test vector |

## Sources

- Puzzle announcement, stacker.news item 908283: https://stacker.news/items/908283
- School of Bitcoin course site: https://schoolofbitcoin.com/
- School of Bitcoin on X: https://x.com/schoolofbitcoin
