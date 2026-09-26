"""Original synthesized distant wildlife cues; no third-party recordings."""
from pathlib import Path
import wave
import numpy as np

root = Path(__file__).resolve().parents[1] / 'assets'
rate = 24000
rng = np.random.default_rng(1742)

def save(name, signal):
    # Short diffuse reflections make the calls feel outside the car.
    dry = signal.copy()
    for delay, level in [(0.13, .19), (.29, .12), (.47, .07)]:
        n = int(rate * delay)
        signal[n:] += dry[:-n] * level
    signal = np.tanh(signal * 1.3) * .55
    with wave.open(str(root / name), 'wb') as f:
        f.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        f.writeframes((signal * 32767).astype('<i2').tobytes())

t = np.arange(rate*7) / rate
owl = np.zeros_like(t)
for start, dur in [(.4,.38),(1.15,.85),(4.1,.4),(4.8,1.0)]:
    u = t-start
    env = np.clip(np.sin(np.pi*np.clip(u/dur,0,1)),0,1)**1.8
    phase = 2*np.pi*(330*u-16*u*u+1.2*np.sin(u*13))
    owl += env*(.32*np.sin(phase)+.025*np.sin(2*phase))
save('owl.wav',owl)
fox=np.zeros_like(t)
for start in [.6,2.7]:
    u=t-start
    env=np.sin(np.pi*np.clip(u/.72,0,1))**2
    phase=2*np.pi*(720*u+85*np.sin(u*4))
    fox+=env*(.13*np.sin(phase)+.055*np.sin(phase*2)+.022*rng.normal(size=t.size))
save('fox.wav',fox)
branches=np.zeros_like(t)
for start in [.9,1.18,1.5,3.2]:
    u=np.maximum(t-start,0)
    env=np.where(t>=start,np.exp(-u*27),0)
    branches+=env*(rng.normal(size=t.size)*.11+np.sin(2*np.pi*160*u)*.09)
save('branches.wav',branches)
