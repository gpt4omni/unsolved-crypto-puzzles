# How to verify an escrow

Every "Escrow" row in a puzzle's "At a glance" table names an address and a check date. Do
not trust the date: prices and balances move, and an escrow can be swept between my last
check and your read. Re-check before you spend any time on a puzzle. This page gives the
one-line command per chain, the traps that produce a wrong verdict, and the tool that
automates all of it.

## Bitcoin

```bash
curl -s "https://mempool.space/api/address/<address>" | python3 -m json.tool
```

Read `chain_stats.funded_txo_sum`, `chain_stats.spent_txo_sum`, and `chain_stats.tx_count`.
Funded and unspent means `funded_txo_sum > 0` and `spent_txo_sum == 0`. Any nonzero
`spent_txo_sum` means at least one output has moved, whether that output was the prize or a
decoy the author sent for their own reasons.

Traps:
- A small test transaction from the author to their own escrow, then back out, still counts
  as "spent" by this API even though the prize itself was never claimed. Read the actual
  transactions before writing off an escrow as swept.
- Reading an `xpub` with the wrong script type (legacy vs. segwit vs. taproot) derives the
  wrong addresses and shows an empty balance where funds exist under a different derivation.
  Check all standard script types before concluding "unfunded".
- Some puzzles fund more than one address (multiple lots, multiple cards, multiple stages).
  Checking only the address in the headline announcement misses the others; check every
  address listed in the folder's `puzzle.json`.
- A P2SH address that has never been spent from shows no redeem script on chain. The address
  can hold funds and still look opaque until the day it is spent; this is expected, not a
  sign of a problem.

## Ethereum and Base

Any public JSON-RPC endpoint or a block explorer works:

```bash
curl -s -X POST https://eth.drpc.org \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["<address>","latest"],"id":1}'
```

Or open `https://etherscan.io/address/<address>` (Ethereum) or
`https://basescan.org/address/<address>` (Base).

Traps:
- If the escrow is a smart contract, its ETH balance is not the whole story: check whether
  the contract actually has a function that pays out to a solver, or whether the funds are
  stuck with no exit path regardless of who solves the riddle.
- Some prizes are ERC-20 tokens (USDT, USDC), not native ETH. A zero ETH balance on an
  address holding USDT is not "unfunded"; check the token balance, not the account balance.

## Arweave

```bash
curl -s "https://arweave.net/wallet/<address>/balance"
```

The result is in winston; divide by 1e12 to get AR. Some Arweave puzzles are page-based
(the challenge is content posted to a permaweb page, not only a funded wallet): also check
that the page itself is still reachable, since a dead gateway link can hide a puzzle that is
otherwise intact.

## Solana

No script in this repository queries Solana automatically; `tools/check_escrows.py` prints a
note and skips it. Check manually at `https://solscan.io/account/<address>`.

## What "unfunded" looks like

An address that was announced as an escrow but never received the announced amount, or never
received anything at all. This is different from "swept": the funds were never there in the
first place, often because a follow-up announcement never materialized, or the amount quoted
publicly does not match anything on chain.

## What "zero-balance-contract" looks like

A deployed contract that is part of a puzzle but is not itself an escrow can be expected to
hold no prize funds. Its manifest uses `zero-balance-contract` so the funding checker records
that expectation without calling it `unfunded` or `swept`. The EVM check requires both a zero
balance and non-empty bytecode, rather than inferring funding history from the account nonce.
Empty bytecode or a later positive balance is reported as drift and makes the check fail.

## What "custodial" means

Some puzzles do not lock funds in a wallet you can check directly. Instead, a platform or a
person holds the prize and pays out by hand once a solution is verified. There is no address
to check on chain; "funded" depends on trusting the custodian's word. Puzzles in this state
are tiered as dead ends unless the custodian's track record and terms make the promise
concrete.

## Running it for you

```bash
python3 tools/check_escrows.py                 # every address in puzzles.json
python3 tools/check_escrows.py --slug <slug>    # one puzzle
python3 tools/check_escrows.py --update         # also writes verified_on into the folder manifest
```

The script prints one row per address: slug, label, address, expected amount, observed
state, and a verdict. It never reports a network error as a sweep; a failed request is
printed as `ERROR`, not as `swept` or `unfunded`, because those two look identical to a
naive check and only one of them means the prize is gone.
