# Open leads: Peter Todd hash-collision bounties

Full notes. The README shows the ranked summary.

## 1. A published practical or academic collision on a live target

The only event that changes this puzzle is a genuine, practical full collision on SHA-256,
RIPEMD-160, or their composite forms HASH160 and HASH256, published the way SHAttered was
for SHA-1 in 2017. This is a cryptography research result, not a search I can mount or
schedule. What would confirm it: an academic paper or public disclosure with a verifiable
example pair. What would let me claim it here: feeding that pair straight into
`tools/oracle.py`.

## 2. RIPEMD-160 and HASH160 as the most-watched sub-targets

Of the 4 live functions, RIPEMD-160 (and its composite, HASH160) carries the smallest
generic bound (2^80 versus SHA-256's 2^128) and the more active reduced-round literature.
If any of the 4 falls first, this is the most likely candidate. Not an action, a
prioritization for what to watch.

## 3. Passive monitoring

I recommend watching the `spent` flag on the 4 live addresses, to catch a third party
claiming first, and watching RIPEMD-160/SHA-256 collision announcements. This is not yet
set up as a running watch; it is a zero-cost thing to check periodically alongside other
folders.
