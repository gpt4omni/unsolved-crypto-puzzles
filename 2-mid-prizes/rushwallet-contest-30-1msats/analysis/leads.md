# Open leads, full notes

## 1. A higher-fidelity copy of the original video

The whiteboard and the Bitcoin whitepaper page held by a person in the video ("Dmitri")
only become legible above 720p, and no source above 720p is currently reachable: both
known YouTube video IDs are dead, and a direct video-index lookup on the Wayback Machine
returns "not archived or indexed" (the HTML page for the video is archived; the video
stream itself is not, in this index). A full-site WARC capture of the original upload may
exist under archive.org outside the indexes already checked, since archive.org keeps some
video content outside the standard video index. This is the highest-ranked lead because it
is the only channel identified so far where the puzzle's own material (not a wordlist) is
suspected to contain the answer, and it is currently unread rather than ruled out.

## 2. An unabsorbed public quote corpus

The Quotes-500K corpus (compiled by ShivaliGoel, linked from the original source as
`goo.gl/R3Sa34`) has not been run against the oracle. Given the contest's other clues favor
short, quotable, thematically loaded phrases (see the John Donne and whitepaper-title
material already tested), a quote corpus of this kind is a plausible next family at a low
cost, on the order of minutes once prepared.

## 3. The uncovered tail of the lyrics corpus

The lyrics sweep in the tested ledger covered the most-viewed 301,000-song, 12-million-line
slice of a larger corpus. The remaining tail, roughly 4.7 million further songs, was never
ingested. This is ranked below leads 1 and 2 because it is a much larger, much lower
signal-to-noise family: nothing in the contest's own material specifically points to an
obscure song.

## Explicitly not recommended

A blind character-mask search (fixed length, unconstrained charset) is not recommended
unless a new constraint fixes the structure of #30's passphrase; without that, a masked
brute force over an open charset has no realistic bound and would not be a bounded search
in the sense this project otherwise requires.
