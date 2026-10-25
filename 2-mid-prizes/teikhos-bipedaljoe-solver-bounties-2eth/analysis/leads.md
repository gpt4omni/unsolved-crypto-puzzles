# Leads, in full

## 1. Ask Johan Nygren directly

Johan Nygren is identifiable and reachable: GitHub `resilience-me`, Reddit `johanngr`,
Steemit `@johan-nygren`, and an X/Medium handle `@resilience_me`, with activity as recently
as 2024 to 2026 on an unrelated project (Panarchy, `scan.polytopia.org`). He is the only
person who has ever held the public keys for C1, C2, and 9732: the scheme is designed so
that address alone reveals nothing. Asking him directly where those keys, or a solution, are
published (if anywhere) is the only lever here with a real chance of working, since every
other channel checked (source below) is a dead end by the scheme's own design, not by an
incomplete search. This costs the time to write and send one message; I have not sent it.

## 2. Passive triggers

None of the following are worth acting on until they happen on their own, but each would
immediately make C1, C2, or 9732 solvable if it did:

- A testnet snapshot (Rinkeby or Goerli) that includes this era resurfaces somewhere, letting
  a signed transaction from the target address be pulled and its public key recovered.
- The author reveals a public key or private key for one of the 3 open contracts anywhere
  public, which OSINT monitoring would need to catch.
- A competitor submits a correct public key to C1 or C2 in a public mempool transaction:
  since those two pay whoever's call succeeds, and the correct key becomes visible in that
  calldata the moment it is broadcast, the only way to benefit here is to have front-running
  infrastructure (a private relay submission) ready in advance, which is not currently set
  up and not worth setting up before there is a real transaction to react to.

## What this is not

This is not a cryptanalysis problem: the ECDSA and keccak constructions here have no known
weakness, and the scheme is specifically designed so the public key is unrecoverable from
anything on chain until its owner chooses to reveal it. Every avenue tested (analysis/tested.md)
confirms this rather than finding a flaw. The only way forward for C1, C2, and 9732 is new
information about where the author's public keys live, which points to lead 1.
