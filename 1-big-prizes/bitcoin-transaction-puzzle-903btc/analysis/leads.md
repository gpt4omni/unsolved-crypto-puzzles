# Open leads -- Bitcoin Transaction Puzzle

Ranked by expected value per unit of effort. Ranges are public, so every entry carries
its cost up front.

## 1. Pollard's kangaroo on the 5 exposed-public-key escrows

Puzzles #140, #145, #150, #155 and #160 have each signed at least one spend, so their
33-byte compressed public keys are on-chain. Kangaroo solves the discrete log on an
interval in about the square root of the range: roughly 2^69.5 group operations for #140
(14 BTC) up to 2^79.5 for #160 (16 BTC). This is the class every mid-range solve has come
from, and large public efforts already operate at this scale. The five public keys are in
the boha records and reproducible by reading each address's spending transactions.

## 2. Pooled brute force on puzzle #71

The lowest unsolved address-only escrow, a 2^70-key space at 7.1 BTC. A single machine
cannot cover it in useful time; the honest move is joining one of the long-running public
pools and taking the pool split, or helping run pool infrastructure. Progress is real but
measured in pool-years.

## 3. Watch for new spends from unsolved escrows

Every spend an unsolved address signs exposes its public key and moves it from the
brute-force class into the kangaroo class. The five current exposures all came from such
spends (and from the creator's own top-ups). A cheap periodic check of the 72 address-only
escrows catches any new exposure.
