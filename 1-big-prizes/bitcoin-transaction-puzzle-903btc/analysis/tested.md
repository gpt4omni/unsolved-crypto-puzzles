# Tested -- Bitcoin Transaction Puzzle

Negatives and certifications, newest last. A negative counts only with a witness.

| Date | Hypothesis | Space | Method | Result | Witness |
|---|---|---|---|---|---|
| 2026-11-19 | the derivation reads the published rule correctly | 1 known vector | derive private key 1 and compare its compressed P2PKH to puzzle #1's funded address | confirmed: exact match to `1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH` | yes: `tools/oracle.py --selftest` |
| 2026-11-19 | the 77 listed escrows are still funded | 77 addresses | live mempool.space balance check on each | confirmed: 72 funded-unspent; #140, #145, #150, #155, #160 partially-spent with prize intact | yes: `data/open_puzzles.csv` |
| 2026-11-19 | a search worth running exists on an address-only escrow | 2^70 keys minimum (#71) | none run: no bounded sub-space exists | not attempted | n/a |

No candidate keys have been run through the oracle beyond the certification vector; there
is no negative ledger to report yet.
