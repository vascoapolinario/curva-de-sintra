"""A short mechanical selector click and gentle FM hiss, without a tonal sweep."""
from pathlib import Path
import math, random, struct, wave
rate=44100
rng=random.Random(71)
samples=[]
low=0.0
for i in range(int(rate*.26)):
    t=i/rate
    white=rng.uniform(-1,1)
    low+=.19*(white-low)
    hiss=low*.16*math.sin(math.pi*min(1,t/.26))**2
    click=white*.25*math.exp(-t*330)
    # Soft contact settling, not a repeated beep or long burst of static.
    contact=0 if t<.035 else math.sin((t-.035)*math.tau*1450)*.08*math.exp(-(t-.035)*220)
    sample=max(-.8,min(.8,hiss+click+contact))
    samples.append(struct.pack('<h',int(sample*32767)))
with wave.open(str(Path(__file__).resolve().parents[1]/'assets/radio/tuning.wav'),'wb') as out:
    out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes(b''.join(samples))
