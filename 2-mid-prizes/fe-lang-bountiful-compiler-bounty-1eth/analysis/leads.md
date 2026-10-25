# Leads (full notes)

The "Open leads, ranked" section of the folder's `README.md` shows the ranked list; this file
carries the full notes behind each entry. Order leads by cost to test, then by expected value.

## 1. Re-audit the hand-written data in each challenge

- **Cost**: hours
- **What it is**: every challenge encodes the same rules twice, once in its move logic and
  once in a table or a set of offsets written out by hand. The current contracts store the
  adjacency table as decimal digits packed into a `u256` (`1 + 4 * 1000 + 666 * 1000000 + ...`,
  with 666 as the marker for a missing neighbour), the 2D variant recomputes row and column
  from an index, and the packed variants address 4 bit fields inside one word. Each of those
  is a place where a single wrong constant could make the deployed behaviour diverge.
- **Why it ranks here**: it needs no build and no chain access, and the material is about 1,000
  lines in a public repository.
- **What would confirm it**: an input where a contract accepts a move that the reference rules
  in `tools/oracle.py` reject, or where the two disagree on the resulting board.
- **What would kill it**: a line by line reconciliation of all 7 tables against the reference
  adjacency, with the offsets recomputed rather than read.
- **Status**: open

## 2. Differential testing against a reference implementation

- **Cost**: hours
- **What it is**: build the workspace with fe 26.1.0 and Foundry as my guide
  describes, then drive both a locally deployed challenge and `tools/oracle.py` with the same
  random sequences of `moveField` calls, comparing all 16 fields after every call. Include
  calls that should revert, since a missing revert is as much a finding as a wrong board.
- **Why it ranks here**: it covers the compiler as well as the contract, which lead 1 does
  not, at the cost of a build and a test harness. It has not been run publicly against the
  current deployment.
- **What would confirm it**: any divergence between the contract and the reference after the
  same call sequence.
- **What would kill it**: nothing kills it outright. A large sample without divergence bounds
  the defect to the parts of the compiler that these 7 contracts do not exercise, which is
  useful to state with the sample size.
- **Status**: open

## 3. Rebuild the two contracts Sourcify does not cover

- **Cost**: hours
- **What it is**: `GameBitboard` (`0x5E987b6aADD4DFC2236D21edE6D07feb04350b06`) and
  `GameTrait` (`0x85b4d0B32b8a285111c244E52524B642f1A5ccFE`) are the two deployed contracts
  with no verified source on Sourcify, while the other 6 match. Compile them from the tagged
  repository with the pinned compiler and compare the runtime bytecode with the deployed code.
- **Why it ranks here**: it is bounded and mechanical, and it either removes a gap in what a
  hunter can trust or shows that the deployed code differs from the published code, which
  would itself be the finding.
- **What would confirm it**: a byte difference between the local build and the deployed
  runtime code that is not explained by metadata or constructor arguments.
- **What would kill it**: a byte for byte match, or a later Sourcify verification by the
  author.
- **Status**: open

## 4. Attack the registry rather than a game

- **Cost**: hours
- **What it is**: the prize logic sits in `claim(address)`. It requires an active lock owned
  by the caller, marks the challenge closed before calling `isSolved()` on it, and then sends
  the prize with a raw call that forwards the remaining gas to the caller. The registry also
  holds 1 ETH against 7 challenges registered at 0.25 ETH each, and keeps every lock deposit.
- **Why it ranks here**: it is the smallest contract in the system and the only one that moves
  money, but the ordering already follows checks, effects, interactions, so this is a reading
  exercise rather than a known weakness.
- **What would confirm it**: a call sequence where the registry pays without the challenge
  reporting a solve, or pays twice for one challenge.
- **What would kill it**: a full reading of the registry source against its compiled output,
  covering the lock accounting and the two raw calls.
- **Status**: open
