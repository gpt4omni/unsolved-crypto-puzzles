# Author posts and puzzle material: Walking Banks

Verbatim quotes from AH White's own Nostr account
(`npub1c2rvx6ue9uewl452kczcfxz9w242sfzn64ul8dv2afd3t5dpktzs0kmmvf`,
https://njump.me/npub1c2rvx6ue9uewl452kczcfxz9w242sfzn64ul8dv2afd3t5dpktzs0kmmvf), chronological,
plus the one in-book passage that carries the puzzle's decoding rule. Individual note
permalinks are not stable on Nostr relays; quotes are dated to the note's own timestamp.

## Nostr announcements

- 2025-05: "If your up for a treasure hunt, the book contains a real Bitcoin seed phrase hidden
  within the story. So if you can piece the right string of words together, it leads to a wallet
  with 800000 sats in it. No funny business, all real. The first one to figure it out gets the
  bitcoin."
- 2025-05: "The information for a real Bitcoin seed phrase can be found across the story that
  leads to a wallet with 0.008 BTC in it."
- 2025 (undated within the year): "It's 24 words... if the wallet is not emptied after some time,
  I'll start dropping some hints from time to time."
- 2025-11-21: "So far, no one has discovered or deduced the access to the bitcoin wallet... Did
  you know that word repetitions are actually allowed in a seed phrase?"
- 2026-03-16: "Well, it's been almost a year without anybody cracking the seed phrase hidden in my
  book. So here some straightforward clues: the book contains the words to a 24-word seed phrase
  in the right order."
- Undated, in response to a reader asking whether the wallet had shown activity: "Hm... weird. I
  don't think it has been discovered because there are no transaction connected to the address
  for some reasons (also not my original transactions to 'load up')." This is the author
  describing, without realizing it, the P2PKH-versus-P2WPKH reading trap: her own xpub reads as
  empty under the default legacy derivation most explorers use.

Public contact channel, listed by the author on her own site (walkingbanks.com): the email
`walkingbanks@protonmail.com`, alongside her Nostr and Reddit (`AH_W`) handles.

## The chapter 11 decoding passage

The book's own mechanism clue, page 128, the genetic-code block that decodes to the one known
seed-word group:

```
xiiithirdiiicrystaliiismalliiiadviceiiireflectxxxxxxcrystaliiismalliiiadviceiiireflectxxxxxxcrystaliiismalliiiadviceiiireflectiiithirdiiix
```

The story's own dialogue explains the reading rule immediately after this block: the ordinal
("third") is repeated twice and names the group's position; the four words that follow, each
repeated three times, are that group's payload. This gives seed positions 9 to 12: `crystal
small advice reflect`.
