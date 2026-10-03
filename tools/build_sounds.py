"""Bake original, softly enveloped Foley and character sounds. No runtime synthesis.
All samples are mono PCM at 22.05 kHz; deterministic variants keep exports repeatable.
"""
from pathlib import Path
import math, random, struct, wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets/audio/town'
TAU = math.tau

def smooth(a, b, t):
    u = max(0., min(1., (t-a)/(b-a)))
    return u*u*(3-2*u)

def bake(kind, variant, duration):
    rng = random.Random(731 + variant*97 + sum(map(ord, kind)))
    data, phase, low, prev = [], 0., 0., 0.
    shift = 1 + (variant-1)*.045
    for i in range(round(duration*RATE)):
        t = i/RATE
        n = rng.uniform(-1, 1)
        low += .14*(n-low)
        air = n-prev
        prev = n
        y = 0.
        if kind in ('voice', 'dodge', 'woof', 'meow'):
            if kind == 'voice':
                f = (164 + variant*19)*(1+.14*math.sin(math.pi*t/duration))
                env = smooth(0,.012,t)*(1-smooth(duration-.022,duration,t))
            elif kind == 'dodge':
                f = (170+variant*23)*(1+.5*math.sin(math.pi*t/duration))
                env = math.sin(math.pi*t/duration)**1.4
            elif kind == 'woof':
                age = t % .24
                f = (125+variant*8)*(1+.55*math.exp(-age*24))
                env = smooth(0,.012,age)*(1-smooth(.065,.19,age)) if t < .44 else 0
            else:
                f = (420+variant*25)*(1-.34*smooth(.12,.65,t)+.07*math.sin(t*18))
                env = smooth(0,.055,t)*(1-smooth(duration-.18,duration,t))
            phase += TAU*f/RATE
            y = (math.sin(phase)*.6 + math.sin(phase*2)*.23 + math.sin(phase*3)*.10 + math.sin(phase*4)*.04)*env
            if kind == 'woof': y += low*env*.6
            if kind == 'meow': y = (math.sin(phase)*.5+math.sin(phase*2)*.28+math.sin(phase*3)*.10)*env
        elif kind == 'bird':
            flap = sum(math.exp(-((t-c)/.04)**2) for c in (.06,.18,.31,.45))
            y = low*flap*1.4 + air*.055*flap
            age = t-.05
            if 0 < age < .17:
                phase += TAU*(1800+600*math.sin(age*math.pi/.17))*shift/RATE
                y += math.sin(phase)*math.sin(math.pi*age/.17)**2*.14
        elif kind in ('wood','fence','metal','brick','bush','car_bump'):
            modes = {'wood':(155,283,450),'fence':(235,414,720),'metal':(340,697,1130), 'brick':(95,170,380),'bush':(90,150,220),'car_bump':(110,240,540)}[kind]
            decay = 4.5 if kind=='metal' else 12
            for j,f in enumerate(modes):
                y += math.sin(TAU*f*shift*t)*math.exp(-t*(decay+j*4))*(.34/(j+1))
            y += low*math.exp(-t*14)*1.8
            if kind in ('wood','fence'): y += low*math.exp(-((t-.09)/.04)**2)*.5
            if kind=='brick': y += air*.10*math.exp(-t*18)
            if kind=='bush': y = low*.8*math.sin(math.pi*t/duration)**1.2 + air*.02*math.exp(-t*6)
        elif kind == 'splash':
            y = low*2.2*math.exp(-t*5)*smooth(0,.025,t) + air*.11*math.exp(-t*8)
            for j in range(4):
                age=t-.16-j*.13
                if age>0: y += math.sin(TAU*(650+240*j)*age)*math.exp(-age*35)*.12
        elif kind == 'clean':
            for j,f in enumerate((523.25,659.25,783.99,1046.5)):
                age=t-j*.09
                if age>=0: y += (math.sin(TAU*f*age)+.12*math.sin(TAU*f*2*age))*smooth(0,.008,age)*math.exp(-age*8)*.26
        elif kind == 'honk':
            env = smooth(0,.025,t)*(1-smooth(duration-.065,duration,t))
            y = (math.sin(TAU*330*shift*t)*.35+math.sin(TAU*415*shift*t)*.32+math.sin(TAU*660*shift*t)*.08)*env
        elif kind == 'chuff':
            y = (low*2 + math.sin(TAU*85*t)*.13)*math.sin(math.pi*t/duration)**1.1*math.exp(-t*6)
        elif kind == 'whistle':
            env = smooth(0,.09,t)*(1-smooth(duration-.26,duration,t))
            phase += TAU*392*shift*(1+.003*math.sin(t*23))/RATE
            y = (math.sin(phase)*.4+math.sin(phase*1.25)*.28+math.sin(phase*1.5)*.22+low*.08)*env
        elif kind == 'ringtone':
            for start in (.05,.66,1.62,2.23):
                age=t-start
                if 0<=age<.40:
                    env=smooth(0,.015,age)*(1-smooth(.31,.40,age))
                    y += (math.sin(TAU*440*t)*.27+math.sin(TAU*554.37*t)*.23)*( .65+.35*math.sin(TAU*19*age))*env
        elif kind == 'engine':
            y = math.sin(TAU*48*t)*.55+math.sin(TAU*96*t)*.20+math.sin(TAU*144*t)*.08
            # Exactly periodic, including its gentle modulation.
            y *= .88+.12*math.sin(TAU*4*t)
        if kind != 'engine': y *= smooth(0,.004,t)*(1-smooth(duration-.012,duration,t))
        data.append(y)
    peak=max(abs(x) for x in data) or 1
    gain=.65/peak
    samples=struct.pack('<'+'h'*len(data), *(round(x*gain*32767) for x in data))
    path=OUT/f'{kind}_{variant}.wav'
    with wave.open(str(path),'wb') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE); out.writeframes(samples)

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    durations={'voice':.065,'dodge':.27,'woof':.48,'meow':.75,'bird':.56,'wood':.50,'fence':.38,'metal':.62,'brick':.43,'bush':.48,'car_bump':.35,'splash':.86,'clean':.8,'honk':.3,'chuff':.34,'whistle':1.18,'ringtone':3.,'engine':1.}
    for kind,duration in durations.items():
        for variant in range(1 if kind in ('ringtone','engine') else 3): bake(kind,variant,duration)
    print('Baked',len(list(OUT.glob('*.wav'))),'original sound clips')
