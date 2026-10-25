# Author posts: Peter Todd hash-collision bounties

Peter Todd, Bitcoin Core contributor, posted the challenge on BitcoinTalk. There is no
separate riddle text: the redeem script itself, posted alongside the funding addresses,
is the puzzle.

---

**2013-09-13, 06:19:33 AM**, BitcoinTalk thread
["REWARD offered for hash collisions for SHA1, SHA256, RIPEMD160 and other"](https://bitcointalk.org/index.php?topic=293382.0),
posted by [Peter Todd](https://bitcointalk.org/index.php?action=profile;u=2546):

> "Rewards at the following P2SH addresses are available for anyone able to demonstrate
> collision attacks against a variety of cryptographic algorithms. You collect your
> bounty by demonstrating two messages that are not equal in value, yet result in the
> same digest when hashed. These messages are used in a scriptSig, which satisfies the
> scriptPubKey storing the bountied funds, allowing you to move them to a scriptPubKey
> (Bitcoin address) of your choice."

The post lists 5 scripts, each the same 8-byte template, only the hash opcode varying:

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

A 6th, non-hash script in the same post, `OP_ABS` in place of a hash opcode (address
`3QsT6Sast6ghfsjZ9VJj9u8jkM2qTfDgHV`, redeem hex `6e879169907c9087`), is not a hash
puzzle at all: `abs(x) == abs(-x)` for any x, so it was solvable by construction. Peter
Todd wrote that this one "created, and then collected" its own bounty as a worked
example of the payout mechanism; the address shows 12 of 12 outputs spent on a recheck
today (2026-08-16). It is not part of the hash-collision prize tracked in this folder.

On the SHA-1 script specifically, the post adds: "Further donations to the bounties are
welcome, particularly for SHA1 ... for which an attack on a single hash value is
believed to be possible at an estimated cost of $2.77M," citing Bruce Schneier's 2012
blog post "When Will We See Collisions for SHA-1?". A note further down states: "Due to
limitations of the Bitcoin scripting language bounties can only be collected with
solutions using messages less than 521 bytes in size."

Source table cross-checked against the community mirror at
[github.com/oritwoen/boha](https://github.com/oritwoen/boha) (`data/hash_collision.jsonc`).
