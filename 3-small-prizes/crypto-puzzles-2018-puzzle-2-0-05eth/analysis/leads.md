# Open leads, ranked -- Crypto Puzzles 2018 Puzzle #2

Supersedes the "Open leads, ranked" section of this folder's README as of 2026-08-18,
and supersedes an earlier draft of this file written the same day (see "Correction" at
the foot). Both of the README's first two leads are now closed or refuted.

## 1. Obtain a source that shows the full glyphs (NEW, top rank, needs a person)

This is the whole puzzle now. tested.md rows 8 and 12 measure the glyphs as truncated in
both videos: in part 1 every live glyph carries full-strength ink in column 639 with no
taper, and in part 2 the column window is hard-cut at x=331. The characters continue past
those boundaries and those pixels are not in either published file.

At 360p, which is the only rendition served, the recoverable payload is 2 characters out
of 64. No processing closes that gap, because it is not a processing problem.

What would close it: the original uploads at native resolution, an archived copy
predating the current transcode, a mirror of the videos posted elsewhere in 2018, or any
still frame published by the author or a contemporary solver. The channel has 5 videos and
about 785 combined views, so a contemporary re-upload is unlikely but a single archived
frame would be worth as much.

## 2. Read the two characters that are recoverable, and use them as a check (done, keep)

Part 2's static block yields `C` (0.771) and `8` (0.849) against the labelled template
library, in that order once the MIRROR flip the video itself asks for is applied. These
are the only two characters anyone should currently treat as known. They are worth
keeping as a constraint on any future full read: whatever a better source yields must
agree with them.

## 3. Re-use the labelled template library (NEW, tooling)

tested.md row 4 builds what the README's old lead 2 only planned: Puzzle #1's solution
screen segmented into its 64 characters and labelled from the published answer, giving
averaged templates for all 16 hex digits at 96.9% self-classification. It is worth
committing to `tools/`, because it is reusable for any future source of this puzzle and
it removes the eyeball step from every reading claim. Classification alone is not the
bottleneck; complete glyphs are.

## Closed and refuted

- **"Replay Puzzle #1 end to end to fix the reading grammar"** (README lead 1). Done. The
  grammar does not transfer: Puzzle #1 renders its key directly at low contrast, Puzzle #2
  truncates rotated glyphs at a boundary. Puzzle #1 certifies the technique and the
  letterforms, nothing about the reading rule.
- **"Finish the planned template-matching pass"** (README lead 2). Done, as row 4 and row
  9. It resolves that the glyphs are rotated 90 degrees, and it cannot do more than that,
  because matching incomplete glyphs against complete templates caps the correlation at
  about 0.57 and leaves the three 90-degree variants disagreeing.
- **"Bounded fallback if a small gap remains"** (README lead 3). Not reachable. It assumed
  8 or fewer characters undetermined; the true figure is 62 of 64.
- **Part 2 as the complementary halves of part 1.** Refuted by tested.md row 10: part 2
  has no edge-touching content in any of its 901 frames.

## Correction to an earlier draft of this file

An earlier draft ranked "apply the MIRROR instruction as part 2's governing transform"
first and "subtract the static decoy, then re-read seam 1" second. Both have now been
carried out and neither is a live lead.

The MIRROR rule is real and worth keeping -- it is what makes `C` and `8` readable -- but
it applies to one static block and yields those two characters only, not a transform that
unlocks the rest. Decoy subtraction works exactly as predicted, and it turned out to be
beside the point: the decoy never overlaps the payload glyphs, since the payload occupies
frames 610-618 and the decoy only appears from 621. That earlier draft also repeated the
claim that payload glyphs wrap the frame edge, which tested.md row 7 refutes.
