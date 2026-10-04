"""Original radio music: no copied melodies, recordings or artist impersonations."""
from pathlib import Path
import numpy as np, wave
root=Path(__file__).resolve().parents[1]/'assets'/'radio';root.mkdir(exist_ok=True)
rate=22050;rng=np.random.default_rng(773)
def save(name,data):
    data=np.tanh(data)*.68
    with wave.open(str(root/name),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes((data*32767).astype('<i2').tobytes())
def note(buf,start,duration,midi,volume,kind):
    at=int(start*rate);n=min(int(duration*rate),len(buf)-at)
    if n<=0:return
    t=np.arange(n)/rate;freq=440*2**((midi-69)/12)
    if kind=='pluck':
        y=sum(np.sin(2*np.pi*freq*k*t+0.1*k)*np.exp(-t*(2.4+k*.9))/(k*k*.65) for k in range(1,7))
    elif kind=='keys':
        y=(np.sin(2*np.pi*freq*t)+.28*np.sin(2*np.pi*freq*2*t))*np.exp(-t*1.3)
    else:
        y=(np.sin(2*np.pi*freq*t)+.3*np.sin(2*np.pi*(freq*1.004)*t))*np.minimum(t,1)*np.minimum((n/rate-t),1)*.4
    y*=np.minimum(t*180,1)
    buf[at:at+n]+=y*volume
for station,bpm,name in [(0,96,'midnight_orchard.wav'),(1,78,'last_tram.wav'),(2,58,'distant_signal.wav')]:
    beat=60/bpm;duration=32*4*beat;buf=np.zeros(int(duration*rate))
    chords=[[48,52,55],[53,57,60],[55,59,62],[48,52,57]] if station==0 else ([[45,48,52,55],[50,53,57,60],[43,47,50,53],[48,52,55,59]] if station==1 else [[45,48,52],[41,45,48],[40,43,47],[45,48,52]])
    for bar in range(32):
        chord=chords[(bar//2)%4];start=bar*4*beat
        for b in range(8):
            when=start+b*beat*.5
            if station==0:
                note(buf,when,1.5,chord[b%3]+12,.075,'pluck')
                if b%2==0:note(buf,when,beat*.8,chord[0]-12,.13,'pluck')
            elif station==1:
                if b in [0,3,6]:
                    for pitch in chord:note(buf,when,2,pitch+12,.05,'keys')
                if b%2==0:note(buf,when,beat*.85,chord[(b//2)%4]-12,.10,'pluck')
            elif b==0:
                for pitch in chord:note(buf,when,beat*4,pitch,.10,'pad')
        if station<2:
            melody=[0,4,7,9,7,4,2,0][bar%8]
            note(buf,start+beat*1.5,beat*1.5,60+melody,.035,'pluck' if station==0 else 'keys')
            for b in range(4):
                at=int((start+b*beat)*rate);n=min(int(.1*rate),len(buf)-at);t=np.arange(n)/rate
                drum=rng.normal(0,1,n)*np.exp(-t*55)*(.012 if b%2==0 else .035)
                buf[at:at+n]+=drum
    # Gentle tape colour and repeatable track lengths.
    buf=np.convolve(buf,np.ones(3)/3,'same')
    fade=np.minimum(np.arange(len(buf))/rate/0.5,1)*np.minimum((len(buf)-np.arange(len(buf)))/rate/1.5,1)
    save(name,buf*fade)
import runpy
runpy.run_path(str(Path(__file__).with_name('build_tuning.py')))
for folder in ['01_estrada','02_nocturno','03_frequencia']: (root/folder).mkdir(exist_ok=True)
print('Original radio tracks built.')
