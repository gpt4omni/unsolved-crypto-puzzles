# Negatives ledger, in full

C1, C2, and 9732 target "ghost" keys: their addresses have nonce 0 and have never sent a
transaction on mainnet, so there is no signed transaction to recover a public key from by the
usual route. Every negative below is therefore a search for the public key leaking somewhere
else (a prior submission attempt, an archived testnet, an OSINT trail), not a search over the
key space itself, which at 256 bits has no witness that could make a brute-force negative
meaningful.

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| A public key was already submitted to the family's contracts on mainnet and simply never matched | full history of calldata sent to the 5 contracts | direct calldata inspection | 2 prior attempts found (one against C1, one against 9732, both from years-old transactions); both checked offline against the correct proof values and confirmed wrong | yes: the oracle correctly matches the real 735B solution and rejects a deliberately altered key, so the same check applied to these 2 candidates is trustworthy | 2026-06-14 |
| The author's GitHub gists (10 Teikhos-related gists) contain a leaked key in an edit history | 10 gists, 103 revisions total, 127 gists/forks/51 repos across the author's full GitHub footprint, alias `bipedaljoe` included | direct diff of every revision for embedded 32 or 64-byte hex values | 0 keys found; the author has deleted about 125 of an original 127 gists, leaving 2 public | uncertified: no known-good leaked key exists to prove the diff method would catch one | 2026-06-14 |
| A Rinkeby or Goerli testnet deployment of the same contracts leaked a signed transaction | testnet archives for both networks | search of available archive snapshots | 0 found; both testnets' historical state for this era is not preserved in any archive I could reach | uncertified: could not test the harness against a known instance | 2026-06-14 |
| The same creator deployed matching contracts on another EVM chain with a signed transaction | 11 live EVM chains | balance and nonce check for the creator address and known contract addresses | 0 found; nonce 0 on every chain checked | not applicable (a direct nonce read, not a guess) | 2026-06-14 |
| The private key follows a weak or brainwallet-style generation pattern | rockyou wordlist (14 million entries) across 5 key-derivation schemes | derive a candidate private key from each phrase, check against known contract addresses | 0 match | uncertified: no known-good brainwallet-derived vector exists in this family to test against | 2026-06-14 |
| The private key has a structural weakness (low entropy, small subgroup) | key-generation analysis of the address format | statistical review | no weakness found; consistent with a standard CSPRNG | not applicable (an analytic check, not an enumeration) | 2026-06-14 |

None of these searches touch the 256-bit key space directly, so none of them "exhausts"
anything the way a bounded password guess can. They rule out the specific leak channels
checked, not the possibility of a leak through a channel not yet checked.
