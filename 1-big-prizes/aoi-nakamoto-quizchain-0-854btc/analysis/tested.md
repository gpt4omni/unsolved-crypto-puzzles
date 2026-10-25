# Tested hypotheses, full ledger

Summary table is in the README. This file has the full detail behind each row.
All figures are re-read from the private research's own dated result logs before
being written here.

## Real Big Block (0.777 BTC)

The mechanism is certified (the case-flip rule reproduces the solved sibling lot
Block 77 Stage One exactly). What is not established is exactly which paragraphs
of the "Second" chapter the author modified on 2019-07-30, and the precise text
she copied. Every row below tests a specific hypothesis about that, against both
the current escrow (`14zMkTgaVXJcxdh4JdWi29MLRR44iUSG9W`) and its superseded
predecessor (`1EFojcAo2vbhRGCGCa7q8Wwvzss28mhQYC`).

| Hypothesis family | Candidates | Result |
|---|---|---|
| Chapter unmodified, every plausible serialization (line-break style, encoding) | approximately 150,000 | 0 match |
| Certified case-flip rule applied to the 3 planted paragraph groups plus the Finney quote, 16 combinations, both letter-position modes | approximately 200,000 | 0 match |
| Every subset of the 17 candidate paragraphs (2^17), 18 serialization variants | 2,360,000 | 0 match |
| Paragraphs selected by a name or word ("Satoshi", "Aoi Nakamoto", "Hal Finney", "Grycoin", and 7 more), by first letter or first character | approximately 10,000 | 0 match |
| Every paragraph starting with F or W (and F, W, H) | approximately 1,000 | 0 match |
| The certified groups plus one arbitrary extra paragraph | 13,000 | 0 match |
| The certified groups plus two arbitrary extra paragraphs | approximately 600,000 | 0 match |
| The single-word planted correction from block 29 ("voice" to "vOIce"), alone and combined with the groups | 6,000 | 0 match |
| Block-29-style link suffixes appended to the text | 8,000 | 0 match |
| Chapter subsections read alone | 3,000 | 0 match |
| Page-level prefixes (duplicated title, author byline) | 2,000 | 0 match |
| A simulated Chromium browser copy (selection/innerText rendering rules) | 1,000 | 0 match |
| Alternate text encodings (Latin-1, UTF-16, cp1252, NBSP normalization) | 3,000 | 0 match |
| Simulated-browser-copy base combined with the name/word selectors, then with all 2^17 paragraph subsets | approximately 800,000 | 0 match |
| A single invisible character (BOM, zero-width space, tab, and 6 more) inserted at the start or end | 5,000 | 0 match |
| Paragraphs selected by the letters of "Satoshi Nakamoto" specifically (a refinement of the name-selector row above, after finding the Finney post has a paragraph starting with M) | 60 | 0 match |
| Last-letter-only or first-letter-only variants of the case-flip rule, on the certified groups | 456 texts (2,736 address checks across derivation indices) | 0 match |
| All of the above serialization families repeated under CRLF line endings | 2,448 texts (14,688 address checks) | 0 match |
| 1 to 3 single-letter case toggles across all sign positions, and 1 to 2 across all paragraph boundaries | 1,450,000 | 0 match |
| Every single-character edit (insert, delete, replace, case toggle) at every position, across 40 base texts (5 paragraph-set choices x 2 NBSP conventions x 2 line-ending conventions x 2 separator conventions) | 266,038,400 | 0 match |
| 2019 Wattpad reader-page copy families not in the rows above: the 12 live API pages and their 1-to-k prefixes; parts I/II/III; Finney-quote slice; drop title / drop headings; header "Second" and "by AoiNakamoto"; SSR 30-space indent inside `<pre>`; reconstructed empty paragraphs as a NBSP line or a space line; in-paragraph `<br>` split into extra paragraphs; joins `\n`, `\n\n`, `\r\n`, `\r\n\r\n`; NBSP kept or turned to space; Stage One case-flip on first character and on first letter; leading/trailing LF; chapter URL suffix | 12,848 unique texts (12,851 including 3 planted witnesses) | 0 match |
| 2019 Common Crawl / userstyle copy families not in the rows above: SSR indent of newline plus 26 spaces (the width in July 2019 story HTML, not the live 30); the same indent with CRLF; empty paragraphs stored as `<p><br></p>` inserted between every pair, or only after heading paragraphs, then joined as plaintext or with the 26-space indent; author's `13 10 13 10` join with those empty paragraphs; Stage One flip; `<br>` splits; NBSP kept or turned to space | 3,030 unique texts (3,033 including 3 planted witnesses) | 0 match |
| Every contiguous span of 2 or more of the 273 paragraphs (copy-paste of a start-end range): Stage One keep-test on first character and on first letter; no flip; joins `\n`, `\r\n`, `\n\n`, `\r\n\r\n`; NBSP kept or turned to space when the span contains any; leading/trailing spaces stripped when the span has edge spaces | 1,469,908 unique texts (1,469,911 including 3 planted witnesses) | 0 match |
| Bounded 2-edit on the full 273 paragraphs: every subset of the 6 in-sentence NBSPs turned to space; and every pair of paragraph-joins swapped between `\n\n` and `\r\n\r\n`; three keep-tests (none, first character, first letter) | 221,520 unique texts (221,523 including 3 planted witnesses) | 0 match |
| The rule paragraph 227 of the chapter dictates itself: flip every paragraph whose first letter is not I, T, A, S or M, skipping the 63 opening quotes that had hidden 118 candidate paragraphs from the earlier first-character test; 3 flip modes; joins `\n\n` and `\n`; with and without trailing newline; indices 0 to 5; both escrows | about 500 | 0 match |
| The 3 planted paragraph groups under a SHA-256 to 24-word BIP39 derivation instead of MD5 to 12 words (8 group combinations, 3 modes, 2 joins, 2 tails) | 96 | 0 match |
| In-paragraph `<br>` treated as a paragraph boundary (283 paragraphs) with the paragraph-227 rule | 6 | 0 match |
| Each section alone (I. Second Life, paragraphs 3 to 52; II. Grycoin, 88 to 161; III. Identity, 163 to 272; the Satoshi Code passage, 174 to 245), with and without the planted groups flipped | 96 | 0 match |
| The chapter's 2 abnormal capitals (`VIrgin` in paragraph 127, `BItcoin` in 135) as a selector or as a "twist" correction, with and without the groups | 64 | 0 match |
| Every pair of boundary edits on 16 certified bases: one invisible character (NBSP, ZWSP, BOM, TAB, CR, LF, SP) inserted at any 2 paragraph joins, or 1 insertion plus 1 case toggle of a boundary letter; 8 keep-sets of the 3 groups with the Finney quote and 8 without, across joins, trailing newline and NBSP conventions | 48,379,696 | 0 match |

