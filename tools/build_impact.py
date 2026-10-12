"""Generate the original, quiet chassis impact used by roadside barriers."""
from pathlib import Path
import math, random, wave, struct
rate=22050;r=random.Random(819);previous=0;out=[]
for i in range(int(rate*.31)):
    t=i/rate;previous=previous*.86+r.uniform(-1,1)*.14
    envelope=(1-math.exp(-t*700))*math.exp(-t*23)
    value=envelope*(.45*math.sin(math.tau*83*t)*math.exp(-t*8)+.43*previous+.12*math.sin(math.tau*162*t))
    out.append(struct.pack('<h',int(max(-1,min(1,value))*32767)))
with wave.open(str(Path(__file__).resolve().parents[1]/'assets/barrier_impact.wav'),'wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(out))
