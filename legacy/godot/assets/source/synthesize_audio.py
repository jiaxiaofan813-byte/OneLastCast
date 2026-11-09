"""Original deterministic prototype sound synthesis, 48 kHz PCM, stdlib only.
No third-party samples or recorded voices. Regenerate from the SSD project.
"""
import math, random, struct, wave
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1] / 'audio'
ROOT.mkdir(exist_ok=True)
SR = 48000
rng = random.Random(583)
def render(name, length, fn):
    data=[]
    for i in range(int(SR*length)):
        t=i/SR
        env=min(1,t/.004)*max(0,1-t/length)**1.5
        value=max(-.95,min(.95,fn(t)*env))
        data.append(struct.pack('<h',round(value*24000)))
    with wave.open(str(ROOT/(name+'.wav')),'wb') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(SR); out.writeframes(b''.join(data))
render('cast',.12,lambda t: .35*math.sin(2*math.pi*(480*t-900*t*t))*math.exp(-t*20)+rng.uniform(-.12,.12)*math.exp(-t*45))
render('reel',.17,lambda t: .15*math.sin(2*math.pi*(620*t+800*t*t))+rng.uniform(-.13,.13)*math.exp(-t*13))
for i,f in enumerate([510,640,765],1):
    render('catch'+str(i),.15,lambda t,f=f:.43*math.sin(2*math.pi*(f*t-1250*t*t))+.12*math.sin(2*math.pi*(f*2.01*t))*math.exp(-t*30))
for name, dur, f in [('splash',.34,160),('big_splash',.43,95)]:
    memory=[0.0]
    def spl(t,f=f):
        memory[0]=memory[0]*.7+rng.uniform(-1,1)*.3
        return .7*memory[0]+.18*math.sin(2*math.pi*(f*t-90*t*t))*math.exp(-t*15)
    render(name,dur,spl)
render('empty',.18,lambda t:.14*math.sin(2*math.pi*(770*t-1700*t*t)))
def result(t):
    total=0
    for start,f in [(0,523.25),(.07,659.25),(.14,783.99)]:
        tt=t-start
        if tt>=0: total+=.22*math.sin(2*math.pi*f*tt)*math.exp(-tt*13)
    return total
render('result',.35,result)
print('9 original PCM WAV effects generated on SSD')
