#!/usr/bin/env python3
"""Assemble game firmware into a dedicated build directory; never overwrite AA_IROM."""
import argparse, hashlib, json, subprocess
from pathlib import Path
DEMO=Path(__file__).resolve().parents[1]
ROOT=DEMO.parents[1]
def assemble(out):
    out=Path(out).resolve();out.mkdir(parents=True,exist_ok=True)
    image=out/'game.mem'
    subprocess.run(['java','-Djava.awt.headless=true',f'-Djava.util.prefs.userRoot={out / "java-prefs"}',
                    '-jar',str(ROOT/'rars1_6.jar'),'nc','a','ae1','dump','.text','HexText',str(image),
                    str(DEMO/'software/game.asm')],check=True,cwd=out)
    words=image.read_text().splitlines()
    if len(words)>4096:raise SystemExit(f'ROM overflow: {len(words)} words, max 4096')
    assert int(words[64],16)&127==0x6f,'Missing fixed IRQ vector jump at 00400100'
    image.write_text('\n'.join(words+['00000013']*(4096-len(words)))+'\n')
    meta={'instructions_including_padding':len(words),'text_bytes':len(words)*4,'rom_bytes':16384,
          'image_sha256':hashlib.sha256(image.read_bytes()).hexdigest(),
          'source_sha256':hashlib.sha256((DEMO/'software/game.asm').read_bytes()).hexdigest()}
    (out/'firmware.json').write_text(json.dumps(meta,indent=2)+'\n')
    print(json.dumps(meta,indent=2));return image
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',default=str(DEMO/'build'));a=p.parse_args();assemble(a.out)
