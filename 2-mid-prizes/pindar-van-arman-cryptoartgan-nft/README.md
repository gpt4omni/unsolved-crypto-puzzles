# Pindar Van Arman: cryptoArtGAN Act 1 Puzzle (1 NFT, [OPEN])

Pindar Van Arman, a generative-art painting-robot artist, announced in February 2022 that
the last piece of his "Act 1" NFT series had "disappeared into a mystery wallet," secured by
a BIP39 seed phrase he described in exactly 2 sentences. I confirmed the wallet has never
signed a transaction and still holds the prize NFT. The mechanism is standard (a 12-word seed
derives an Ethereum address, compared exactly to the wallet); what is genuinely unknown is
which 11 of the artist's own published words are the "glitches" the clue refers to, and in
what order. I have checked about 22.5 million addresses and 9 fully-ordered 11-word candidate
sets against the wallet, with zero matches, and read the artist's own published attribute
table for this puzzle's series closely. The code that produced that search does not live in
this folder today and I did not rewrite it for this write-up; see "Derivation and oracle"
below for how to verify a candidate directly.

## At a glance

| | |
|---|---|
| Author | Pindar Van Arman, [bitgans.com](https://bitgans.com/) |
| Published | 2022-02-05, artist's own site ([announcement](https://bitgans.com/news/cryptoartgans)); restated on X 2022-08-25 |
| Prize | 1 NFT, "Magic Internet moneyGAN" (445/512), no cash value recorded |
| Chain | ethereum |
| Escrow | `0x18f87ec9c527aba1db44f715456bf28b0dae478d` ([explorer](https://etherscan.io/address/0x18f87ec9c527aba1db44f715456bf28b0dae478d)) |
| Last on-chain check | 2026-10-24: re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | OPEN |
| Puzzle type | bip39-seed, word-selection |
| Target format | BIP39 12 words (English), standard Ethereum derivation, no passphrase stated |
| Certified oracle | no certified oracle in this folder; the generator and permutation sweeper used for the negatives below ran outside this repository and are not included here. A candidate is verified by deriving its address with any standard BIP39/Ethereum tool and comparing it to the escrow address above |
| What remains | which 11 of the artist's published words are the "glitches," and their order; the checksum fixes the 12th word to 1 of 128 values once the other 11 are set |
| Series | Van Arman's bitGANs / cryptoArtGAN wallet-puzzle system; at least one earlier puzzle in the same system, "Winter Solstice," is solved |

## The puzzle as published

The announcement, on the artist's own site and restated on X, states the entire public clue
in 2 sentences: "The seed phrase is 11 glitches ending with a random word," and "everyone has
been looking for glitches all wrong." The artist adds that only one clue will ever be given
for this puzzle, "even if it takes over a year." Full quotes with links are in
[clues/author-posts.md](clues/author-posts.md).

## What is understood

### Mechanism

The wallet's seed is a standard 12-word BIP39 mnemonic: 11 words that are, in some sense,
"glitches," plus a 12th word the artist calls "random," which the BIP39 checksum in fact
narrows to 128 possible values once the first 11 words and their order are fixed. The
standard Ethereum derivation from that seed must reproduce the escrow address exactly. On an
already-solved puzzle from the same wallet system, the artist's own solution notes state that
token attributes are indexed into the SLIP-0039 wordlist and map one-to-one, by index, onto
the BIP-39 wordlist: a documented transform from this same artist, reusable here as one of
several candidate readings for what a "glitch" word actually is.

### Derivation and oracle

No certified oracle is shipped in this folder: the generator and permutation sweeper that
produced the negatives below were run outside this repository, and porting them was not
straightforward enough to certify here. A candidate can still be verified independently with
any standard BIP39 derivation tool: derive the 12-word mnemonic to its Ethereum address and
compare it, as an exact string, to `0x18f87ec9c527aba1db44f715456bf28b0dae478d`. That exact
string comparison is the oracle for this puzzle.

### Certified against

Not applicable; no oracle ships in this folder.

### Established facts

1. I confirmed today, 2026-08-16, via a public Ethereum RPC endpoint, that the wallet holds
   0 ETH, has nonce 0 (it has never signed any transaction), and holds exactly 1 of the prize
   NFT via `balanceOf` on the token contract.
2. The wallet received the NFT in a single inbound transfer from the artist on 2022-02-05 and
   has had no other activity since.
3. I checked `data/bitgans-attributes.csv`, a 513-row table transcribed from the artist's own
   published journal, directly: it spans several of his NFT series, and only 8 of its 513
   rows belong to the cryptoArtGAN / Act 1 series that holds this puzzle's prize, so any count
   taken from the full table is scoped to the wider catalogue, not to the 512-piece Act 1
   series on its own.

## What has been tested

Full ledger in [analysis/tested.md](analysis/tested.md). Summary:

| Hypothesis | Scope | Volume | Result |
|---|---|---|---|
| The 11 anomalies are the rows with Type = Glitch | full 513-row table | 513 rows | refuted for this table: 67 rows, not 11 |
| About 50 candidate 11-word sets across several transforms, orderings and paths | reported | about 22.5 million addresses | 0 match |
| 9 specific 11-word sets, each fully ordered | reported | 9 x 39,916,800 orderings | 0 match |

## Open leads, ranked

1. **Frame-by-frame analysis of the artist's "Act 1 - Review" archive on Arweave** (hours of
   work). The one channel not yet touched by any metadata search; the artist has separately
   described a "glitch" as a real visual artifact on prime-numbered pieces. Full details in
   [analysis/leads.md](analysis/leads.md).
2. **Finish the on-chain metadata sweep** (bounded). About 132 token indices between 1 and
   700 return 404 under an assumption that may not hold for every piece in the series.
3. **A bounded 11! x 128 sweep once a specific 11-word set is argued for** (about 59 hours on
   24 CPU cores, reported). A proposal for a specific candidate, not a blind search.

## Files in this folder

| Path | What it is |
|---|---|
| `clues/author-posts.md` | dated quotes from the announcement and a related solved puzzle, with links |
| `data/bitgans-attributes.csv` | the artist's own published attribute table, 513 rows across several series |
| `analysis/tested.md` | the complete negatives ledger |
| `analysis/leads.md` | full notes behind the 3 ranked leads |

## Sources

- Pindar Van Arman, artist site: https://bitgans.com/
- cryptoArtGAN announcement: https://bitgans.com/news/cryptoartgans
- Restated on X, 2022-08-25: https://x.com/VanArman/status/1562799956175757313
- "BIP39 and bitGANs" journal entry: https://bitgans.com/journal/page014
