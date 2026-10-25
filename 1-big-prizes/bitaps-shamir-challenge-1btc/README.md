# Bitaps Shamir Secret Sharing Challenge (1.00016775 BTC, [OPEN])

Bitaps, a Bitcoin and Litecoin wallet service, launched a public bug-bounty challenge on
2020-06-19: break its Shamir secret-sharing backup scheme, or find a bug in the
implementation, and the reward sits at the challenge address itself. The company
published 2 of the 3 mnemonic shares needed to reconstruct a 12-word BIP39 secret split
with a 3-of-5 threshold over GF(256). I established the exact code base that generated
the shares, reconstructed the scheme, and measured a real defect in the deployed
generator's entropy check, which narrows the secret from 128 to about 125 bits. That is
not enough to search. Two independent bug reports describe the same defect from 6 days
before I found it, and the 3rd share has not surfaced anywhere in 4 years of archives.

## At a glance

| | |
|---|---|
| Author | Bitaps, [bitaps.com](https://web.archive.org/web/20230328022959/https://bitaps.com/mnemonic/challenge) |
| Published | 2020-06-19, challenge page `bitaps.com/mnemonic/challenge` ([archived](https://web.archive.org/web/20230328022959/https://bitaps.com/mnemonic/challenge)) |
| Prize | 1.00016775 BTC (about $63,011 at BTC = $63,000, 2026-08-16) |
| Chain | bitcoin |
| Escrow | `bc1qyjwa0tf0en4x09magpuwmt2smpsrlaxwn85lh6` ([mempool.space](https://mempool.space/address/bc1qyjwa0tf0en4x09magpuwmt2smpsrlaxwn85lh6)) |
| Last on-chain check | 2026-10-24: re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | OPEN |
| Puzzle type | shamir, bip39-seed |
| Target format | BIP39 12-word English mnemonic (the secret), BIP84 `m/84'/0'/0'/0/0`, no passphrase |
| Certified oracle | yes: `tools/oracle.py --selftest` (certified against the public BIP84 test vector and a synthetic 3-of-5 GF(256) round trip; it reconstructs a candidate, it does not search for one) |
| What remains | a 3rd Shamir share, never published, or a disclosed constraint on it. Same-day copies, the 2020-07-04 Common Crawl body, and later archives all show only the original 2 shares. |
| Series | none |

## The puzzle as published

Bitaps posted the challenge on 2020-06-19: "The New Bug Bounty program for Shamir Secret
Backup Scheme... if you can hack the scheme completely, then the main reward is already
waiting for you at the bitcoin address," and "The goal is to break the Shamir Secret
Sharing scheme or break the implementation of software for SSSS. We publish 2 of 3 shares
needed to restore." The stated reward structure was 1 BTC for recovering the wallet key,
another 1 BTC for disclosing the method, and 0.1 BTC for a bug leading to loss of access;
only the wallet-recovery address is tracked here. The 2 published shares, each a 12-word
phrase:

```
session cigar grape merry useful churn fatal thought very any arm unaware
clock fresh security field caution effort gorilla speed plastic common tomato echo
```

Full quotes with dates and links in [clues/author-posts.md](clues/author-posts.md).

## What is understood

### Mechanism

The secret is a 12-word BIP39 mnemonic, 128 bits of entropy, split byte by byte with
Shamir secret sharing over GF(256), threshold 3 of 5, using the same reducing polynomial
AES uses (0x11B). Each share is itself a 12-word phrase: its first 128 bits carry one
share of the entropy, and its last 4 bits, which BIP39 normally reserves for a checksum,
carry the share's index instead. Reconstructing the secret from 3 shares is Lagrange
interpolation at x=0 in GF(256); the result is re-encoded as a 12-word mnemonic with its
true BIP39 checksum and derives the challenge address at BIP84 `m/84'/0'/0'/0/0`. I
confirmed the code base that generated the 2 published shares is `bitaps-com/jsbtc`
(bundled into `mnemonic-offline-tool` at commit `5b6dd995`, 2020-06-19), not `pybtc`, a
similarly named Python reimplementation an earlier reading of mine had assumed: only
`jsbtc`'s 4-bit share-index field reaches the value 15, which is what the second
published share actually carries (`analysis/tested.md`, section 2).

### Derivation and oracle

```
python3 tools/oracle.py --selftest
python3 tools/oracle.py "word1 word2 ... word12"    # a candidate 3rd share
python3 tools/oracle.py --stdin
```

Given a candidate 3rd share, the oracle combines it with the 2 published shares,
reconstructs the 16-byte secret, re-derives the BIP84 address, and compares it to the
escrow, printing `MATCH <address>` or `NO MATCH`. It checks a candidate; it cannot search
for one, since the space of possible 3rd shares is the same size as the space of possible
secrets.

### Certified against

`tools/oracle.py --selftest` reproduces the public BIP84 test vector (`abandon` times 11
plus `about` derives to `bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu`), confirms the 2
published shares decode to distinct nonzero indexes, confirms those 2 shares alone
(below the 3-share threshold) do not derive the escrow address, and round-trips a
synthetic 3-of-5 split built with the same GF(256) arithmetic. No solved sibling exists
for this puzzle, so the public vector and the round trip are what certify the derivation
path. Reproduced 2026-08-16.

### Established facts

1. The escrow holds 1.00016775 BTC across 5 funding transactions, 0 spent, confirmed
   2026-08-28 on [mempool.space](https://mempool.space/address/bc1qyjwa0tf0en4x09magpuwmt2smpsrlaxwn85lh6).
2. The 2 published shares decode to Shamir indexes 3 and 15; index 15 is only reachable
   under `jsbtc`'s 4-bit index field, which settles `jsbtc` over `pybtc` as the code of
   record.
3. The residual entropy of the secret, after every constraint I could establish, is
   about 125 bits (`data/entropy_measurements.csv`).
4. The GF(256) arithmetic and Lagrange interpolation behind that measurement were
   checked against an independent reference: 65,536 multiplication products and 32,553
   interpolation evaluations, 0 discrepancies.
5. 14 archived captures of the challenge page and its regional mirrors, spanning
   2020-07-04 to 2024-02-25, show only the same 2 shares. The first Common Crawl
   hit is `CC-MAIN-2020-29` at `20200704182040`; that payload is now in-folder as
   `challenge.warc` and still has only those 2 shares. Same-day copies on Reddit
   and Telegram already carry only those 2 shares, so a later deletion of a 3rd
   share from the challenge page would also have to explain those parallel
   announcements.
6. Two GitHub issues on `bitaps-com/jsbtc`, filed 2026-07-28 and 2026-07-29, reported
   the same entropy-check defect I measured, 6 days before I found it independently
   (verified via the GitHub API on 2026-08-03). Neither issue number resolves on a
   recheck on 2026-08-16; I could not determine why.
7. The published zpub
   `zpub6qdEDkv51FpxX6g1rpFGckmiL46vV8ccmtEgPAkj3qj8N4ZZHyXDRA9RwpTiFK2Kb8vRaDmSmwgX6rfB4t2K8Ktdq8ExQ6fumKpn2ndJCqL`
   is a BIP84 account-level key (depth 3, last child `0'`), so `m/84'/0'/0'/0/0` is
   the `0/0` child of that key. That derivation produces
   `bc1qyjwa0tf0en4x09magpuwmt2smpsrlaxwn85lh6`. Confirmed from the 2020-07-04 WARC
   string on 2026-08-28 (version `04b24746`, child `0x80000000`).
8. Live challenge pages on `bitaps.com`, `tbtc.bitaps.com`, and `ltc.bitaps.com` still
   show the same 2 shares on 2026-08-28. The `bitaps.com` page had returned HTTP 403 on
   2026-08-16.

## What has been tested

Full ledger in [analysis/tested.md](analysis/tested.md). Summary:

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| `pybtc` as the code of record | 1 candidate implementation | reconstructed from `pybtc`, checked its index range against the observed share indexes | refuted: `pybtc`'s index range (1 to 5) cannot produce the observed index 15 | yes: index-range argument plus the public BIP84 vector | 2026-08-03 |
| 3rd share published anywhere in the archived challenge page or its mirrors | 14 archived captures, 5 hosts, 2020-07-04 to 2024-02-25 | fetched every capture, extracted every 12-word phrase, compared to the 2 known shares | 0 additional shares found | yes: detector recovers both known-good shares from every capture | 2026-08-03 |
| coefficient PRNG weakness in the deployed `jsbtc` | source review of the bundled `bip39_mnemonic.js` | read the file for a `Math.random` fallback path | none found; CSPRNG only | uncertified: source review, not an executed test | 2026-08-03 |
| direct reconstruction from the 2 published shares alone | below the 3-share threshold | GF(256) interpolation with only 2 points | does not derive the escrow address | yes: `tools/oracle.py --selftest` | 2026-08-16 |
| 3rd share in the 15-day Wayback/Common Crawl gap | 0 captures, 2020-06-19 to 2020-07-03 | Wayback CDX, Common Crawl 2020-24/29/34, Arquivo.pt | gap still empty; earliest hit remains 2020-07-04 | yes: same CDX query returns later known captures | 2026-08-28 |
| 3rd share on archive.today | 1 snapshot, 2021-06-20 | fetched listing and snapshot `8bNRM` | same 2 shares | yes: both known shares recovered | 2026-08-28 |
| 3rd share in same-day announcements | Reddit `hc4bfk` (26 comments), Telegram `bitapscom`, X status 1274018817304379394 | fetched each, extracted 12-word BIP39 sequences, oracle on overlap windows | 0 unpublished share; 13 overlap windows, 0 MATCH | yes: both known shares recovered from the Reddit body | 2026-08-28 |
| 3rd share in a GitHub fork of `mnemonic-offline-tool` | 13 reachable forks | compare default-branch HEAD to `5b6dd995`; code search for the published share prefixes | 12 heads equal the known commit; 1 predates the challenge; 0 extra share | yes: 12 heads equal `5b6dd995` | 2026-08-28 |
| 3rd share on the live challenge pages | 3 hosts | fetched 2026-08-28 | same 2 shares; zpub derives the escrow | yes: both known shares recovered; zpub-to-address exact match | 2026-08-28 |
| determined 2-share algebraic models | 394,125 secrets and constructed shares | unique coefficient assumptions, global `a1`/`a2`, 6 mixed 2^16 families, constructed 3rd shares | 0 match; 65,536 constant-`(a1,a2)` pairs with 0 consistent | yes: `tools/structured_candidates.py --selftest` | 2026-08-28 |
| 3rd share in the 2020-07-04 Common Crawl WARC payloads | 4 records (`challenge.warc`, `offline.warc`, `tool-en.warc`, `tool-ru.warc`) | parse records, strip tags, collect `span.word-N`, search for a third slot | 0 extra share; `offline.warc` truncated at 1 MiB in the dice wordlist, after empty restore slots; zpub is account-level, `0/0` derives the escrow | yes: stripped `challenge.warc` recovers both known shares; dice prefix matches BIP39 | 2026-08-28 |

## Open leads, ranked

1. **The unpublished 3rd share** (hours to wait). Every public copy I can read, including
   same-day Reddit and Telegram announcements, the 2020-07-04 Common Crawl body
   (`challenge.warc`), archive.today's 2021-06-20 snapshot, and the live pages on
   2026-08-28, shows the original 2 shares. The remaining shares of the 3-of-5 split have
   not appeared. Confirmed by the author publishing a 3rd share, or by a dated copy that
   disagrees with the 2-share text.
2. **Memento TimeTravel, and the rest of the X reply tree** (hours). Memento still did
   not resolve on 2026-08-28 (DNS). The X announcement was re-read with the 3 replies
   returned alongside it; one 2025 reply asked for 1 or 2 words of the third share, and
   there is no author reply among those 3. A complete reply listing, or a working
   Memento read, would close the leftover unread surface.

Full notes: [analysis/leads.md](analysis/leads.md).

## Files in this folder

| Path | What it is |
|---|---|
| `clues/author-posts.md` | the challenge-page quotes and the 2 published shares, verbatim, with dates and links |
| `challenge.warc` | Common Crawl payload of `bitaps.com/mnemonic/challenge`, 2020-07-04T18:20:40Z |
| `tool-en.warc` | same-day payload of `bitaps.com/mnemonic?language=en` |
| `tool-ru.warc` | same-day payload of `bitaps.com/mnemonic?language=ru` |
| `offline.warc` | same-day payload of `bitaps.com/mnemonic/offline` (Common Crawl truncated at 1 MiB in the dice wordlist) |
| `data/entropy_measurements.csv` | the 3 residual-entropy measurements behind "about 125 bits," with method and date |
| `data/related_disclosures.csv` | dated timeline of events on the `jsbtc` repository and the challenge address |
| `data/channel_reads.csv` | channels read on 2026-08-28 for a 3rd share, with counts and witnesses |
| `analysis/tested.md` | full negatives ledger |
| `analysis/leads.md` | full lead notes |
| `tools/oracle.py` | reconstruction checker: candidate 3rd share plus the 2 published shares to a derived address |
| `tools/structured_candidates.py` | 2-share algebraic models: unique coefficients, mixed 2^16 families, constructed 3rd shares |

## Sources

- Bitaps, "Shamir Secret Backup Scheme" bug bounty, `bitaps.com/mnemonic/challenge`, 2020-06-19 (archived: [web.archive.org](https://web.archive.org/web/20230328022959/https://bitaps.com/mnemonic/challenge); archive.today: [archive.is/8bNRM](https://archive.is/8bNRM), 2021-06-20). Earliest payload on file: `challenge.warc`, Common Crawl `CC-MAIN-2020-29`, 2020-07-04T18:20:40Z.
- Bitaps, announcement, [x.com/bitaps_com/status/1274018817304379394](https://x.com/bitaps_com/status/1274018817304379394), 2020-06-19 (re-read 2026-08-28)
- Bitaps, same-day Reddit copy, [r/Bitcoin `hc4bfk`](https://www.reddit.com/r/Bitcoin/comments/hc4bfk/1_btc_cryptographic_challenge_with_splitted/), 2020-06-19 (archived: [web.archive.org, 2023-06-11](https://web.archive.org/web/20230611002230/https://old.reddit.com/r/Bitcoin/comments/hc4bfk/1_btc_cryptographic_challenge_with_splitted/))
- Bitaps, same-day Telegram copy, [t.me/bitapscom/15](https://t.me/bitapscom/15), 2020-06-19
- `bitaps-com/mnemonic-offline-tool`, commit [`5b6dd995`](https://github.com/bitaps-com/mnemonic-offline-tool/commit/5b6dd995478b49c489b95444fbb0dca4006746a2), 2020-06-19
- [`bitaps-com/jsbtc`](https://github.com/bitaps-com/jsbtc), repository (code of record)
- [jsbtc issue #65](https://github.com/bitaps-com/jsbtc/issues/65), coefficient-bias defect, 2026-07-16
- [mempool.space](https://mempool.space/address/bc1qyjwa0tf0en4x09magpuwmt2smpsrlaxwn85lh6), escrow address, checked 2026-08-28
