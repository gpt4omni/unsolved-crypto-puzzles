# Open leads, full notes

Ranked summary is in the README. This file has the reasoning behind the ranking.

## 1. The third door: the preimage of the unmessaged planted address

The creator funded, from the vanity wallet `3GSMG24TujqfMJG1kQoBX18DzJHQLeJYMK`, one
address per stage answer with the SHA-256 of the answer as its private key, and two
"Good job, Neo!" addresses whose keys are the raw and bit-reversed bytes of the image
URL (README, "Planted addresses"; `data/planted-addresses.csv`). The one address funded
without a message, on 2020-04-07, `1NULY7DhzuNvSDtPkFzNo6oRTZQWBqXNE9`, has no known
preimage. It was planted four days after the two door markers, between the January
2020 poem and the April 2020 audio hint, and the creator named it in December 2020 as
a verification address and a year later said that door was "still a thing"
(Telegram, reported). It is an exact, free, offline oracle: a candidate is hashed (or
padded, or bit-reversed) into a key and its compressed and uncompressed P2PKH
addresses compared to the list, at about 176,000 keys/s per core.

Everything textual is negative under the six constructions (`analysis/tested.md`
sections 18 and 19): the puzzle's vocabulary, the system dictionary, short word
windows of every text and of the three films, `gsmg.io/` paths, the image's text and
numbers and colour masks, the 8 image texts, every page hashed, the phase 2.1 riddle,
prime-rank derivatives of the digit objects.

What would confirm it: an address match.
What would kill it, family by family: the creator's rules from that window, "Yellow
has a number and so does Blue", "primes", "zeroed out", read on a non-textual object
and exhausted; then, when noise is acceptable, a GPU brainwallet pass (SHA-256
construction) over large dictionaries and a CPU pass for the raw construction, which
is at most 32 bytes and therefore a short phrase.
Cost: seconds per family on a CPU; the GPU pass is minutes.

## 2. Both 80-byte locks, with extended readings

The phase 3.2.2 blob (2019, inside the phase 3.2 plaintext) and the SalPhaseIon small
blob (2021) have the same shape: `Salted__`, 80 bytes of ciphertext, 64 to 80 bytes of
plaintext. "The private keys belong to half and better half" precedes the first,
"yinyang" is announced as the phase after the second, and the creator's 2021-07-18
"neighbors, half and double" transaction pays the uncompressed addresses of 2P and P/2
of the prize key. A working hypothesis is that the two plaintexts are the two halves,
two keys or a key and its double or half. Every password is therefore tested against
both locks, and every plaintext with valid padding is read 40 ways (as is, reversed,
bit-reversed, doubled, halved, plus or minus one modulo n) before the oracle. The
11,473 valid-padding plaintexts from sections 15 to 17 have been re-read that way, 0
match.

What would confirm it: either lock opening.
What would kill it: nothing bounded; it is a discipline applied to every password
family, not a space of its own.
Cost: none beyond the families themselves.

## 3. Replay the dynamically-constructed candidates that a filter bug never reached

The 2026-07-28 review (see `analysis/tested.md`) found that an appearance-based
acceptance filter had been silently rejecting the correct answer shape in 98 of 213
historical scripts. A first replay already resubmitted 116,043 literal strings
harvested from those scripts directly to the real address comparison (0 match, see
`analysis/tested.md` row 8), but that replay covers literal strings only. The same
scripts also constructed candidates dynamically at run time: token concatenations,
permutations of decoded fragments, and chained transforms (for example, applying a
Vigenere step and then a substitution step in sequence). Those dynamic candidates
were generated, passed through the same broken filter, and discarded, but were
never logged as literal strings, so this first replay cannot reach them.

What would confirm it: re-running each script's own candidate-generation logic
(not just its final output) with the filter bug fixed, and finding a match.
What would kill it: exhausting the same generation logic with no match; since the
scripts number in the hundreds, this is judged in stages, not as one pass.
Cost: hours to days, since the generation logic differs script by script and each
needs re-reading before it can be replayed correctly.

## 7. Determine whether the 256-symbol object is the right object at all

Every hypothesis in `analysis/tested.md` rows 1 to 5 assumes the final key comes
directly from the 256-symbol, 23-letter object produced by the puzzle's Bifid
decoding step. That assumption has one point in its favor: of the 7 possible
letter-pairs that could be removed from the 285-letter pre-reduction stream to
leave exactly 256 symbols, exactly one (the pair I and O) yields a Base58-valid
alphabet, which is unlikely to be accidental. But the object itself is written
entirely in uppercase letters, and an all-uppercase Base58 encoding of 32 bytes has
a chance of about 1 in 10^17 of arising by coincidence, which argues against reading
it as a literal Base58 string (consistent with row 4 and row 5 both being negative).

What would confirm it: a reduction of the object to 32 bytes, other than the ones
already tried, that matches an address.
What would kill it, or redirect it: establishing that the final key instead comes
from the AES-blob route this folder's oracle implements (`tools/oracle.py`), or
from the still-unopened "Dualite" blob, making the 256-symbol object a waypoint
rather than the key's direct source.
Cost: an afternoon of directed reasoning, not a sweep; this lead is about which
object to target next, not about enumerating more of the current one.

## 4. Identify the tool the author says was used at every phase

