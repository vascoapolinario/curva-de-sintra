"""Single road-data source for the world and the paper map. Run with Python + Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math, random, json, heapq
ROOT=Path(__file__).resolve().parents[1]
r=random.Random(5319)
nodes=[(0,0),(700,-150),(1000,-1100),(100,-1500),(-900,-1100),(-1400,-2200),(-250,-2600),(600,-2400),(1000,-3300),(0,-3700)]
mids=[[(0,-190),(170,-340),(430,-320),(620,-200)],[(920,-280),(820,-570),(1120,-790)],[(950,-1360),(680,-1260),(510,-1590),(290,-1650)],[(-130,-1680),(-480,-1510),(-720,-1600),(-1020,-1330)],[(-1130,-1030),(-1490,-1320),(-1300,-1670),(-1510,-1900)],[(-1100,-2360),(-860,-2230),(-610,-2570)],[(0,-2820),(250,-2650),(480,-2730)],[(840,-2260),(1110,-2510),(880,-2920)],[(860,-3540),(560,-3430),(310,-3790)]]
paths=[dict(a=i,b=i+1,points=[nodes[i],*mids[i],nodes[i+1]],kind='main') for i in range(9)]
extras=[(1,2,[(1170,30),(1570,-180),(1690,-630),(1500,-960)]),(3,4,[(120,-1170),(-150,-950),(-450,-940),(-650,-770)]),(5,6,[(-1560,-2670),(-1150,-2920),(-730,-2990),(-480,-2800)]),(6,7,[(-80,-2420),(220,-2390),(390,-2470)]),(7,8,[(790,-1960),(1240,-2090),(1450,-2790),(1210,-3090)])]
for a,b,mid in extras: paths.append(dict(a=a,b=b,points=[nodes[a],*mid,nodes[b]],kind='loop'))
spurs=[(1,[(620,80),(850,240),(1020,180)]),(2,[(1240,-1130),(1430,-1300),(1530,-1500)]),(3,[(210,-1740),(80,-1990),(-150,-2060)]),(4,[(-900,-760),(-1210,-570),(-1420,-620)]),(5,[(-1690,-2260),(-1810,-2130),(-1900,-2420)]),(6,[(-210,-2390),(-440,-2180),(-410,-1990)]),(7,[(600,-2140),(380,-2020),(530,-1850)]),(8,[(1280,-3400),(1450,-3180),(1600,-3240)])]
for a,mid in spurs:
    idx=len(nodes); nodes.append(mid[-1]); paths.append(dict(a=a,b=idx,points=[nodes[a],*mid],kind='spur'))
def tangent(p,prev,nxt):
    dx,dz=nxt[0]-prev[0],nxt[1]-prev[1]; length=math.hypot(dx,dz) or 1
    distances=[v for v in [math.dist(p,prev),math.dist(p,nxt)] if v>0]
    handle=min(distances)*1.15
    return (dx/length*handle,dz/length*handle)

def sample(path):
    points=path['points']
    tangents=[tangent(p,points[max(0,i-1)],points[min(len(points)-1,i+1)]) for i,p in enumerate(points)]
    # Through-roads share a tangent at every junction. Side lanes retain their
    # own approach, so forks remain legible instead of meeting at square corners.
    if path['kind']=='main':
        a,b=path['a'],path['b']
        if a>0: tangents[0]=tangent(nodes[a],mids[a-1][-1],mids[a][0])
        if b<9: tangents[-1]=tangent(nodes[b],mids[b-1][-1],mids[b][0])
    out=[]
    for i in range(len(points)-1):
        a,b=points[i],points[i+1]; pre=points[max(0,i-1)]; nex=points[min(len(points)-1,i+2)]
        ta,tb=tangents[i],tangents[i+1]
        count=max(2,int(math.dist(a,b)/3))
        for j in range(count):
            t=j/count; h00=2*t**3-3*t*t+1;h10=t**3-2*t*t+t;h01=-2*t**3+3*t*t;h11=t**3-t*t
            out.append([h00*a[k]+h10*ta[k]+h01*b[k]+h11*tb[k] for k in range(2)])
    return out+[list(points[-1])]
for p in paths: p['samples']=sample(p)
length=sum(sum(math.dist(a,b) for a,b in zip(p['samples'],p['samples'][1:])) for p in paths[:9])
scale=8100/length
for p in paths:
    p['samples']=[[round(x*scale,3),round(z*scale,3)] for x,z in p.pop('samples')]
    p.pop('points')
    p['length']=sum(math.dist(a,b) for a,b in zip(p['samples'],p['samples'][1:]))
nodes=[[round(x*scale,3),round(z*scale,3)] for x,z in nodes]
# Check intended connectivity and minimum journey time (11.5 m/s).
dist={0:0};q=[(0,0)]
while q:
    d,n=heapq.heappop(q)
    if d>dist[n]:continue
    for p in paths:
        if n not in (p['a'],p['b']):continue
        other=p['b'] if n==p['a'] else p['a'];nd=d+p['length']
        if nd<dist.get(other,1e20):dist[other]=nd;heapq.heappush(q,(nd,other))
allpoints=[v for p in paths for v in p['samples']]
bound=[min(p[0] for p in allpoints)-160,min(p[1] for p in allpoints)-160,max(p[0] for p in allpoints)+160,max(p[1] for p in allpoints)+160]
def placement(road,fraction,offset):
    pts=paths[road]['samples']; i=int(fraction*(len(pts)-2))
    x,z=pts[i]; dx,dz=pts[i+1][0]-x,pts[i+1][1]-z
    length=math.hypot(dx,dz); right=(-dz/length,dx/length)
    return dict(road=road,sample=i,position=[x+right[0]*offset,z+right[1]*offset],yaw=math.atan2(-dx,-dz))

landmarks=[]
for road,fraction,offset,kind,label in [(0,.64,13,'pond','LAGOA'),(2,.58,-8,'cross','CRUZ ALTA'),(4,.48,12,'quarry','PEDREIRA'),(5,.65,-9,'fountain','FONTE FRIA'),(7,.56,10,'chapel','ERMIDA')]:
    landmarks.append(dict(**placement(road,fraction,offset),kind=kind,label=label))
    landmarks[-1]['yaw']-=math.copysign(math.pi/3,offset)
obstacles=[]
for road,fraction,side,kind in [(1,.54,1,'log'),(3,.42,-1,'rockfall'),(6,.53,1,'log'),(8,.30,-1,'rockfall'),(9,.57,-1,'rockfall'),(11,.46,1,'log'),(13,.58,1,'rockfall')]:
    # The inner edge stays 0.95 m from the centre: over four metres of asphalt
    # remain free on the other side, even allowing for the car's full width.
    obstacles.append(dict(**placement(road,fraction,side*2.75),kind=kind,side=side,half_size=[1.8,.6 if kind=='log' else 2.2]))
data=dict(nodes=nodes,roads=paths,bounds=bound,destination=nodes[9],main_route=list(range(9)),minimum_distance=dist[9],maximum_speed=11.5,landmarks=landmarks,obstacles=obstacles)
(ROOT/'assets/region.json').write_text(json.dumps(data,separators=(',',':')))
W,H=1800,1800
im=Image.new('RGB',(W,H));px=im.load()
for y in range(H):
    for x in range(W):
        v=r.gauss(0,2.2)+5*math.sin(x/141)*math.sin(y/213)
        px[x,y]=(int(183+v),int(170+v),int(131+v))
draw=ImageDraw.Draw(im)
def font(s,bold=False):return ImageFont.truetype('C:/Windows/Fonts/'+('georgiab.ttf' if bold else 'georgia.ttf'),s)
# Drawing coordinates are shared with the Godot shader. North is toward decreasing Z.
def uv(p):return (150+(p[0]-bound[0])/(bound[2]-bound[0])*1500,200+(p[1]-bound[1])/(bound[3]-bound[1])*1400)
for i in range(180):
    cx,cy=r.randrange(80,1720),r.randrange(170,1640)
    for rad in range(25,r.randrange(70,180),15):
        pts=[(cx+math.cos(t*.1)*rad*(1+.08*math.sin(t*.6)),cy+math.sin(t*.1)*rad*.63) for t in range(64)]
        draw.line(pts,fill=(168,157,119),width=1)
for x in range(150,1651,250):draw.line((x,200,x,1600),fill=(164,157,122),width=1)
for y in range(200,1601,233):draw.line((150,y,1650,y),fill=(164,157,122),width=1)
for p in paths:
    pts=[uv(v) for v in p['samples']]
    draw.line(pts,fill=(62,57,42),width=18,joint='curve');draw.line(pts,fill=(216,200,158),width=8,joint='curve')
names=['PORTELA','LAGOA','CANCELA','CRUZ ALTA','PEDREIRA','FONTE FRIA','MONTE','VALE','ERMITA','S. PEDRO']
for i in range(10):
    x,y=uv(nodes[i]);draw.ellipse((x-7,y-7,x+7,y+7),fill=(75,65,42))
    # Junction numbers stay small; named features below carry navigation.
    label='PORTELA' if i==0 else ('' if i==9 else f'{i:02d}')
    draw.text((x+15,y+12),label,font=font(34,True),fill=(60,58,43),stroke_width=3,stroke_fill=(186,174,137))
for i in range(30):
    x,y=r.randrange(140,1620),r.randrange(230,1560)
    draw.text((x,y),str(r.randrange(240,530)),font=font(13),fill=(126,125,94))
draw.rectangle((38,36,1762,1764),outline=(85,79,56),width=3)
draw.text((86,67),'SERRA DE SINTRA',font=font(52,True),fill=(54,56,41))
draw.text((89,132),'CARTA DAS ESTRADAS FLORESTAIS     /     EDIÇÃO 1996',font=font(22),fill=(87,81,58))
draw.text((94,1662),'S. PEDRO  ·  ABRIGO FLORESTAL',font=font(24),fill=(69,65,46))
draw.text((94,1710),'CURVAS · ESTRADAS SECUNDÁRIAS · CAMINHOS SEM SAÍDA',font=font(19),fill=(91,80,54))
draw.text((1620,85),'N',font=font(29,True),fill=(67,64,44));draw.line((1634,166,1634,121),fill=(67,64,44),width=3);draw.polygon([(1634,113),(1625,131),(1643,131)],fill=(67,64,44))
for x in [600,1200]:
    draw.rectangle((x-2,40,x+2,1760),fill=(147,136,100));draw.line((x+4,40,x+4,1760),fill=(209,195,154),width=2)
for y in [600,1200]:draw.line((40,y,1760,y),fill=(151,142,108),width=3)
# Printed pictograms match actual roadside features. Labels are set for the
# held map's screen size, not merely for this high-resolution source texture.
ink=(53,62,51); halo=(190,176,138)
label_offsets=[(-200,-82),(35,-90),(-190,35),(-95,38),(34,18)]
for landmark,(lx,ly) in zip(landmarks,label_offsets):
    x,y=uv(landmark['position']); kind=landmark['kind']
    draw.ellipse((x-27,y-27,x+27,y+27),fill=halo)
    if kind=='pond':
        draw.ellipse((x-24,y-13,x+24,y+13),fill=(95,112,102),outline=ink,width=3)
        for dy in [-5,5]:draw.line((x-13,y+dy,x+13,y+dy),fill=halo,width=2)
    elif kind=='cross':
        draw.line((x,y-24,x,y+23),fill=ink,width=7);draw.line((x-17,y-10,x+17,y-10),fill=ink,width=7)
    elif kind=='quarry':
        draw.polygon([(x-24,y+19),(x-14,y-13),(x+6,y-21),(x+25,y+19)],fill=ink)
        draw.line((x-14,y+10,x+15,y+10),fill=halo,width=3)
    elif kind=='fountain':
        draw.arc((x-23,y-9,x+23,y+20),0,180,fill=ink,width=5)
        draw.line((x,y-20,x,y+8),fill=ink,width=5)
        draw.arc((x-17,y-22,x+17,y-2),180,350,fill=ink,width=4)
    else:
        draw.rectangle((x-19,y-6,x+19,y+22),outline=ink,width=5)
        draw.line([(x-25,y-4),(x,y-23),(x+25,y-4)],fill=ink,width=5)
        draw.line((x,y-36,x,y-21),fill=ink,width=4);draw.line((x-7,y-30,x+7,y-30),fill=ink,width=4)
    label=landmark['label'].replace(' ','\n') if kind=='fountain' else landmark['label']
    draw.text((x+lx,y+ly),label,font=font(48,True),fill=ink,stroke_width=4,stroke_fill=halo,spacing=0)
# Two imperfect felt-pen loops and a handwritten arrow visibly distinguish the
# destination from printed map information without adding a game HUD.
x,y=uv(nodes[9]); red=(131,39,30)
for k in range(2):
    pts=[(x+math.cos(t)* (57+3*math.sin(t*3+k))+k*4,y+math.sin(t)*(42+3*math.cos(t*5+k))+k*3) for t in [j*math.tau/100 for j in range(103)]]
    draw.line(pts,fill=red,width=7,joint='curve')
draw.line([(x-95,y-63),(x-80,y-48),(x-58,y-15)],fill=red,width=8,joint='curve')
draw.line([(x-76,y-39),(x-58,y-15),(x-88,y-15)],fill=red,width=7)
draw.text((x-290,y-134),'ABRIGO',font=ImageFont.truetype('C:/Windows/Fonts/segoeprb.ttf',55),fill=red,stroke_width=1)
draw.text((x-286,y-67),'SÃO PEDRO',font=font(29,True),fill=red)
im.save(ROOT/'assets/sintra_map.png')
# Pale mineral texture for masonry, separate from the dark forest floor.
stone=Image.new('RGB',(128,128)); grain=random.Random(4251)
for y in range(128):
    for x in range(128):
        value=int(194+grain.gauss(0,12)+12*math.sin(x*.13)*math.cos(y*.16))
        value=max(100,min(240,value))
        stone.putpixel((x,y),(value,value,max(0,value-10)))
stone.save(ROOT/'assets/weathered_stone.png')
print(f'{len(paths)} roads, {sum(p["length"] for p in paths)/1000:.2f} km total. Shortest {dist[9]/1000:.2f} km / {dist[9]/11.5/60:.2f} min at maximum speed.')
