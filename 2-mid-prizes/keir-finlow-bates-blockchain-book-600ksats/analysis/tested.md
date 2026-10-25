# Tested (full negatives ledger)

The summary table in `README.md` shows the highlights; this file is the complete record
for the 3 open lots (EN_medium, EN_veryhard, IT_veryhard). All rows use the sha256x3
oracle in `tools/oracle.py`, certified against the solved lots EN_easy_1 ("221B Baker
Street"), EN_easy_2 ("9781688289970") and IT_hard ("Genova Firenze Bologna Brindisi"):
the same code that failed to match any candidate below is proven, on those three lots, to
match the correct answer exactly. Since 2026-09-01 the oracle also checks hex-string
chaining with and without a trailing newline (see the README, Mechanism). I never repeat a row; a hypothesis retested with a different method gets a new
row.

| Hypothesis | Space (N) | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| SHA-256 applied 1 to 3 times over whole blocks of the raw book text (chapters, full text) | text blocks of both editions | same transform as the known answers, checked against all 12 addresses | 0 match. An earlier version of this row called the whole brainwallet family dead; that was wrong, since the three known answers are short strings under exactly this transform | yes: the oracle re-finds EN_easy_1, EN_easy_2 and IT_hard | 2026-07-10 |
| Systematic EN ebook mechanisms: planted numbers as signposts, flaw-and-fix to a corrected noun (10 sites), acrostic and positional reading at book scale, CHEST and discography letter extraction, section-heading to text-fragment crossings (about 120 pairs), reader-instruction sites (12 locations, the same class of clue as EN_easy_1) | approximately 5,500 candidates cumulative across these 6 mechanism classes (per-class split not separately recorded) | derived each candidate string with sha256x3, both key forms, checked against all 12 addresses | 0 match on the 3 open lots | yes: oracle certified against EN_easy_1 and IT_hard | 2026-07-18 |
| Late per-site closures: the "orange juice" flaw (Hoffman's canon is tomato juice, not orange), the EN Monopoly squares (Park Lane, Park Place, Mayfair, Boardwalk), the L606 pronoun slip | 33 candidates | same sha256x3 oracle | 0 match | yes: same certified oracle | 2026-07-18 |
| Discography reading order as a decoded site index (later refuted: the author's live Spotify playlist matches the printed order verbatim, so this was never a real signal); re-mined anyway on chapter 19 and "About the Author" | 111 candidates | same sha256x3 oracle | 0 match | yes: same certified oracle | 2026-07-14 |
| Erdos-number collaboration chain (Keir Finlow-Bates to Paul Erdos through 5 intermediate co-authors, printed only in the Italian edition's body text) | 30 candidate forms | same sha256x3 oracle | 0 match | yes: same certified oracle | 2026-07-14 |
| Pair-discipline sweep: crossing signposts (a planted detail plus a cultural reference, the same grammar that produced EN_easy_1) tested as pairs across 4 designated sites (an elephant parable, a Figure 7 caption, the Erdos back matter, a Figure 12 caption) | 146 candidate pairings | same sha256x3 oracle | 0 match | yes: same certified oracle | 2026-07-14 |

| Proof-of-work reading of Figure 11: find N such that sha256(pangram + N) has 8 or more leading zero hex digits, then use the hash, sha256(hash), sha256^2(hash) as a key, or the input string, the nonce, the lowercase or uppercase hex as an answer under every chaining convention | N < 2^33 under 4 input conventions (space or no space before N, newline or none after): 34.4e9 hashes; 1,988 nonces with 6 or more zeros kept, 8 of them with 8 zeros and 2 with 9 | `tools/pow_nonce_search.c`, 45,000,000 hashes/s on 24 CPU cores, 8 min 56 s; each kept nonce evaluated 9 ways | 0 match | yes: the book's own nonce 8 re-found (prefix 0ca85b7d); the C output is identical to an independent Python pass on the first 30,000,000 nonces of the first convention (16 hits, same nonces, same hashes) | 2026-09-01 |
| Figure 11 as a copy of the EN_hard_2 mechanism: XOR of every non-empty subset of the 9 full hashes (511 per convention), sha256 of the concatenated hashes, the printed prefixes concatenated as a 256-bit number, sha256 of the prefix string, under 4 input conventions | about 2,100 keys | direct key check, both key forms | 0 match | yes: the Figure 10 XOR re-finds EN_hard_2 | 2026-09-01 |
| Physical-only strings: ISBN-13 of the 4 print editions (9781688289970, 9781716479724, 9798725348668, 9798790431509) in every 3-hyphen split, ISBN-10 forms, "ISBN" prefixes, EAN 5-digit (00000 to 99999) and 2-digit price add-ons with and without a space; back-cover blurb sentences, 4 endorsement quotes and endorsers, 5 printed URLs and handles, the 90000 add-on, page counts 321, 339, 311, dimensions, weight, publication dates, ASINs, Google Books id | 800,800 add-on forms plus about 400 strings | sha256x3 raw chain (add-ons) and full extended oracle (strings), all 12 addresses and 5 exposed public keys | 0 match on the 3 open lots and on IT_easy | yes: the plain ISBN re-finds EN_easy_2 | 2026-09-01 |
| Proper-noun lists from the book's anecdotes (train cities, author's countries, breached sites, Buterin's cities, steam pioneers, beta readers, D&D items, cutlery orders, Elite ship labels, the 6 ring-signature names and 6 fruits in all rotations and both directions) in 8 join forms | 865 forms | full extended oracle | 0 match | yes: the IT_hard city list re-found in the same run | 2026-09-01 |
| EN "three times" winks (the Passwords chapter sentence repeated three times, the Snark line, Three Chords, the grandfather's axe), Lexington 125 address forms, Italian forms of "221B Baker Street", Figure 5 story strings, the DIY truth-table words, planted block heights 74,638 and 252,450 as block hashes, merkle roots and timestamps, the Merkle patent number, the mugshot data | about 800 strings | full extended oracle | 0 match | yes: 221B and ISBN re-found in the same runs | 2026-09-01 |
| Italian figure calques: the Italian Kindle Figure 9 bitmap re-extracted at pixel level (0 ambiguous cells), Figure 10 hash rows and Figure 17 key examples read from the page captures | 3 figures | pixel comparison, then the bitmap enumeration used for EN_medium_s | identical to the English edition; the Italian grid re-derives EN_medium_s with the same missing bits | yes: EN_medium_s re-found from the Italian capture | 2026-09-01 |

| Print surfaces read from Amazon's public "Read sample" reader (no login) for 4 physical editions: EN paperback pages 1 to 8 (title, copyright page with `ISBN: 9781688289970`, acknowledgments, table of contents), About the Author and back cover; KDP hardcover 2023 (same interior); 2025 Limited Indexed Edition pages 1 to 20 and index pages 323 to 330; Italian paperback pages 1 to 10 (copyright page dated 17.9.2021) and back cover | about 100 strings read off those pages | full extended oracle | 0 match | yes: the ISBN read off the copyright page re-finds EN_easy_2 | 2026-09-01 |
| Print page numbers: pages 1 to 339 as "N", "page N", "p. N", "Page N of 321/339" and 8 more formats; all ordered pairs (a, b) with 6 separators; the 47, 70, 91 triple in every order | 4,407 single forms, 689,562 pairs and triples | sha256x3 raw chain, both key forms | 0 match | yes: the same code re-finds 221B, the ISBN and the IT_hard cities | 2026-09-01 |
| Every identifier printed in the book: URLs (full, without scheme, last path segments), DOIs, arXiv ids, the Merkle patent, Bitcointalk topic ids, Medium post ids, YouTube ids, all numbers of 6 or more digits, the Spotify playlist and user ids; the author's own 60 patent and publication numbers (Justia) in 8 formats | 583 plus 486 strings | full extended oracle | 0 match | yes: 221B and ISBN re-found in the same runs | 2026-09-01 |
| Structured combinations: Merkle roots of the Figure 10 rows, the Figure 11 full hashes under 4 input conventions and the 8 EN addresses (single and double SHA-256, both leaf orders, hashed leaves), SHA-256 chains of every XOR subset of those tables, discography track numbers and years as strings | about 2,600 keys and strings | direct key check, extended oracle | 0 match | yes: the Figure 10 XOR re-finds EN_hard_2 | 2026-09-01 |

Cumulative across the rows above: approximately 9,600 answer strings, 694,000 page-number
forms, 800,800 ISBN add-on forms and 34.4e9 proof-of-work nonces tested against the 3 open
lots, 0 match.

## What this rules out and what it does not

Every mechanism I could construct from the EN and IT ebook text and figures is closed.
Four plants remain identified but unmapped to any natural-language answer: the Figure 8
DeLorean VIN that reads 26 in the prose and 27 in the figure, the number 74,638 printed
near a block explanation, an unattributed E. E. Cummings line in the preface ("the
deepest secret nobody knows"), and a chess note ("Bishop to a6"). Each was tried against
its obvious noun candidates as part of the 2026-07-18 row above; none matched. This does
not rule out a print-only answer for any of the 3 open lots: the physical 2020 to 2021
print runs have not been checked, since I have not yet compared a physical copy against
the ebook captures page by page.
