# Open leads: Bitaps Shamir secret-sharing challenge

Full notes. The README shows the ranked summary.

## 1. The unpublished 3rd share (author-held)

The scheme is 3-of-5. Two shares were published on 2020-06-19 and every later public
copy agrees on those two. The remaining shares were never posted in any channel I
could read. Same-day copies (Reddit, Telegram, X) already show only 2 shares, and the
2020-07-04 Common Crawl body (`challenge.warc`) shows the same pair, so a
"posted then deleted during the 15-day Wayback gap" story now has to explain why the
parallel announcements and the first crawl never carried a 3rd share either. What would confirm it: the
author publishing a 3rd share, or a dated copy of the challenge page that disagrees
with the 2-share text. What would close it: that still has not happened. Cost:
watching the author's remaining channels; no compute.

## 2. Memento TimeTravel, and the rest of the X reply tree

Memento TimeTravel (`timetravel.mementoweb.org`) did not resolve on 2026-08-28 (DNS).
That aggregator is still unread. The X announcement was re-read, including the 3
replies returned with the post; one of those (2025-05-14) asks the author to reveal
1 or 2 words of the third share, and there is no author reply among those 3. A fuller
reply listing might still exist off that truncated view. What would confirm or kill
each: a working Memento read of the challenge URL, or a complete reply listing for
status 1274018817304379394 that either surfaces share words or comes back clean with
the known announcement text as witness. Cost: minutes, if the services answer.

## 3. Direct computation

Not ranked as a lead. The residual entropy is about 125 bits (see
`data/entropy_measurements.csv`). Every 2-share model that actually determines a
secret, or a 2^16 mix of two such models, is now tested and negative
(`analysis/tested.md` section 12). What remains is the unconstrained byte, which is
not in range for search on any hardware I have access to. This door is closed by the
numbers, not by assumption.

## Closed this round (2026-08-28)

The 15-day Wayback/Common Crawl gap is no longer an independent source of a hidden 3rd
share: the gap is still empty in those two indexes, but same-day Reddit and Telegram
copies exist, archive.today's one snapshot (2021-06-20) matches, and the live pages on
2026-08-28 still match. The Common Crawl payload itself is now in-folder
(`challenge.warc`, 2020-07-04T18:20:40Z) and carries the same 2 shares; the same-day
mnemonic tool WARCs (`tool-en.warc`, `tool-ru.warc`, `offline.warc`) have empty restore
slots. `offline.warc` is truncated at Common Crawl's 1 MiB cap inside the BIP39
dice wordlist (255 words, `abandon` through `cabin`); the split/restore UI is
above that cut and fully present. archive.today, Telegram `t.me/s/bitapscom`, the 13 reachable GitHub forks of
`mnemonic-offline-tool`, and the live regional mirrors are now read, not merely
uncertified. Determined 2-share algebraic models (unique coefficients, global `a1`/`a2`,
constructed 3rd shares, mixed 2^16 families) are negative. Details in
`analysis/tested.md` sections 7 to 13.
