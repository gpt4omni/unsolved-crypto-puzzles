# Author posts and quotes

Material published by Corey Phillips about this puzzle: his own article, and a
community-maintained hint repository that mirrors it.

## 2019-07-09, Medium, "Part 1/3: Turn Your Photos Into Bitcoin Private Keys/Addresses"

https://corey-lyle-phillips.medium.com/part-1-3-turn-your-photos-into-bitcoin-private-keys-addresses-57669771cf7a

The article that introduces the kitten image and both addresses, in the author's own
words:

> "To prove the viability of this method, I have also sent 0.01 BTC to the following
> address, `bc1qcyrndzgy036f6ax370g8zyvlw86ulawgt0246r`. This address was generated using
> the kitten image along with a BIP39 passphrase. Remember, this is not meant to be
> solved. It is meant to prove the viability of this method, but if you somehow manage to
> claim it, congrats!"

> "The mnemonic for the kitten photo without a passphrase contains roughly 0.00095133
> BTC. Feel free to claim it if you manage to sweep the keys in time."

No Part 3 of the series was ever published: the author's Medium index lists exactly
"Bitbip" (2019-03), this Part 1 article (2019-07-09), "A Bitcoin Audio Puzzle"
(2020-01-05), and Part 2 (2021-03-20), and nothing after.

## Community hint repository (mirrors the author's write-up, adds 3 numbered hints)

https://github.com/Schum-io/BTC-Puzzle-by-Corey-Phillips

States: "This repository contains all publicly known hints for BTC Puzzle by Corey
Phillips challenge. Contributions are welcome!" It gives the mechanism (base64 the image,
SHA-256 the result, feed the digest to BIP39's `entropyToMnemonic`) and 3 hints: working
Python code to derive keys from the image, a brute-force script over a `wordlists`
folder (noting the author had already tried the skullsecurity lists without success), and
a suggestion to check the image for steganography with named public tools (aperisolve,
StegOnline).

## 2020-01-05, Medium, "A Bitcoin Audio Puzzle" (same author, related puzzle)

https://corey-lyle-phillips.medium.com/a-bitcoin-audio-puzzle-61174b9849ce

The author's related audio puzzle, decoded separately (see README, "What is
understood"). Opening line: "Happy New Year! It's been a while since my last puzzle so
for 2020 I thought I would have some fun and make another Bitcoin audio puzzle." The
article states a reward of approximately 760,000 sats for that separate puzzle.

## Author's own tool

https://github.com/coreyphillips/bitimage ("Turn Any Image Or Document Into A Mnemonic
Phrase"), the proof-of-concept code the article demonstrates.
