# Open leads, full notes

Ranked summary is in the README. This file has the reasoning behind the ranking.

## 1. A photograph of AA012381's back face (highest expected value)

AA012381's passphrase is already known and photo-confirmed legible:
`594Y-L2RW-4ME7-2XVX-9B41`. What is missing is a photograph of the card's back face,
which carries the BIP38-encrypted WIF (the `6P...` blob) under a tamper-evident
sticker that was never removed in any published photo. The front face (address and
scratch-off) is the only face of this card published in the `oritwoen/boha` mirror.

If this single photograph surfaced, decoding the QR code (or transcribing the printed
string) and running it through `tools/oracle.py` with the known passphrase would be an
immediate offline check: this is the only one of the two open cards where exactly one
artifact is missing and the other half is already in hand.

What would confirm it: the encrypted WIF from that photograph, run through
`tools/oracle.py "<encrypted_wif> 594Y-L2RW-4ME7-2XVX-9B41 1QGtbKxx6FKDD66LwnrzHCAHmyZ7mDHqC4"`,
returns MATCH.
What would kill it: no such photograph exists or surfaces; Bobby Lee, Ballet's own
channels, or a conference demo attendee would be the plausible source, since the
`boha` community mirror only has the front face for this card.
Cost: needs new information from a person; no compute cost once the photograph exists.

## 2. A photograph of AA009926's passphrase scratch-off face

AA009926 publishes the opposite half: its encrypted WIF is known
(`6PnQmAyBky9ZXJyZBv9QSGRUXkKh9HfnVsZWPn4YtcwoKy5vufUgfA3Ld7`), and its passphrase
scratch-off (front face) has never been scratched in any published photograph.

Each passphrase character recovered from a partial or angled photograph of the
scratch-off residue divides the residual ~100-bit space by approximately 32 (the size
of the observed passphrase alphabet). A handful of confirmed characters would make
the remainder brute-forceable with the existing oracle; a full readout would solve it
outright the same way as lead 1.

What would confirm it: any subset of the 20 passphrase characters, tested with
`tools/oracle.py` against the known encrypted WIF; a full 20-character read returns
MATCH directly.
What would kill it: no photograph of this face surfaces, or a surfaced photograph
still shows the scratch-off intact (unreadable).
Cost: needs new information from a person; the residual compute cost after a partial
read depends on how many characters are recovered (each unknown group of 4 costs
roughly 32^4, about 1e6, scrypt evaluations, which is minutes to hours on one GPU;
the full 20-character space is not compute-feasible as shown in `analysis/tested.md`).

## 3. A credible disclosure of a Ballet 2020 entropy weakness

No published vulnerability report, theft disclosure, or third-party audit describing
a weakness in Ballet's card-generation process exists as of 2026-08-16. Ballet states
passphrase entropy comes from dice rolls in a Las Vegas facility, with manufacturing
data destroyed after printing, which removes the two most common weaknesses in this
class of hardware wallet (a predictable RNG seed, or a leaked manufacturing log).

What would confirm it: a credible security researcher publishing a reproducible
weakness in Ballet's 2020-era entropy generation, with enough detail to narrow either
card's residual space below what brute force can cover on rented compute.
What would kill it: this lead has no expiry; it simply has nothing to test today.
Cost: needs a research breakthrough from a third party; no action available now.
