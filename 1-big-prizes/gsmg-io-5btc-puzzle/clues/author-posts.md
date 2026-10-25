# Author posts and quotes

The puzzle's author posts as "Jrk Bgrt" (handle `@SoWut`) inside a puzzle-specific
Telegram group; the group is not indexed at a stable public URL, so this file does
not quote it. What follows is the material that is verifiable at a public URL.

## GSMG.io, platform site

https://www.gsmg.io/

The platform presents itself as an automated crypto-trading service. The puzzle is
a separate, unpaid challenge hosted on the same domain; the escrow address was
first funded on 2019-04-13.

## bitcointalk topic 5532424, "Need help Puzzle GSMG.IO 5BTC"

https://bitcointalk.org/index.php?topic=5532424.0

Community discussion thread, active since 2025-02-18, including several solvers'
notes on the stage chain. Used here only to corroborate the public stage order, not
quoted directly.

## Reddit, r/bitcoinpuzzles

https://www.reddit.com/r/bitcoinpuzzles/comments/bf7siz/gsmgio_5_btc_puzzle_challenge/

https://www.reddit.com/r/bitcoinpuzzles/comments/dfwcqk/gsmgio_5_btc_puzzle/

Two community discussion threads, also linked from the community repository below.

## Community repository

https://github.com/puzzlehunt/gsmgio-5btc-puzzle

A community-maintained repository documenting the solved stages, referenced here
for the public stage-chain order (see `data/stage-chain.json`). Not mirrored in
this folder; consult it directly for the community's own write-ups.

## The Phase 2 and Phase 3 page, archived 2020-11-12

https://web.archive.org/web/20201112015439/https://gsmg.io/choiceisanillusioncreatedbetweenthosewithpowerandthosewithoutaveryspecialdessertiwroteitmyself

The page that follows the phase 1 verification (its URL is a line of the Merovingian's
from The Matrix Reloaded, all lowercase, no spaces) states the cipher convention in
the creator's words:

> "Ciphered with aes-256-cbc /w base64 sha-256(password)"

> "parts 1..7 -> sha-256 -> dgst is the password"

## Messages the creator wrote on chain

From the vanity wallet `3GSMG24TujqfMJG1kQoBX18DzJHQLeJYMK`, as `OP_RETURN` outputs of
the transactions that funded planted addresses (dates are block dates; see
`data/planted-addresses.csv` for the addresses and their verified preimages):

- 2020-03-24: "GSMG.io: are you sure?", "GSMG.io: Right, this is causality", "GSMG.io:
  You are here because 227 chars were correct", "GSMG.io: phase3.2 pass OK", "GSMG.io:
  part of the cipher", "GSMG.io: do you beleive me you need it?" (spelling as written).
- 2020-04-03: "Good job, Neo!", twice, for the raw and the bit-reversed image URL.
- 2020-04-07: an address funded with no message; no preimage known.
- 2020-05-11, block 630,001: "Halving", with a 700-satoshi output to the prize address
  that the 2.5 BTC split spends (README, "The puzzle as published").
- 2021-07-18: "GSMG.io neighbors, half and double", paying the uncompressed addresses
  of 2P, P/2, P+G and P-G for the prize public key P.

## The puzzle's own published page content

The final page (reached after "the Architect Choice" stage) publishes its content
directly in the page body: a sequence of 1075 single-character tokens, an
image, and a base64-encoded block. This folder quotes only the two short strings
that are the deterministic decoding of that published content, not an
interpretation: `matrixsumlist` and `ourfirsthintisyourlastcommand` (see
"What is understood / Mechanism" in the README for how each is decoded). The
128-character base64 blob is reproduced in `tools/oracle.py` because it is itself
the object the final gate is built on.
