# Open leads, ranked

## 1. A systematic LSB scan of the continuous grayscale and alpha channels (hours)

Every candidate tried so far reads the geometry (building heights, widths, roof lines) or the
container metadata as a whole value, hashed as a block. What has not been run is a bit-level
scan of the 2 continuous 8-bit channels (grayscale, 256 levels; alpha, 26 distinct values
observed) with a tool built for exactly this, such as `zsteg -a` or `stegoveritas`, keeping only
a 64-hex output that derives exactly to the target address. This is the most direct reading of
the author's own hint that "format does not matter," which argues for a payload in the pixel
values themselves rather than in any container structure. Confirms: an extracted 64-hex string
derives the target address exactly. Kills: an exhaustive bit-order and bit-width sweep of both
channels with no address match, which has not yet been run to exhaustion.

## 2. Join the community Telegram group and search first-hand for the "$100" hint (needs a
person)

I already searched a full local archive of `@arweavep` (55,002 messages, November 2021 to May
2026) and found no later message announcing new hints, plus 47 messages from other members
independently confirming the promised follow-up never arrived. That closes this as a lead
inside the archived window. What remains untested is anything posted before the archive's
start (the announcement itself is from April 2020) or through a channel the archive does not
cover, such as a direct message or a since-deleted post. Confirms: a member with early access
to the group, or Tiamat directly, produces a hint not present in the archive. Kills: nothing
further can kill this lead technically; it depends on information I do not have a channel to.

## 3. Puzzle #9's real solving method, if it ever surfaces (needs new information)

Tiamat described puzzle #9 as "similar" to #11, and #9 was swept by an anonymous solver in
2020 who never published a method; multiple community members describe the last step as
"forced" (brute-forced), not derived from a stated rule. If a #9 write-up ever surfaces, it
would give a real, oracle-certifiable answer to calibrate #11's harness against, which is
exactly what this folder is currently missing. Confirms: a published #9 method that this
folder's harness can reproduce byte-exact, at which point the same method becomes a certified
candidate class for #11. Kills: nothing; this is a standing watch item, not an active search.