An authenticated statement from the puzzle's author says the same software was used
to build every phase of the puzzle. Comparing the cipher conventions confirmed on
already-solved stages against one specific, publicly available cipher tool's source
code shows an exact match on non-obvious implementation details: the tool's Bifid
implementation takes no period parameter (it always uses a period equal to the full
message length, which is exactly the convention confirmed on this puzzle's own
Bifid step), and its available cipher list is short. If this identification is
right, it bounds every remaining cipher hypothesis to that tool's own menu, instead
of the space of all published ciphers.

What would confirm it: a cipher from that tool's menu, applied with its default
conventions, producing a match on a currently unexplained object (most plausibly
the "Dualite" blob's password, or the reduction step from the 256-symbol object).
What would kill it: the author naming a different tool, or every cipher on the
identified tool's menu being exhausted with no match.
Cost: the tool's menu is short (documented in the private research as fewer than a
dozen ciphers); testing all of them against the currently open objects is a matter
of hours.

## 5. Follow "esrever" on the remaining objects

The earliest hint attributed to the author reads "esrever" ("reverse" spelled
backwards). On the object it was paired with, the image's binary code, it is now
explained: the 192 bits of `gsmg.io/theseedisplanted` reversed are the private key
of the second "Good job, Neo!" address (`data/planted-addresses.csv`). It has not
been exhausted on the current final-gate objects (the 256-symbol object, the two
locks' plaintexts beyond the extended readings of lead 2, or the "Dualite" blob).

What would confirm it: applying a reversal (of reading order, of case, or of the
described object itself) to one of the current final-gate objects and getting a
match.
What would kill it: exhausting the small set of reasonable "reverse" readings
(string reversal, bit reversal, reading-order reversal) on all three current
objects with no match.
Cost: minutes to hours; this is a small, well-defined space, not a sweep.

## 6. Read the 29 symbols dropped during the object-256 reduction

Reducing the 285-letter pre-reduction stream to the 256-symbol object drops exactly
29 letters (the I's and O's removed to reach the Base58-safe alphabet). Every
hypothesis so far treats those 29 letters as discard. They have not been read as a
message in their own right, in their own extraction order.

What would confirm it: reading the 29 dropped letters (in order of removal) as
their own object and finding a match, or a legible fragment that leads to one.
What would kill it: reading them under the small set of reasonable orderings
(extraction order, position order) and finding neither a match nor a legible
fragment.
Cost: minutes; the space is small (29 letters, a handful of reading orders).

## Where the "Dualite" blob and the second address fit

The "Dualite" blob (see the README's mechanism section) is confirmed to be
well-formed AES-CBC ciphertext, not noise, and has never been decrypted: the
community's "decrypt" is a padding accident (`analysis/tested.md` section 14), and
9,252 passwords tested for a nested layer inside it found none (section 17). The
second address is the halving split-off, not a payout (README, "The puzzle as
published"), and nothing published links the blob to it. No lead above targets the
blob with a password sweep of its own; leads 3 and 4 are the routes most likely to
produce a password hypothesis for it.

## 8. Re-run anything that was tested through the shipped oracle

Not a hypothesis about the puzzle, but the precondition for trusting any result from this
folder's own tool. Until 2026-08-19 `tools/oracle.py` derived the AES key with
EVP_BytesToKey/MD5, which fails on every blob in this puzzle whose password is known
(`analysis/tested.md` section 10). Any candidate previously pushed through it was compared
against a key the puzzle does not produce.

What would confirm it: nothing further; the derivation is now certified against the
phase-2 blob, and the selftest asserts that MD5 fails on the same blob.
What this changes: negatives obtained through the shipped oracle are void rather than
negative. Section 9's sweeps have been re-run under the corrected derivation. Anyone who
swept this pipeline independently before this date should assume the same.
Cost: the pipeline runs at about 76,800 candidates per second per core, so re-running a
past sweep costs roughly what the original cost.

## 9. The small blob is on the SalPhaseIon page, not the final page (the literal reading is closed)

The README described the small blob as published on the final page reached after the
Architect Choice. It is published on the SalPhaseIon page,
`gsmg.io/89727c598b9cd1cf8873f27cb7057f050645ddb6a7a157a110239ac0152f6a32`, reached by a
different route: hashing the text of the first puzzle page. Verified by reassembling the
blob from that page's own single-character token run, where the two 64-character halves sit
at token positions 916 and 1020 with a 40-character run of a and b between them; reading
that run as a=0, b=1 gives the five bytes `enter`.

Why it matters as a lead, not just a correction: the password should be sought in the
instructions on the page that carries the blob. That page decodes to exactly two
directives, `lastwordsbeforearchichoice` and `thispassword`, which read together as a
statement that the last words before the Architect Choice are this blob's password.
What would confirm it: a reading of those "last words" that matches.
Status 2026-09-02: the literal reading is closed. Every window of up to 20 words,
every suffix and prefix, of every text the solver holds, including the Architect scene
of the film and the transcripts of the three films up to 15 words, is negative as the
password of both locks under 7 forms and 2 key derivations (`analysis/tested.md`
section 15). The phase 1 image's text is transcribed and tested too (section 19). What
survives is a non-literal reading of the two directives.
Cost: an insight, not a sweep.
