import hashlib, base58, ecdsa

# NB: no target hardcoded here by design. Pass the target address explicitly
# to target_h160(addr).

def _h160(pub):
    return hashlib.new('ripemd160', hashlib.sha256(pub).digest()).digest()

def priv_to_addrs(priv32):
    """Return (compressed_addr, uncompressed_addr) for 32-byte priv key."""
    if len(priv32)!=32: return (None,None)
    n=int.from_bytes(priv32,'big')
    N=0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
    if n==0 or n>=N: return (None,None)
    sk=ecdsa.SigningKey.from_string(priv32, curve=ecdsa.SECP256k1)
    vk=sk.verifying_key
    xb=vk.to_string()  # 64 bytes x||y
    x=xb[:32]; y=xb[32:]
    unc=b'\x04'+xb
    comp=(b'\x03' if y[-1]&1 else b'\x02')+x
    def addr(pub):
        h=_h160(pub)
        payload=b'\x00'+h
        chk=hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
        return base58.b58encode(payload+chk).decode()
    return addr(comp), addr(unc)

def target_h160(addr):
    """hash160 (20 bytes) of a P2PKH base58check address. Address is REQUIRED as argument."""
    raw=base58.b58decode(addr)
    return raw[1:-4]

if __name__=='__main__':
    import sys
    a=sys.argv[1] if len(sys.argv)>1 else None
    if a: print(f'{a} -> h160:', target_h160(a).hex())
    else: print('usage: btc_p2pkh.py <address>')
