# Puzzle material: School of Bitcoin

## The card image (m.stacker.news/81280, announced via stacker.news item 908283, 2025-03-09)

Decoded channels, in the order I resolved them:

- **Blue QR code** (bottom-left): links to the mempool.space page for the escrow address,
  `bc1qcsdfkaqgy9ux668vmzflzqsyg0qtspncymt5ed`. This is the puzzle confirming its own target.
- **Yellow Morse code** (right column): decodes to a binary-then-text message reading, in full,
  "10 things needed for the address to see prize."
- **Blue Wingdings text** (left column): decodes to "Wingdings, what a font! But it is the black
  characters you want," pointing at 10 highlighted black characters elsewhere on the card.
- Orange and white QR codes (center and bottom-center) were not decoded to puzzle content; they
  read as a generic "SCAN TO ENTER" call to action and a likely link to the author's X account.

## The course site (schoolofbitcoin.com)

- A hidden bonus slide in lesson 1, reached through the slide-selector control rather than by
  normal navigation, leads through a short redirect to a binary-encoded overlay. Decoded, it
  reads: "You found a clue to the hidden treasure of 1 FULL BITCOIN! :) abstract." This gives
  seed word 1: `abstract`.
- A downloadable file, `whatisthepassphrase.kdbx`, was served from the course site with an
  access restriction and has since been removed; it is absent from any web archive known to me.

## Passphrase construction rule (taught in the course)

The course teaches a rule for building a memorable passphrase from a short nonsensical phrase:
lowercase, no spaces between words, every "o" doubled, every "k" capitalized, with a numeric
suffix. The course's own worked example is `froogsliKetoowearpinK##1` ("frogs like to wear
pink"). The course's own client-side source code separately confirms the suffix `##3` maps to a
Bitcoin-themed passphrase, distinct from the `##1` shown in the worked example above.
