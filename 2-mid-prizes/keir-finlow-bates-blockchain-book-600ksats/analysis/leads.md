# Leads (full notes)

The "Open leads, ranked" section of `README.md` shows the ranked list; this file carries
the full notes behind each entry.

## 1. Buy the physical books: KDP paperback, Lulu hardcover, Italian paperback

- **Cost**: needs a person and about $60 (three books).
- **What it is**: every digitally accessible surface of both editions (ebook text, page
  captures, figure images) has been checked against every mechanism I could construct
  (see `tested.md`), with 0 match on the 3 open lots. On 2026-09-01 I recovered the
  EN_easy_2 answer: it is the paperback ISBN-13, "9781688289970", a string that exists
  only on the physical book (the ebook has an ASIN and no ISBN). That makes the author's
  line in the hunt announcement, "you hold the source of each and every key in your
  hands... as long as you have a physical copy, that is", an instruction rather than a
  joke. Two physical English editions exist: the KDP paperback (ISBN 9781688289970, 321
  pages, 5.5 x 8.5 inches, published 2020-12-02) and the Lulu hardcover (ISBN
  9781716479724, 322 pages on Amazon), plus a 2023 KDP hardcover (ISBN 9798394360602,
  321 pages) and a 2025 "Limited Indexed Edition" (ISBN 9798265632500, 330 pages). The
  Kindle edition reports 339 pages, which matches none of them, so the Kindle page
  numbers are an Amazon estimate. Through Amazon's public sample reader I have read the
  paperback's pages 1 to 8 (the copyright page prints the ISBN, the table of contents
  gives the full print pagination), its About the Author page and back cover, the same
  pages of the 2023 hardcover, pages 1 to 20 and the index of the 2025 edition, and pages
  1 to 10 of the Italian paperback; every string on them is null, as are all page numbers
  and page pairs. The unseen part of the physical object is the interior, pages 9 to 320.
  A used copy from the original print run is preferable to a fresh print-on-demand
  reprint: on the IT side, a planted flaw is known to have moved between printings.
- **Why it ranks here**: it is the only lead grounded in a confirmed answer of the same
  series, and it is the one lead not yet executed.
- **What would confirm it**: a string or detail on the physical object (copyright page,
  spine, back cover, last page, the figure pages at pages 47, 70 and 91 of each
  pagination) that derives to an open lot through the certified oracle.
- **What would kill it**: every surface of both physical English editions and of the
  Italian paperback matches the ebook captures exactly, with no new string or detail.
- **Status**: open, not yet executed (a purchase decision, not a compute task).

## 2. Crack IT_easy using its exposed public key as a free calibration oracle

- **Cost**: hours.
- **What it is**: IT_easy (`1MEstvLAzc5DzJtvx7uyvKNNUCPN3ofWMK`) was solved and swept by
  a community reader in 2022-02-18, which proves its answer is recoverable from the text
  alone, with no print gate. Because it was spent from, its public key is exposed
  on-chain. Deriving the IT_easy answer, even without the prize (already claimed), would
  reveal the Italian-edition answer style most likely to solve IT_veryhard, the
  remaining IT lot.
- **Why it ranks here**: it is bounded (a single known-solvable lot) and cheap relative
  to lead 1, but it depends on finding the right IT-only textual detail, which the
  ebook-mapping work has not yet located for IT_easy specifically (as opposed to
  IT_hard, which is solved).
- **What would confirm it**: a sha256x3 candidate string whose derived uncompressed
  P2PKH address matches `1MEstvLAzc5DzJtvx7uyvKNNUCPN3ofWMK`, or whose derived public key
  matches the one exposed by the spending transaction.
- **What would kill it**: exhausting the Italian front matter and body text (already
  mapped once, see `tested.md`) without a match; that would suggest IT_easy's answer
  also depends on print-only content.
- **Status**: open.
