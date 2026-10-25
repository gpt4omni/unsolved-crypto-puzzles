# Peter Todd Hash Collision Bounties (0.59364885 BTC, [WATCH])

Peter Todd, a Bitcoin Core contributor, posted 5 hash-collision bounty scripts on
BitcoinTalk on 2013-09-13: pay out to anyone who supplies 2 distinct byte strings with
the same digest under SHA-256, RIPEMD-160, their composite forms HASH160 and HASH256, or
SHA-1. The SHA-1 sibling was claimed in 2023 with a real academic collision, proving the
payout mechanism works; the other 4 total 0.59364885 BTC, intact since 2013. I confirmed
the predicate directly from the redeem-script bytes and from the actual claiming
transaction. There is no derivation to search here: a full collision on any of the 4
remaining functions has never been published, and finding one is a cryptography research
result, not a computation I can schedule.

## At a glance

| | |
|---|---|
| Author | Peter Todd, [BitcoinTalk profile](https://bitcointalk.org/index.php?action=profile;u=2546) |
| Published | 2013-09-13, [BitcoinTalk thread 293382](https://bitcointalk.org/index.php?topic=293382.0) |
| Prize | 0.59364885 BTC (about $37,400 at BTC = $63,000, 2026-08-16) |
| Chain | bitcoin |
| Escrow | 4 live P2SH scripts (SHA-256, RIPEMD-160, HASH160, HASH256), full table in [The puzzle as published](#the-puzzle-as-published) |
| Last on-chain check | 2026-10-24: re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | WATCH |
| Puzzle type | hash-collision |
| Target format | 2 distinct byte strings, each under 521 bytes, with equal digest under the named hash function; no key derivation |
| Certified oracle | yes: `tools/oracle.py --selftest` (certified against the real 2023 SHA-1 claim and the 2013 OP_ABS demo claim; it verifies a submitted pair, it does not search for one) |
| What remains | a published practical collision on SHA-256, RIPEMD-160, HASH160, or HASH256 |
| Series | none |

## The puzzle as published

Peter Todd wrote: "Rewards at the following P2SH addresses are available for anyone able
to demonstrate collision attacks against a variety of cryptographic algorithms. You
collect your bounty by demonstrating two messages that are not equal in value, yet
result in the same digest when hashed." (BitcoinTalk, 2013-09-13, 06:19:33 AM). Every
script shares the same 8-byte template, only the hash opcode changing:

```
OP_2DUP OP_EQUAL OP_NOT OP_VERIFY <HASH> OP_SWAP <HASH> OP_EQUAL
```

| Function | Address | Redeem script (hex) |
|---|---|---|
| SHA-256 | `35Snmmy3uhaer2gTboc81ayCip4m9DT4ko` | `6e879169a87ca887` |
| RIPEMD-160 | `3KyiQEGqqdb4nqfhUzGKN6KPhXmQsLNpay` | `6e879169a67ca687` |
| HASH160 (RIPEMD160(SHA256())) | `39VXyuoc6SXYKp9TcAhoiN1mb4ns6z3Yu6` | `6e879169a97ca987` |
| HASH256 (SHA256(SHA256())) | `3DUQQvz4t57Jy7jxE86kyFcNpKtURNf1VW` | `6e879169aa7caa87` |
| SHA-1 (reference, claimed 2023) | `37k7toV1Nv4DfmQbmZ8KuZDQCYK9x5KpzP` | `6e879169a77ca787` |

A 6th script in the same post, `OP_ABS` in place of a hash opcode
(`3QsT6Sast6ghfsjZ9VJj9u8jkM2qTfDgHV`), is not a hash puzzle: `abs(x) == abs(-x)` for any
x, so it was solvable on sight. Peter Todd wrote that it "created, and then collected,"
its own bounty as a worked example; the address shows 12 of 12 outputs spent, the first
about 5.5 hours after the post. It is not part of the prize tracked here. Full quotes in
[clues/author-posts.md](clues/author-posts.md).

## What is understood

### Mechanism

Every live script demands, in a single `scriptSig`, 2 distinct pushes `a` and `b` such
that `HASH(a) == HASH(b)`: a full, exact collision of the named hash function, with no
truncation, no reduced-round shortcut, and no constrained message structure. I
disassembled all 5 redeem scripts from their raw hex and confirmed each is exactly the
8-byte template above; none carries a truncation opcode. The bounty author's own note
caps candidate messages under 521 bytes, a scripting-language limit, not a cryptographic
one. There is no offline chain to compute here: SHA-256's generic collision cost is
2^128, RIPEMD-160 and HASH160's is 2^80, both beyond any feasible search, and no known
method beats the generic bound for the full, unmodified function.

### Derivation and oracle

```
python3 tools/oracle.py --selftest
python3 tools/oracle.py "<hash_name> <a_hex> <b_hex>"
python3 tools/oracle.py --stdin
```

`<hash_name>` is one of `sha256`, `ripemd160`, `hash160`, `hash256`, or `sha1`. The oracle
checks that `a != b` and that `HASH(a) == HASH(b)` for the named function, printing
`MATCH <hash_name> <address>` or `NO MATCH`. It verifies a candidate pair; it cannot
search for one.

### Certified against

`tools/oracle.py --selftest` reproduces the real 2023-02-22 SHA-1 claim: I read the 2
pushed values directly from the `scriptSig` of transaction
[`9ec2a0db0c4c3423a6b2c3cb2a26fc626b037121b4b5f3f57b08916196ff14e0`](https://mempool.space/tx/9ec2a0db0c4c3423a6b2c3cb2a26fc626b037121b4b5f3f57b08916196ff14e0)
(block 777856), which spends `37k7toV1Nv4DfmQbmZ8KuZDQCYK9x5KpzP`: 2 distinct 320-byte
values, the well-known "SHAttered" PDF-prefix pair, whose SHA-1 digests are equal
(`f92d74e3874587aaf443d1db961d4e26dde13e9c`). Since the 4 live scripts share the
identical template with only the hash opcode changed, this certifies the predicate
reading for all 5 and confirms Bitcoin actually pays out on a satisfying witness. The
same-day 2013-09-13 `OP_ABS` claim is a second, independent confirmation that this script
family pays out as written. Reproduced 2026-08-16.

### Established facts

1. All 4 live scripts are funded and unspent, totaling 0.59364885 BTC, confirmed
   2026-08-16 on [mempool.space](https://mempool.space/address/35Snmmy3uhaer2gTboc81ayCip4m9DT4ko).
2. The SHA-1 reference script is fully spent (23 of 23 outputs), claimed 2023-02-22 with
   the real SHAttered collision pair, confirmed by reading its `scriptSig` directly.
3. All 5 hash-bounty scripts share the identical 8-byte template; none carries a
   truncation or reduced-round opcode.
4. The `OP_ABS` sibling script, not a hash puzzle, was claimed the same day it was
   posted (2013-09-13), the first spend about 5.5 hours later, confirming the payout
   template works independent of the SHA-1 case.
5. No known method beats the generic collision bound for the full, unmodified form of
   SHA-256, RIPEMD-160, HASH160, or HASH256; the best public reduced-round results reach
   about 38 of 64 rounds for SHA-256 and 30 of 80 steps for RIPEMD-160, neither
   threatening the full function.
6. Candidate messages are capped under 521 bytes by a Bitcoin scripting-language limit
   stated in the original post, not by any property of the hash functions themselves.

## What has been tested

Full ledger in [analysis/tested.md](analysis/tested.md). Summary:

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| a live script hides a truncated or reduced-round shortcut | 5 redeem scripts, 8 bytes each | byte-by-byte disassembly against the known opcode table | refuted: all 5 are the identical full-collision template | yes: `tools/oracle.py --selftest` template check | 2026-08-16 |
| the payout mechanism does not actually work as written | 2 real on-chain claims | read the claiming transactions' `scriptSig` directly | confirmed: both the SHA-1 claim and the `OP_ABS` demo pay out on a satisfying witness | yes: 2 independent on-chain claims | 2026-08-16 |
| a published shortcut exists for the 4 live functions | literature review, not a compute run | checked best public reduced-round results against the full-function bound | none found for any of the 4 | uncertified: a literature position, not a dated experiment | 2026-08-16 |
| direct search for a collision | 2^80 to 2^128 per function | none run: no bounded space exists to search | not attempted | n/a | n/a |

## Open leads, ranked

1. **A published practical or academic collision** (needs a research breakthrough). The
   only event that changes this puzzle is a genuine full collision on SHA-256,
   RIPEMD-160, or their composite forms, published the way SHAttered was for SHA-1 in
   2017. Confirmed by a verifiable example pair; claimed here by feeding it straight
   into `tools/oracle.py`.
2. **RIPEMD-160 and HASH160 as the most-watched sub-targets** (no cost, a
   prioritization). Their generic bound, 2^80, is the smallest of the 4, and RIPEMD-160
   has the more active reduced-round literature. If any of the 4 falls first, this is
   the likely candidate.
3. **Passive monitoring** (minutes, periodic). Watching the `spent` flag on the 4 live
   addresses, to catch a third party claiming first, and watching collision-research
   announcements. Not yet set up as a running watch.

Full notes: [analysis/leads.md](analysis/leads.md).

## Files in this folder

| Path | What it is |
|---|---|
| `clues/author-posts.md` | the BitcoinTalk post, quoted, with the redeem-script table and the `OP_ABS` demo |
| `data/redeem_scripts.csv` | the 5 scripts with generic collision cost and balance, checked 2026-08-16 |
| `data/timeline.csv` | dated events: posting, the `OP_ABS` demo, SHAttered, the SHA-1 claim |
| `analysis/tested.md` | full negatives ledger |
| `analysis/leads.md` | full lead notes |
| `tools/oracle.py` | predicate checker: candidate pair to match/no match per hash function |

## Sources

- Peter Todd, ["REWARD offered for hash collisions for SHA1, SHA256, RIPEMD160 and other"](https://bitcointalk.org/index.php?topic=293382.0), BitcoinTalk, 2013-09-13
- [github.com/oritwoen/boha](https://github.com/oritwoen/boha), community bounty mirror (`data/hash_collision.jsonc`)
- Stevens, Bursztein, Karpman, Albertini, Markov, ["The first collision for full SHA-1"](https://shattered.io), 2017-02-23
- [mempool.space](https://mempool.space/tx/9ec2a0db0c4c3423a6b2c3cb2a26fc626b037121b4b5f3f57b08916196ff14e0), SHA-1 bounty claiming transaction, checked 2026-08-16
- [mempool.space](https://mempool.space/address/35Snmmy3uhaer2gTboc81ayCip4m9DT4ko), the 4 live escrow addresses, checked 2026-08-16
