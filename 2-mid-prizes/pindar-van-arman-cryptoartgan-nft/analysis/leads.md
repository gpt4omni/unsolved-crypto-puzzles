# Open leads, full notes

## 1. Frame-by-frame analysis of the "Act 1 - Review" artwork archive

The artist has published a zip of frame-by-frame renders of the Act 1 series on Arweave:
[arweave.net/jz0h8lraiEZlzJn2_e53vNi-tg2lYNljdu6PXukb55E](https://arweave.net/jz0h8lraiEZlzJn2_e53vNi-tg2lYNljdu6PXukb55E).
On a separate journal page (bitgans.com/journal, the entry titled "Prime skullGANs"), the
artist frames a "glitch" as a genuine visual artifact tied to prime-numbered pieces. This
image archive has not been analyzed frame by frame in this research; it is the one channel
untouched by every metadata-based search tried so far, and the place where a set of exactly
11 could live without showing up in any attribute table.

## 2. Finish the on-chain metadata sweep

The 513-row table only covers pieces that were assumed to have a supply of 1 when their
on-chain token IDs were constructed. About 132 token indices between 1 and 700 return 404
under that assumption and may hide undiscovered Act 1 pieces with metadata not present in the
table used here.

## 3. A bounded 11! x 128 sweep, once an 11-word set is likely

If a specific 11-word set becomes a strong candidate without its exact order being known,
checking all 11! orderings against all 128 checksum-valid 12th words is a bounded computation
(reported at roughly 59 hours on 24 CPU cores), not an open-ended brute force. This is a
proposal to run once a specific set is argued for, not a search to run blindly across many
candidate sets.
