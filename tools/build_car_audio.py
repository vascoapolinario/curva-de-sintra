"""Original looping horn, electrical switch, wind drone and forest cues."""
from pathlib import Path
import wave
import numpy as np

root=Path(__file__).resolve().parents[1]/'assets'
sr=24000
rng=np.random.default_rng(5471)
def save(name,x):
    x=np.clip(x,-.92,.92)
    with wave.open(str(root/name),'wb') as f:
        f.setparams((1,2,sr,0,'NONE','not compressed'))
        f.writeframes((x*32767).astype('<i2').tobytes())
def noise(n,width):
    return np.convolve(rng.normal(size=n),np.ones(width)/width,mode='same')
t=np.arange(sr)/sr
# Integer periods loop cleanly, giving a worn two-tone electromechanical horn.
x=sum(np.sin(2*np.pi*f*k*t)/k**1.35 for f in [350,440] for k in range(1,7))
save('car_horn.wav',np.tanh(x*.7)*.45)
t=np.arange(int(sr*.14))/sr
save('light_switch.wav',(.28*noise(len(t),3)+.2*np.sin(2*np.pi*1500*t))*np.exp(-t*65))
t=np.arange(sr*24)/sr
x=(np.sin(2*np.pi*47*t)+.5*np.sin(2*np.pi*49*t)+.22*np.sin(2*np.pi*93*t))*.19
x*=.72+.28*np.sin(2*np.pi*t/24)
# Smooth periodic wind; no click at the loop boundary.
n=noise(len(t),180)
n*=np.sin(np.pi*t/24)**2
save('forest_dread.wav',x+n*.5)
t=np.arange(sr*6)/sr
x=np.zeros_like(t)
for start in [.4,1.45,2.8,4.0]:
    u=np.maximum(0,t-start)
    env=np.where(t>=start,np.exp(-u*19)*(1-np.exp(-u*180)),0)
    x+=env*(noise(len(t),15)*.55+np.sin(2*np.pi*78*u)*.15)
save('forest_steps.wav',x)
t=np.arange(sr*8)/sr
env=np.sin(np.pi*t/8)**2
phase=2*np.pi*(105*t+7*np.sin(t*1.7))
x=(np.sin(phase)*.13+np.sin(phase*2.01)*.045+noise(len(t),22)*.16)*env
save('tree_creak.wav',x)
