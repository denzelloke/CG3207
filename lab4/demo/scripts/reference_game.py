#!/usr/bin/env python3
"""Independent gameplay specification for deterministic replay (no CPU model)."""
import argparse, json
from dataclasses import dataclass
@dataclass
class Object:
    x:int=0
    y:int=0
    active:int=0
    dx:int=0
    def words(self):return [self.x | (self.y<<16), self.active | ((self.dx&255)<<8)]
def replay(updates=600,difficulty=0):
    player=308;score=0;health=3;wave=1;cooldown=0
    def enemies():return [Object(96+i*128,144,1+(difficulty>>1),2+difficulty) for i in range(4)]
    fleet=enemies();bullets=[Object() for _ in range(4)]
    for tick in range(updates):
        if health==0:continue
        player=max(16,min(600,player+(5 if (tick//64)%2==0 else -5)))
        if cooldown:cooldown-=1
        else:
            for b in bullets:
                if not b.active:
                    b.x=player+10;b.y=430;b.active=1;cooldown=6;break
        for b in bullets:
            if not b.active:continue
            b.y-=8
            if b.y<128:
                # Firmware suppresses the final y write when deactivating.
                b.y+=8;b.active=0;continue
            for e in fleet:
                if e.active and b.x<e.x+24 and e.x<b.x+4 and b.y<e.y+16 and e.y<b.y+10:
                    e.active-=1;b.active=0
                    if not e.active:score+=10
                    break
        if tick%8==0:
            for e in fleet:
                if not e.active:continue
                e.x+=e.dx
                if e.x<16 or e.x>600:
                    e.x-=e.dx;e.dx=-e.dx;e.y+=16+min(wave,12)
                if e.y>=420:
                    e.active=0;health=max(0,health-1)
        if not any(e.active for e in fleet) and health:
            wave+=1;fleet=enemies()
    def mix(h,w):return (((h<<5)|(h>>27))&0xffffffff)^w
    checksum=0x4e454f4e
    for w in [score,health,wave,player]:checksum=mix(checksum,w)
    checksum^=updates;checksum^=cooldown
    for o in fleet+bullets:
        for w in o.words():checksum=mix(checksum,w)
    return dict(updates=updates,difficulty=difficulty,score=score,health=health,wave=wave,
                player=player,checksum=f'{checksum:08x}')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--updates',type=int,default=600);p.add_argument('--difficulty',type=int,default=0)
    a=p.parse_args();print(json.dumps(replay(a.updates,a.difficulty),indent=2))
