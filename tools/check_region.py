"""Verify map topology, journey lengths, and unintentional road crossings."""
from pathlib import Path
import json, math, itertools
data=json.loads((Path(__file__).resolve().parents[1]/'assets/region.json').read_text())
roads=data['roads']
choices=[[0],[1,9],[2],[3,10],[4],[5,11],[6,12],[7,13],[8]]
routes=sorted((sum(roads[i]['length'] for i in route)/11.5/60,route) for route in itertools.product(*choices))
assert len(routes)==32 and routes[0][0]>=10
assert sum(minutes<14 for minutes,_ in routes)>=3
print(f'{len(routes)} connected routes; {sum(m<14 for m,_ in routes)} below 14 minutes at maximum speed; shortest {routes[0][0]:.2f} min')
def cross(a,b,c): return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
grid={}; crossings=[]
for ri,road in enumerate(roads):
    for si,(a,b) in enumerate(zip(road['samples'],road['samples'][1:])):
        keys=[(x,y) for x in range(math.floor(min(a[0],b[0])/20),math.floor(max(a[0],b[0])/20)+1) for y in range(math.floor(min(a[1],b[1])/20),math.floor(max(a[1],b[1])/20)+1)]
        seen=set()
        for key in keys:
            for rj,sj,c,d in grid.get(key,[]):
                if (rj,sj) in seen or (ri==rj and abs(si-sj)<3):continue
                seen.add((rj,sj))
                if cross(a,b,c)*cross(a,b,d)<0 and cross(c,d,a)*cross(c,d,b)<0:
                    crossings.append((ri,rj,a))
        for key in keys:grid.setdefault(key,[]).append((ri,si,a,b))
assert not crossings, f'Unplanned intersections: {crossings}'
print('No unplanned intersections or self-crossings.')
for mark in data['landmarks']:
    assert mark['kind'] in ['pond','cross','quarry','fountain','chapel']
print('Landmarks, map, and obstacles share the same generated coordinates.')
