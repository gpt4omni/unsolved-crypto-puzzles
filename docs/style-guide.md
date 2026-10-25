# Style guide

These are the writing rules for every page in this repository. Follow them for a new folder
and when editing an existing one.

## Voice and tone

- First person singular. "I tested", "I measured", "I could not confirm". Methods may use
  passive voice.
- Plain declarative sentences. No rhetorical questions, no exclamation marks, no "Note:"
  boxes, no motivational lines, no jokes.
- Numbers instead of adjectives: "669,858 selections, 0 match" not "an enormous number".
- Say what is known, what was assumed, what failed. Failures are stated as results.

## Forbidden

Characters: em dash (U+2014), en dash (U+2013), ellipsis (U+2026, write three periods or
rephrase), curly quotes (U+201C, U+201D, U+2018, U+2019), non-breaking space, emoji, any
Unicode arrow (write "to" or "->" inside code only).

Words and phrases: delve, worth noting, it's worth, tapestry, realm, landscape (figurative),
navigate (figurative), journey (figurative), unlock (figurative), embark, dive into, deep
dive, testament to, game-changer, cutting-edge, leverage (verb), utilize, seamless, robust,
crucial, pivotal, exciting, fascinating, intriguing, needless to say, at the end of the day,
in today's, "in conclusion", "in summary" as section openers, "let's".

"impossible", "proven impossible", "hopeless", "wall". Write what it would take instead: "no
known method", "costs about 650 times the prize", "needs information not in the public
material".

Any hedge stack: "may possibly perhaps". One hedge per sentence.

Bullet lists of adjectives. A bullet is a fact or an action.

Marketing: no "amazing community", no "join the hunt".

## Citations and links

- Inline links on the noun: `the announcement on [bitcoin.fr](url) (2020-03-01)`.
- Every external claim gets a URL. When the page can vanish, add a Wayback URL in Sources.
- Relative links inside the repo: `../../docs/verify-funding.md`, never absolute GitHub URLs.
- Cite by URL and date, never by internal file IDs of any private research notes.

## Dates, numbers, addresses

- Dates: ISO 8601, `2026-08-16`. Times: `05:13:20 UTC`. Never "last month".
- Sats: `369,369 sats`. BTC: `1.2563 BTC` (as many decimals as needed, no trailing zeros
  beyond the exact amount). ETH: `8.61 ETH`. AR: `1000.17 AR`. Stables: `305.93 USDT`.
- USD: `about $79,000 (BTC at $63,000, 2026-08-16)`; the snapshot appears once per README, in
  the At a glance table; later mentions say "about $79,000".
- Counts: thousands separator with a comma. Rates: `790,000 derivations/s`. Sizes: `2^128`,
  `3.6e9`.
- Addresses and txids: full, never truncated, in backticks, followed on first mention by an
  explorer link. Explorer conventions: `https://mempool.space/address/<a>` and
  `https://mempool.space/tx/<txid>` (Bitcoin), `https://etherscan.io/address/<a>` (Ethereum),
  `https://basescan.org/address/<a>` (Base), `https://viewblock.io/arweave/address/<a>`
  (Arweave), `https://solscan.io/account/<a>` (Solana).
- Derivation paths in backticks: `m/84'/0'/0'/0/0`.
- Word lists in fenced code blocks, one line, exact.

## Uncertainty vocabulary (use only these)

- "confirmed": a command or transaction anyone can re-run shows it.
- "reported": the author or a named source said it; link.
- "likely" / "I believe": my interpretation; say what would settle it.
- "unverified": I could not check it.

## Negatives (the phrasing is fixed)

"N candidates tested, 0 match. Method: <one line>. Witness: <known-good input> re-found at
head, middle and tail / uncertified. Rate: <r>/s on <hardware>. Date: <YYYY-MM-DD>."

A negative without a witness is written "uncertified" in the table. Never drop it, never
present it as proof.

Scope goes with the number: "0 match under BIP84 with empty passphrase" not "0 match".

## Translation from source notes

- Translate; do not transliterate French structure when working from French-language source
  notes. Keep French words that are data (the BIP39 French wordlist, book titles, quoted
  French sentences with an English gloss in brackets).
- Recompute or re-read every number from source material before writing it. If a number
  cannot be traced, drop it or mark it "approximate".
- Replace internal shorthand with plain words describing what actually happened.
- Remove operational detail about rented hardware, hosts, and budgets. "on one RTX 5080" or
  "on a rented GPU" is enough.

---

## Style card (use this checklist before publishing any page)

```
STYLE CARD, unsolved-crypto-puzzles
1. English, first person singular, plain declarative sentences. Numbers over adjectives.
2. NEVER use the em dash (U+2014), the en dash (U+2013) or the ellipsis character (U+2026). Use commas, colons, periods, parentheses. Straight quotes only. No emoji.
3. Never write: delve, worth noting, tapestry, realm, landscape/journey/navigate/unlock (figurative), embark, dive into, deep dive, testament to, game-changer, cutting-edge, leverage, utilize, seamless, robust, crucial, pivotal, exciting, fascinating, impossible, hopeless, wall.
4. Never mention AI, agents, models, or tools as having done the work. "I tested", "I measured".
5. Never reproduce book text, transcripts, articles, wordlists, dumps. Link them. Author-published puzzle images and short author quotes are fine, with URL and date.
6. Follow docs/templates/README.template.md headings exactly, in order. Delete "Solution" unless solved. Do not add a solved or dead-end section in this repository.
7. Dates ISO 8601. Sats with commas (369,369 sats). BTC as 1.2563 BTC. USD as "about $79,000 (BTC at $63,000, 2026-08-16)", once per README.
8. Addresses and txids full, in backticks, with an explorer link on first mention. Paths in backticks.
9. Negatives: "N candidates tested, 0 match. Method: ... Witness: ... / uncertified. Rate: ... Date: ...". Scope travels with the number.
10. Uncertainty words: confirmed / reported / likely / unverified. One hedge per sentence.
11. Leads ranked by cost to test, then expected value; each says what would confirm or kill it.
12. Every claim from outside has a URL and date. Relative links inside the repo.
13. Every number is re-read from the source material before it is written; untraceable numbers are dropped or marked approximate.
14. Every figure comes from a script reading a data file; caption says which. Untested = "not tested", never shaded as measured.
15. No private-repo jargon (F-020, L-001, EV-, ADR, supervisor, make brief, Fable, Opus, vast.ai).
16. Summary 60 to 120 words. README 120 to 400 lines. Overflow goes to analysis/.
17. Section "The puzzle as published" = author's material only. Section "What is understood" = my findings.
18. Solved: answer, derivation, key material, payout tx, what it teaches about the series.
19. Dead end: reason enum in words, verification, reopen condition, one lesson.
20. Run tools/validate.py --folder <slug> before handing in.
```
