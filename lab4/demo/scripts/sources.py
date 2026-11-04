from pathlib import Path
DEMO=Path(__file__).resolve().parents[1]
LAB=DEMO.parent
CORE=[LAB/f for f in ['RV.v','HazardUnit.v','MCycle.v','BranchPredictor.v','Subword.v',
    'IRQHandler.v','InterruptController.v','Timer.v','ButtonDebouncer.v',
    'Pipline_Resgisters/DRegister.v','Pipline_Resgisters/ERegister.v',
    'Pipline_Resgisters/MRegister.v','Pipline_Resgisters/WRegister.v',
    'old/ALU.v','old/Decoder.v','old/Extend.v','old/PC_Logic.v','old/ProgramCounter.v',
    'old/RegFile.v','old/Shifter.v']]
SOC=CORE+[DEMO/'rtl'/f for f in ['PerformanceCounters.v','GameInputs.v','DisplayRegisters.v','GameSoC.v']]
