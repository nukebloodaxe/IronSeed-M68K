import struct, sys, collections
d=open(sys.argv[1],'rb').read()
scr,joy,iters,loglen,frames=struct.unpack('>4IH',d[:18])
NF=int(sys.argv[2]) if len(sys.argv)>2 else 300
snd=struct.unpack('>%dH'%NF,d[18:18+2*NF])
log=struct.unpack('>%dI'%(loglen//4),d[18+2*NF:18+2*NF+loglen])
print(f'frames {frames}  joystick packets {joy}  c2p frames done {iters}')
s=[x for x in snd if x][2:]; print(f'mixer pairs per VBL: min {min(s)} max {max(s)} mean {sum(s)/len(s):.1f}')
res=collections.Counter(); bad=collections.Counter()
for i in range(0,len(log)-1,2):
    e=(log[i]>>8)-scr; a=(log[i+1]>>8)-scr
    la,ca=divmod(a,160); le,ce=divmod(e,160)
    if la>=200 or la==0: res['outside picture']+=1; continue
    if ca==0 and la%50==0: res['on time (in blank before line %d)'%la]+=1
    else: res['late']+=1; bad[(la,ca,le,ce)]+=1
for k,v in sorted(res.items()): print(f'  {k}: {v}')
late=[ (c, l) for (l,c,_,_),n in bad.items() for _ in range(n)]
if late:
    cols=sorted(c for c,_ in late); print('  late by (bytes into line, 1 byte = 2 px):',collections.Counter(cols).most_common(8))
    print('  entry positions of late ones (line,byte):',collections.Counter((le,ce) for (l,c,le,ce),n in bad.items() for _ in range(n)).most_common(8))
