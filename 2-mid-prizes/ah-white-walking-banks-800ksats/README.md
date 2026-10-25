# AH White: Walking Banks (800,000 sats, [OPEN])

AH White self-published the bitcoin thriller novel "Walking Banks" in 2024 and hid a real
24-word BIP39 seed phrase inside the story. Starting in 2025 she announced the hunt on Nostr:
find the words in the book, and the first person to reconstruct the seed keeps the 800,000 sats
locked in the wallet. The book encodes seed words as a genetic-code passage read through an
in-story decoding rule; I confirmed the mechanism and recovered 4 of the 24 words from the one
passage the book prints in full. The other 20 words are not present anywhere in the text I could
mine mechanically. I re-verified the escrow on-chain and it remains untouched two years later,
most likely because the author published the wrong wallet type on her own site.

## At a glance

| | |
|---|---|
| Author | AH White, [Nostr](https://njump.me/npub1c2rvx6ue9uewl452kczcfxz9w242sfzn64ul8dv2afd3t5dpktzs0kmmvf) |
| Published | 2024, novel "Walking Banks"; hunt announced on Nostr from 2025-05 |
| Prize | 800,000 sats (about $504 at BTC = $63,000, 2026-08-16) |
| Chain | bitcoin |
| Escrow | `bc1qxy4tf0s4n7x9w24rawf9qsxh2hyljrmvyrhwzt` ([explorer](https://mempool.space/address/bc1qxy4tf0s4n7x9w24rawf9qsxh2hyljrmvyrhwzt)), 100,000 sats, and `bc1q4qc24xk5cehc4t7vr264zldsms2kmxf86jqjau` ([explorer](https://mempool.space/address/bc1q4qc24xk5cehc4t7vr264zldsms2kmxf86jqjau)), 700,000 sats |
| Last on-chain check | 2026-10-24: re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | OPEN |
| Puzzle type | bip39-seed, book, text-cipher |
| Target format | BIP39 24 words, English, empty passphrase, account key matching the author's published xpub (native SegWit, BIP84) |
| Certified oracle | yes: `tools/oracle.py --selftest` (certified against the published xpub's own known addresses and the public BIP39 test vector) |
| What remains | 20 of 24 words: not found by any mechanical reading of the published text |
| Series | none |

## The puzzle as published

The author's Nostr announcement (2025-05, [profile](https://njump.me/npub1c2rvx6ue9uewl452kczcfxz9w242sfzn64ul8dv2afd3t5dpktzs0kmmvf)):
"If your up for a treasure hunt, the book contains a real Bitcoin seed phrase hidden within the
story. So if you can piece the right string of words together, it leads to a wallet with 800000
sats in it. No funny business, all real. The first one to figure it out gets the bitcoin." A
follow-up the same month fixed the length: "It's 24 words." In 2026-03-16 she added: "the book
contains the words to a 24-word seed phrase in the right order," and earlier, in 2025-11-21: "Did
you know that word repetitions are actually allowed in a seed phrase?" No further clue has
appeared since the 2026-03-16 post.

The book itself carries the mechanism in a genetic-code passage in chapter 11 (page 128):
```
xiiithirdiiicrystaliiismalliiiadviceiiireflectxxxxxxcrystaliiismalliiiadviceiiireflectxxxxxxcrystaliiismalliiiadviceiiireflectiiithirdiiix
```
followed by in-story dialogue explaining the reading rule: the ordinal ("third") is the group's
position label, repeated twice; the four words that follow it, repeated three times, are the
payload for that position group.

The author also complained publicly that her own wallet appeared empty on a block explorer:
"I don't think it has been discovered because there are no transaction connected to the address
for some reasons (also not my original transactions to 'load up')." She had published only the
xpub, and most explorers derive legacy addresses from an xpub by default, which do show empty;
the funds are native SegWit.

## What is understood

### Mechanism

The novel's plot has a killer harvesting one organ from each of six victims. Each organ carries
a genetic intron whose translation follows the pattern in chapter 11: a value repeated twice
labels the position group (1 to 6), and a word repeated three times is the payload. Six groups
of four words make the 24-word seed. Only one group is printed as a full decodable block: group
3, seed positions 9 to 12, reads `crystal small advice reflect` (order fixed by the ordinal
label in the passage).

### Derivation and oracle

The author published the wallet's account-level xpub rather than an address. A candidate is a
24-word mnemonic; I derive its account-0 extended key under BIP84, BIP44, BIP49 and BIP86 (empty
passphrase) and compare the compressed public key and chain code, byte for byte, to the
published xpub. A match at the account level guarantees a match on every address the wallet can
produce.

```
python3 tools/oracle.py --selftest
python3 tools/oracle.py "word1 word2 ... word24"
```

### Certified against

The selftest confirms the published xpub derives both known treasure addresses at child indexes
0/0 and 0/1 in P2WPKH, and reproduces the account key for the public 24-word BIP39 test vector
(all-zero entropy, checksum word "art"), reproduced 2026-08-16.

### Established facts

1. The escrow is split across two P2WPKH addresses on one account xpub, 100,000 and 700,000
   sats, both unspent as of 2026-08-16.
2. Reading the published xpub as legacy P2PKH, the default on most explorers, shows an empty
   wallet; this is very likely why the prize went unclaimed for two years.
3. Only one of the six organ-donor groups is printed as a decodable block in the text: group 3,
   `crystal small advice reflect` (seed positions 9 to 12).
4. Diffing the free PDF, the walkingbanks.com site text, and the audiobook narration (25 tracks,
   transcribed) shows the same underlying text in all three, so there is no separate hidden
   edition to search; the book's own narrative also interrupts the harvest pattern, since the
   surgeon is shot partway through the list of recipients and two victims are never named.

## What has been tested

Full ledger in [analysis/tested.md](analysis/tested.md). Summary:

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| Other 20+ letter concatenated blocks like the chapter 11 pattern, across the full book (OCR + text layer) | whole book | string search | only the known block found | yes: the known block is the search target | 2026-08-15 |
| Typographic marking (italics, bold, font, color, offset) across all 87 embedded PDF font subsets | full span data | font/style diff | no signal beyond the known block | yes: known block recovered | 2026-08-15 |
| Acrostics: line, paragraph, sentence initials and finals, words 5+ letters | 5,998 lines, about 60,000 words | oracle-checked BIP39 word extraction | noise-level hits only | yes: oracle certified | 2026-08-15 |
| Seed reconstruction from repeats/permutations/rotations of the known group-3 words alone | all orderings | oracle, BIP39 checksum filter | 0 checksum-valid match | yes: oracle certified | 2026-08-15 |
| "One word per section" (25 sections), 52 selectors times 2 splitting schemes, plus a full reread of the book and 530 Nostr events | 104 candidate readings, whole book, whole Nostr history | oracle plus manual review | 0 valid matches, no further words recovered | yes: oracle certified | 2026-08-15 |

## Open leads, ranked

1. **Write to the author** (needs a person, minutes). She is active and responsive on Nostr and
   Reddit, has promised more hints "from time to time," and has a public contact address,
   `walkingbanks@protonmail.com`, listed on her own site. A neutral question about whether all 24
   words are printed in the free edition is likely to get a direct answer.
2. **Keep watching her Nostr feed** (cost: minutes per check). Any new hint narrows the search
   immediately; feed it straight into the oracle above.
3. **If 20 of 24 words become known some other way**, the remaining 4 are within reach of a GPU
   search: 2048 to the 4th power, divided by 16 for the checksum filter, is about 6.9e10
   combinations.

## Files in this folder

| Path | What it is |
|---|---|
| `clues/author-posts.md` | dated, verbatim Nostr quotes and the chapter 11 decoded passage |
| `analysis/tested.md` | the complete negatives ledger |
| `analysis/leads.md` | full notes behind the ranked leads |
| `tools/oracle.py` | candidate checker, certified against the published xpub and the public BIP39 test vector |

## Sources

- AH White, Nostr profile: https://njump.me/npub1c2rvx6ue9uewl452kczcfxz9w242sfzn64ul8dv2afd3t5dpktzs0kmmvf
- "Walking Banks" official site, "Find the Treasure" section: https://walkingbanks.com
- Escrow address 1: https://mempool.space/address/bc1qxy4tf0s4n7x9w24rawf9qsxh2hyljrmvyrhwzt
- Escrow address 2: https://mempool.space/address/bc1q4qc24xk5cehc4t7vr264zldsms2kmxf86jqjau
