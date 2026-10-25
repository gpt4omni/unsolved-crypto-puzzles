# Leads (full notes)

The "Open leads, ranked" section of `README.md` shows the ranked list; this file carries
the full notes behind each entry.

## 1. Ask the author directly

- **Cost**: needs a person; otherwise free.
- **What it is**: every public source I can identify is exhausted. The audio puzzle from
  the same author is fully decoded (it yields a structural hint, not a reusable secret).
  His article series has no unpublished third part. The image is confirmed clean of
  steganography. Corey Phillips is reachable through his Medium account
  (`corey-lyle-phillips`), his GitHub (`@coreyphillips`), and his employer's account
  (Synonym, `@synonymdev`); he explicitly invites solvers in his own write-up ("if you
  somehow manage to claim it, congrats!").
- **Why it ranks here**: it is the only channel that can still deliver genuinely new
  information; everything else is a search within a space I have already partly mapped.
- **What would confirm it**: any reply that narrows the passphrase's theme, length, or
  source.
- **What would kill it**: no reply; that leaves only the bounded fallbacks below.
- **Status**: open, not yet executed.

## 2. Safety-net derivation on alternate BIP paths

- **Cost**: minutes.
- **What it is**: the puzzle uses BIP84 (native segwit); replaying the 108-word
  Corey-specific corpus (already built) against BIP44 (`m/44'`) and BIP49 (`m/49'`) at the
  change level costs seconds of compute and closes off a cheap alternative-derivation
  explanation before assuming the passphrase itself is the only variable.
- **Why it ranks here**: bounded and already available (the corpus exists); low
  probability since the author's own code and article both specify BIP84, but the cost of
  checking is close to zero.
- **What would confirm it**: a derived address under BIP44 or BIP49 for any of the 108
  words matching the target.
- **What would kill it**: 108 candidates times 2 paths, 0 match (expected).
- **Status**: open, not yet run.

## 3. Three-word thematic combinator

- **Cost**: hours.
- **What it is**: only two-word combinations from the puzzle's thematic vocabulary
  (kitten, image, Corey, project names) have been tested (7,350 candidates, see
  `tested.md`). A three-word combinator over the same curated word list, with the same
  join styles, is a bounded extension that has not been run.
- **Why it ranks here**: more speculative than the safety-net check, and more expensive;
  worth trying only after lead 1 has had a chance to return new information.
- **What would confirm it**: a match among the generated three-word combinations.
- **What would kill it**: a full sweep with 0 matches.
- **Status**: open, not yet run.

## Ruled out, not re-tested

Blind dictionary attacks with no thematic basis (rockyou x dive, rockyou x d3ad0ne, on
the order of billions of candidates) are not planned next: the raw rockyou list and
rockyou with best64 rules are already exhausted (see `tested.md`), and a further blind
sweep has a low prior compared to a thematic or rule-mangled search, given the author
frames the whole puzzle as a proof of concept rather than a designed treasure hunt.
