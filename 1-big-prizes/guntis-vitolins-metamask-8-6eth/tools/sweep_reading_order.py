#!/usr/bin/env python3
"""
sweep_reading_order.py -- the complete reading-order model for this challenge.

WHAT THIS SWEEPS

Hypothesis: all 12 elements are whole words appearing in the recovered 2020
written surfaces, 6 from the video side and 6 from the post side, and they keep
the order in which they are written. The 3 author-stated anchors are fixed:
`dutch` at position 1, `fog` at position 5, `parrot` at position 12.

`fork` is treated as a floater. It appears only in the post's tag "ethereum
fork", and a tag has no position in running prose, so it has no reading-order
slot and may occupy any of the 5 non-anchor post slots. `fiber` by contrast
sits after `dutch` in post reading order, so it needs no exemption. That is
consistent with hint 5 naming only `fork` as out of place.

THE SPACE, AS A CLOSED FORM

  video word sets   = C(25,2)*C(2,2) + C(25,3)*C(2,1) = 300 + 4,600 = 4,900
  templates         = C(3,2)*C(6,2) = 45  for the (2 pre-fog, 2 mid) shape
                      C(3,3)*C(6,1) = 6   for the (3 pre-fog, 1 mid) shape
  video pairs       = 300*45 + 4,600*6 = 13,500 + 27,600 = 41,100
  post word sets    = C(18,3) = 816
  fork slot choices = 5
  arrangements      = 41,100 * 816 * 5 = 167,688,000

About 1 arrangement in 16 passes the BIP39 checksum, so expect close to
1.048x10^7 derivations. `--size` prints these numbers and checks that the
layout enumeration reproduces them before any work is done.

A CONSTRAINT THAT FALLS OUT OF THE ANCHORS

With `fog` at 5 and `parrot` at 12 and order preserved, the 4 free video words
split k before `fog` and m between `fog` and `parrot`, with k+m=4. Only 2
dictionary words lie between `fog` and `parrot` in the video text, so m is at
most 2 and k is at most 3, forcing (k,m) to be (2,2) or (3,1). Every
arrangement in this space therefore contains at least 1 of those 2 mid words.
If this sweep is negative over its whole space, then either the pool is
incomplete or order is not preserved. See `analysis/leads.md`.

UNITS AND RESUMPTION

1 unit = 1 post word set, so 816 units of 205,500 arrangements each. The log is
flushed after every unit, so an interrupted run resumes with `--resume`. The
original run of this space used 3,264 smaller units ordered by how far each
candidate strays from the 5 planted sentences; the space enumerated is
identical.

USAGE

  python3 tools/sweep_reading_order.py --size
  python3 tools/sweep_reading_order.py --selftest
  python3 tools/sweep_reading_order.py --run --log sweep.tsv
  python3 tools/sweep_reading_order.py --run --log sweep.tsv --resume

The BIP-0039 English wordlist is not included in this repository. Supply it
with `--wordlist PATH` or in `$BIP39_WORDLIST`. Its expected SHA-256 is
checked, so a wrong or reordered list is rejected rather than silently used.

Dependencies: stdlib for enumeration and the checksum filter, which is why
`--size` and most of `--selftest` run anywhere. Derivation is delegated to
`tools/oracle.py` in this same folder, which needs `bip_utils`.
"""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)

WORDLIST_SHA256 = "2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda"
TARGET_ADDRESS = "0x9c2f44efad0c1e852a09df9939e6daf061140caf"

# 0-based seed positions.
DUTCH, FOG, PARROT = 0, 4, 11
PRE_SLOTS = (1, 2, 3)
MID_SLOTS = (5, 6, 7, 8, 9, 10)

SHIFT = [11 * (11 - p) for p in range(12)]
ENT_MASK = (1 << 128) - 1


def load_wordlist(path):
    with open(path, "rb") as fh:
        raw = fh.read()
    words = raw.decode("utf-8").split()
    if len(words) != 2048:
        sys.exit("wordlist has %d words, expected 2048" % len(words))
    digest = hashlib.sha256(("\n".join(words) + "\n").encode("utf-8")).hexdigest()
    if digest != WORDLIST_SHA256:
        sys.exit("wordlist SHA-256 is %s, expected the canonical %s"
                 % (digest, WORDLIST_SHA256))
    return words, {w: i for i, w in enumerate(words)}


