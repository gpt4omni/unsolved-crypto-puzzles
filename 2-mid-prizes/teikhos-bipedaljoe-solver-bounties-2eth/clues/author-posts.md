# Author material, TeikhosBounty family

## The idea, posted by the author

Johan Nygren (GitHub `resilience-me`, formerly `bipedaljoe`) posted the underlying scheme as
a GitHub issue on the Ethereum EIPs repository, referred to informally as "EIP-935":

> Signature idea for use with account abstraction, proof_of_public_key = keccak256(nextPublicKey)

Posted 2018-03-19: https://github.com/ethereum/EIPs/issues/935

The same day, he published the reference implementation as a gist named
`ProofOfSymmetricKey.sol`, created 2018-02-27: https://gist.github.com/resilience-me/be11a0ed3575dddca10df8263b53cc1d

## The puzzle as deployed: `authenticate()`, the "simple" variant

The following is the verified Solidity source of the `authenticate` function as deployed at
`0x17e5e0910b9185b0ede564dcbf074ca910ad56a4` (contract "C1", 1 ETH, still open), reproduced
from Etherscan's verified source, dated to the contract's 2018 deployment:

```solidity
function authenticate(bytes _publicKey) {
    address signer = address(keccak256(_publicKey));
    bytes32 publicKey1;
    bytes32 publicKey2;
    assembly {
    publicKey1 := mload(add(_publicKey,0x20))
    publicKey2 := mload(add(_publicKey,0x40))
    }
    bytes32 r = proof_of_public_key1 ^ publicKey1;
    bytes32 s = proof_of_public_key2 ^ publicKey2;
    bytes32 msgHash = keccak256("\x19Ethereum Signed Message:\n64", _publicKey);
    if(ecrecover(msgHash, 27, r, s) == signer) suicide(msg.sender);
    if(ecrecover(msgHash, 28, r, s) == signer) suicide(msg.sender);
}
```

Source: https://etherscan.io/address/0x17e5e0910b9185b0ede564dcbf074ca910ad56a4#code (verified
2018 compiler, viewed 2026-08-16).

## The scheme's name, in the author's own words

From the body of the same GitHub issue, posted 2018-03-19:

> Uses one-time keys and a proof of the next public-private key pair included in each
> transaction, `proof_of_public_key = keccak256(nextPublicKey)`. I call the scheme Teikhos,
> from the Greek for "fortification".

Nygren continues, in the same issue body, that the name reflects how the scheme hides the
asymmetric cryptography behind a one-way hash function, the way a fortification hides what
is behind it.

The issue is a design discussion between Nygren and other Ethereum developers, not a bounty
announcement. No separate bounty announcement by the author has been found on any public
channel; the contracts themselves, funded and left open, are the only public trace of the
puzzles.
