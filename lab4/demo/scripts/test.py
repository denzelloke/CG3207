#!/usr/bin/env python3
"""Compile and run actual RTL tests with Icarus; fail on missing PASS or any FAIL."""
import argparse, concurrent.futures, hashlib, json, os, re, subprocess
from pathlib import Path
from assemble import assemble
from sources import DEMO, LAB, CORE, SOC
from reference_game import replay

def run(command,cwd,log,timeout=240):
    p=subprocess.run(command,cwd=cwd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    log.write_text(p.stdout)
    if p.returncode or re.search(r'\b(?:FAIL|FATAL|ERROR)\b',p.stdout):
        raise RuntimeError(f'{log.name}:\n{p.stdout[-5000:]}')
    return p.stdout

def main():
    p=argparse.ArgumentParser();p.add_argument('--out',default=str(DEMO/'build'))
    p.add_argument('--iverilog',default=os.environ.get('IVERILOG','iverilog'))
    p.add_argument('--ivl-base',default=os.environ.get('IVL_BASE'))
    p.add_argument('--vvp',default=os.environ.get('VVP','vvp'))
    p.add_argument('--suite',choices=['all','units','game','controls','core','board'],default='all')
    p.add_argument('--jobs',type=int,default=2)
    p.add_argument('--updates',type=int,default=120)
    p.add_argument('--modes',default='8,9,10,11,12,13,14,15',help='Replay mode switch values; bit3 must be set')
    a=p.parse_args();build=Path(a.out).resolve();assemble(build)
    provenance={'firmware':json.loads((build/'firmware.json').read_text()),
                'suite':a.suite,'replay_updates':a.updates,
                'rtl_sha256':{str(f.relative_to(LAB)):hashlib.sha256(f.read_bytes()).hexdigest()
                              for f in CORE+sorted((DEMO/'rtl').glob('*.v'))}}
    (build/'test_results.json').write_text(json.dumps(dict(status='RUNNING',**provenance),indent=2)+'\n')
    cc=[a.iverilog]+(['-B',a.ivl_base] if a.ivl_base else [])+['-g2012']
    tests=[]
    def add(top,sources,variants=[[]],legacy=False):
        path=(LAB/'Testbenches' if legacy else DEMO/'tests')/(top+'.v')
        output=build/(top+'.vvp')
        parameters=[f'-Ptest_game.UPDATE_LIMIT={a.updates}'] if top=='test_game' else []
        if top=='test_board':parameters+=['-DSIMULATION']
        run(cc+parameters+['-s',top,'-o',str(output)]+list(map(str,sources))+[str(path)],build,build/(top+'_compile.log'))
        for extra in variants:tests.append((top,output,extra))
    if a.suite in ('all','units'):
        add('test_peripherals',[DEMO/'rtl'/f for f in ['PerformanceCounters.v','DisplayRegisters.v','GameInputs.v']]+[LAB/'ButtonDebouncer.v'])
        add('test_video',[DEMO/'rtl'/f for f in ['VgaTiming.v','GameRenderer.v','Font5x7.v']],[['+DUMP']])
    if a.suite in ('all','core'):
        for top in ['test_Timer','test_InterruptController','test_IRQHandler','test_RV_Interrupt']:
            add(top,CORE,legacy=True)
        # This bench installs its own program after time zero. Supply harmless
        # isolated initial images instead of touching the user's selected ROM.
        legacy_dir=build/'legacy';legacy_dir.mkdir(exist_ok=True)
        (legacy_dir/'AA_IROM.mem').write_text('00000013\n'*8192)
        (legacy_dir/'AA_DMEM.mem').write_text('00000000\n'*128)
        add('test_Wrapper_TimerIRQ',CORE+[LAB/'old/Wrapper.v'],legacy=True)
    if a.suite in ('all','game'):
        modes=[int(m,0) for m in a.modes.split(',')]
        if any(not m&8 for m in modes):raise SystemExit('Replay tests require switch bit3=1')
        add('test_game',SOC,[[f'+MODE={mode}'] for mode in modes])
    if a.suite in ('all','controls'):add('test_game_controls',SOC,[['+MODE=0'],['+MODE=7']])
    if a.suite=='board':
        add('test_board',SOC+[DEMO/'rtl'/f for f in ['VgaTiming.v','Font5x7.v','GameRenderer.v','NeonTop.v']])
    def simulate(item):
        top,output,extra=item;name=top+('_'+'_'.join(x.lstrip('+').replace('=','') for x in extra) if extra else '')
        cwd=build/'legacy' if top=='test_Wrapper_TimerIRQ' else build
        result=run([a.vvp,'-i',str(output)]+extra,cwd,build/(name+'.log'),timeout=max(240,a.updates*3))
        if 'PASS' not in result:raise RuntimeError(f'{name}: no explicit PASS')
        lines=[line for line in result.splitlines() if 'PASS' in line]
        print(name+': '+lines[-1],flush=True)
        return name,result
    with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool:
        results=dict(pool.map(simulate,tests))
    games=[re.search(r'GAME PASS mode=(\d+) checksum=([0-9a-fA-F]+).*cycles=(\d+) retired=(\d+) branches=(\d+) misses=(\d+) irq=(\d+)',s) for n,s in results.items() if n.startswith('test_game_MODE')]
    summary=dict(status='PASS',**provenance)
    if games:
        assert all(games),'Missing game metrics'
        for g in games:
            expected=replay(a.updates,(int(g[1])>>4)&3)['checksum']
            assert g[2].lower()==expected,f'Mode {g[1]} differs from gameplay reference: {g[2]} != {expected}'
        summary['replay']=[dict(zip(['mode','checksum','cycles','retired','branches','misses','irq'],g.groups())) for g in games]
        print('REPLAY REFERENCE PASS: every tested mode matches its independent gameplay reference')
    summary['passed']=list(results)
    (build/'test_results.json').write_text(json.dumps(summary,indent=2)+'\n')
if __name__=='__main__':main()