def load_pool(path):
    with open(path, encoding="utf-8") as fh:
        d = json.load(fh)
    pre = d["video_pre_fog"]
    mid = d["video_between_fog_and_parrot"]
    post = d["post_reading_order_after_dutch"]
    free = [w for w in post if w != "fiber"]
    if (len(pre), len(mid), len(post), len(free)) != (25, 2, 19, 18):
        sys.exit("pool shape is %d/%d/%d/%d, expected 25/2/19/18; the closed form "
                 "assumes those sizes, so re-derive it before running"
                 % (len(pre), len(mid), len(post), len(free)))
    if "fiber" not in post:
        sys.exit("fiber is missing from the post reading order; it is a confirmed "
                 "member and must keep its written place")
    # Reading order is what the model is testing, so the position of fiber
    # relative to the free words is load bearing, not cosmetic.
    order = {w: i for i, w in enumerate(post)}
    return pre, mid, free, order


def closed_form():
    c = math.comb
    vsets = c(25, 2) * c(2, 2) + c(25, 3) * c(2, 1)
    t22 = c(3, 2) * c(6, 2)
    t31 = c(3, 3) * c(6, 1)
    vpairs = c(25, 2) * c(2, 2) * t22 + c(25, 3) * c(2, 1) * t31
    bsets = c(18, 3)
    return {"video_sets": vsets, "templates_2_2": t22, "templates_3_1": t31,
            "video_pairs": vpairs, "post_sets": bsets, "fork_slots": 5,
            "arrangements": vpairs * bsets * 5}


def shapes():
    return [(k, 4 - k) for k in range(0, 4) if 0 <= 4 - k <= 2]


def layouts(k, m):
    """One layout is a video slot assignment plus the fork choices it allows."""
    out = []
    for pre in itertools.combinations(PRE_SLOTS, k):
        for mid in itertools.combinations(MID_SLOTS, m):
            vpos = pre + (FOG,) + mid + (PARROT,)
            used = set(vpos) | {DUTCH}
            post = [p for p in range(12) if p not in used]
            if len(post) != 5:
                sys.exit("layout produced %d post slots, expected 5" % len(post))
            forks = [(f, tuple(p for p in post if p != f)) for f in post]
            out.append((vpos, forks))
    return out


def video_sets(pre, mid, index_of):
    """Word-index tuples for the free video slots, pre words then mid words,
    each group in written order, keyed by shape."""
    by_shape = {}
    for (k, m) in shapes():
        rows = []
        for a in itertools.combinations(pre, k):
            for b in itertools.combinations(mid, m):
                rows.append(tuple(index_of[w] for w in a + b))
        by_shape[(k, m)] = rows
    return by_shape


def build_layouts():
    return {(k, m): layouts(k, m) for (k, m) in shapes()}


def scan_unit(bset, pool, index_of, words, lay, vsets, order, derive, target,
              witness_cap=1):
    """Sweep 1 post word set across every video pair and fork slot.

    Returns (arrangements, derivations, hit_mnemonic_or_None, witness_state).
    The witness state is OK when an independently recomputed address for the
    first derived candidate agrees, so a unit that reports OK has proved its own
    pipeline live rather than assuming it.
    """
    ordered4 = [index_of[w] for w in
                sorted(list(bset) + ["fiber"], key=lambda w: order[w])]
    fork_i = index_of["fork"]
    base_anchor = ((index_of["dutch"] << SHIFT[DUTCH])
                   + (index_of["fog"] << SHIFT[FOG])
                   + (index_of["parrot"] << SHIFT[PARROT]))
    sha = hashlib.sha256
    n = d = 0
    wstate = "NONE"
    witnessed = 0
    for (k, m), rows in vsets.items():
        if not rows:
            continue
        for vpos, forks in lay[(k, m)]:
            free_slots = [SHIFT[p] for p in vpos[:k] + vpos[k + 1:-1]]
            for fslot, others in forks:
                base = base_anchor + (fork_i << SHIFT[fslot])
                for w4, p in zip(ordered4, others):
                    base += w4 << SHIFT[p]
                for v in rows:
                    acc = base
                    for wi, sh in zip(v, free_slots):
                        acc += wi << sh
                    n += 1
                    ent = ((acc >> 4) & ENT_MASK).to_bytes(16, "big")
                    if (sha(ent).digest()[0] >> 4) != (acc & 0xF):
                        continue
                    d += 1
                    mnemonic = " ".join(
                        words[(acc >> SHIFT[p]) & 0x7FF] for p in range(12))
                    address = derive(mnemonic)
                    if witnessed < witness_cap:
                        witnessed += 1
                        wstate = "OK" if _recheck(mnemonic, address) else "FAIL"
                    elif wstate == "NONE":
                        wstate = "SKIP"
                    if address == target:
                        return n, d, mnemonic, wstate
    return n, d, None, wstate


