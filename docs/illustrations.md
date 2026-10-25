# Illustration conventions

Location: `<slug>/images/`. Generator: `<slug>/tools/fig_<name>.py` for anything computed
(matplotlib, PIL, graphviz via the `graphviz` Python package or a `.dot` file next to it).
Hand-written SVG is allowed for diagrams with fewer than 20 nodes and must be readable in a
text editor (no minified paths, no embedded rasters).

Format: SVG for diagrams and timelines; PNG for annotated raster images and plots with many
points; never JPEG for illustrations (JPEG only for author-published originals that were
JPEG).

Limits: SVG <= 300 KB; PNG <= 500 KB, <= 1600 px long side, `dpi=150`.

Naming: `images/<nn>-<type>-<subject>.<ext>`, e.g. `01-pipeline-derivation.svg`,
`02-timeline-funding.svg`, `03-annotated-puzzle-regions.png`, `04-coverage-tested-space.png`.
`nn` follows the order of first reference in the README.

Embedding: `![<alt text: what the figure shows in one sentence>](images/01-pipeline-derivation.svg)`
followed by an italic caption line: `*Figure 1. <what it shows, from which data file, date>.*`

## Honesty rules

- Every number in a figure comes from a file in `data/` or from `analysis/tested.md`; the
  generator script reads that file, never hard-codes results.
- Coverage figures show only what was tested, with counts. Untested regions are labeled
  "not tested", never shaded as if measured.
- Annotated puzzle images keep the original pixels underneath; annotations are boxes, arrows,
  labels in one accent color; the un-annotated original stays in `clues/`.
- Timelines use real block heights and dates from the chain; each event has a txid in the
  script.
- No decorative figures. If a figure has no data behind it, it is a diagram (pipeline or
  structure) and says so in the caption.
- Consistent style: white background, one sans-serif font, one accent color for "unknown"
  (orange), one for "confirmed" (blue), gray for "tested negative". Same palette in every
  folder.

## Palette

| Meaning | Color | Hex |
|---|---|---|
| Unknown | orange | `#E07A1F` |
| Confirmed | blue | `#1F5FBF` |
| Tested negative | gray | `#9A9A9A` |
| Background | white | `#FFFFFF` |

Font: DejaVu Sans, for both matplotlib figures and hand-written SVG text. Keep this palette
and font identical in every folder so a reader who has seen one figure can read any other
figure in the repository without a new legend.

## Illustration types (menu)

| Type | When | How | Obvious candidates |
|---|---|---|---|
| 1. Derivation pipeline | Mechanism known: clue to key to address | graphviz LR, boxes = objects, edges = transforms with names (sha256, BIP39, PBKDF2, hash160) | GSMG (stage chain and final oracle), Corey Phillips, RushWallet, Aoi Quizchain, Andy Bauch (brick raster to minikey), Arweave 3/10/12 (SHA512^n then AES), Ballet BIP38 EC-multiply, bc1q21 (P2SH oracle), Finlow (footnote to figure to XOR) |
| 2. On-chain funding timeline | Escrow with more than one funding event, or a trap in the counters | matplotlib horizontal timeline, one marker per tx, labels = amount and block; script lists txids | Prometheus (21,000 sats test tx trap), Dug (3 addresses, sweep by third party), Objective Thune (2020-01-03 and 2020-06-19), Aoi (2 escrows), Peter Todd (4 scripts, SHA-1 sibling swept 2023), GSMG (125 tx) |
| 3. Annotated puzzle image | Image puzzles: show which region encodes what | PIL boxes and labels on the original; legend | BLM collage (clock, runes, micro text), Arweave 11 (alpha map, tEXt decoy), Zden LVL5 (8x8 rectangles O/I/S), GSMG 14x14 grid (spiral order, invisible fifth color), Keysa card (row ends, the 20 px gap after "mad"), Andy Bauch COG panel |
| 4. Seed slot grid | BIP39 seed puzzles with partial knowledge | SVG grid 12 or 24 cells: confirmed word (blue), candidates listed (orange), unknown (gray) | Walking Banks (4/24), Noizat (7/24 fixed), Luckylurker (4/12), School of Bitcoin (1/12), Guntis (anchors at 1, 5, 12), Exitonly (7/12), Dug (solved: 12/12 with the two-letter error) |
| 5. Coverage of tested space | Many hypothesis families with counts | matplotlib horizontal bars, log scale, one bar per family, label = count and witness yes/no; a heat map only when the space is 2D (word position x candidate) | Keysa (9 families), Corey Phillips (rockyou, combinator, themed), RushWallet (95 M by corpus), Guntis (R1, R2, S1), Noizat, GSMG (335 M masks) |
| 6. Structure diagram | Puzzle is a tree, chain, or grid of sub-puzzles | graphviz or SVG; nodes colored by state (solved, gated, open) | Smith Lyle Moore (Wix page tree, 4 branches, gated pages), FTPK (12 games grid with status), Finlow (12 lots by chapter and figure), Aoi Quizchain (blocks), Zodomo (schemes 869 vs 993), Teikhos (4 contracts, ecrecover) |
| 7. Measurement plot | A physical measurement carries the argument | matplotlib from a CSV in data/ | Zden HALV (lobe cap-width per lobe, capacity 118 bits), LogicBeach (spectral energy above 13 kHz near 0), Keysa (inter-word pixel gaps), Bitaps (entropy loss from the igam defect, ~125 bits) |
| 8. Solved sibling calibration | An oracle is certified against a solved sibling | small pipeline with the sibling's real values in the boxes | Ballet AA007448, Arweave #8, Finlow EN_hard_2 (7 rows XOR), RushWallet #17/#28, Aoi Block 77 Stage One, FTPK season 1 example |

Minimum per folder: big prizes get 2 or more figures (pipeline plus one of types 2 to 7),
mid prizes 1 or more, small prizes 0 or 1, solved 2 (pipeline and payout timeline), dead
ends 0 or 1 (a timeline or structure that shows why it is dead: Commander U hint parts,
Teikhos contract flow).
