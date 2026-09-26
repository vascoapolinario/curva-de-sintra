from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import random, math, wave, struct
root=Path(__file__).resolve().parents[1]/'assets'
root.mkdir(parents=True,exist_ok=True)
r=random.Random(173)
def font(size,bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/'+('georgiab.ttf' if bold else 'georgia.ttf'),size)
def noise(name,base,size=256):
    im=Image.new('RGB',(size,size)); p=im.load()
    for y in range(size):
        for x in range(size):
            v=r.gauss(0,12)+math.sin(x*.23)*2
            p[x,y]=tuple(max(0,min(255,int(c+v))) for c in base)
    d=ImageDraw.Draw(im)
    if name=='asphalt':
        for i in range(22):
            x,y=r.randrange(size),r.randrange(size)
            pts=[(x,y)]
            for j in range(r.randrange(3,11)):
                x+=r.randrange(-13,14); y+=r.randrange(4,17); pts.append((x,y))
            d.line(pts,fill=(24,25,22),width=1)
    if name=='bark':
        for i in range(130):
            x=r.randrange(size); y=r.randrange(size)
            d.line([(x,y),(x+r.randrange(-5,6),y+r.randrange(5,100))],fill=(28,24,18),width=r.randrange(1,4))
    if name=='cloth':
        for y in range(0,size,4): d.line((0,y,size,y),fill=(49,44,33))
        for x in range(0,size,4): d.line((x,0,x,size),fill=(28,27,24))
    im.save(root/(name+'.png'))
noise('asphalt',(67,66,56));noise('bark',(92,76,48));noise('ground',(61,58,34));noise('vinyl',(48,47,39));noise('cloth',(47,42,32))
# Accurate diagram of the actual playable road; it deliberately has no moving GPS dot.
im=Image.new('RGB',(1100,1000),(194,177,125));p=im.load()
for y in range(1000):
    for x in range(1100):
        v=r.gauss(0,3)+9*math.sin(x/175)*math.cos(y/93)
        p[x,y]=(int(192+v),int(176+v),int(124+v))
d=ImageDraw.Draw(im)
d.rectangle((25,25,1075,975),outline=(69,65,41),width=3)
d.text((65,46),'SERRA DE SINTRA',font=font(42,True),fill=(53,53,34))
d.text((67,101),'ESTRADAS FLORESTAIS  /  1996',font=font(19),fill=(73,67,44))
def xy(a): return (int(440+a[0]*2.5),int(886+(a[1]-30)*1.18))
routes=[[(0,30),(0,-60),(-15,-95),(-42,-125),(-42,-170),(-10,-205),(0,-245)],[(0,-245),(35,-273),(70,-290),(90,-330),(65,-370),(45,-405)],[(0,-245),(-55,-265),(-90,-310),(-100,-345)],[(45,-405),(8,-435),(-35,-450),(-50,-490),(-24,-520),(15,-530),(48,-560)],[(45,-405),(95,-440),(120,-465),(145,-460)]]
for i in range(75):
    cx,cy=r.randrange(40,1060),r.randrange(145,950)
    for rad in range(20,r.randrange(70,160),13):
        pts=[(cx+math.cos(t*.14)*rad*(1+.1*math.sin(t)),cy+math.sin(t*.14)*rad*.6) for t in range(46)]
        d.line(pts,fill=(160,153,109),width=1)
for pts in routes:
    points=[xy(p) for p in pts];d.line(points,fill=(66,60,39),width=12,joint='curve');d.line(points,fill=(213,195,140),width=6,joint='curve')
for x in (366,733):
    d.rectangle((x-3,28,x+3,972),fill=(166,151,106));d.line((x+5,28,x+5,972),fill=(224,206,151),width=2)
d.line((28,500,1072,500),fill=(158,144,100),width=3)
ink=(82,64,42);red=(114,47,32)
for point,text,offset in [((0,30),'PARTIDA',(20,-8)),((-40,-145),'CURVA',(-135,-5)),((0,-245),'01  PEDREIRA',(15,20)),((45,-405),'02  CRUZAMENTO',(-140,20)),((48,-560),'S. PEDRO / ABRIGO',(25,-25))]:
    x,y=xy(point);d.ellipse((x-5,y-5,x+5,y+5),fill=ink);d.text((x+offset[0],y+offset[1]),text,font=font(18,True),fill=ink)
for point in [(-100,-345),(145,-460)]:
    x,y=xy(point);d.line((x-10,y-10,x+10,y+10),fill=red,width=4);d.line((x+10,y-10,x-10,y+10),fill=red,width=4)
    d.text((x-52,y-41),'SEM SAÍDA',font=font(16),fill=red)
d.text((65,174),'N',font=font(26,True),fill=ink);d.line((78,216,78,282),fill=ink,width=3);d.polygon([(78,202),(69,223),(87,223)],fill=ink)
d.text((670,770),'Chegar antes do amanhecer.',font=font(19),fill=red)
d.text((670,802),'01: direita.  02: esquerda.',font=font(18),fill=red)
d.text((67,932),'ESQUEMA LOCAL  ·  NÃO É UM MAPA TURÍSTICO',font=font(16),fill=ink)
im.save(root/'sintra_map.png')
# Instrument graphics, used as actual dashboard surfaces.
im=Image.new('RGB',(512,256),(11,14,11));d=ImageDraw.Draw(im)
for cx,cy,rad in [(128,135,103),(371,135,103)]:
    d.ellipse((cx-rad,cy-rad,cx+rad,cy+rad),outline=(71,77,49),width=3)
    for n in range(41):
        a=math.radians(140+n*6.5); ln=13 if n%5==0 else 6
        p1=(cx+math.cos(a)*(rad-8),cy+math.sin(a)*(rad-8));p2=(cx+math.cos(a)*(rad-ln-8),cy+math.sin(a)*(rad-ln-8))
        d.line((p1,p2),fill=(165,180,108),width=2)
        if n%5==0:
            tx=cx+math.cos(a)*(rad-34);ty=cy+math.sin(a)*(rad-34)
            d.text((tx,ty),str(n*3 if cx==128 else n//5),font=font(13),fill=(175,187,116),anchor='mm')
    d.line((cx,cy,cx-62,cy+48),fill=(219,145,59),width=3)
    d.ellipse((cx-6,cy-6,cx+6,cy+6),fill=(85,83,58))
d.text((92,176),'km/h',font=font(15),fill=(166,183,112));d.text((336,176),'x1000',font=font(15),fill=(166,183,112))
im.save(root/'gauges.png')
# Original seamless engine and forest ambience, no third-party asset dependencies.
for name,seconds in [('engine',4),('forest',12)]:
    rate=22050;frames=[];last=0
    for i in range(rate*seconds):
        t=i/rate;last=last*.98+r.uniform(-1,1)*.02
        if name=='engine': val=(math.sin(math.tau*42*t)*.12+math.sin(math.tau*84*t)*.05+r.uniform(-1,1)*.02)*(1+.2*math.sin(math.tau*7*t))
        else: val=last*.28+math.sin(math.tau*1350*t)*max(0,math.sin(math.tau*0.25*t))**30*.012
        frames.append(struct.pack('<h',int(max(-1,min(1,val))*32767)))
    with wave.open(str(root/(name+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(frames))
print('Created original textures, route map, instrument faces and audio.')
