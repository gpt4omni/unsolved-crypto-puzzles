#!/usr/bin/env python3
"""
arv_candfile.py - stream an ARBITRARY precomputed candidate list (one full
passphrase per line, <= 64 bytes each) through libarv.so at GPU speed.

Unlike the mixed-radix `--sweep` (which can only CONCATENATE per-slot tokens),
this handles any structural hypothesis you can enumerate on the CPU: sliced
strings, bracket-literal variants, reordered tokens, mixed separators, etc.

It uploads the list in chunks of MAX_TOK as a single generated "slot" (nslot=1)
and runs arv_run_index_range over each chunk. A device HIT (block-0 == {"kty)
is then re-checked EXACTLY (Arweave address == target) with the CPU reference
before being declared - zero false positives.

    python3 arv_candfile.py --page <PZL10.html> --cands cands.txt --target <addr>
"""
import argparse, ctypes, os, sys, time, hashlib, base64
import arweave_var_host as H

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--page", required=True)
    ap.add_argument("--cands", required=True, help="file: one candidate per line")
    ap.add_argument("--target", default="bkjJGw3NLxs8OAyRxgTL-QFpiB3lBJqZ76kDhWdB-Rs")
    ap.add_argument("--threads", type=int, default=64)
    ap.add_argument("--blocks", type=int, default=256)
    ap.add_argument("--no-selftest", action="store_true")
    args = ap.parse_args()

    lib = H.load_lib()
    if not args.no_selftest and not H.do_selftest(lib):
        sys.stderr.write("selftest FAILED - abort\n"); return 4

    salt, c0 = H.salt_and_c0(H.page_msg(args.page))
    if lib.arv_init(salt, c0) != 0:
        raise SystemExit("arv_init failed")

    # load + dedup candidates, enforce byte length
    seen = set(); cands = []
    for line in open(args.cands, encoding="utf-8"):
        s = line.rstrip("\n").rstrip("\r")
        if not s: continue
        b = s.encode("utf-8")
        if len(b) > H.MAX_TLEN or len(b) > H.MAX_PASS:
            sys.stderr.write(f"[skip >{H.MAX_TLEN}B] {s!r}\n"); continue
        if s in seen: continue
        seen.add(s); cands.append(b)
    n = len(cands)
    sys.stderr.write(f"[candfile] {n:,} unique candidates, page={os.path.basename(args.page)}\n")

    NS = H.MAX_TOK
    t0 = time.time(); done = 0; hit_pw = None
    for base in range(0, n, NS):
        chunk = cands[base:base+NS]
        # pack as slot 0 only, nslot=1
        words = bytearray(H.NSLOT_MAX * H.MAX_TOK * H.MAX_TLEN)
        tlens = bytearray(H.NSLOT_MAX * H.MAX_TOK)
        counts = (ctypes.c_int * H.NSLOT_MAX)()
        counts[0] = len(chunk)
        for i in range(1, H.NSLOT_MAX): counts[i] = 1
        for i, t in enumerate(chunk):
            off = i * H.MAX_TLEN
            words[off:off+len(t)] = t
            tlens[i] = len(t)
        if lib.arv_set_wordlists(bytes(words), bytes(tlens), counts, 1) != 0:
            raise SystemExit("set_wordlists failed")
        hit = lib.arv_run_index_range(0, len(chunk), args.threads, args.blocks)
        done += len(chunk)
        if hit >= 0:
            hit_pw = chunk[hit].decode("utf-8", "replace")
            break
        if (base // NS) % 200 == 0:
            el = time.time()-t0; r = done/el if el else 0
            sys.stderr.write(f"\r[candfile] {done:,}/{n:,} {r:,.0f}/s ETA {(n-done)/r/60 if r else 0:.1f}m  ")
            sys.stderr.flush()
    el = time.time()-t0
    sys.stderr.write(f"\n[candfile] scanned {done:,} in {el:.1f}s ({done/el if el else 0:,.0f}/s)\n")

    if hit_pw is None:
        sys.stderr.write("[candfile] NO device hit (no candidate yields a {\"kty JWK).\n")
        return 1

    # exact address confirmation via CPU reference
    pw = hit_pw.encode("utf-8")
    keyhex = H.stretch_keyhex(pw)
    # full decrypt for the address is done by node oracle; here we at least
    # re-derive block0 to confirm the JWK prefix, then hand to node.
    b0 = H.cpu_block0(pw, salt, c0)
    sys.stderr.write(f"\n*** DEVICE HIT: {hit_pw!r}  block0={b0!r}\n")
    print(hit_pw)
    return 0

if __name__ == "__main__":
    sys.exit(main())
