# Exitonly Bitcoin Challenge 14 (30,000 sats, [OPEN])

The YouTube channel Exitonly ran a series of 16 numbered "Bitcoin Challenge"
videos, each publishing part of a BIP39 seed and the address holding a small
prize, with difficulty measured in how many words are missing. Challenge 14
gives 7 of the 12 words in clear and leaves 5 missing; it is the last of the 16
episodes still funded, the other 15 already spent. I found no hidden clue
anywhere in the video, using a pipeline that reads real hidden text correctly on
a different episode from the same channel that genuinely hid words in its
imagery, so this is a real negative rather than a tooling gap. The remaining
brute-force space costs thousands of times the 30,000-sat prize, so I am
documenting this as a method reference, not a target I plan to run.

## At a glance

| | |
|---|---|
| Author | Exitonly, YouTube channel ([channel](https://www.youtube.com/channel/UCRLx2BwF7wNHGoduOZE4QVw)) |
| Published | 2024-10-03, YouTube ([video](https://www.youtube.com/watch?v=jMRoWtsfCuY)) |
| Prize | 30,000 sats (about $18.90 at BTC = $63,000, 2026-08-16) |
| Chain | bitcoin |
| Escrow | `bc1q5rjy2cdfy4n4dkk4r6pxtwqlm8tgjcc2dj0ee9` ([explorer](https://mempool.space/address/bc1q5rjy2cdfy4n4dkk4r6pxtwqlm8tgjcc2dj0ee9)) |
| Last on-chain check | 2026-10-24: re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | OPEN |
| Puzzle type | bip39-seed, word-selection |
| Target format | BIP39 12 words (English), 7 given in clear, 5 missing, most likely BIP84 `m/84'/0'/0'/0/0` (script type v0_p2wpkh), no passphrase stated, positions and order of the missing words not confirmed by the author |
| Certified oracle | yes: `tools/oracle.py --selftest` (certified against the public BIP39/BIP84 test vectors; no solved sibling with a published seed exists for this channel) |
| What remains | 5 of 12 words; the brute-force cost is roughly 1,600 to 8,300 times the prize (see Established facts) |
| Series | 16 numbered "Bitcoin Challenge" episodes on the same channel; 15 already spent, this is the last one funded |

## The puzzle as published

The video is 93 seconds of stock footage with burned-in subtitles: a voice-over
and on-screen text read out 7 of the 12 seed words, in this order: `dad butter
wink follow trophy mixed erosion`. The description states the mechanism
directly: "You will find 7 out of the 12 words needed for the seed phrase. The
challenge is to guess the missing word," and "The sats in this wallet are up
for grabs, so be quick to crack the code before anyone else!" The author has
commented on this and neighboring episodes that the series is meant to be
brute-forced, not solved by insight, and specifically about this episode's
wallet: "All wallets is deleted after creation" and "I guess this 30k sats is
lost forever!" Full quotes, the description, and my own re-transcription are in
[clues/author-posts.md](clues/author-posts.md). I do not include the video file
or extracted frames here, since they are the author's copyrighted video content;
the video is linked above by ID.

## What is understood

### Mechanism

A candidate is a full 12-word BIP39 mnemonic that must match the 7 known words
and pass the BIP39 checksum, then derive under BIP84 to the escrow address.
Neither the positions of the 7 known words within the 12 nor the order in which
they were read out is confirmed by the author, so a solver cannot assume they
sit in seed order.

### Derivation and oracle

```
python3 tools/oracle.py --selftest
python3 tools/oracle.py "w1 w2 ... w12"
```

A full 12-word candidate is checked for a valid BIP39 checksum, then derived
under BIP84, BIP49, and BIP44 and compared to the escrow address.

### Certified against

No episode of this series has a publicly known seed to calibrate against, so
`tools/oracle.py --selftest` certifies the derivation against the public
BIP39/BIP84 test vector: "abandon" repeated 11 times plus "about" derives to
`bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu` under `m/84'/0'/0'/0/0`. Reproduced
2026-08-16.

### Established facts

1. The escrow is funded and unspent as of 2026-08-16 (checked via
   [mempool.space](https://mempool.space)); a single funding transaction, none
   spent.
2. As of 2026-07-31, 15 of the channel's 16 numbered challenge episodes were
   already spent; only #14 remained funded. Not re-verified today.
3. If the 5 missing positions are known and one of them is the checksum-bearing
   12th word, the space is 2048^4 x 128 = 2,251,799,813,685,248 candidates. At
   my measured local rate of 969 derivations/second (pure Python, BIP84 only)
   that is about 73,600 years on one CPU core. At an assumed 1,000,000
   derivations/second on a rented GPU, an order of magnitude I have not
   measured for this puzzle, full coverage is about 625,500 GPU-hours, roughly
   $156,000 at $0.25 per GPU-hour; even at 5,000,000 derivations/second that is
   about $31,000. Against the $18.90 prize, that is roughly 1,600 to 8,300
   times over. If the 7 known words are not in seed order, the space is 792
   times larger still.

## What has been tested

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| A hidden clue exists somewhere in the video (frames, audio, description, comments) | 186 frames at 2fps + 9 scene keyframes, full audio, description, comments | independent Whisper re-transcription; OCR on every frame and keyframe | no text found beyond the burned-in subtitles | yes: the same OCR pipeline correctly reads the 11 words genuinely hidden in episode 8's imagery on this channel | 2026-07-31 |
| Full brute force with known word positions | 2,251,799,813,685,248 candidates | not run | not attempted, cost estimated only | uncertified: no run, cost estimate below | 2026-08-16 |

## Open leads, ranked

1. **Test whether the series' seeds share a weak or correlated random source**
   (about 10 minutes of GPU time, low prior). Solving episode #12 (3 missing
   words, about 5.4x10^8 valid candidates) and comparing its full seed to
   episode #13's already-solved seed would show whether the generator behind
   this series is a standard CSPRNG or something weaker. The expected payoff
   stays capped at this episode's 30,000 sats either way, so this is a
   background task, not a priority.
2. **What is missing to run that test**: the complete solved seeds of episodes
   #11, #12, and #13 are not recorded anywhere I have access to; only the word
   lists published in their own videos are archived.

## Files in this folder

| Path | What it is |
|---|---|
| `clues/author-posts.md` | the video's known words, description, and short author/commenter quotes, verbatim |
| `tools/oracle.py` | BIP39 to BIP84/BIP49/BIP44 candidate checker, certified against the public BIP39 test vector |

## Sources

- Bitcoin Challenge 14 video: https://www.youtube.com/watch?v=jMRoWtsfCuY (2024-10-03)
- Channel Exitonly: https://www.youtube.com/channel/UCRLx2BwF7wNHGoduOZE4QVw
