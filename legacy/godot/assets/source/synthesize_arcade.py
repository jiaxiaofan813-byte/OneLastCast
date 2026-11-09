"""Original one-thumb arcade sounds. 48kHz mono PCM, no samples or third-party audio."""
from pathlib import Path
import math, random, struct, wave
root=Path(__file__).resolve().parents[1]/'audio'/'arcade'; root.mkdir(exist_ok=True)
sr=48000; rng=random.Random(1907)
def sound(name,length,fn):
 b=bytearray()
 for i in range(int(length*sr)):
  t=i/sr; amp=min(1,t/.0025)*max(0,1-t/length)**1.1
  v=max(-.96,min(.96,fn(t)*amp)); b+=struct.pack('<h',int(v*30000))
 with wave.open(str(root/(name+'.wav')),'wb') as f: f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes(b)
sound('cast',.18,lambda t:.26*math.sin(2*math.pi*(420*t+1400*t*t))+.16*rng.uniform(-1,1))
sound('slam',.22,lambda t:.65*math.sin(2*math.pi*(160*t-230*t*t))*math.exp(-t*13)+.22*rng.uniform(-1,1)*math.exp(-t*9))
def bite(t):
 out=0
 for start in (0,.075):
  a=t-start
  if a>=0: out+=.62*math.sin(2*math.pi*(105*a+150*a*a))*math.exp(-a*35)
 return out
sound('bite',.2,bite)
sound('snap',.16,lambda t:.35*rng.uniform(-1,1)*math.exp(-t*60)+.58*math.sin(2*math.pi*(740*t-1800*t*t))*math.exp(-t*20))
sound('counter',.15,lambda t:.65*math.sin(2*math.pi*(180*t-380*t*t))*math.exp(-t*17)+.2*rng.uniform(-1,1)*math.exp(-t*60))
low=[0.0]
def breach(t):
 low[0]=.66*low[0]+.34*rng.uniform(-1,1)
 return .8*low[0]+.35*math.sin(2*math.pi*(95*t-80*t*t))*math.exp(-t*16)
sound('breach',.35,breach)
sound('basket',.17,lambda t:.55*math.sin(2*math.pi*260*t)*math.exp(-t*22)+.15*rng.uniform(-1,1)*math.exp(-t*40))
sound('chime',.32,lambda t:.48*math.sin(2*math.pi*523.25*t)*math.exp(-t*9)+.13*math.sin(2*math.pi*1046.5*t)*math.exp(-t*16))
sound('fever',.45,lambda t:sum(.16*math.sin(2*math.pi*f*t)*math.exp(-t*7) for f in [523.25,659.25,783.99,1046.5]))
sound('miss',.14,lambda t:.2*math.sin(2*math.pi*(330*t-500*t*t))*math.exp(-t*18))
print('10 original arcade WAV files')
