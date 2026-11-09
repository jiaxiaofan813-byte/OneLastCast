"""Original 24-second low-level pond music, no samples, royalty dependency or network."""
import math, struct, wave
from pathlib import Path
sr=48000; duration=24
out=Path(__file__).resolve().parents[1]/'audio'/'pond_music.wav'
notes=[(0,392),(2,523.251),(5,587.33),(8,659.255),(11,523.251),(14,440),(17,392),(20,523.251)]
with wave.open(str(out),'wb') as f:
 f.setnchannels(1); f.setsampwidth(2); f.setframerate(sr)
 data=bytearray()
 for i in range(sr*duration):
  t=i/sr; envelope=math.sin(math.pi*t/duration)**2
  sample=.02*math.sin(2*math.pi*130*t)+.014*math.sin(2*math.pi*196*t)+.01*math.sin(2*math.pi*261*t)
  for start,hz in notes:
   age=t-start
   if 0<=age<4: sample+=.09*math.sin(2*math.pi*hz*age)*math.exp(-age*1.35)*(1-math.exp(-age*30))
  sample*=envelope
  data+=struct.pack('<h',max(-32767,min(32767,int(sample*32767))))
  if len(data)>65536: f.writeframesraw(data); data.clear()
 f.writeframes(data)
print(out)
