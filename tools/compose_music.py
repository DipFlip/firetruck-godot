"""Original, seamless 16-bar miniature-town marimba sketch. No sampled audio."""
import wave, math, array, random
RATE=22050; BEAT=60/88; LENGTH=32*BEAT
buf=array.array('f',[0])*(int(LENGTH*RATE))
random.seed(7)
def note(midi,start,volume=.2,duration=1.8):
    f=440*2**((midi-69)/12)
    for i in range(int(duration*RATE)):
        t=i/RATE
        e=(1-math.exp(-t*200))*math.exp(-t*3.1)
        v=(math.sin(math.tau*f*t)+.23*math.sin(math.tau*f*2.001*t)*math.exp(-t*7)+.12*math.sin(math.tau*f*4*t)*math.exp(-t*12))*e*volume
        idx=(int(start*RATE)+i)%len(buf);buf[idx]+=v
        # Small, warm room response; delay wraps with the loop.
        buf[(idx+int(RATE*.19))%len(buf)]+=v*.14
        buf[(idx+int(RATE*.31))%len(buf)]+=v*.08
chords=[[48,60,64,67,74],[45,60,64,69,72],[50,62,65,69,76],[43,59,62,67,74]]
melody=[76,74,72,None,74,76,79,76,74,None,72,69,72,74,71,None]
for bar in range(8):
    chord=chords[(bar//2)%4]
    note(chord[0],bar*4*BEAT,.14,2.8)
    for step in [0,1.5,2.5,3.5]:
        key=chord[1+(int(step*2)+bar)%4]
        note(key,(bar*4+step)*BEAT,.065,1.5)
    for j in range(2):
        key=melody[bar*2+j]
        if key:note(key,(bar*4+j*1.5+.5)*BEAT,.10,2.2)
peak=max(abs(x) for x in buf)
out=array.array('h',(int(x/max(1,peak)*26000) for x in buf))
with wave.open('assets/audio/maple_morning.wav','wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(out.tobytes())
print('Original music loop:',len(buf)/RATE,'seconds')