def _recheck(mnemonic, address):
    """Independent confirmation that the derivation is reproducible: re-derive
    through a fresh call and require the same answer. A real cross-engine check
    is stronger; this at least catches a stateful or cached derivation."""
    return _oracle().derive_address(mnemonic) == address


_ORACLE = None


def _oracle():
    global _ORACLE
    if _ORACLE is None:
        sys.path.insert(0, HERE)
        try:
            import oracle
        except ImportError as exc:
            sys.exit("cannot import tools/oracle.py (%s). Derivation needs "
                     "bip_utils; --size and the stdlib parts of --selftest do "
                     "not." % exc)
        _ORACLE = oracle
    return _ORACLE


def cmd_size(args):
    cf = closed_form()
    for key in ("video_sets", "templates_2_2", "templates_3_1", "video_pairs",
                "post_sets", "fork_slots", "arrangements"):
        print("%-16s %s" % (key, format(cf[key], ",")))
    lay = build_layouts()
    counted = 0
    for (k, m), rows in lay.items():
        print("shape (%d,%d): %d layouts" % (k, m, len(rows)))
        counted += len(rows) * (math.comb(25, k) * math.comb(2, m)) * 5
    counted *= cf["post_sets"]
    print("enumerated layouts reproduce the closed form: %s"
          % ("yes" if counted == cf["arrangements"] else
             "NO (%s)" % format(counted, ",")))
    print("expected derivations at 1 in 16: about %s"
          % format(cf["arrangements"] // 16, ","))
    if counted != cf["arrangements"]:
        return 1
    return 0


def cmd_selftest(args):
    ok = True

    cf = closed_form()
    part = cf["arrangements"] == 167688000
    print("closed form gives 167,688,000 arrangements: %s"
          % ("OK" if part else "FAIL"))
    ok = ok and part

    part = cmd_size(argparse.Namespace()) == 0
    print("layout enumeration agrees with the closed form: %s"
          % ("OK" if part else "FAIL"))
    ok = ok and part

    words, index_of = load_wordlist(args.wordlist)
    print("wordlist is the canonical BIP-0039 English list: OK")

    pre, mid, free, order = load_pool(args.pool)
    part = set(mid) == {"lake", "also"}
    print("the 2 words between fog and parrot are lake and also: %s"
          % ("OK" if part else "FAIL"))
    ok = ok and part

    for w in ("dutch", "fog", "parrot", "fiber", "fork"):
        if w not in index_of:
            print("anchor word %s is not in the wordlist: FAIL" % w)
            ok = False

    # Checksum acceptance rate, measured on real enumerated arrangements rather
    # than assumed. A rate far from 1 in 16 means the packing is wrong.
    lay = build_layouts()
    vsets = video_sets(pre, mid, index_of)
    bset = tuple(free[:3])
    n, d, hit, _ = scan_unit(bset, None, index_of, words, lay, vsets, order,
                             lambda mn: "0x" + "0" * 40, TARGET_ADDRESS,
                             witness_cap=0)
    rate = d / n if n else 0.0
    part = abs(rate - 1 / 16) < 0.004 and n == 205500
    print("1 unit enumerates 205,500 arrangements, %d pass the checksum, "
          "rate %.4f against 0.0625: %s" % (d, rate, "OK" if part else "FAIL"))
    ok = ok and part

    # Plant a witness: take a real enumerated candidate, make its own address
    # the target, and require the pipeline to find it. This is the check that
    # a negative result from this script is worth anything.
    try:
        derive = _oracle().derive_address
    except SystemExit:
        print("derivation is unavailable here, so the planted-witness check and "
              "the canonical vector check were not run. A negative produced in "
              "this environment would be UNCERTIFIED.")
        print("SELFTEST INCOMPLETE")
        return 1 if not ok else 2

    vector = " ".join(["abandon"] * 11 + ["about"])
    part = derive(vector) == "0x9858effd232b4033e47d90003d41ec34ecaeda94"
    print("canonical BIP-0039 vector derives its published address: %s"
          % ("OK" if part else "FAIL"))
    ok = ok and part

    probe = {}

    def capture(mn):
        addr = derive(mn)
        probe.setdefault("first", (mn, addr))
        return addr

    n, d, hit, wstate = scan_unit(bset, None, index_of, words, lay, vsets, order,
                                  capture, "0x" + "f" * 40, witness_cap=1)
    if not probe:
        print("no candidate was derived, so no witness could be planted: FAIL")
        ok = False
    else:
        planted_mn, planted_addr = probe["first"]
        n2, d2, hit2, w2 = scan_unit(
            bset, None, index_of, words, lay, vsets, order,
            derive, planted_addr, witness_cap=1)
        part = hit2 == planted_mn and w2 == "OK"
        print("a planted candidate is recovered through the identical pipeline: "
              "%s" % ("OK" if part else "FAIL"))
        ok = ok and part

    if ok:
        print("SELFTEST OK")
    return 0 if ok else 1


def cmd_run(args):
    words, index_of = load_wordlist(args.wordlist)
    pre, mid, free, order = load_pool(args.pool)
    lay = build_layouts()
    vsets = video_sets(pre, mid, index_of)
    derive = _oracle().derive_address

    units = list(itertools.combinations(free, 3))
    done = set()
    if args.resume and os.path.exists(args.log):
        with open(args.log, encoding="utf-8") as fh:
            for line in fh:
                cols = line.rstrip("\n").split("\t")
                if len(cols) > 1 and cols[0] != "unit":
                    done.add(int(cols[0]))
        print("resuming, %d of %d units already logged" % (len(done), len(units)))

    new = not os.path.exists(args.log)
    log = open(args.log, "a", encoding="utf-8")
    if new:
        log.write("unit\tarrangements\tderivations\twitness\tseconds\n")
        log.flush()

    total_n = total_d = 0
    started = time.time()
    for idx, bset in enumerate(units):
        if idx in done:
            continue
        if args.deadline and time.time() - started > args.deadline:
            print("deadline reached, stopping cleanly; rerun with --resume")
            break
        t0 = time.time()
        n, d, hit, wstate = scan_unit(bset, None, index_of, words, lay, vsets,
                                      order, derive, TARGET_ADDRESS)
        total_n += n
        total_d += d
        log.write("%d\t%d\t%d\t%s\t%.1f\n" % (idx, n, d, wstate, time.time() - t0))
        log.flush()
        if hit:
            # Do not print the phrase. Write it outside the log and stop.
            path = args.hit
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(hit + "\n")
            print("MATCH found. The phrase was written to %s and deliberately "
                  "not printed here. Sweep the wallet before disclosing "
                  "anything." % path)
            log.close()
            return 0
    log.close()
    elapsed = time.time() - started
    print("units run this call: %d, arrangements %s, derivations %s, "
          "%.1f derivations/second, no match"
          % (len(units) - len(done) if not args.deadline else 0,
             format(total_n, ","), format(total_d, ","),
             total_d / elapsed if elapsed else 0.0))
    return 1


def main():
    ap = argparse.ArgumentParser(description="reading-order sweep for the "
                                             "Guntis Vitolins 12-word challenge")
    ap.add_argument("--wordlist",
                    default=os.environ.get("BIP39_WORDLIST", "bip39_english.txt"),
                    help="path to the BIP-0039 English wordlist, 1 word per line")
    ap.add_argument("--pool",
                    default=os.path.join(FOLDER, "data", "reading-order-pool.json"),
                    help="derived pool file")
    ap.add_argument("--log", default="sweep_reading_order.tsv")
    ap.add_argument("--hit", default="hit.txt",
                    help="where a match is written; keep this out of version control")
    ap.add_argument("--deadline", type=float, default=0.0,
                    help="stop cleanly after this many seconds")
    ap.add_argument("--resume", action="store_true")
    ap.add_argument("--size", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--run", action="store_true")
    args = ap.parse_args()

    if args.size:
        return cmd_size(args)
    if args.selftest:
        return cmd_selftest(args)
    if args.run:
        return cmd_run(args)
    ap.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
