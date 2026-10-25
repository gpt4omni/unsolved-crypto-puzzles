# <Puzzle name> (<prize>, [OPEN])

<Summary paragraph, 60 to 120 words. Who published it, when, what is locked and where,
what kind of puzzle it is, what has been established, and in one sentence what is left.>

## At a glance

| | |
|---|---|
| Author | <name>, <handle with link> |
| Published | <YYYY-MM-DD>, <where> (<link>) |
| Prize | <amount asset> (about $<n> at <asset> = $<p>, 2026-08-16) |
| Chain | <bitcoin / ethereum / base / arweave> |
| Escrow | `<full address>` ([explorer](<url>)) |
| Last on-chain check | <YYYY-MM-DD>: <funded and unspent / ...> |
| Status | OPEN |
| Puzzle type | <2 to 4 tags> |
| Target format | <e.g. BIP39 12 words, English, BIP84 m/84'/0'/0'/0/0, no passphrase> |
| Certified oracle | yes: `tools/oracle.py --selftest` (certified against <what>) / no |
| What remains | <one line from the difficulty_left vocabulary> |
| Series | <link or "none"> |

## The puzzle as published

<The author's material only, in chronological order. Puzzle images embedded from clues/.
Short clues verbatim in quotes with date and link. Long material summarized with a link.
Nothing I inferred goes here.>

## What is understood

### Mechanism
<How the puzzle encodes the key: the pipeline from clue to address, in prose and one
flowchart when the mechanism is known.>

### Derivation and oracle
<Exact target format, derivation path, and how to check a candidate. Command lines.>

### Certified against
<Which known-good vector the oracle reproduces, byte for byte, and where it comes from.>

### Established facts
<Numbered list. Each fact: the statement, how it was verified (command, measurement, source),
date. Only things a reader can re-check.>

## What has been tested

<Summary table of the negatives ledger. Full ledger in analysis/tested.md.>

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| <what was assumed> | <N candidates> | <one line> | 0 match | yes: <how> / uncertified | <YYYY-MM-DD> |

## Open leads, ranked

1. **<lead title>** (<cost: minutes / hours / needs a person / needs new information>).
   <What it is, why it ranks here, what would confirm or kill it.>
2. ...

## Solution

<SOLVED FOLDERS ONLY. Delete this section elsewhere. Answer, derivation, key material,
payout transaction. See section 5.3.>

## Files in this folder

| Path | What it is |
|---|---|
| `clues/<file>` | <one line, with source> |
| `data/<file>` | <one line, how produced> |
| `tools/oracle.py` | <one line> |
| `images/<file>` | <one line> |

## Sources

- <Title>, <site>, <YYYY-MM-DD>: <url> (archived: <wayback url>)
- ...
