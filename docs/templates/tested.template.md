# Tested (full negatives ledger)

The summary table in the folder's `README.md` shows the highlights; this file is the
complete record. Add one row per hypothesis family tested, in the order tested. Never remove
a row; if a hypothesis is retested with a different method, add a new row rather than editing
the old one.

| Hypothesis | Space (N) | Method | Result | Witness | Rate | Date |
|---|---|---|---|---|---|---|
| Example: all permutations of the 12 printed words, BIP84, empty passphrase | 479,001,600 / 16 = 29,925,000 (checksum filter applied) | generated valid-checksum permutations, derived first BIP84 address, compared as raw hash160 | 0 match | yes: known mnemonic re-found at head, middle and tail of the generated set | 790,000 derivations/s on a rented GPU | 2026-08-02 |
