# Author posts: Bitaps Shamir secret-sharing challenge

Verbatim short posts published by Bitaps (bitaps.com), the company running the challenge.
Chronological.

---

**2020-06-19, challenge page**, `bitaps.com/mnemonic/challenge`
(live page returned the challenge body on 2026-08-28; it had returned HTTP 403 on
2026-08-16. Archived copies:
[web.archive.org, 2023-03-28](https://web.archive.org/web/20230328022959/https://bitaps.com/mnemonic/challenge),
[archive.is/8bNRM, 2021-06-20](https://archive.is/8bNRM)):

> "The New Bug Bounty program for Shamir Secret Backup Scheme... if you can hack the scheme
> completely, then the main reward is already waiting for you at the bitcoin address."

> "The goal is to break the Shamir Secret Sharing scheme or break the implementation of
> software for SSSS. We publish 2 of 3 shares needed to restore."

The two published shares (12 words each, Shamir index embedded in the last 4 bits in place
of the BIP39 checksum):

```
session cigar grape merry useful churn fatal thought very any arm unaware
clock fresh security field caution effort gorilla speed plastic common tomato echo
```

The same page also publishes the BIP84 account zpub used to derive the challenge
address at `m/84'/0'/0'/0/0`:

```
zpub6qdEDkv51FpxX6g1rpFGckmiL46vV8ccmtEgPAkj3qj8N4ZZHyXDRA9RwpTiFK2Kb8vRaDmSmwgX6rfB4t2K8Ktdq8ExQ6fumKpn2ndJCqL
```

That zpub is an account-level BIP84 key (depth 3, last child `0'`). The path
`m/84'/0'/0'/0/0` is the `0/0` child of that key and produces
`bc1qyjwa0tf0en4x09magpuwmt2smpsrlaxwn85lh6`. The 2020-07-04 WARC string is
the same (lowercase `w` in `DmSmwgX`); a capital-W transcription fails the
Base58 checksum.

The earliest payload I have of this page is `challenge.warc` (Common Crawl
`CC-MAIN-2020-29`, WARC-Date 2020-07-04T18:20:40Z). That capture already has the
same 2 shares and the same zpub. Its body is the short form of the page: title
"1 BTC challenge with splitted mnemonic code", no ZeroNights framing, no extra
bounty tiers, and a displayed balance of `1.00000000 BTC`. The SSSS
implementation pointer is `jsbtc`; the footer already has a "Powered by"
`pybtc` logo linking to `pybtc.readthedocs.io`, which is site chrome. The
ZeroNights / bug-bounty wording quoted above is from later copies
(archive.today 2021-06-20 and the 2023-03-28 Wayback capture).

**2020-06-19, announcement**: [x.com/bitaps_com/status/1274018817304379394](https://x.com/bitaps_com/status/1274018817304379394)
(re-read 2026-08-28). Posted 2020-06-19T16:38:50Z. Text: "1 BTC cryptographic challenge
with splitted mnemonic code." plus the escrow address and a short link to the challenge
page. No share words in the post. The 3 replies returned with the post do not add a
share.

**2020-06-19, Reddit copy**: [r/Bitcoin `hc4bfk`](https://www.reddit.com/r/Bitcoin/comments/hc4bfk/1_btc_cryptographic_challenge_with_splitted/)
by u/bitaps. Same 2 shares, same zpub, same address, same jsbtc pointer. Wayback
[2023-06-11 old.reddit capture](https://web.archive.org/web/20230611002230/https://old.reddit.com/r/Bitcoin/comments/hc4bfk/1_btc_cryptographic_challenge_with_splitted/)
includes 26 comments; none adds a 12-word share.

**2020-06-19, Telegram copy**: [t.me/bitapscom/15](https://t.me/bitapscom/15)
(public preview [t.me/s/bitapscom](https://t.me/s/bitapscom)). Reprint of the X
announcement: address and link, no share words.

**2020-06-19, code of record**: [github.com/bitaps-com/mnemonic-offline-tool](https://github.com/bitaps-com/mnemonic-offline-tool),
commit [`5b6dd995`](https://github.com/bitaps-com/mnemonic-offline-tool/commit/5b6dd995478b49c489b95444fbb0dca4006746a2)
(2020-06-19T09:46:32Z, the same day the challenge address was funded), bundling the
`jsbtc` library that generated the two published shares.
