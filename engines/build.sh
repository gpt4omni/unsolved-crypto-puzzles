#!/bin/bash
# Build the GPU bruteforce engines.
# Targets sm_80 / sm_90 PTX and lets the driver JIT it to whatever GPU is
# actually installed (e.g. an sm_120 Blackwell card, or anything newer than
# your nvcc knows about). This is the portable path: it works with a stock
# nvcc install and does not require a native build for your exact GPU
# architecture.
set -e
cd "$(dirname "$0")"

GENCODE="-gencode arch=compute_80,code=compute_80 -gencode arch=compute_90,code=compute_90"
FLAGS="-O3 -std=c++14 --use_fast_math -diag-suppress 177"

# 1) Brainwallet engine: input -> SHA256 -> secp256k1 -> hash160 -> compare.
#    Windowed scalar mult + single-inversion + addition-chain fe_inv.
nvcc $FLAGS $GENCODE -o secp256k1_hash160_engine secp256k1_hash160_engine.cu
echo "[build] OK -> $(pwd)/secp256k1_hash160_engine"

# 2) BIP39-passphrase engine (shared lib): FIXED mnemonic + passphrase salt
#    -> PBKDF2-SHA512 -> BIP32 -> secp256k1 -> hash160 -> compare. Also
#    exposes the order-search (PERM11) and multi-target BTC/ETH kernels.
if [ -f bip39_passphrase_engine.cu ]; then
  nvcc $FLAGS $GENCODE -Xcompiler -fPIC -shared \
    -o libbip39pass.so bip39_passphrase_engine.cu
  echo "[build] OK -> $(pwd)/libbip39pass.so"
fi

# 3) Electrum v1 ("old seed") engine: 16B entropy -> 100000x SHA256 stretch ->
#    master priv -> per (change,idx) seq=SHA256d -> child priv -> hash160 compare.
#    Validated bit-exact vs bip_utils.ElectrumV1.
if [ -f electrum_v1_engine.cu ]; then
  nvcc $FLAGS $GENCODE -o electrum_v1_engine electrum_v1_engine.cu
  echo "[build] OK -> $(pwd)/electrum_v1_engine"
fi

# 4) Arweave engine, FIXED 8x4-char passphrase (32 bytes): passphrase ->
#    SHA512^11513 -> OpenSSL EvpKDF(MD5,1e4) -> Rijndael(Nk=32,Nr=38) CBC ->
#    decrypt block0, test JWK prefix. Reuses the SHA-512 device core from
#    bip39_passphrase_engine.cu. Host driver: pzl3_host.py (ctypes).
#    Self-test: python3 pzl3_host.py --selftest
if [ -f pzl3_arweave_engine.cu ]; then
  nvcc $FLAGS $GENCODE -Xcompiler -fPIC -shared \
    -o libpzl3.so pzl3_arweave_engine.cu
  echo "[build] OK -> $(pwd)/libpzl3.so"
fi

# 5) Arweave engine, VARIABLE-length passphrase (same pipeline as #4, but the
#    passphrase length is free, <= 111 bytes: sha512_first_var). Used where
#    the answer is not a fixed 8x4 token concatenation. Host driver:
#    arweave_var_host.py
if [ -f arweave_var_engine.cu ]; then
  nvcc $FLAGS $GENCODE -Xcompiler -fPIC -shared \
    -o libarv.so arweave_var_engine.cu
  echo "[build] OK -> $(pwd)/libarv.so"
fi

# 6) P2WSH 2-of-2 pair enumerator: N pubkeys -> all ordered pairs -> witness script
#    OP_2 <Ki> <Kj> OP_2 OP_CHECKMULTISIG -> SHA256 -> compare to <= 8 target programs.
#    Native sm_120 build when a CUDA >= 12.8 nvcc is available, JIT fallback otherwise.
if [ -f p2wsh_2of2_pairs.cu ]; then
  if [ -n "${NVCC_NATIVE:-}" ] && [ -x "$NVCC_NATIVE" ]; then
    "$NVCC_NATIVE" -ccbin g++-12 -O3 -arch=sm_120 -diag-suppress 177 -o p2wsh_2of2_pairs p2wsh_2of2_pairs.cu
    echo "[build] OK (native sm_120) -> $(pwd)/p2wsh_2of2_pairs"
  else
    nvcc $FLAGS $GENCODE -o p2wsh_2of2_pairs p2wsh_2of2_pairs.cu
    echo "[build] OK (JIT compute_80/90) -> $(pwd)/p2wsh_2of2_pairs"
  fi
fi