Witness status: every row above 2026-08-15 used the oracle certified against Block 77 Stage
One (see README, "Certified against"); the single-character-edit row additionally
planted 3 synthetic witnesses per base text (head, middle, tail) and recovered
all of them on all 40 bases, plus recovered the real Stage One text and address
when run as a 41st base. Dates: those rows 2026-08-15.

The 2026-08-27 Wattpad-copy row used `tools/oracle.py` `attempt()` (MD5 to BIP39 to
BIP44 indices 0 to 5, compared to both listed addresses). Witness: 3 synthetic
two-paragraph texts planted at head, middle and tail of the same generator were
all recovered before the run was accepted. Rate: 503 candidates/s. Date:
2026-08-27. This row is a targeted test of copy/serialization families grounded
in the live reader DOM/CSS and in the author's 2019-07-28 / 2019-08-01 ASCII
notes; it is not a sweep of every paragraph subset.

The 2026-08-27 2019-CSS/editor row used the same `attempt()` path. Witness: 3
synthetic two-paragraph texts planted at head, middle and tail of the same
generator were all recovered before the run was accepted. Rate: 534
candidates/s. Date: 2026-08-27. Grounded in July 2019 Common Crawl story HTML
(newline plus 26 spaces between `<p>` tags inside `<pre>`; empty paragraphs
still stored in other chapters that week as `<p data-p-id="d41d8cd98f00b204e9800998ecf8427e"><br></p>`)
and in a 2019-08-15 userstyle that copies Wattpad's generic
`pre { white-space: pre-wrap }` rule. It is not a sweep of every subset of
empty-paragraph positions.

The 2026-08-27 contiguous-span row used the same `attempt()` path. Witness: 3
synthetic two-paragraph texts planted at head, middle and tail were all
recovered before the run was accepted. Rate: 530 candidates/s. Elapsed: 2,774 s.
Date: 2026-08-27. This is a complete sweep of its stated space: every start-end
pair with length at least 2, under the joins and keep-tests listed in the row.
It is not a sweep of non-contiguous selections.

The 2026-08-27 bounded-2-edit row used the same `attempt()` path. Witness: 3
synthetic two-paragraph texts planted at head, middle and tail were all
recovered. Rate: 514 candidates/s. Date: 2026-08-27. This is a complete sweep
of the two stated 2-edit families on the full chapter only; it is not the
unbounded 2-character space, and it is not the 40-base 1-character sweep
repeated.

