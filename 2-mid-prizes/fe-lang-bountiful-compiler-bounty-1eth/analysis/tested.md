# Tested (full negatives ledger)

The summary table in the folder's `README.md` shows the highlights; this file is the complete
record. Add one row per hypothesis family tested, in the order tested. Never remove a row; if
a hypothesis is retested with a different method, add a new row rather than editing the old
one.

Every row here is about the state of the chain and the published rules. No candidate move
sequence has been run against the 7 deployed contracts yet, and no compiler level search has
been run, so nothing below narrows the space of possible defects.

| Hypothesis | Space (N) | Method | Result | Witness | Rate | Date |
|---|---|---|---|---|---|---|
| The published move rules connect `[1,2,3,4,5,6,7,8,9,10,11,12,13,15,14,0]` to the solved board | all sequences of any length, the reachable half of the 16! board states | computed the invariant (inversions among the tiles plus the row of the empty field, modulo 2) for both boards with `tools/oracle.py --parity`, which is unchanged by every move the adjacency table allows | 0 match: start board invariant 0, solved board invariant 1 | yes: a synthetic board one legal move from the goal keeps the same invariant and is solved by the same replay code | single evaluation | 2026-08-17 |
| A challenge of the current deployment has already been locked or claimed | every transaction sent to the registry `0x71fB6afcD98c5BD611712ad4b8D314EF729aa69D` since its creation on 2026-05-01 | listed the full transaction history and classified each by selector | 0 `lock(address)` calls, 0 `claim(address)` calls; 9 transactions total: the creation with 1 ETH, 7 `registerChallenge` calls by the admin, and one `withdraw()` on 2026-07-15 from `0xdF04A38f0d60C913b70B60255139e3f12CB43B94` that reverted because the caller is not the admin | uncertified: no positive transaction-history control is retained here | full history, 4 months | 2026-08-17 |
| Round 2 was claimed at some point between 2023-01-11 and its retirement | every internal transaction of the round 2 registry `0x76eB86d4f92901f2af0d10feDDdA0B3B4630700D` | listed all internal transfers and kept the ones carrying value | 0 payouts; the single value-bearing transfer is the admin withdrawal of 3.1 ETH on 2025-11-04 | uncertified: no positive transfer-history control is retained here | full history, 2 years 10 months | 2026-08-17 |
| The deployed boards differ from the board stated in the announcement, or a contract already reports solved | 7 contracts, 16 fields plus `isSolved()` each, 119 reads | read `getBoard` from every contract and called `isSolved()` over an Ethereum RPC endpoint (`tools/oracle.py --live`), including the two argument getter used by `Game2D` | 0 differences and 0 solved: all 7 report `[1,2,3,4,5,6,7,8,9,10,11,12,13,15,14,0]` and return `isSolved()` false | uncertified: no known solved contract was read through the same RPC path as a positive control | 119 reads | 2026-08-17 |
| The deployed code is the published code | 8 contracts | queried the Sourcify v2 API for each address on chain 1 | 6 of 8 report a runtime `match` with the language recorded as Fe and the compiler as fe 26.1.0; `GameBitboard` and `GameTrait` have no verified source there, which is not evidence of a difference, only an absence of the check | uncertified: no local rebuild was compared against the deployed runtime bytecode | 8 queries | 2026-08-17 |
