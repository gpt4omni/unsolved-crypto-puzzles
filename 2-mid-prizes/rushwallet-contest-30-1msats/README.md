# RushWallet Contest #30 (1,000,000 sats, [OPEN])

RushWallet, a KryptoKit product, ran a 30-brainwallet treasure hunt around 2014-2015: each
address holds a small prize claimable by anyone who finds the passphrase that hashes to its
private key. All 29 other addresses were claimed by real solvers over the life of the
contest's BitcoinTalk thread; #30 is the sole one still open. I read the derivation directly
from the contest's own archived client-side script and certified it against 2 sibling
brainwallets. I have tried about 95 million candidate passphrases across public wordlists,
brainwallet-specific lists, quotations and song lyrics, with zero matches. The likely gate is
a video clue only legible above the 720p footage I could find.

## At a glance

| | |
|---|---|
| Author | RushWallet / KryptoKit (site defunct; contest hosted at rushwallet.com) |
| Published | earliest archived capture of the live contest script: 2015-02-08 ([Wayback](http://web.archive.org/web/20150208174448/https://rushwallet.com/js/contest.js)); the RushWallet site and its promotional video are commonly dated to 2014 |
| Prize | 1,000,000 sats (about $630 at BTC = $63,000, 2026-08-16) |
| Chain | bitcoin |
| Escrow | `13Q8hJqagtd77ojTJcEZPjTz2sBFSsYxyj` ([explorer](https://mempool.space/address/13Q8hJqagtd77ojTJcEZPjTz2sBFSsYxyj)) |
| Last on-chain check | 2026-10-24: re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | OPEN |
| Puzzle type | brainwallet, audio |
| Target format | an unknown passphrase string, hashed verbatim (no trim, no case folding), uncompressed P2PKH |
| Certified oracle | yes: `tools/oracle.py --selftest` (certified against passphrases publicly claimed for 2 sibling brainwallets, #17 and #28, in the same contest) |
| What remains | the passphrase string itself; no wordlist tried so far has produced it, and the leading lead is a higher-resolution copy of the promotional video |
| Series | RushWallet/KryptoKit 30-brainwallet contest; this is the last unclaimed lot |

## The puzzle as published

The contest's client-side script, archived 2015-02-08, lists all 30 contest addresses and
implements the check directly:

```javascript
var bytes = Bitcoin.Crypto.SHA256($("#txtBrain").val(), {asBytes: true});
var address = new Bitcoin.Key(bytes).getBitcoinAddress().toString();
```

A promotional video accompanied the contest (original upload `sr8lBrtd9U4`, since removed
from YouTube; a surviving re-upload is `x0LqsUOIw0M`). Its audio track carries a Morse-code
message, "the puzzles are just the beginning," and it shows a person holding a printed copy
of the Bitcoin whitepaper, a whiteboard, and a QR code, all only partly legible at the
resolutions still available. A PGP-signed message posted 2014-12-25 on the contest's
BitcoinTalk thread and a QR code decoded from the video round out the public material; full
quotes with links are in [clues/author-posts.md](clues/author-posts.md). None of this
material has produced a passphrase for #30 specifically: a QR code visible in the video
decodes to the passphrase for a different puzzle in the same contest (#19), a documented
red herring.

## What is understood

### Mechanism

`private_key = SHA256(utf8(passphrase))`, the passphrase taken exactly as typed, no
trimming, no case change, no salt. The public key is uncompressed (`0x04 || X || Y`,
`Bitcoin.Key`'s default behavior in this 2014 library), and the address is
`base58check(0x00 || RIPEMD160(SHA256(pubkey)))`. The only unknown is the passphrase
string; the check is exact address equality.

### Derivation and oracle

```
python3 tools/oracle.py --selftest
python3 tools/oracle.py "candidate passphrase"
```

`MATCH <address>` on a hit, `NO MATCH` otherwise, exit 0 or 1.

### Certified against

`tools/oracle.py --selftest` reproduces 3 known-good vectors: the passphrases "Dmitri Nancy
Enrique" and "Dmitri Enrique Nancy," publicly claimed by other solvers for puzzles #17 and
#28 of the same contest, and "www.rushwallet.com" for the contest host's own address (one of
the 30 listed in the contest script). All 3 reproduced 2026-08-16.

### Established facts

1. I confirmed the escrow holds a 1,000,000 sats residue, funded 2015-04-24 and unspent
   since, on top of an unrelated 100,000,000 sats deposit that arrived 2014-09-22 and was
   returned to its own sender 2015-03-25 (checked via [mempool.space](https://mempool.space)).
2. I read the derivation directly from the contest's own script; it is not inferred.
3. 27 of the 30 contest passphrases are publicly known from claimed brainwallets; their
   phrasing (deliberate case irregularity, 2 to 6-word repetitions, direct URLs, character
   names, marketing slogans) sets the style prior I used to build the tested candidate lists.

## What has been tested

Full ledger in [analysis/tested.md](analysis/tested.md). Summary:

| Hypothesis | Candidates | Result | Date |
|---|---|---|---|
| Structured passphrases from the video and contest text | about 3,000 | 0 match | 2026 |
| rockyou.txt, 5 case variants | 37,523,253 | 0 match | 2026 |
| Brainwallet-specific dictionaries | 2,292,116 | 0 match | 2026 |
| King James Bible, full text by verse | 725,198 | 0 match | 2026 |
| Canonical-source exact windows (whitepaper, press release, Donne) | 1,959,326 | 0 match | 2026 |
| Song lyrics, top 301,000 songs | 52,299,649 | 0 match | 2026 |
| OCR and community guesses | about 509,399 | 0 match | 2026 |
| Quotes-500K corpus (`jstet/quotes-500k`), case variants plus surface normalizations | 3,376,547 | 0 match | 2026-08-22 |
| Full genius-song-lyrics corpus tail plus re-test of the top slice (`Dr3dre/Genius-song-lyrics-cleaned`, English-language songs, per-song line dedupe), GPU brainwallet engine | 456,693,751 | 0 match | 2026-08-23 |

About 552 million candidates in total, 0 matches. Rounds 1 through 3 are reported as
candidates consumed without planted witnesses. Rounds 4 and 5 are witnessed: in round 4
the 3 public sibling passphrases were planted at head/middle/tail of the stream and all
recovered through the same code path; in round 5 the checker kernel passed its built-in
certification vectors plus an end-to-end positive control immediately before the run, and
its consumed-candidate counter matched the fed count exactly.

## Open leads, ranked

1. **A higher-fidelity copy of the original video** (needs new information). The whiteboard
   and whitepaper page held on camera are only legible above 720p, and no source above 720p
   is currently reachable. Full details in [analysis/leads.md](analysis/leads.md).
2. **KILLED 2026-08-22: the Quotes-500K corpus.** Executed as round 4 with planted
   witnesses; see [analysis/tested.md](analysis/tested.md). This lead is closed.
3. **KILLED 2026-08-23: the remaining tail of the lyrics corpus.** Executed as round 5 on
   a rented GPU with an end-to-end positive control; about 456.7 million candidates across
   the full ~5.1 million-song corpus (English-language songs). This lead is closed.

## Files in this folder

| Path | What it is |
|---|---|
| `clues/author-posts.md` | dated quotes from the contest script, video audio, and BitcoinTalk thread, with links |
| `analysis/tested.md` | the complete negatives ledger |
| `analysis/leads.md` | full notes behind the 3 ranked leads |
| `tools/oracle.py` | candidate checker, certified against 2 sibling brainwallets' known passphrases |

## Sources

- RushWallet contest script, archived 2015-02-08: http://web.archive.org/web/20150208174448/https://rushwallet.com/js/contest.js
- RushWallet contest page, archived 2015-02-08: http://web.archive.org/web/20150208172337/https://rushwallet.com/contest
- BitcoinTalk discussion thread: https://bitcointalk.org/index.php?topic=793720.0
- Surviving video re-upload: https://www.youtube.com/watch?v=x0LqsUOIw0M
