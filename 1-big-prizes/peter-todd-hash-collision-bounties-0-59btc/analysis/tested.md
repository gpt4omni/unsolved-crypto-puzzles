# Tested: Peter Todd hash-collision bounties

Full negatives ledger. The README shows the summary.

## 1. Redeem script disassembly

I disassembled all 5 redeem scripts byte by byte from their raw hex (`data/redeem_scripts.csv`,
sourced from the community mirror [github.com/oritwoen/boha](https://github.com/oritwoen/boha)
and cross-checked against the on-chain scripts themselves). Method: opcode table lookup,
`tools/oracle.py --selftest` (template check). Result: every script is exactly the same
8-byte template, `OP_2DUP OP_EQUAL OP_NOT OP_VERIFY <HASH> OP_SWAP <HASH> OP_EQUAL`, with
only the hash opcode byte varying. None carries a truncation or reduced-round opcode
(`OP_LEFT`, `OP_SUBSTR`/`0x7f`), which refutes the hypothesis that any of the 4 live
scripts is a cheaper truncated-hash variant seen elsewhere in Peter Todd's other bounty
scripts. Witness: the decoder's table reproduces the known SHA-1 template exactly. Date:
2026-08-16 (re-disassembled this session; first established 2026-06-17 per the folder's
own prior record).

## 2. Predicate certification against a real payout

I confirmed the SHA-1 sibling script (not part of the live prize) was actually spent
on-chain: transaction
[`9ec2a0db0c4c3423a6b2c3cb2a26fc626b037121b4b5f3f57b08916196ff14e0`](https://mempool.space/tx/9ec2a0db0c4c3423a6b2c3cb2a26fc626b037121b4b5f3f57b08916196ff14e0),
block 777856, 2023-02-22, spends `37k7toV1Nv4DfmQbmZ8KuZDQCYK9x5KpzP`. I read the 2 pushed
values directly from its `scriptSig`: two distinct 320-byte strings whose SHA-1 digests
are equal (`f92d74e3874587aaf443d1db961d4e26dde13e9c`), the well-known "SHAttered"
PDF-prefix pair. Method: fetch the spending transaction, parse the `scriptSig` opcodes,
hash both pushes with `hashlib.sha1`, compare. Result: confirmed, byte for byte;
`tools/oracle.py --selftest` reproduces this exact match. Since the 4 live scripts share
the identical template with only the hash opcode changed, this certifies that the
predicate reading is correct for all 5, and that Bitcoin actually pays out on a
satisfying witness. Date: 2026-08-16.

## 3. Literature check for the 4 live functions

Not a compute run: a review of published cryptanalysis results. SHA-256 and HASH256 (its
double-application): the best public collision attacks reach 31 to 38 of 64 rounds; no
result threatens the full function, so the 2^128 generic bound stands. RIPEMD-160 and
HASH160 (its composite with SHA-256): the best public reduced-round collision results
reach about 30 of 80 steps; no full-function collision has been published, so the 2^80
generic bound stands. Result: no known shortcut for any of the 4 live bounties. Date:
2026-08-16 (a literature position, not a dated experiment; re-check periodically).

## 4. No search run

No brute force, no GPU allocation, and no solver has been run against any of the 4 live
targets. The predicate offers no shortcut over the generic collision problem for any of
the 4 hash functions, so there is no bounded space to search; this is a standing bet on a
cryptography result that does not exist yet, not a computation to schedule.
