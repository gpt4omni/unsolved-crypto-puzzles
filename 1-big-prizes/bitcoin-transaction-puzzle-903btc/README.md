# Bitcoin Transaction Puzzle (903.01687103 BTC still funded, [OPEN])

On 2015-01-15 an anonymous donor began funding a chain of 160 Bitcoin addresses with a
deliberate, published structure: the private key of address #n is a single integer drawn
uniformly from [2^(n-1), 2^n). Small numbers fell to ordinary key search almost
immediately, and the hunt has run ever since under the name "the 1000 BTC challenge" or
"the puzzle transaction". As of the 2026-11-19 on-chain check, 83 of the 160 are solved
and 77 remain funded, holding 903.01687103 BTC, about $56.0M: the largest unsolved crypto
puzzle on record, and more than everything else in this catalogue combined.

## At a glance

| | |
|---|---|
| Author | anonymous donor; the community tracking thread is [BitcoinTalk topic 5218972](https://bitcointalk.org/index.php?topic=5218972) |
| Published | 2015-01-15, extended and topped up in later years |
| Prize | 903.01687103 BTC across 77 escrows (about $56.0M at BTC = $62,004, 2026-11-19) |
| Chain | bitcoin |
| Escrow | 77 P2PKH addresses, full table in [The puzzle as published](#the-puzzle-as-published) |
| Last on-chain check | 2026-11-19: all 77 re-checked; exact balance and state for every address in [verification/BALANCES.md](../../verification/BALANCES.md) |
| Status | OPEN |
| Puzzle type | raw-private-key |
| Target format | secp256k1 private key in [2^(n-1), 2^n), compressed public key, P2PKH |
| Certified oracle | yes: `tools/oracle.py --selftest` (certified on solved puzzle #1) |
| What remains | 77 funded escrows; the address-only ones need brute force, the 5 public-key-exposed ones are Pollard's-kangaroo targets |
| Series | Bitcoin Transaction Puzzle #1-160 |

## The puzzle as published

Address #n holds roughly n/10 BTC and its private key sits in the half-open range
[2^(n-1), 2^n): every puzzle is a brute-force search over a published interval, nothing
more. The 77 rows below are the escrows still funded on 2026-11-19; the other 83 were
solved and swept over the years. A row marked "exposed" has signed at least one spend,
which puts its 33-byte compressed public key on-chain and opens the kangaroo attack
described below.

| # | Key space | Address | Balance (sats) | Public key |
|---|---|---|---|---|
| 71 | 2^70 to 2^71 - 1 | `1PWo3JeB9jrGwfHDNpdGK54CRas7fsVzXU` | 710,196,696 | not exposed |
| 72 | 2^71 to 2^72 - 1 | `1JTK7s9YVYywfm5XUH7RNhHJH1LshCaRFR` | 720,014,379 | not exposed |
| 73 | 2^72 to 2^73 - 1 | `12VVRNPi4SJqUTsp6FmqDqY5sGosDtysn4` | 730,013,849 | not exposed |
| 74 | 2^73 to 2^74 - 1 | `1FWGcVDK3JGzCC3WtkYetULPszMaK2Jksv` | 740,004,977 | not exposed |
| 76 | 2^75 to 2^76 - 1 | `1DJh2eHFYQfACPmrvpyWc8MSTYKh7w9eRF` | 760,000,000 | not exposed |
| 77 | 2^76 to 2^77 - 1 | `1Bxk4CQdqL9p22JEtDfdXMsng1XacifUtE` | 770,002,426 | not exposed |
| 78 | 2^77 to 2^78 - 1 | `15qF6X51huDjqTmF9BJgxXdt1xcj46Jmhb` | 780,000,000 | not exposed |
| 79 | 2^78 to 2^79 - 1 | `1ARk8HWJMn8js8tQmGUJeQHjSE7KRkn2t8` | 790,000,000 | not exposed |
| 81 | 2^80 to 2^81 - 1 | `15qsCm78whspNQFydGJQk5rexzxTQopnHZ` | 810,001,500 | not exposed |
| 82 | 2^81 to 2^82 - 1 | `13zYrYhhJxp6Ui1VV7pqa5WDhNWM45ARAC` | 820,000,000 | not exposed |
| 83 | 2^82 to 2^83 - 1 | `14MdEb4eFcT3MVG5sPFG4jGLuHJSnt1Dk2` | 830,002,046 | not exposed |
| 84 | 2^83 to 2^84 - 1 | `1CMq3SvFcVEcpLMuuH8PUcNiqsK1oicG2D` | 840,001,500 | not exposed |
| 86 | 2^85 to 2^86 - 1 | `1K3x5L6G57Y494fDqBfrojD28UJv4s5JcK` | 860,000,000 | not exposed |
| 87 | 2^86 to 2^87 - 1 | `1PxH3K1Shdjb7gSEoTX7UPDZ6SH4qGPrvq` | 870,000,000 | not exposed |
| 88 | 2^87 to 2^88 - 1 | `16AbnZjZZipwHMkYKBSfswGWKDmXHjEpSf` | 880,000,000 | not exposed |
| 89 | 2^88 to 2^89 - 1 | `19QciEHbGVNY4hrhfKXmcBBCrJSBZ6TaVt` | 890,000,000 | not exposed |
| 91 | 2^90 to 2^91 - 1 | `1EzVHtmbN4fs4MiNk3ppEnKKhsmXYJ4s74` | 910,000,000 | not exposed |
| 92 | 2^91 to 2^92 - 1 | `1AE8NzzgKE7Yhz7BWtAcAAxiFMbPo82NB5` | 920,000,000 | not exposed |
| 93 | 2^92 to 2^93 - 1 | `17Q7tuG2JwFFU9rXVj3uZqRtioH3mx2Jad` | 930,000,000 | not exposed |
| 94 | 2^93 to 2^94 - 1 | `1K6xGMUbs6ZTXBnhw1pippqwK6wjBWtNpL` | 940,000,000 | not exposed |
| 96 | 2^95 to 2^96 - 1 | `15ANYzzCp5BFHcCnVFzXqyibpzgPLWaD8b` | 960,000,600 | not exposed |
| 97 | 2^96 to 2^97 - 1 | `18ywPwj39nGjqBrQJSzZVq2izR12MDpDr8` | 970,002,613 | not exposed |
| 98 | 2^97 to 2^98 - 1 | `1CaBVPrwUxbQYYswu32w7Mj4HR4maNoJSX` | 980,000,000 | not exposed |
| 99 | 2^98 to 2^99 - 1 | `1JWnE6p6UN7ZJBN7TtcbNDoRcjFtuDWoNL` | 991,257,338 | not exposed |
| 101 | 2^100 to 2^101 - 1 | `1CKCVdbDJasYmhswB6HKZHEAnNaDpK7W4n` | 1,010,000,000 | not exposed |
| 102 | 2^101 to 2^102 - 1 | `1PXv28YxmYMaB8zxrKeZBW8dt2HK7RkRPX` | 1,020,000,000 | not exposed |
| 103 | 2^102 to 2^103 - 1 | `1AcAmB6jmtU6AiEcXkmiNE9TNVPsj9DULf` | 1,030,000,000 | not exposed |
| 104 | 2^103 to 2^104 - 1 | `1EQJvpsmhazYCcKX5Au6AZmZKRnzarMVZu` | 1,040,001,600 | not exposed |
| 106 | 2^105 to 2^106 - 1 | `18KsfuHuzQaBTNLASyj15hy4LuqPUo1FNB` | 1,060,000,000 | not exposed |
| 107 | 2^106 to 2^107 - 1 | `15EJFC5ZTs9nhsdvSUeBXjLAuYq3SWaxTc` | 1,070,000,000 | not exposed |
| 108 | 2^107 to 2^108 - 1 | `1HB1iKUqeffnVsvQsbpC6dNi1XKbyNuqao` | 1,080,000,000 | not exposed |
| 109 | 2^108 to 2^109 - 1 | `1GvgAXVCbA8FBjXfWiAms4ytFeJcKsoyhL` | 1,090,010,500 | not exposed |
| 111 | 2^110 to 2^111 - 1 | `1824ZJQ7nKJ9QFTRBqn7z7dHV5EGpzUpH3` | 1,110,010,000 | not exposed |
| 112 | 2^111 to 2^112 - 1 | `18A7NA9FTsnJxWgkoFfPAFbQzuQxpRtCos` | 1,120,000,000 | not exposed |
| 113 | 2^112 to 2^113 - 1 | `1NeGn21dUDDeqFQ63xb2SpgUuXuBLA4WT4` | 1,130,000,000 | not exposed |
| 114 | 2^113 to 2^114 - 1 | `174SNxfqpdMGYy5YQcfLbSTK3MRNZEePoy` | 1,140,000,000 | not exposed |
| 116 | 2^115 to 2^116 - 1 | `1MnJ6hdhvK37VLmqcdEwqC3iFxyWH2PHUV` | 1,160,001,210 | not exposed |
| 117 | 2^116 to 2^117 - 1 | `1KNRfGWw7Q9Rmwsc6NT5zsdvEb9M2Wkj5Z` | 1,170,000,000 | not exposed |
| 118 | 2^117 to 2^118 - 1 | `1PJZPzvGX19a7twf5HyD2VvNiPdHLzm9F6` | 1,180,000,661 | not exposed |
| 119 | 2^118 to 2^119 - 1 | `1GuBBhf61rnvRe4K8zu8vdQB3kHzwFqSy7` | 1,190,000,000 | not exposed |
| 121 | 2^120 to 2^121 - 1 | `1GDSuiThEV64c166LUFC9uDcVdGjqkxKyh` | 1,210,000,000 | not exposed |
| 122 | 2^121 to 2^122 - 1 | `1Me3ASYt5JCTAK2XaC32RMeH34PdprrfDx` | 1,220,000,000 | not exposed |
| 123 | 2^122 to 2^123 - 1 | `1CdufMQL892A69KXgv6UNBD17ywWqYpKut` | 1,230,000,000 | not exposed |
| 124 | 2^123 to 2^124 - 1 | `1BkkGsX9ZM6iwL3zbqs7HWBV7SvosR6m8N` | 1,240,000,000 | not exposed |
| 126 | 2^125 to 2^126 - 1 | `1AWCLZAjKbV1P7AHvaPNCKiB7ZWVDMxFiz` | 1,260,000,000 | not exposed |
| 127 | 2^126 to 2^127 - 1 | `1G6EFyBRU86sThN3SSt3GrHu1sA7w7nzi4` | 1,270,000,000 | not exposed |
| 128 | 2^127 to 2^128 - 1 | `1MZ2L1gFrCtkkn6DnTT2e4PFUTHw9gNwaj` | 1,280,000,000 | not exposed |
| 129 | 2^128 to 2^129 - 1 | `1Hz3uv3nNZzBVMXLGadCucgjiCs5W9vaGz` | 1,290,000,000 | not exposed |
| 131 | 2^130 to 2^131 - 1 | `16zRPnT8znwq42q7XeMkZUhb1bKqgRogyy` | 1,310,000,000 | not exposed |
| 132 | 2^131 to 2^132 - 1 | `1KrU4dHE5WrW8rhWDsTRjR21r8t3dsrS3R` | 1,320,000,000 | not exposed |
| 133 | 2^132 to 2^133 - 1 | `17uDfp5r4n441xkgLFmhNoSW1KWp6xVLD` | 1,330,000,000 | not exposed |
| 134 | 2^133 to 2^134 - 1 | `13A3JrvXmvg5w9XGvyyR4JEJqiLz8ZySY3` | 1,340,000,000 | not exposed |
| 136 | 2^135 to 2^136 - 1 | `1UDHPdovvR985NrWSkdWQDEQ1xuRiTALq` | 1,360,000,000 | not exposed |
| 137 | 2^136 to 2^137 - 1 | `15nf31J46iLuK1ZkTnqHo7WgN5cARFK3RA` | 1,370,000,000 | not exposed |
| 138 | 2^137 to 2^138 - 1 | `1Ab4vzG6wEQBDNQM1B2bvUz4fqXXdFk2WT` | 1,380,000,000 | not exposed |
| 139 | 2^138 to 2^139 - 1 | `1Fz63c775VV9fNyj25d9Xfw3YHE6sKCxbt` | 1,390,000,000 | not exposed |
| 140 | 2^139 to 2^140 - 1 | `1QKBaU6WAeycb3DbKbLBkX7vJiaS8r42Xo` | 1,400,002,880 | exposed |
| 141 | 2^140 to 2^141 - 1 | `1CD91Vm97mLQvXhrnoMChhJx4TP9MaQkJo` | 1,410,014,846 | not exposed |
| 142 | 2^141 to 2^142 - 1 | `15MnK2jXPqTMURX4xC3h4mAZxyCcaWWEDD` | 1,420,000,000 | not exposed |
| 143 | 2^142 to 2^143 - 1 | `13N66gCzWWHEZBxhVxG18P8wyjEWF9Yoi1` | 1,430,000,000 | not exposed |
| 144 | 2^143 to 2^144 - 1 | `1NevxKDYuDcCh1ZMMi6ftmWwGrZKC6j7Ux` | 1,440,000,000 | not exposed |
| 145 | 2^144 to 2^145 - 1 | `19GpszRNUej5yYqxXoLnbZWKew3KdVLkXg` | 1,450,000,600 | exposed |
| 146 | 2^145 to 2^146 - 1 | `1M7ipcdYHey2Y5RZM34MBbpugghmjaV89P` | 1,460,000,000 | not exposed |
| 147 | 2^146 to 2^147 - 1 | `18aNhurEAJsw6BAgtANpexk5ob1aGTwSeL` | 1,470,000,000 | not exposed |
| 148 | 2^147 to 2^148 - 1 | `1FwZXt6EpRT7Fkndzv6K4b4DFoT4trbMrV` | 1,480,000,000 | not exposed |
| 149 | 2^148 to 2^149 - 1 | `1CXvTzR6qv8wJ7eprzUKeWxyGcHwDYP1i2` | 1,490,001,000 | not exposed |
| 150 | 2^149 to 2^150 - 1 | `1MUJSJYtGPVGkBCTqGspnxyHahpt5Te8jy` | 1,500,001,600 | exposed |
| 151 | 2^150 to 2^151 - 1 | `13Q84TNNvgcL3HJiqQPvyBb9m4hxjS3jkV` | 1,510,001,000 | not exposed |
| 152 | 2^151 to 2^152 - 1 | `1LuUHyrQr8PKSvbcY1v1PiuGuqFjWpDumN` | 1,520,001,000 | not exposed |
| 153 | 2^152 to 2^153 - 1 | `18192XpzzdDi2K11QVHR7td2HcPS6Qs5vg` | 1,530,001,000 | not exposed |
| 154 | 2^153 to 2^154 - 1 | `1NgVmsCCJaKLzGyKLFJfVequnFW9ZvnMLN` | 1,540,001,000 | not exposed |
| 155 | 2^154 to 2^155 - 1 | `1AoeP37TmHdFh8uN72fu9AqgtLrUwcv2wJ` | 1,550,011,600 | exposed |
| 156 | 2^155 to 2^156 - 1 | `1FTpAbQa4h8trvhQXjXnmNhqdiGBd1oraE` | 1,560,001,000 | not exposed |
| 157 | 2^156 to 2^157 - 1 | `14JHoRAdmJg3XR4RjMDh6Wed6ft6hzbQe9` | 1,570,001,000 | not exposed |
| 158 | 2^157 to 2^158 - 1 | `19z6waranEf8CcP8FqNgdwUe1QRxvUNKBG` | 1,580,001,000 | not exposed |
| 159 | 2^158 to 2^159 - 1 | `14u4nA5sugaswb6SZgn5av2vuChdMnD9E5` | 1,590,002,600 | not exposed |
| 160 | 2^159 to 2^160 - 1 | `1NBC8uXJy1GiJ6drkiZa1WuKn51ps7EPTv` | 1,600,123,082 | exposed |


## What is understood

### Mechanism

Two difficulty classes. For the 72 address-only escrows, the only public information is
the HASH160 in the address: a candidate key must be tried directly, at an expected cost
of about 2^(n-2) key trials for puzzle #n. For the 5 escrows that have already signed a
spend (#140, #145, #150, #155, #160), the compressed public key is revealed on-chain, so
Pollard's kangaroo algorithm applies to the interval: the cost drops to about 2^((n-1)/2)
group operations. That split is why every mid-range solve so far happened on an
exposed-public-key address, and why the exposed five are where serious work concentrates.

### Derivation and oracle

```
python3 tools/oracle.py --selftest
python3 tools/oracle.py <key>
python3 tools/oracle.py --stdin
```

A candidate is one integer (decimal or 0x-hex). The oracle derives its compressed
secp256k1 public key, hashes it to a P2PKH address, and compares it to all 77 live
escrows, printing `MATCH puzzle #n <address>` or `NO MATCH`. It verifies a candidate; it
does not search.

### Certified against

`tools/oracle.py --selftest` reproduces solved puzzle #1: private key 1 derives to
`1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH`, the funded-then-swept address. This certifies the
secp256k1-to-P2PKH path end to end; the only remaining step, checking membership of the
published range, is arithmetic. Reproduced 2026-11-19.

### Established facts

1. All 77 escrows are funded, totaling 90,301,687,103 sats, checked 2026-11-19 on
   mempool.space; the per-address balances are in [data/open_puzzles.csv](data/open_puzzles.csv).
2. The range rule is real and verifiable: puzzle #1's key is 1, deriving to its funded
   address.
3. 83 of the 160 puzzles are solved and swept; every mid-range solve happened on an
   address whose public key was already exposed, consistent with kangaroo being the only
   practical attack so far.
4. Five live escrows (#140, #145, #150, #155, #160) have spent outputs, so their
   compressed public keys are public: each is a kangaroo target at about 2^69.5 to 2^79.5
   group operations.
5. The other 72 are address-only. The cheapest unsolved one, #71, is a 2^70-key space;
   at any rate a single high-end GPU manages, exhaustively covering it is a
   centuries-scale job, which is why this puzzle class is worked by pools, not machines.
6. Balances drift upward slightly over time as spectators dust the famous addresses; the
   prize is the recorded balance at check time, always re-verifiable on the explorer
   links.

## What has been tested

Full ledger in [analysis/tested.md](analysis/tested.md). Summary:

| Hypothesis | Space | Method | Result | Witness | Date |
|---|---|---|---|---|---|
| the derivation reads the rule correctly | 1 known vector | derive key 1 and compare to puzzle #1's funded address | confirmed: exact match to `1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH` | yes: `tools/oracle.py --selftest` | 2026-11-19 |
| the 77 listed escrows are still funded | 77 addresses | live mempool.space balance check on every address | confirmed: 72 funded-unspent, 5 partially-spent with the prize balance intact | yes: [data/open_puzzles.csv](data/open_puzzles.csv) | 2026-11-19 |
| a candidate key worth searching exists for an address-only escrow | 2^70 keys minimum | none run: no bounded sub-space exists to attack | not attempted | n/a | n/a |

## Open leads, ranked

1. **Pollard's kangaroo on the 5 exposed-public-key escrows** (#140, #145, #150, #155,
   #160). About 2^69.5 group operations for the smallest, on the edge of what large public
   efforts have already done. A win there sweeps 14 to 16 BTC per target.
2. **Pooled brute force on #71.** The lowest unsolved address-only target and the focus
   of the long-running public pools. A single machine's expected share is negligible; the
   honest path is joining a pool or running one for the split.
3. **Watch for new spends.** Any spend signed by an unsolved escrow exposes its public
   key and re-classes it into the kangaroo group; the five current exposures all came from
   such spends.

Full notes: [analysis/leads.md](analysis/leads.md).

## Files in this folder

| Path | What it is |
|---|---|
| `data/open_puzzles.csv` | the 77 live escrows: puzzle number, address, balance in sats, public-key flag |
| `clues/author-posts.md` | what is publicly known about the donor and the funding structure |
| `analysis/tested.md` | full negatives ledger |
| `analysis/leads.md` | full lead notes |
| `tools/oracle.py` | candidate checker: integer key to match/no match across all 77 escrows |

## Sources

- [BitcoinTalk topic 5218972](https://bitcointalk.org/index.php?topic=5218972), the community tracking thread
- [privatekeys.pw puzzle list](https://privatekeys.pw/puzzles/bitcoin-puzzle-tx), per-address status history
- [mempool.space](https://mempool.space/address/1PWo3JeB9jrGwfHDNpdGK54CRas7fsVzXU), live balances, checked 2026-11-19
- boha dataset (`@agntn/puzzles` 0.31.0), address and public-key flags, cross-checked against the chain on 2026-11-19
