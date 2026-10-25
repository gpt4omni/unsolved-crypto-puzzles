# Puzzle material: Wealth in Poetry

Trithemius, "Securing Bitcoin Seed Phrases in Stories," Medium/Coinmonks, 2019-02-11:
https://medium.com/coinmonks/securing-bitcoin-seed-phrases-in-stories-d8eb43a02254

This narrative was written and published by the puzzle author himself specifically as the
vehicle for the puzzle; the two worked examples below are the author's own demonstration, not the
real answer.

## Worked example 1: story plus phone number

Digits of a phone number give word positions in a courtship story. Positions
`2, 6, 9, 18, 22, 25, 45, 70, 86, 100, 113, 116` give the words `faint lonely scale gate camera
shoulder adult game medal language a payment`. The author's own demonstration lands on "a" at
position 113, which is not a BIP39 wordlist word, an acknowledged imperfection in the demo.

## Worked example 2: letter plus GPS coordinates

Formula `position[i] = i*10 + digit[i]`, applied to the concatenated digits of a latitude and
longitude (38.8906 N, 77.0044 W), against a story about a letter to a court. Positions `3, 18,
28, 39, 40, 56, 67, 77, 80, 90, 104, 114` give the words `asset trial load escape symbol story
bomb picnic river aerobic mystery honey`, a fully valid 12-word BIP39 phrase with a valid
checksum.

## Closing lines

"The beauty of trithemian seeds is that they hide in plain sight. If you've read this far,
you've read every word required to access a wallet with .03 BTC. Good luck!"

"Only you know which story contains your wealth."
