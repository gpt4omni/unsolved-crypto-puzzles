# Negatives ledger: Walking Banks

Every row is oracle-checked against `tools/oracle.py` (published xpub, account-level compressed
key and chain code, byte for byte) unless noted as a direct text search that produced no
candidate to test. Witness: the oracle correctly reproduces the two known treasure addresses and
the public 24-word BIP39 test vector (see the README "Certified against"). Source: session notes
dated 2026-08-15, folder results.

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| Other 20+ letter concatenated blocks matching the chapter 11 pattern, searched across the whole book (OCR layer and PDF text layer) | whole book | string search | only the known chapter 11 block found | yes: the known block is the search target | 2026-08-15 |
| Typographic marking (italics, bold, font, color, vertical offset, invisible text) across all 87 embedded PDF font subsets | full font-span XML data | span diff against `walkingbanks_pdftohtml.xml` | negative, except recovering the already-known italic block | yes: known block recovered | 2026-08-15 |
| Acrostics: first/last letter of each typeset line (5,998), paragraph (1,655), sentence (4,349), for BIP39 words 5+ letters | about 60,000 words scanned | manual extraction plus oracle | 2 words 5+ letters found at chance level ("slice", "asset"), no structured signal | yes: oracle certified | 2026-08-15 |
| Word-initial or word-final letters of consecutive words spelling a BIP39 word 6+ letters | full book | manual extraction | 31 distinct hits, all explainable as ordinary text ("estate" x10, "thought", "rather") | uncertified (manual, not oracle-run) | 2026-08-15 |
| Seed reconstruction from repeats, permutations and rotations of the known group-3 words (`crystal small advice reflect`) alone | all orderings of the 4 known words | oracle, BIP39 checksum filter first | 0 checksum-valid 24-word seed matches the target | yes: oracle certified | 2026-08-15 |
| "One word per section" hypothesis: 25 narrative sections (preface, prologue, 21 chapters, epilogue, afterword), 52 selector variants (first/last BIP39 word, length thresholds, rarest, most frequent) times 2 section-splitting schemes into 24 slots | 104 candidate readings | oracle | 0 valid matches | yes: oracle certified | 2026-08-15 |
| Italics-as-message and OP_RETURN and block-height hypotheses: 15 italic lines, block 922,023 (the novel's own referenced block), block 958,522 (mined 2026-07-18, checked live), the two funding transactions, audiobook MP3 ID3 tags, and the walkingbanks.com site's own mini-game (`crypto.getRandomValues`, confirmed random) | small, enumerated | direct inspection | all negative, no hidden text or structured content | uncertified (direct inspection, not oracle-run) | 2026-08-15 |
| Frequency-exactly-3 words across the whole book (testing the "error correction" repeat pattern as a general marker) | 119 words at exactly 3 occurrences | manual review | no additional structured group found | uncertified (manual review) | 2026-08-15 |
| Full audiobook-versus-PDF diff, 25 tracks (about 6.5 hours), Whisper transcription aligned word by word | full narration | `src/diff_audio.py` | text identical to the PDF everywhere; the chapter 11 block is narrated without its `iii`/`x` separators, no added content | yes: alignment checked chapter by chapter | 2026-08-15 |
| Full reread of the 530-event Nostr history across 10 relays | 530 events | manual review | only the quotes in `clues/author-posts.md`; no clue posted after 2026-03-16 | uncertified (manual review) | 2026-08-15 |

Cumulative: no additional seed word recovered beyond the 4 in the chapter 11 block. The
mechanical and structural search space of the published text is thoroughly mapped; nothing found
argues the remaining 5 organ-donor groups are encoded in the free PDF at all.
