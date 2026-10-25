# Negatives and structural findings, Crypto Puzzles 2018 Puzzle #2

This folder previously carried its ledger inline in the README's "What has been tested"
table. Those two rows are reproduced as rows 1 and 2. Rows 3 to 12 are new, dated
2026-08-18.

Headline: **no 64-hex candidate has been assembled by anyone, and on this pass only 2 of
the 64 characters could be recovered with confidence.** The cumulative candidate count
against the escrow remains 0. The reason is given in rows 8 to 12: the glyphs are cut off
by the frame boundary in part 1 and by an internal window in part 2, and the missing
pixels are not present in either published video.

| # | Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|---|
| 1 | The 64-hex reading transform, applied to a known answer | 1 known vector | temporal maximum-projection across the frame sequence | reproduces Puzzle #1's answer exactly | yes: known-good input reproduced | 2026-08-02 |
| 2 | Deterministic template matching of Puzzle #2's ambiguous glyphs against Puzzle #1's known letterforms | planned, not run | would use the 16 hex-digit shapes visible on Puzzle #1's solution screen | not executed | uncertified: step never run | 2026-08-02 |
| 3 | Re-derive the reading grammar from Puzzle #1's statement video rather than its solution screen | 1 known vector | residual vs temporal median, then max projection, over `3l1jFa3Mw0s` | reproduces `4487FC620AD0C4C67E...`; Puzzle #1's grammar is a directly rendered low-contrast string | yes: known-good input re-found through the same code | 2026-08-18 |
| 4 | Build a labelled hex template library (row 2's prerequisite) | 64 glyphs | segment Puzzle #1's solution screen into 23+23+18 characters at a merge gap of >5px, label each from the published answer, average per digit | all 16 hex digits covered; 96.9% (62/64) self-classification | yes: labels are ground truth from the published answer | 2026-08-18 |
| 5 | Locate part 1's payload windows | 900 frames | wrap-aware extent of residual > 60, per frame, over `TRUUTryah70` | live glyphs frames 610-618 at the right edge; a second window frames 727-797 at the top/bottom edges | n/a, structural | 2026-08-18 |
| 6 | Isolate the static decoy | 86 frames | fit a per-frame scale of a late-frame template in fixed frame coordinates | decoy absent through frame 620 (alpha ~0), present 621-691 decaying 0.90 to 0.23; subtraction drives frames >=630 to zero residual, confirming those carry decoy only | yes: subtraction nulls the decoy-only frames | 2026-08-18 |
| 7 | **Do the live glyphs wrap around the frame edge?** | 24 frames | connected-component count before vs after a circular roll | **No, for the payload.** Frames 610-618 are a single 33px component touching the right edge only; rolling does not merge anything. Frames 619-633 are two components that a roll merges into one 58-61px object, and that object is the decoy. The thing that wraps is the decoy, not the payload | n/a, structural and exhaustive over the window | 2026-08-18 |
| 8 | Are the live glyphs cut by the frame boundary? | 7 live glyphs | ink count in column 639 vs the glyph's own interior maximum | **Cut.** Every live glyph carries ink at column 639 equal to or above its interior maximum, with no taper to a natural stroke end. A real portion of each character lies beyond x=639 | n/a, measured | 2026-08-18 |
| 9 | Seam-1 glyph orientation | 8 orientations (4 rotations x mirror) x 5 distinct live glyphs | correlate against the row-4 template library | 90-degree rotations clearly win (rot270 mean 0.570, rot90-mirrored 0.548) over upright (0.281-0.341), so the glyphs are rotated. But peak mean correlation is 0.570 against complete templates, which is what clipping predicts, and the resulting strings are not stable across the three competing 90-degree variants. **No reading is claimed** | uncertified: the input glyphs are incomplete | 2026-08-18 |
| 10 | Does part 2 supply the clipped-off halves? | all 901 frames of `U_0DtYHDPy0` | scan every frame for residual touching any frame edge | **Refuted.** Part 2 has no edge-touching content at any frame. Part 1 has it (right 610-670, left 619-677, top 727-786, bottom 737-797). The two videos are not complementary halves | n/a, exhaustive over the video | 2026-08-18 |
| 11 | Part 2 static block under the mirror rule | frames 615-775, 8 components | connected components, horizontal flip, classify against the template library | 2 hex characters recovered with confidence: **C** (0.771) and **8** (0.849), in that reading order after the flip. The other 6 components are the letters of the word MIRROR, which the hex-only templates force onto hex classes -- a useful negative control | n/a, direct read at high correlation | 2026-08-18 |
| 12 | Part 2 alternating column | frames 778-900, 2 layers, 8 components | separate the layers by residual pixel count, classify in 4 orientations | not characters: components run to 96 and 181 pixels tall, every component spans the full window width, and no orientation exceeds 0.62. The window is hard-cut on the right (ink 125 at x=331, 0 at x=332) while tapering naturally on the left, so these are truncated glyphs, not whole ones | uncertified | 2026-08-18 |

## What this means for the folder's stated difficulty

The README says "about 40 to 50 of 64 hex characters legible today". **This pass does not
reproduce that**, and rows 8 and 12 give the reason: the glyphs are truncated in both
videos, in part 1 by the frame boundary and in part 2 by an internal window edge. Two
characters (`C`, `8`) are held with confidence and no more.

If that is right, the folder's `difficulty_left` is not `insight` but `external-info`:
what is missing is a source that shows the full glyphs -- a higher-resolution or
differently-cropped rendition -- and no amount of processing recovers pixels that were
never published. Anyone who can obtain the original uploads at their native resolution,
or an archived copy predating the current transcode, should say so before more reading
effort is spent.

## Practical notes

Only itag 18 (640x360, 30fps) is served for all five videos on this channel. YouTube also
returns HTTP 403 to the default client for these IDs; `--extractor-args
"youtube:player_client=android"` is what fetches them.

## Correction to an earlier statement of these findings

An earlier draft of this ledger said the payload glyphs "are single glyphs split by the
frame boundary and reunited by a circular roll", and treated decoy subtraction as the way
to clean them up. Row 7 refutes that: the payload glyphs do not cross the seam at all,
and the object that does wrap is the decoy. A circular roll applied to frames 619 onward
joins a right-edge glyph to an unrelated left-edge object and manufactures a chimera,
which is what produced earlier readings containing `R` and `U` -- shapes that are not hex
digits and were never really there.
