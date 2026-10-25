# Bountiful: the Fe compiler bug bounty (1 ETH, [OPEN])

We deploy 15-puzzle contracts on Ethereum mainnet in a start state that the published move rules cannot solve, and pay whoever can
turn that setup into a successful claim anyway. Such a claim demonstrates a defect in the Fe
compiler, in the challenge contract, or in the registry that holds the money. The current
deployment went live on 2026-05-01 with 7 challenges at 0.25 ETH each and 1 ETH in the
registry. An earlier deployment ran for almost 3 years without getting solved.

## At a glance

| | |
|---|---|
| Author | Fe language team, [fe-lang.org](https://fe-lang.org), repository [fe-lang/bountiful](https://github.com/fe-lang/bountiful) |
| Published | 2026-05-04, announced on the project blog ([bountiful: reloaded](https://blog.fe-lang.org/posts/bountiful-reloaded/)) |
| Prize | 1 ETH in the registry, 0.25 ETH per challenge (about $1,900 at ETH = $1,880, 2026-08-16) |
| Chain | ethereum |
| Escrow | the registry contract `0x71fB6afcD98c5BD611712ad4b8D314EF729aa69D` ([etherscan](https://etherscan.io/address/0x71fB6afcD98c5BD611712ad4b8D314EF729aa69D)); the 7 challenge contracts hold no funds themselves |
| Last on-chain check | 2026-10-24: re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | OPEN |
| Puzzle type | smart-contract, timelock |
| Target format | a reproducible transaction or calldata sequence against a current challenge or the registry that makes `claim(challenge)` succeed and transfer the prize; the normal flow requires an active lock, ordinary challenges expose `moveField(uint256)`, Game2D exposes `moveField(uint256,uint256)`, and an exploit may use raw calldata or bypass an expected registry condition |
| Reference model | `tools/oracle.py --selftest`; useful for parity and differential checks, not certified as a solution oracle |
| What remains | a defect nobody has found yet in fe 26.1.0 or in about 1,000 lines of published Fe |
| Series | the retired round 2 registry is noted below |

## The puzzle as published

The current deployment was announced on 2026-05-04 in [bountiful:
reloaded](https://blog.fe-lang.org/posts/bountiful-reloaded/), after the language was rewritten
for the Fe 26.0.0 release:

> We are starting with a small set of challenges, but we plan to add more over time. We are
> also starting with small prizes of currently 0.25 ETH per challenge, but we plan to increase
> both the number of challenges and the prize amounts as we go.

The entry point is [bountiful.fe-lang.org](https://bountiful.fe-lang.org/), and I document the
procedure in my [bounty hunting
guide](https://github.com/fe-lang/bountiful/blob/master/doc/bounty-hunting-guide.md). I keep
every contract source in [fe-lang/bountiful](https://github.com/fe-lang/bountiful) and hold
office hours on Thursdays on Zulip and Twitch.

## What is understood

### Mechanism

Each challenge stores a 4 by 4 board of the numbers 1 to 15 plus one empty field, written as
0. Most variants expose `moveField(index)`; Game2D exposes `moveField(row, col)`. A move slides
the selected tile into the empty field and reverts with `NotMovable` unless the two fields are
neighbours. The reference model represents both forms with a flat index. `isSolved()` returns
true only for `[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]`.
All 7 contracts start from `[1,2,3,4,5,6,7,8,9,10,11,12,13,15,14,0]`, which is the solved
board with tiles 14 and 15 swapped.

That swap is what makes the start state unreachable. For a 4 by 4 board, the number of
inversions among the tiles plus the row index of the empty field has a parity that no legal
move changes: sliding a tile sideways changes neither term, and sliding it vertically changes
the inversion count by an odd number and the empty row by one. The start board has invariant
0 and the solved board has invariant 1, so under the published rules no sequence of
`moveField` calls connects them, however long. A claim therefore requires a state change that
escapes those rules.

The 7 challenges implement the same rules over different Fe constructs, which is the point of
the exercise: each one exposes a different part of the compiler.

| Contract | Address | Fe construct exercised | Sourcify |
|---|---|---|---|
| Game | `0x046a3a4968282BaA7ad6291723873C8275434623` | `StorageMap<u256, u256>` | verified |
| Game2D | `0xE959e7ecA1afCa6cf2Bf8b07e25Da355b6C8E8c7` | `[[u256; 4]; 4]` nested arrays, `getBoard(row, col)` | verified |
| GameEnum | `0xfb5423aDfBAC65ac675845Bb4FEBf8aeC128272E` | enums, `match`, struct methods | verified |
| GameBitboard | `0x5E987b6aADD4DFC2236D21edE6D07feb04350b06` | one `u256`, 4 bits per field | not verified |
| GameMonadic | `0x86B7AEce1503242fED29E593FAEde3b7b00a5a1D` | one `u256`, functional combinators | verified |
| GameNested | `0x3dF9789634995546B0126bC28B9F9FcBCB129F18` | nested structs | verified |
| GameTrait | `0x85b4d0B32b8a285111c244E52524B642f1A5ccFE` | `[u256; 16]` plus trait dispatch | not verified |

The money sits in the registry, not in the games. Claiming has three steps, and the middle one
exists because a winning transaction is profitable and would otherwise be copied out of the
mempool: call `lock(challenge)` with a 0.01 ETH deposit, which reserves the challenge for the
caller for 100 blocks and is also what the challenge move functions check on every call; solve
the challenge within that window; call `claim(challenge)`, which calls `isSolved()` on the
challenge and sends the prize to the caller. The lock deposit stays with the registry.

### Derivation and oracle

```
python3 tools/oracle.py --selftest                       # must print SELFTEST OK
python3 tools/oracle.py --parity                         # invariant of the deployed board
python3 tools/oracle.py --moves 11,7,6,5                 # replay under the deployed rules
python3 tools/oracle.py --live https://your-rpc.example                 # read boards and isSolved(), read only
```

`tools/oracle.py` is a reference model of the published move rules, not a solution oracle.
It is useful for checking the parity invariant and for comparing a compiled challenge with the
expected behaviour after the same calls. It models ordinary moves as flat indices; it does not
model malformed calldata or registry exploits. Its self-test uses a synthetic board one legal
move away from the goal as a positive witness and rejects a non-adjacent move as a negative
control. An actual bounty candidate must be run against the compiled contracts and confirmed
by a successful `claim(challenge)`.

### Established facts

1. The registry `0x71fB6afcD98c5BD611712ad4b8D314EF729aa69D` holds 1 ETH, and each of the 7
   challenges is registered at 0.25 ETH and is open. `isLocked()` returned false for all 7;
   that negative state is uncertified because I retained no known locked control. I read these
   values on 2026-08-17 with `cast balance`, `getPrizeAmount(address)`,
   `isOpenChallenge(address)` and `isLocked(address)`. The nominal total of 1.75 ETH is
   larger than the balance, so the registry pays the first 4 claims and the 5th reverts until
   it is funded again.
2. All 7 challenges hold a zero balance and report the same board,
   `[1,2,3,4,5,6,7,8,9,10,11,12,13,15,14,0]`. `isSolved()` returned false for all 7; that
   negative state is uncertified because I retained no known solved contract as a positive
   RPC control. I read all 16 fields and called `isSolved()` on each contract on 2026-08-17
   (`python3 tools/oracle.py --live <rpc-url>`).
3. The lock deposit is 0.01 ETH and the lock period is 100 blocks, about 20 minutes.
   Confirmed 2026-08-17 with `getLockDeposit()` and the constant `LOCK_PERIOD` in the
   published source.
4. The registry was created on 2026-05-01 by `0xaD0Ad88D27F49fe6a0c73FdB743f6B7304a2C357`
   with 1 ETH sent at deployment, followed by 7 `registerChallenge` calls in the same minutes.
   Confirmed from the creation transaction
   [`0xb74abeb76c6436d54df5f8022703580955b29cc8377d358672a2f153962d0822`](https://etherscan.io/tx/0xb74abeb76c6436d54df5f8022703580955b29cc8377d358672a2f153962d0822).
5. The compiler pinned for the current round is fe 26.1.0, and Sourcify reports a runtime
   `match` for 6 of the 8 deployed contracts, with the language recorded as Fe. `GameBitboard` and
   `GameTrait` have no verified source there. Confirmed 2026-08-17 against the Sourcify v2
   API.
7. `claim(address)` marks the challenge closed before it calls `isSolved()` on it, and pays
   with a raw call that forwards the remaining gas to the caller. `withdraw()` is restricted
   to the admin and reverts while any lock is active. Read from the published registry source.

## What has been tested

Full ledger in [analysis/tested.md](analysis/tested.md). Summary:

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| The published rules connect the start board to the solved board | all move sequences of any length | invariant of the start board compared with the solved board, computed by the reference model | 0 match, the two differ | yes: a synthetic board one legal move from the goal keeps the same invariant and is solved by the same replay code | 2026-08-17 |
| Somebody already solved a challenge of the current deployment | full transaction history of the registry since 2026-05-01 | every transaction to the registry inspected | 0 locks, 0 claims, one reverted `withdraw()` by a non-admin | uncertified: no positive transaction-history control is retained here | 2026-08-17 |
| Round 2 was claimed at some point in its 2 years and 10 months | full internal transaction history of the round 2 registry | every value-bearing internal transfer inspected | 0 claims, only the admin withdrawal | uncertified: no positive transfer-history control is retained here | 2026-08-17 |

No candidate move sequence has been tested against the current 7 contracts, and no compiler
level search has been run. The negatives above are about the state of the chain, not about
the space of possible defects.

## Open leads, ranked

1. **Re-audit the hand-written data in each challenge** (hours). Each of the 7 contracts
   contains hand-written material that implements the same rules in different forms: an
   adjacency table encoded as decimal digits, index arithmetic for the 2D variant, and bit
   offsets for the packed variants. Reading those files against the reference rules is the
   cheapest bounded check. What would confirm it: any input where a contract accepts a move
   the reference rules reject.
2. **Differential testing against a reference implementation** (hours). Build the workspace
   with fe 26.1.0, then drive each challenge and `tools/oracle.py` with the same random move
   sequences and compare the full board after every call. Divergence is the finding; agreement
   over a large sample bounds the search rather than closing it.
3. **Rebuild the two contracts that Sourcify does not cover** (hours). `GameBitboard` and
   `GameTrait` are the two challenges without verified sources. Compiling them from the tagged
   repository with the pinned compiler and comparing the runtime bytecode to the deployed code
   either verifies them or shows that what is deployed is not what is published.
4. **Attack the registry rather than a game** (hours). The prize is paid by `claim`, which
   closes the challenge before the external `isSolved()` call and then forwards all remaining
   gas to the caller in a raw call. The pot is shared by 7 challenges but funded for 4 claims,
   so the accounting between prizes, lock deposits and the balance is worth reading closely.

Full notes: [analysis/leads.md](analysis/leads.md).

## Files in this folder

| Path | What it is |
|---|---|
| `data/challenges.json` | the 7 deployed challenges, their prizes, boards, `getBoard` selectors and `isSolved()` results, read from the chain on 2026-08-17 |
| `analysis/tested.md` | the complete negatives ledger |
| `analysis/leads.md` | full notes behind the 4 ranked leads |
| `tools/oracle.py` | reference model for parity and differential checks; its self-test does not certify bounty candidates |

## Sources

- Fe language team, "bountiful: reloaded", blog.fe-lang.org, 2026-05-04: https://blog.fe-lang.org/posts/bountiful-reloaded/
- Fe language team, "bountiful: round #2", blog.fe-lang.org, 2023-01-11: https://blog.fe-lang.org/posts/bountiful-round-2/
- Bountiful platform, live challenge list, 2026-08-17: https://bountiful.fe-lang.org/
- Bounty hunting guide, fe-lang/bountiful, 2026-08-17: https://github.com/fe-lang/bountiful/blob/master/doc/bounty-hunting-guide.md
- Registry and challenge sources, fe-lang/bountiful, 2026-08-17: https://github.com/fe-lang/bountiful
- Round 2 admin withdrawal, Etherscan, 2025-11-04: https://etherscan.io/tx/0xdd5188f6bb7a2fb5fab1b170213c3ad107dab20407e900128525adb92e36077e
- Sourcify verification of the Game challenge, compiler fe 26.1.0, 2026-08-17: https://sourcify.dev/server/v2/contract/1/0x046a3a4968282BaA7ad6291723873C8275434623
