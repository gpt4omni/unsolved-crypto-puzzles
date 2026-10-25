# Crypto Puzzles 2018: Puzzle #2 (0.05 ETH, [OPEN])

A small YouTube channel called "Crypto Puzzles" ran two video puzzles in July and
August 2018, each locking 0.05 ETH behind a hidden 64-character private key
encoded as glyphs in the footage, no address ever stated by the author. Puzzle #1
was solved within 3 hours of release and its prize was claimed; Puzzle #2, posted
5 days after Puzzle #1's escrow was funded by the same wallet for the same
amount, has sat untouched for 8 years. The transform is certified end to end
using Puzzle #1's own published solution as a known-good vector. What is missing
is a complete visual read of Puzzle #2's two videos. Part 1's seam yields 10 hex
characters, `6A6B0860B4`, read cleanly at 1280x720/60fps. Part 2 remains unread. A planned
template-matching pass against Puzzle #1's known glyph shapes was never finished.

## At a glance

| | |
|---|---|
| Author | unnamed; YouTube channel "Crypto Puzzles" ([channel](https://www.youtube.com/channel/UCR8-P07nNhxyEr6fwJXvjQQ)) |
| Published | 2018-08-06, YouTube, two videos ([part 1](https://www.youtube.com/watch?v=TRUUTryah70), [part 2](https://www.youtube.com/watch?v=U_0DtYHDPy0)) |
| Prize | 0.05 ETH (about $94 at ETH = $1,880, 2026-08-16) |
| Chain | ethereum |
| Escrow | `0x1fa8Be9De5bBFE047C72dB8E8E3257128F7661ad` ([explorer](https://etherscan.io/address/0x1fa8Be9De5bBFE047C72dB8E8E3257128F7661ad)) |
| Last on-chain check | 2026-10-24: re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | OPEN |
| Puzzle type | raw-private-key, image-stego, video-series |
| Target format | 64-character hex private key (32 bytes), secp256k1, Keccak-256 of the uncompressed public key to a 20-byte address, no BIP39, no passphrase, no derivation path |
| Certified oracle | yes: `tools/oracle.py --selftest` (certified against Puzzle #1's own published solution, same series) |
| What remains | a complete visual read of Puzzle #2's two videos. Part 1's seam yields 10 hex characters at 720p60, `6A6B0860B4`; part 2 is unread. See `analysis/tested.md` |
| Series | same channel as the solved Puzzle #1 (different, already-spent address); no separate folder |

## The puzzle as published

The channel posted two videos for each puzzle: a statement and, once solved, a
solution reveal. Puzzle #1's statement videos are
[3l1jFa3Mw0s](https://www.youtube.com/watch?v=3l1jFa3Mw0s) and
[hX-pOBj8VsI](https://www.youtube.com/watch?v=hX-pOBj8VsI); its solution reveal,
["Crypto Puzzle 1 Solved!"](https://www.youtube.com/watch?v=0jJ6XadOAWk), shows a
"THE SOLUTION" screen with 64 hex characters across 3 lines, held stable for the
last 6 seconds of the video, not revealed one character at a time. Puzzle #2's
two videos, [part 1](https://www.youtube.com/watch?v=TRUUTryah70) and
[part 2](https://www.youtube.com/watch?v=U_0DtYHDPy0), posted 2018-08-06, show
composite glyphs instead: part 1 wraps glyphs around the frame edges and reveals
them through two "seam" sequences (one rotated 90 degrees, one upright), with a
static decoy digit mixed in; part 2 is a mirrored scene with a vertical column
alternating between two overlaid layers. The channel has 5 videos total, about
785 combined views, and no public writeup for either puzzle in 8 years. I do not
reproduce any video frames here, since they are the author's copyrighted video
content; both puzzles are linked above by video ID.

## What is understood

### Mechanism

The author never publishes an address for either puzzle: the 64-character hex
string shown in each solution video is the private key itself, and the address
is what it derives to. No BIP39, no passphrase, no intermediate derivation. The
same funder wallet, `0x0a937ec94abc55d92f5740a988a122ebdcab2e15`, sent exactly
0.05 ETH to Puzzle #1's escrow on 2018-07-19 and to Puzzle #2's presumed escrow
on 2018-08-01, 5 days before Puzzle #2's videos went up. That the second address
is Puzzle #2's escrow is a strong inference from the funder and amount matching,
not a fact the author stated directly.

### Derivation and oracle

```
python3 tools/oracle.py --selftest
python3 tools/oracle.py "<64 hex chars>"
```

A 64-character hex candidate is read as a raw secp256k1 private key, its
uncompressed public key is hashed with Keccak-256, and the last 20 bytes of the
digest, checksummed, are compared to the escrow address.

### Certified against

`tools/oracle.py --selftest` reproduces Puzzle #1's own published answer:
`4487FC620AD0C4C67E80BE342B2EA1F5A3DC482BE6FB9C2451007322EA8BE35F`, read off that
puzzle's own solution video, derives to
`0xc99A54EEA6036115f913A13D6606e935bcA47a8f`, the address that received 0.05 ETH
on 2018-07-19 and was spent from by its winner on 2018-07-26. Reproduced
2026-08-16. This confirms both the transform and that the author genuinely pays.

### Established facts

1. Puzzle #2's escrow is funded and unspent as of 2026-08-16 (checked by RPC
   against a public Ethereum node): balance 0.05 ETH, nonce 0, one incoming
   transaction, none outgoing. Puzzle #1's escrow, re-checked the same day,
   holds 0 ETH, consistent with having been spent by its winner on 2018-07-26.
2. Reading Puzzle #1's own solution screen and deriving from it reproduces the
   address Puzzle #1 actually paid out, confirming the 64-hex-to-address
   transform (see Certified against). Its solution screen is stable for its
   last 6 seconds, not an animation revealing characters one at a time.
3. A temporal maximum-projection technique, applied across each video's frame
   sequence, reconstructs Puzzle #1's known answer correctly; applied to
   Puzzle #2 it currently reads about 40-50 of the required 64 characters, with
   recurring ambiguity between certain glyph pairs.

## What has been tested

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| The 64-hex reading transform, applied to a known answer | 1 known vector | temporal maximum-projection across the frame sequence | reproduces Puzzle #1's answer exactly | yes: known-good input reproduced | 2026-08-02 |
| Deterministic template matching of Puzzle #2's ambiguous glyphs against Puzzle #1's known letterforms | planned, not run | would use the 16 hex-digit shapes visible on Puzzle #1's solution screen | not executed | uncertified: step never run | 2026-08-02 |

## Open leads, ranked

1. **Replay Puzzle #1 end to end to fix the reading grammar** (minutes, no cost).
   Puzzle #1's videos give a case with a known answer; reconstructing exactly how
   each visual cue maps to a hex character there, then applying the same rule to
   Puzzle #2, is the strongest lever in this folder and costs nothing to try.
2. **Finish the planned template-matching pass** (hours). Extract the 16
   hex-digit glyph shapes from a clean frame of Puzzle #1's solution screen,
   correlate each of Puzzle #2's ambiguous cells against them (normal, mirrored,
   rotated), and resolve the pairing order. Planned in an earlier session, never
   carried through.
3. **Bounded fallback if a small gap remains** (minutes, after leads 1 and 2).
   If the reading leaves 8 or fewer hex characters undetermined, sweeping the
   remaining 16^8 = 4.3 billion combinations against the offline oracle is
   cheap; beyond that gap, the missing piece is the reading, not more compute.

## Files in this folder

| Path | What it is |
|---|---|
| `tools/oracle.py` | 64-hex private key to Ethereum address checker, certified against Puzzle #1's own solution |

## Sources

- Crypto Puzzle 1, statement part 1: https://www.youtube.com/watch?v=3l1jFa3Mw0s (2018-07-19)
- Crypto Puzzle 1, statement part 2: https://www.youtube.com/watch?v=hX-pOBj8VsI (2018-07-19)
- Crypto Puzzle 1 Solved!: https://www.youtube.com/watch?v=0jJ6XadOAWk (2018-07-19)
- Crypto Puzzle 2, part 1: https://www.youtube.com/watch?v=TRUUTryah70 (2018-08-06)
- Crypto Puzzle 2, part 2: https://www.youtube.com/watch?v=U_0DtYHDPy0 (2018-08-06)
- Channel "Crypto Puzzles": https://www.youtube.com/channel/UCR8-P07nNhxyEr6fwJXvjQQ
