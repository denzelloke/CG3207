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
    player=308;score=0;health=3;wave=1;cooldown=0;grace=0;shooter=0
    fire_period=90-16*difficulty;fire_count=fire_period
    def enemies():
        return [Object(64+i*80,144+(i%2)*32,1+(difficulty>>1),
                       (2+difficulty)*(-1 if i%2 else 1))
                if i<4+difficulty else Object() for i in range(7)]
    fleet=enemies();bullets=[Object() for _ in range(4)]
    hostile=[Object() for _ in range(4)]
    for tick in range(updates):
        if health==0:continue
        grace=max(0,grace-1)
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
        if tick%4==0:
            for i,e in enumerate(fleet):
                if not e.active:continue
                phase=tick+i*8
                if phase%64==0:
                    e.dx=-e.dx;e.y+=4+difficulty
                e.y+=-1 if phase&32 else 1
                e.x+=e.dx
                if e.x<16 or e.x>600:
                    e.x-=e.dx;e.dx=-e.dx;e.y+=16+min(wave,12)
                if e.y>=420:
                    e.active=0;health=max(0,health-1)
        for b in hostile:
            if not b.active:continue
            x=b.x+b.dx;y=b.y+3+difficulty
            if x<16 or x>620 or y>=460:
                b.active=0;continue
            b.x=x;b.y=y
            if x<player+24 and player<x+4 and y<456 and 440<y+10:
                b.active=0
                if not grace and health:
                    health-=1;grace=45
        if health:
            fire_count-=1
            if fire_count<=0:
                fire_count=fire_period
                free=next((b for b in hostile if not b.active),None)
                if free is not None:
                    for _ in range(7):
                        e=fleet[shooter];shooter=(shooter+1)%7
                        if e.active:
                            free.x=e.x+10;free.y=e.y+16;free.active=1
                            free.dx=((player+10>free.x)-(player+10<free.x)) if difficulty else 0
                            break
        if not any(e.active for e in fleet) and health:
            wave+=1;fleet=enemies()
            hostile=[Object() for _ in range(4)];fire_count=fire_period;shooter=0
    def mix(h,w):return (((h<<5)|(h>>27))&0xffffffff)^w
    checksum=0x4e454f4e
    for w in [score,health,wave,player]:checksum=mix(checksum,w)
    checksum^=updates;checksum^=cooldown
    for w in [fire_count,shooter,grace]:checksum=mix(checksum,w)
    for o in fleet+bullets+hostile:
        for w in o.words():checksum=mix(checksum,w)
    return dict(updates=updates,difficulty=difficulty,score=score,health=health,wave=wave,
                player=player,checksum=f'{checksum:08x}')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--updates',type=int,default=600);p.add_argument('--difficulty',type=int,default=0)
    a=p.parse_args();print(json.dumps(replay(a.updates,a.difficulty),indent=2))
