# Contributing

This repository tracks public crypto treasure-hunt puzzles that are still funded: escrow
addresses, author clues, what has been tested, and open leads. Solved and swept puzzles are
removed and recorded in `verification/REMOVED.md`.
Contributions follow a few rules so the catalogue stays accurate and safe to build on.

## If you solve a puzzle

Sweep the funds first. Then open an issue titled "SOLVED: `<slug>`" with the payout txid and,
if you wish, the derivation. Do not post keys or seeds before sweeping. Once the sweep is
confirmed on chain, I will remove the folder and record the solve, the payout txid and your
credit in `verification/REMOVED.md`.

## If you rule something out

Open a pull request adding a row to `<folder>/analysis/tested.md` with the count, the method,
the witness, and the date. Include the script under `<folder>/tools/` if it is new. Rows
without a witness are accepted, but only labeled "uncertified": say so plainly rather than
presenting an unwitnessed negative as proof.

## If you find a lead

Open a pull request adding an entry to `<folder>/analysis/leads.md` describing what the lead
is and what would confirm or kill it.

## If an escrow moved

Open an issue with the txid. I will re-check the chain and remove the puzzle if its state
changed to swept or solved.

## What gets rejected

- Copyrighted material: book text, ebook files, audiobook audio or transcripts, full articles,
  forum dumps, wordlists, chain data dumps.
- Lists of "near candidate" values that a reader could mistake for a claim on an unsolved
  puzzle.
- Hype, marketing language, emoji, em dashes, curly quotes.
- Absolute filesystem paths in scripts or docs.
- Files above the size limits in `docs/methodology.md` and the per-puzzle folder layout.
- Anything that fails `python3 tools/validate.py --folder <slug>`.

## Credit and tips

Contributions are credited by handle, either in the folder's "Sources" section or in a
"Credits" line under the folder's Summary. Tipping is between you and the reader; I do not
solicit tips and no address in this repository should be read as a request for one.
