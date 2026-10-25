// Fast nonce search with an inline SHA-256 (OpenSSL 3's one-shot SHA256() is ~5us/call).
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <omp.h>
static const uint32_t K[64]={0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2};
#define ROTR(x,n) (((x)>>(n))|((x)<<(32-(n))))
static void sha256_block(uint32_t st[8], const unsigned char *p){
    uint32_t w[64]; for(int i=0;i<16;i++) w[i]=(uint32_t)p[4*i]<<24|(uint32_t)p[4*i+1]<<16|(uint32_t)p[4*i+2]<<8|p[4*i+3];
    for(int i=16;i<64;i++){uint32_t s0=ROTR(w[i-15],7)^ROTR(w[i-15],18)^(w[i-15]>>3),s1=ROTR(w[i-2],17)^ROTR(w[i-2],19)^(w[i-2]>>10); w[i]=w[i-16]+s0+w[i-7]+s1;}
    uint32_t a=st[0],b=st[1],c=st[2],d=st[3],e=st[4],f=st[5],g=st[6],h=st[7];
    for(int i=0;i<64;i++){uint32_t S1=ROTR(e,6)^ROTR(e,11)^ROTR(e,25),ch=(e&f)^(~e&g),t1=h+S1+ch+K[i]+w[i],S0=ROTR(a,2)^ROTR(a,13)^ROTR(a,22),mj=(a&b)^(a&c)^(b&c),t2=S0+mj; h=g;g=f;f=e;e=d+t1;d=c;c=b;b=a;a=t1+t2;}
    st[0]+=a;st[1]+=b;st[2]+=c;st[3]+=d;st[4]+=e;st[5]+=f;st[6]+=g;st[7]+=h;
}
static void sha256(const unsigned char *m, size_t len, unsigned char out[32]){
    uint32_t st[8]={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19};
    unsigned char buf[128]; size_t i=0; for(;i+64<=len;i+=64) sha256_block(st,m+i);
    size_t r=len-i; memcpy(buf,m+i,r); buf[r]=0x80; size_t tot=(r+9<=64)?64:128; memset(buf+r+1,0,tot-r-1);
    uint64_t bits=(uint64_t)len*8; for(int j=0;j<8;j++) buf[tot-1-j]=(unsigned char)(bits>>(8*j));
    sha256_block(st,buf); if(tot==128) sha256_block(st,buf+64);
    for(int j=0;j<8;j++){out[4*j]=st[j]>>24;out[4*j+1]=st[j]>>16;out[4*j+2]=st[j]>>8;out[4*j+3]=st[j];}
}
static const char *base = "the quick red fox jumped over the lazy brown dog";
int main(int argc,char**argv){
    uint64_t maxn = argc>1 ? strtoull(argv[1],0,10) : (1ULL<<33);
    int minz = argc>2 ? atoi(argv[2]) : 6;
    const char *seps[2]={" ",""}; const char *tails[2]={"\n",""};
    for(int c=0;c<4;c++){
        const char *sep=seps[c&1], *tail=tails[c>>1];
        #pragma omp parallel for schedule(dynamic, 1<<22)
        for(uint64_t n=0;n<maxn;n++){
            char buf[96]; int L=snprintf(buf,sizeof buf,"%s%s%llu%s",base,sep,(unsigned long long)n,tail);
            unsigned char d[32]; sha256((unsigned char*)buf,L,d);
            if(d[0]||d[1]||(d[2]>>4)) continue;   // need >= 5 leading zero nibbles before exact count
            int z=0; for(int i=0;i<32;i++){ if(d[i]==0){z+=2;continue;} if((d[i]>>4)==0){z+=1;} break; }
            if(z>=minz){ char hex[65]; for(int i=0;i<32;i++) sprintf(hex+2*i,"%02x",d[i]);
                #pragma omp critical
                { printf("conv=%d sep=[%s] tail=[%s] nonce=%llu zeros=%d hash=%s\n",c,sep,tail[0]?"\\n":"",(unsigned long long)n,z,hex); fflush(stdout);} }
        }
        fprintf(stderr,"convention %d done (%s|%s)\n",c,sep,tail[0]?"nl":"");
    }
    return 0;
}
