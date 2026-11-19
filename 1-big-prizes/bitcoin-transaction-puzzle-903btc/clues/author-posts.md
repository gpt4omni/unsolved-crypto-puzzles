# Clues -- Bitcoin Transaction Puzzle

The donor was anonymous and never explained the puzzle in words; the structure is the
clue. What is publicly established, from the chain itself and the long-running
BitcoinTalk tracking thread
([topic 5218972](https://bitcointalk.org/index.php?topic=5218972)):

- Funding began on 2015-01-15. Address #n holds about n/10 BTC, and its private key is an
  integer in [2^(n-1), 2^n). The chain was topped up and extended over the years to a
  total near 1,000 BTC across 160 addresses, which is where the "1000 BTC challenge"
  name comes from.
- The donor deliberately spent from a small number of funded addresses over the years,
  which is how the five public-key-exposed escrows (#140, #145, #150, #155, #160) came to
  be: every signed spend puts the compressed public key on-chain.
- No statement of intent, rules text, or solution hints were published. The
  "certificate" for the construction is puzzle #1 itself: private key 1 derives exactly
  to the first funded address.
- Per-address solve history is tracked at
  [privatekeys.pw](https://privatekeys.pw/puzzles/bitcoin-puzzle-tx).
