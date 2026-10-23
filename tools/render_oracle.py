# render.py FILE.raw|FILE.bin OUT.png : raw = 64000 screen + 256x3 palette (0-63); bin = oracle dump
import sys, struct
from PIL import Image
d=open(sys.argv[1],'rb').read()
if sys.argv[1].endswith('.bin'):
    blocks={}; i=0
    while i<len(d):
        n=d[i+1:i+1+d[i]].decode(); sz=struct.unpack('<i',d[i+24:i+28])[0]
        blocks[n]=d[i+28:i+28+sz]; i+=28+sz
    scr,pal=blocks['screen'],blocks['colors']
else:
    scr,pal=d[:64000],d[64000:64000+768]
im=Image.frombytes('P',(320,200),scr)
im.putpalette([min(255,v*255//63) for v in pal])
im.convert('RGB').resize((640,400),Image.NEAREST).save(sys.argv[2])