Cumulative for Real Big Block: approximately 272 million candidates tested
through 2026-08-15, plus 12,848 unique 2019-copy serializations, 3,030 unique
2019-indent/empty-`<p><br></p>` serializations, 1,469,908 unique contiguous
spans, and 221,520 unique bounded 2-edits on 2026-08-27, 0 match. The
single-character-edit sweep accounts for the large majority of this total.
Two rows are certified as complete sweeps of their stated space: that
1-character sweep (all 40 bases, every single edit) and the 2026-08-27
contiguous-span row (every start-end pair of length at least 2, under the
listed joins and keep-tests). Every other row is a targeted, not exhaustive,
test of one specific hypothesis about which paragraphs were modified.

The 2026-08-21 rows (chapter-dictated rule, SHA-256 24-word derivation, `<br>`
boundaries, sections alone, abnormal capitals) used an oracle rebuilt that day
that reproduces Block 77 Stage One from the Finney post byte for byte. The base
text was re-pulled from the Wattpad API the same day: 273 paragraphs joined with
`\n\n` plus a final `\n` are exactly 45,451 characters, the `length` the API
declares, with 6 NBSPs, straight quotes, no HTML entities and 10 internal `<br>`.
Date: 2026-08-21. A brainwallet reading (MD5, SHA-256 or double SHA-256 of the text
used directly as the private key, compressed and uncompressed, 96 variants) is also
0 match but uncertified, since no known-good vector exists for that reading.

The 2026-08-23 boundary 2-edit row reuses the certified GPU derivation (MD5 on CPU
in a process pool, BIP39 12 words to `m/44'/0'/0'/0/i` hash160 on the GPU) against
the current escrow, the superseded 2019-07-24 escrow and Stage One at once. Witness:
4 synthetic texts per base (3 pairs of insertions at offsets in the head, middle and
tail, 1 mixed insertion plus case toggle) with addresses computed on the CPU, all 4
recovered on every one of the 16 bases, plus the real Stage One text. Rate: about
223,000 candidates/s, bounded by the MD5 of a 45 KB text on the CPU, about 2 minutes
per keep-set. Date: 2026-08-23. This space was the only one of 10 Real Big Block
spaces listed in a reader's private GPU plan that this ledger had not already
covered; the other 9 coincide with rows above (about 272 million candidates in both
tallies).

What the 2026-08-23 row establishes: if the remaining "twist" is a copy artefact,
it is 3 or more edits, or it sits inside a paragraph rather than at a join (all
positions at 2 edits is about 1e14, out of bounded reach), or the author's source
differs from today's Wattpad storage, for which no 2019 copy exists.

A second 2026-08-27 run, over Finney-pattern groups and first/last N-paragraph
chunks, is also a negative. Method: `tools/oracle.py` certified on Block 77
Stage One, with a synthetic witness recovered at the head of the run. Rate:
522 candidates/s. Date: 2026-08-27.

| Hypothesis family | Candidates | Result |
|---|---|---|
| Full current Wattpad serializations (API, innerText, selection, body markers) with Stage One case-flip, title/heading prefixes, NBSP/unicode-space normalization, LF/CR/CRLF/double-CRLF separators | 115 | 0 match |
| First/last N-paragraph chunk serializations (sizes 10-273) with the same flip/prefix/separator/normalization variants | 2,290 | 0 match |
| Full-chapter serializations with all three flip modes (none, full first+last, first-only) and the author-stated CRLF/double-CRLF separators | 351 | 0 match |
| Four Finney-pattern paragraph groups (three planted at section starts plus the Finney quote): natural and F-F-W-I-W reordered, all subsets/permutations, whole or non-sign-only, three flip modes, quote stripping, title prefixes, LF/CR/CRLF/double-CRLF separators | 15,165 | 0 match |

N = 17,921 unique candidates, 0 match. Some of these overlap the 2019-copy
families above; they are kept as a separate count because the Finney-group
permutations and the first/last N-paragraph chunks are not those rows.

## Quizchain2 Block 76 (0.077 BTC)

The chain a community player found in 2019 (`solution = "format"`,
`TOMI = "before TOMI"`) satisfies both of the author's published MD5-prefix
hints, but no standard BIP44/49/84 derivation, derivation path, or passphrase
variant of it produces the escrow address. Two later calibration checks (blocks
73 and 74, both already solved and swept, not part of the live prize) confirm
the derivation code itself is correct, and a later cross-check on 2019-07-29
comment timing suggests the "format" chain was itself a false positive found by
searching for strings that pass the 2 published prefixes, rather than the
author's real answer, since the author never corrected the block after seeing it
posted publicly (see README).

