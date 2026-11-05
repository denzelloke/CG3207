"""Assemble and collect the complete game source set for manual Vivado setup."""
import hashlib
import json
import shutil
from assemble import assemble
from sources import DEMO, LAB, SOC

def main():
    rom = assemble(DEMO / 'build')
    sources = SOC + [DEMO / 'rtl' / name for name in
                     ['VgaTiming.v', 'Font5x7.v', 'GameRenderer.v', 'NeonTop.v']]
    sources += [rom, DEMO / 'constraints/NeonTop.xdc']
    assert len(sources) == 30 and len({p.name for p in sources}) == 30
    out = DEMO / 'vivado_sources'
    out.mkdir(exist_ok=True)
    manifest = {}
    for source in sources:
        target = out / source.name
        shutil.copyfile(source, target)
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        assert hashlib.sha256(target.read_bytes()).hexdigest() == digest
        manifest[target.name] = {'source': str(source.relative_to(LAB)), 'sha256': digest}
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (out / 'START_HERE.txt').write_text(
        'NEON SPACE DEFENDER - COMPLETE VIVADO SOURCE SET\n\n'
        'Target FPGA: xc7a100tcsg324-1 (Nexys4 DDR).\n'
        '1. Add all 28 .v files as Design Sources.\n'
        '2. Add game.mem as a Design Source / Memory Initialization File.\n'
        '3. Add NeonTop.xdc as the ONLY constraint file for the game.\n'
        '4. Set NeonTop as the synthesis top module.\n'
        '5. Do not define SIMULATION for synthesis.\n'
        '6. Run synthesis, implementation, and Generate Bitstream.\n\n'
        'No AA_IROM.mem, AA_DMEM.mem, old Wrapper or VHDL top is needed.\n'
        'Firmware initializes data RAM. The board input clock is 100 MHz;\n'
        'NeonTop generates the shared 25 MHz CPU/video clock.\n\n'
        'These are generated copies of the current repository sources.\n'
        'Edit the original files, then refresh this folder by running from\n'
        'the repository root: python lab4/demo/scripts/prepare_vivado.py\n'
        'If Vivado copied sources into its project, refresh those copies too.\n'
        'manifest.json records the original paths and SHA-256 identities.\n'
        'Project creation, synthesis and board programming are not performed\n'
        'by the preparation script.\n', encoding='utf-8')
    print(f'VIVADO SOURCES READY: {out} (28 Verilog + ROM + constraints)')

if __name__ == '__main__':
    main()
