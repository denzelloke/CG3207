"""Execute the actual firmware rate calculation in RARS against boundary cases.

Run: python lab4/demo/tests/test_hud_rates.py
This checks assembly behaviour, not pipeline RTL or VGA rendering.
"""
import subprocess
import tempfile
from pathlib import Path

DEMO = Path(__file__).resolve().parents[1]
source = (DEMO / 'software/game.asm').read_text()
block = source.split('    # Refresh rates after >=60 timer ticks', 1)[1]
block = '    # Refresh rates after >=60 timer ticks' + block.split('publish_rate_done:', 1)[0]
block += 'publish_rate_done:\n    ret\n'

# now, previous tick, current/previous misses, current/previous updates,
# previous displayed rates, expected displayed rates
cases = [
    (59, 0, 120, 0, 59, 0, 7, 8, 7, 8),
    (60, 0, 120, 0, 60, 0, 0, 0, 120, 60),
    (180, 60, 300, 120, 150, 60, 120, 60, 90, 45),
    (240, 180, 300, 300, 150, 150, 90, 45, 0, 0),
    (44, 0xfffffff0, 36, 0, 60, 0, 0, 0, 36, 60),
    (60, 0, 20, 0xfffffff0, 60, 0, 0, 0, 36, 60),
    (61, 0, 121, 0, 59, 0, 0, 0, 119, 58),
]
asm = ['.data', 'state: .space 256', 'mmio: .space 300',
       'success: .asciz "HUD RATES PASS\\n"', 'failure: .asciz "HUD RATES FAIL\\n"',
       '.text', 'la s0,state', 'la s1,mmio']
for now, prev, misses, old_misses, updates, old_updates, old_mr, old_ur, mr, ur in cases:
    initial = {24: updates, 112: misses, 120: prev, 124: old_misses,
               128: old_updates, 132: old_mr, 136: old_ur}
    for offset, value in initial.items():
        asm += [f'li t0,0x{value:08x}', f'sw t0,{offset}(s0)']
    asm += [f'li t0,0x{now:08x}', 'sw t0,264(s1)', 'jal ra,rate_test']
    expected = {24: updates, 112: misses, 132: mr, 136: ur}
    if ((now - prev) & 0xffffffff) >= 60:
        expected.update({120: now, 124: misses, 128: updates})
    else:
        expected.update({120: prev, 124: old_misses, 128: old_updates})
    for offset, value in expected.items():
        asm += [f'lw t0,{offset}(s0)', f'li t1,0x{value:08x}', 'bne t0,t1,fail']
asm += ['la a0,success', 'li a7,4', 'ecall', 'li a7,10', 'ecall',
        'fail:', 'la a0,failure', 'li a7,4', 'ecall', 'li a7,10', 'ecall',
        'rate_test:', block]
with tempfile.TemporaryDirectory(prefix='neon_hud_rates_') as tmp:
    test = Path(tmp) / 'rates.asm'
    test.write_text('\n'.join(asm) + '\n')
    result = subprocess.run(['java', '-Djava.awt.headless=true', '-jar',
                             str(DEMO.parents[1] / 'rars1_6.jar'),
                             'nc', 'ae1', 'se1', '100000', str(test)],
                            capture_output=True, text=True, timeout=60)
    if result.returncode or 'HUD RATES PASS' not in result.stdout or 'HUD RATES FAIL' in result.stdout:
        raise SystemExit(result.stdout + result.stderr)
print(f'HUD RATES PASS: {len(cases)} assembly cases; totals preserved')