Standard-derivation sweep on the `format`/`before TOMI` chain:

| Hypothesis family | Candidates | Result |
|---|---|---|
| BIP44, BIP49, BIP84, accounts 0 to 4, external and internal chains, index 0 to 199 (BIP44 external: 0 to 1999) | standard derivation space | 0 match |
| Non-standard derivation paths (Coleman-style m/0'/0/i, m/0/i, m/0', root key) | small, enumerated | 0 match |
| Passphrase variants ("TOMI", "format", "before TOMI", bracket and whitespace forms) | small, enumerated | 0 match |
| Alternate entropy functions (SHA-256 as a 24-word mnemonic, SHA-1, RIPEMD-160, truncated SHA-512, double MD5) | small, enumerated | 0 match |
| Off-by-one word at BIP39 import (12 positions x 2,047 alternate words each) | 24,564 | 0 match |
| Word order reversed | 1 | 0 match |

Word-transform "salves" on the question "change to" / "from change to" (each
family's candidate solution strings tested through the same 2 MD5-prefix filters
before any derivation; only pairs passing both filters were derivation-tested):

| Salve | Candidate solutions | Passed prefix 1d | Passed both filters (derivation-tested) |
|---|---|---|---|
| Single-letter edits, anagrams, Atbash/ROT/foldover, translations of "change" | 7,730 | 32 | 3,506 TOMI pairs, 0 match |
| WordNet synsets and hyper/hyponyms of change/alter | 20,199 | 74 | 8,806 TOMI pairs, 0 match |
| Wikipedia article titles containing "change" | 14,666 | 44 | 4,949 TOMI pairs, 0 match |
| Sentences from Satoshi/Hal Finney bitcointalk posts and emails containing "change to" | 46 | 0 | n/a |
| Sentences from bitcointalk posts numbered 60 to 94 (2 orderings) | 1,992 | 11 (noise) | n/a |
| Strings built from the number 76 (years, technical constants, ordinals) | 3,779 | 23 (noise) | n/a |
| Encodings of "change" (hex, base64, NATO alphabet, Morse, keyboard shift) | approximately 130 | 1 (noise) | n/a |
| "changeto" (no space) combined with TOMI variants | 1 | 1 | 1,701 TOMI pairs, 0 match |
| Every address and txid from the author's 158 other funding transactions | approximately 1,500 | 4 (case noise) | n/a |
| Renaming candidates ("wealth", "legacy", and similar) | 45 | 0 | n/a |
| An Easter/resurrection word family, echoing the same block number in round 1 | 2,752 | 17 (noise) | 5,857 TOMI pairs, 0 match |
| Halving-related terms | 45 | 1 (noise) | n/a |
| Grycoin/burn-address/second-layer terms from the chapter | 60 | 0 | n/a |
| Literal strings and typos from the block's own post | 45 | 0 | n/a |

A separate "post-number-as-index" method, confirmed on 3 other blocks in the
series (numbers 56, 57 and 58 each index a specific post or tweet by Satoshi or
Hal Finney, by position), does not carry over to block 76: post number 76 in
every corpus and ordering tried (Satoshi's bitcointalk posts newest-first and
chronological, Hal Finney's posts, Hal Finney's tweets) contains neither "change"
nor "from".

A large dictionary-times-corpus sweep tested every 1-to-4-word phrase built from
the author's own writing (Reddit posts, comments, and Wattpad chapters) as a
candidate TOMI value, against a dictionary-and-WordNet-derived candidate solution
list: 189,565 candidate solutions passing the first filter, times 656,845 to
1,250,000 candidate TOMI phrases depending on the pass, for a combined total of
approximately 3.2x10^11 MD5 computations and approximately 78 million full
address derivations on the pairs that passed both filters. 0 match. The
derivation code was re-confirmed correct on both calibration blocks (73 and 74)
at the head, middle and tail of this run.

Cumulative for Block 76: approximately 78 million address derivations from the
scripted dictionary sweep, plus approximately 53,000 smaller thematic candidates
across the 14 salves above, plus the full standard-derivation sweep on the one
chain found by search. 0 match anywhere. This is reported as a targeted, not
exhaustive, negative: the true solution may use vocabulary outside the corpora
swept (the author's own writing and 2 general-purpose dictionaries), and the
block may simply be misconfigured (see README).
