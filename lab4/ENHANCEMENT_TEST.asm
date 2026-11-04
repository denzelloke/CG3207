# ENHANCEMENT_TEST.asm -- integrated, self-checking Lab 4 board regression
# Educational test derived in part from branch_predictor_selftest.asm and
# subword_test.asm in this repository. Assemble with RARS 1.6 in RV32 mode.
# Run on the actual Wrapper/RV; RARS execution does NOT model these peripherals.
#
# DISPLAY: 00000000 initially; decimal-digit completed-case count after each
# passed case; C001B33F only after ALL automatic AND manual tests pass.
# Failure: DEADdddd, where dddd is the decimal case ID. RAM+64 also contains
# DEAD0000 | binary case ID; RAM+68 = last passed ID; RAM+72 = active ID.
# A hard CPU hang leaves the last passed count displayed. It cannot self-report.
# No artificial per-case delay; quick cases may pass faster than your eye sees.
#
# MEMORY: instruction base 00400000; vector stub fixed at 00400100;
# main fixed at 00400200; RAM base 10010000; stack top 10010200.
# RAM 000..03f scratch, 040..04f results, 080..0bf ISR state,
# 0c0..0df stress scratch, 1e0..1ff ISR stack frame. DMEM_DEPTH_BITS=9 suffices.
# RAM is initialized by software; no accompanying .data image is required.
# ASSEMBLED SIZE (RARS 1.6): 4,990 instruction words = 19,960 bytes,
# including vector padding and expanded pseudoinstructions/macros.
# Set Wrapper.v IROM_DEPTH_BITS = 15 (32 KiB / 8,192 words).
# Depth 13 (8 KiB) and depth 14 (16 KiB) are BOTH too small.
# There are 234 numbered cases. Source line count is NOT instruction count.
# Last occupied text byte: 0x00404DF7; end-exclusive: 0x00404DF8.
#
# INPUTS: boot with ALL buttons released; do not press them during automatic
# tests. At the end, LEDs prompt center-button actions (seven-segment keeps
# showing completed cases): 01=PRESS AND HOLD center; 02=KEEP HOLDING;
# 04=RELEASE center; 08=PRESS AND HOLD again. FF=all tests passed.
# Each action has a 30-second CPU-cycle timeout at the configured CPU_HZ.
# Default CPU_HZ=6250000 matches current TOP divider=3 (100MHz / 16).
# If changing clock, change CPU_HZ AND BUTTON_TIMEOUT=30*CPU_HZ below.
# Hardware reset restarts the suite.
#
# COVERAGE: 1..95 existing CPU/branch/MCycle directed cases;
# 96..191 subword lane/sign/sentinel/misalignment cases;
# then exhaustive values, load/store dependency matrix, timer/control/IRQ,
# mixed branch/subword/MCycle IRQ stress, and physical button/combined sources.
# "Exhaustive" applies to finite byte/halfword value sweeps, NOT all CPU states.
# No performance counters/bypass exist yet. This checks prediction correctness,
# not accuracy, speedup, saturating-counter states or once-only internal training.
# Exact IRQ-on-launch/flush/reset edges, ACK+event same-cycle arbitration,
# debounce glitches, and every resume PC require the existing RTL testbenches.
# Very short timer periods may spend most cycles in the handler until its
# eight-service limit; longer periods exercise interleaved foreground work.
#
# VALIDATION (2026-11-04): RARS assembly succeeded. An independent temporary
# sequential RV32/MMIO sanity model completed all 234 cases, including modeled
# button actions, with monotonically increasing completed-case displays.
# This validates test-program logic against that model, NOT pipeline timing,
# debounce RTL, predictor correctness, synthesis, or physical FPGA behavior.
# This new suite has not yet been executed on the RTL or board.
#
# IMPORTANT RETURN ABI: RARS 1.6 supports uret, not mret or .word in .text.
# The CURRENT Decoder treats every SYSTEM opcode 0x73 as interrupt return.
# Thus uret (00200073) below invokes the CURRENT IRQHandler return mechanism.
# This is deliberately the existing custom hardware ABI, not privileged ISA
# compliance. If Decoder is tightened to exact MRET, use an assembler supporting
# mret (30200073) and change the single return instruction accordingly.
# There are no ECALL/EBREAK/CSR instructions and no OS dependencies.
#
# ISR saves every register it modifies (t0..t6, sp); ra/s-registers untouched.
# Main owns test counters. ISR only changes its state block and timer/IRQ MMIO.
# Timer tests assume reset/startup without externally pressed buttons.

.eqv CPU_HZ 6250000
.eqv BUTTON_TIMEOUT 187500000

.macro EXPECT (%actual, %expected)
    beq %actual, %expected, expected_ok
    j fail
expected_ok:
.end_macro
.macro PASS_CASE
    sw s9, 128(s8)
    lui s10, 0x10010
    sw s11, 68(s10)
.end_macro
.macro BEGIN_CASE (%id, %digits)
    li s11, %id
    li s9, %digits
    lui s10, 0x10010
    sw s11, 72(s10)
.end_macro

.text 0x00400000
.globl main
boot:
    j main

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

irq_vector:                    # exactly 0x00400100
    j irq_handler

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

main:                          # exactly 0x00400200
    lui s8, 0xffff0
    li sp, 0x10010200
    sw zero, 268(s8)             # mask IRQs
    sw zero, 260(s8)             # disable timer
    li t0, 3
    sw t0, 276(s8)               # clear old pending events
    sw zero, 128(s8)
    sw zero, 96(s8)
    lui s0, 0x10010
    mv t0, s0
    li t1, 128
init_ram:
    sw zero, 0(t0)
    addi t0, t0, 4
    addi t1, t1, -1
    bne t1, zero, init_ram

# ----------------------------------------------------------------------
# TEST 1: x0 remains zero
# ----------------------------------------------------------------------
test_01:
    BEGIN_CASE (1, 0x0001)
    addi zero, zero, 123
    li t6, 0
    beq zero, t6, check_continue_1
    j fail
check_continue_1:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 2: ADD and operand forwarding
# ----------------------------------------------------------------------
test_02:
    BEGIN_CASE (2, 0x0002)
    li t0, 123
    li t1, 456
    add t2, t0, t1
    li t6, 579
    beq t2, t6, check_continue_2
    j fail
check_continue_2:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 3: SUB gives a negative result
# ----------------------------------------------------------------------
test_03:
    BEGIN_CASE (3, 0x0003)
    li t0, 3
    li t1, 10
    sub t2, t0, t1
    li t6, -7
    beq t2, t6, check_continue_3
    j fail
check_continue_3:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 4: 32-bit addition wraps
# ----------------------------------------------------------------------
test_04:
    BEGIN_CASE (4, 0x0004)
    li t0, 0xffffffff
    addi t2, t0, 1
    li t6, 0
    beq t2, t6, check_continue_4
    j fail
check_continue_4:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 5: ADDI sign extension
# ----------------------------------------------------------------------
test_05:
    BEGIN_CASE (5, 0x0005)
    li t0, 10
    addi t2, t0, -17
    li t6, -7
    beq t2, t6, check_continue_5
    j fail
check_continue_5:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 6: AND
# ----------------------------------------------------------------------
test_06:
    BEGIN_CASE (6, 0x0006)
    li t0, 0x55aa55aa
    li t1, 0x0ff00ff0
    and t2, t0, t1
    li t6, 0x05a005a0
    beq t2, t6, check_continue_6
    j fail
check_continue_6:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 7: OR
# ----------------------------------------------------------------------
test_07:
    BEGIN_CASE (7, 0x0007)
    li t0, 0x55005500
    li t1, 0x00aa00aa
    or t2, t0, t1
    li t6, 0x55aa55aa
    beq t2, t6, check_continue_7
    j fail
check_continue_7:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 8: XOR
# ----------------------------------------------------------------------
test_08:
    BEGIN_CASE (8, 0x0008)
    li t0, 0x55aa55aa
    li t1, 0xffffffff
    xor t2, t0, t1
    li t6, 0xaa55aa55
    beq t2, t6, check_continue_8
    j fail
check_continue_8:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 9: SLL register shift
# ----------------------------------------------------------------------
test_09:
    BEGIN_CASE (9, 0x0009)
    li t0, 3
    li t1, 4
    sll t2, t0, t1
    li t6, 48
    beq t2, t6, check_continue_9
    j fail
check_continue_9:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 10: SRL zero fills
# ----------------------------------------------------------------------
test_10:
    BEGIN_CASE (10, 0x0010)
    li t0, 0x80000000
    li t1, 4
    srl t2, t0, t1
    li t6, 0x08000000
    beq t2, t6, check_continue_10
    j fail
check_continue_10:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 11: SRA sign fills
# ----------------------------------------------------------------------
test_11:
    BEGIN_CASE (11, 0x0011)
    li t0, 0x80000000
    li t1, 4
    sra t2, t0, t1
    li t6, 0xf8000000
    beq t2, t6, check_continue_11
    j fail
check_continue_11:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 12: SLT signed comparison
# ----------------------------------------------------------------------
test_12:
    BEGIN_CASE (12, 0x0012)
    li t0, -1
    li t1, 1
    slt t2, t0, t1
    li t6, 1
    beq t2, t6, check_continue_12
    j fail
check_continue_12:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 13: SLTU unsigned comparison
# ----------------------------------------------------------------------
test_13:
    BEGIN_CASE (13, 0x0013)
    li t0, -1
    li t1, 1
    sltu t2, t0, t1
    li t6, 0
    beq t2, t6, check_continue_13
    j fail
check_continue_13:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 14: SLTI signed immediate
# ----------------------------------------------------------------------
test_14:
    BEGIN_CASE (14, 0x0014)
    li t0, -3
    slti t2, t0, -2
    li t6, 1
    beq t2, t6, check_continue_14
    j fail
check_continue_14:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 15: SLTIU sign-extended immediate
# ----------------------------------------------------------------------
test_15:
    BEGIN_CASE (15, 0x0015)
    li t0, 1
    sltiu t2, t0, -1
    li t6, 1
    beq t2, t6, check_continue_15
    j fail
check_continue_15:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 16: Immediate shifts and logical immediates
# ----------------------------------------------------------------------
test_16:
    BEGIN_CASE (16, 0x0016)
    li t0, 0x80000000
    srai t1, t0, 28
    andi t1, t1, 15
    slli t1, t1, 4
    ori t1, t1, 3
    xori t1, t1, 1
    srli t2, t1, 1
    li t6, 65
    beq t2, t6, check_continue_16
    j fail
check_continue_16:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 17: LUI
# ----------------------------------------------------------------------
test_17:
    BEGIN_CASE (17, 0x0017)
    lui t2, 0x12345
    li t6, 0x12345000
    beq t2, t6, check_continue_17
    j fail
check_continue_17:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 18: AUIPC uses this instruction's PC
# ----------------------------------------------------------------------
test_18:
    BEGIN_CASE (18, 0x0018)
    auipc t0, 0
    auipc t1, 1
    sub t2, t1, t0
    li t6, 0x1004
    beq t2, t6, check_continue_18
    j fail
check_continue_18:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 19: Several consecutive ALU dependencies
# ----------------------------------------------------------------------
test_19:
    BEGIN_CASE (19, 0x0019)
    li t0, 7
    add t1, t0, t0
    add t2, t1, t0
    sub t2, t2, t1
    li t6, 7
    beq t2, t6, check_continue_19
    j fail
check_continue_19:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 20: Write-back to Decode operand forwarding
# ----------------------------------------------------------------------
test_20:
    BEGIN_CASE (20, 0x0020)
    addi t0, zero, 17
    addi t3, zero, 1
    addi t4, zero, 2
    add t2, t0, t0
    li t6, 34
    beq t2, t6, check_continue_20
    j fail
check_continue_20:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 21: SW / LW full word
# ----------------------------------------------------------------------
test_21:
    BEGIN_CASE (21, 0x0021)
    li t0, 0x89abcdef
    sw t0, 0(s0)
    lw t2, 0(s0)
    li t6, 0x89abcdef
    beq t2, t6, check_continue_21
    j fail
check_continue_21:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 22: LW immediately followed by dependent ADD
# ----------------------------------------------------------------------
test_22:
    BEGIN_CASE (22, 0x0022)
    li t0, 21
    sw t0, 0(s0)
    lw t1, 0(s0)
    add t2, t1, t1
    li t6, 42
    beq t2, t6, check_continue_22
    j fail
check_continue_22:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 23: LW immediately followed by SW of loaded data
# ----------------------------------------------------------------------
test_23:
    BEGIN_CASE (23, 0x0023)
    li t0, 0x13579bdf
    sw t0, 0(s0)
    lw t1, 0(s0)
    sw t1, 4(s0)
    lw t2, 4(s0)
    li t6, 0x13579bdf
    beq t2, t6, check_continue_23
    j fail
check_continue_23:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 24: LW supplies the following store address
# ----------------------------------------------------------------------
test_24:
    BEGIN_CASE (24, 0x0024)
    addi t0, s0, 16
    li t2, 0x2468ace0
    sw t0, 12(s0)
    lw t1, 12(s0)
    sw t2, 0(t1)
    lw t3, 16(s0)
    li t6, 0x2468ace0
    beq t3, t6, check_continue_24
    j fail
check_continue_24:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 25: LH lower half sign extension
# ----------------------------------------------------------------------
test_25:
    BEGIN_CASE (25, 0x0025)
    li t0, 0x7fff8001
    sw t0, 0(s0)
    lh t2, 0(s0)
    li t6, 0xffff8001
    beq t2, t6, check_continue_25
    j fail
check_continue_25:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 26: LHU lower half zero extension
# ----------------------------------------------------------------------
test_26:
    BEGIN_CASE (26, 0x0026)
    lhu t2, 0(s0)
    li t6, 0x8001
    beq t2, t6, check_continue_26
    j fail
check_continue_26:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 27: LH upper positive half
# ----------------------------------------------------------------------
test_27:
    BEGIN_CASE (27, 0x0027)
    lh t2, 2(s0)
    li t6, 0x7fff
    beq t2, t6, check_continue_27
    j fail
check_continue_27:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 28: LHU upper negative-bit half
# ----------------------------------------------------------------------
test_28:
    BEGIN_CASE (28, 0x0028)
    li t0, 0x80011234
    sw t0, 0(s0)
    lhu t2, 2(s0)
    li t6, 0x8001
    beq t2, t6, check_continue_28
    j fail
check_continue_28:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 29: LH upper negative half
# ----------------------------------------------------------------------
test_29:
    BEGIN_CASE (29, 0x0029)
    lh t2, 2(s0)
    li t6, 0xffff8001
    beq t2, t6, check_continue_29
    j fail
check_continue_29:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 30: SH lower half preserves upper half
# ----------------------------------------------------------------------
test_30:
    BEGIN_CASE (30, 0x0030)
    li t0, 0x11223344
    sw t0, 0(s0)
    li t1, 0xa1b2
    sh t1, 0(s0)
    lw t2, 0(s0)
    li t6, 0x1122a1b2
    beq t2, t6, check_continue_30
    j fail
check_continue_30:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 31: SH upper half preserves lower half
# ----------------------------------------------------------------------
test_31:
    BEGIN_CASE (31, 0x0031)
    li t1, 0xc3d4
    sh t1, 2(s0)
    lw t2, 0(s0)
    li t6, 0xc3d4a1b2
    beq t2, t6, check_continue_31
    j fail
check_continue_31:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 32: LH immediately followed by dependent ADD
# ----------------------------------------------------------------------
test_32:
    BEGIN_CASE (32, 0x0032)
    lh t1, 0(s0)
    addi t2, t1, 1
    li t6, 0xffffa1b3
    beq t2, t6, check_continue_32
    j fail
check_continue_32:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 33: LW-to-SH forwarding with upper-half mask
# ----------------------------------------------------------------------
test_33:
    BEGIN_CASE (33, 0x0033)
    li t0, 0x12345678
    sw t0, 0(s0)
    lw t1, 0(s0)
    sh t1, 2(s0)
    lw t2, 0(s0)
    li t6, 0x56785678
    beq t2, t6, check_continue_33
    j fail
check_continue_33:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 34: SB lane 1 preserves other bytes
# ----------------------------------------------------------------------
test_34:
    BEGIN_CASE (34, 0x0034)
    li t0, 0x11223344
    sw t0, 0(s0)
    li t1, 0xaa
    sb t1, 1(s0)
    lw t2, 0(s0)
    li t6, 0x1122aa44
    beq t2, t6, check_continue_34
    j fail
check_continue_34:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 35: SB lane 3 preserves other bytes
# ----------------------------------------------------------------------
test_35:
    BEGIN_CASE (35, 0x0035)
    li t1, 0xfe
    sb t1, 3(s0)
    lw t2, 0(s0)
    li t6, 0xfe22aa44
    beq t2, t6, check_continue_35
    j fail
check_continue_35:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 36: LB sign extends lane 3
# ----------------------------------------------------------------------
test_36:
    BEGIN_CASE (36, 0x0036)
    lb t2, 3(s0)
    li t6, -2
    beq t2, t6, check_continue_36
    j fail
check_continue_36:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 37: LBU zero extends lane 3
# ----------------------------------------------------------------------
test_37:
    BEGIN_CASE (37, 0x0037)
    lbu t2, 3(s0)
    li t6, 254
    beq t2, t6, check_continue_37
    j fail
check_continue_37:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 38: LB sign extends lane 1
# ----------------------------------------------------------------------
test_38:
    BEGIN_CASE (38, 0x0038)
    lb t2, 1(s0)
    li t6, -86
    beq t2, t6, check_continue_38
    j fail
check_continue_38:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 39: LBU zero extends lane 1
# ----------------------------------------------------------------------
test_39:
    BEGIN_CASE (39, 0x0039)
    lbu t2, 1(s0)
    li t6, 170
    beq t2, t6, check_continue_39
    j fail
check_continue_39:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 40: Negative load/store offsets
# ----------------------------------------------------------------------
test_40:
    BEGIN_CASE (40, 0x0040)
    addi t0, s0, 8
    li t1, 0x76543210
    sw t1, -4(t0)
    lw t2, -4(t0)
    li t6, 0x76543210
    beq t2, t6, check_continue_40
    j fail
check_continue_40:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 41: BEQ taken and not-taken outcomes
# ----------------------------------------------------------------------
test_41:
    BEGIN_CASE (41, 0x0041)
    li t0, 5
    li t1, 5
    beq t0, t1, branch_41_taken
    j fail
branch_41_taken:
    li t0, 5
    li t1, 6
    bne t0, t1, check_continue_41
    j fail
check_continue_41:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 42: BNE taken and not-taken outcomes
# ----------------------------------------------------------------------
test_42:
    BEGIN_CASE (42, 0x0042)
    li t0, 5
    li t1, 6
    bne t0, t1, branch_42_taken
    j fail
branch_42_taken:
    li t0, 5
    li t1, 5
    beq t0, t1, check_continue_42
    j fail
check_continue_42:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 43: BLT taken and not-taken outcomes
# ----------------------------------------------------------------------
test_43:
    BEGIN_CASE (43, 0x0043)
    li t0, -1
    li t1, 1
    blt t0, t1, branch_43_taken
    j fail
branch_43_taken:
    li t0, 1
    li t1, -1
    bge t0, t1, check_continue_43
    j fail
check_continue_43:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 44: BGE taken and not-taken outcomes
# ----------------------------------------------------------------------
test_44:
    BEGIN_CASE (44, 0x0044)
    li t0, 1
    li t1, -1
    bge t0, t1, branch_44_taken
    j fail
branch_44_taken:
    li t0, -1
    li t1, 1
    blt t0, t1, check_continue_44
    j fail
check_continue_44:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 45: BLTU taken and not-taken outcomes
# ----------------------------------------------------------------------
test_45:
    BEGIN_CASE (45, 0x0045)
    li t0, 1
    li t1, -1
    bltu t0, t1, branch_45_taken
    j fail
branch_45_taken:
    li t0, -1
    li t1, 1
    bgeu t0, t1, check_continue_45
    j fail
check_continue_45:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 46: BGEU taken and not-taken outcomes
# ----------------------------------------------------------------------
test_46:
    BEGIN_CASE (46, 0x0046)
    li t0, -1
    li t1, 1
    bgeu t0, t1, branch_46_taken
    j fail
branch_46_taken:
    li t0, 1
    li t1, -1
    bltu t0, t1, check_continue_46
    j fail
check_continue_46:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 47: Repeated taken loop then not-taken exit
# ----------------------------------------------------------------------
test_47:
    BEGIN_CASE (47, 0x0047)
    li s1, 16
    li s2, 0
train_taken:
    addi s2, s2, 1
    addi s1, s1, -1
    bne s1, zero, train_taken
    li t6, 16
    beq s2, t6, check_continue_47
    j fail
check_continue_47:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 48: Same branch repeatedly not taken, then taken
# ----------------------------------------------------------------------
test_48:
    BEGIN_CASE (48, 0x0048)
    li s1, 0
train_not_taken:
    addi s1, s1, 1
    slti t0, s1, 6
    beq t0, zero, train_not_taken_done
    j train_not_taken
train_not_taken_done:
    li t6, 6
    beq s1, t6, check_continue_48
    j fail
check_continue_48:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 49: Alternating branch outcomes
# ----------------------------------------------------------------------
test_49:
    BEGIN_CASE (49, 0x0049)
    li s1, 16
    li s2, 0
alternate_loop:
    andi t0, s1, 1
    beq t0, zero, alternate_even
    addi s2, s2, 1
alternate_even:
    addi s1, s1, -1
    bne s1, zero, alternate_loop
    li t6, 8
    beq s2, t6, check_continue_49
    j fail
check_continue_49:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 50: Taken branch squashes wrong-path store and register write
# ----------------------------------------------------------------------
test_50:
    BEGIN_CASE (50, 0x0050)
    sw zero, 20(s0)
    li s3, 0
    li t0, 1
    beq t0, t0, squash_done
    sw t0, 20(s0)
    addi s3, s3, 1
squash_done:
    lw t2, 20(s0)
    li t6, 0
    beq t2, t6, check_continue_50
    j fail
check_continue_50:
    li t6, 0
    beq s3, t6, check_continue_51
    j fail
check_continue_51:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 51: LW immediately supplies branch comparison
# ----------------------------------------------------------------------
test_51:
    BEGIN_CASE (51, 0x0051)
    li t0, 37
    sw t0, 0(s0)
    lw t1, 0(s0)
    beq t1, t0, load_branch_done
    j fail
load_branch_done:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 52: LH sign-extended value immediately supplies branch
# ----------------------------------------------------------------------
test_52:
    BEGIN_CASE (52, 0x0052)
    li t0, -2
    sh t0, 0(s0)
    lh t1, 0(s0)
    beq t1, t0, half_branch_done
    j fail
half_branch_done:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 53: JAL return address and JALR return
# ----------------------------------------------------------------------
test_53:
    BEGIN_CASE (53, 0x0053)
    jal ra, call_target
call_return:
    j call_done
call_target:
    la t0, call_return
    beq ra, t0, check_continue_52
    j fail
check_continue_52:
    li t2, 42
    jalr zero, 0(ra)
call_done:
    li t6, 42
    beq t2, t6, check_continue_53
    j fail
check_continue_53:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 54: JAL x0 squashes fall-through operations
# ----------------------------------------------------------------------
test_54:
    BEGIN_CASE (54, 0x0054)
    li s3, 0
    jal zero, jump_zero_done
    addi s3, s3, 1
    addi s3, s3, 1
jump_zero_done:
    li t6, 0
    beq s3, t6, check_continue_54
    j fail
check_continue_54:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 55: JALR clears target bit 0 and writes link
# ----------------------------------------------------------------------
test_55:
    BEGIN_CASE (55, 0x0055)
    la t0, odd_target
    ori t0, t0, 1
    jalr ra, 0(t0)
odd_return:
    j fail
odd_target:
    la t1, odd_return
    beq ra, t1, check_continue_55
    j fail
check_continue_55:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 56: Same JALR instruction alternates between two targets
# ----------------------------------------------------------------------
test_56:
    BEGIN_CASE (56, 0x0056)
    li s1, 0
    li s2, 0
    la t0, indirect_a
indirect_dispatch:
    jalr zero, 0(t0)
    j fail
indirect_a:
    addi s2, s2, 1
    la t0, indirect_b
    j indirect_check
indirect_b:
    addi s2, s2, 10
    la t0, indirect_a
indirect_check:
    addi s1, s1, 1
    slti t1, s1, 8
    bne t1, zero, indirect_dispatch
    li t6, 44
    beq s2, t6, check_continue_56
    j fail
check_continue_56:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 57: 32-entry BTB index collision: branch PCs differ by 128 bytes
# ----------------------------------------------------------------------
test_57:
    BEGIN_CASE (57, 0x0057)
    li s1, 4
    li s2, 0
    j alias_a
alias_a:
    beq zero, zero, alias_a_target
    j fail
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
    addi zero, zero, 0
alias_b:
    beq zero, zero, alias_b_target
    j fail
alias_a_target:
    addi s2, s2, 1
    j alias_b
alias_b_target:
    addi s2, s2, 10
    addi s1, s1, -1
    bne s1, zero, alias_a
    li t6, 44
    beq s2, t6, check_continue_57
    j fail
check_continue_57:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 58: MUL signed low word
# ----------------------------------------------------------------------
test_58:
    BEGIN_CASE (58, 0x0058)
    li t0, 7
    li t1, -9
    mul t2, t0, t1
    li t6, -63
    beq t2, t6, check_continue_58
    j fail
check_continue_58:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 59: MUL low-word overflow
# ----------------------------------------------------------------------
test_59:
    BEGIN_CASE (59, 0x0059)
    li t0, 0x80000000
    li t1, 2
    mul t2, t0, t1
    li t6, 0
    beq t2, t6, check_continue_59
    j fail
check_continue_59:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 60: MULH signed negative high word
# ----------------------------------------------------------------------
test_60:
    BEGIN_CASE (60, 0x0060)
    li t0, -2
    li t1, 3
    mulh t2, t0, t1
    li t6, 0xffffffff
    beq t2, t6, check_continue_60
    j fail
check_continue_60:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 61: MULH positive high word
# ----------------------------------------------------------------------
test_61:
    BEGIN_CASE (61, 0x0061)
    li t0, 0x40000000
    li t1, 4
    mulh t2, t0, t1
    li t6, 1
    beq t2, t6, check_continue_61
    j fail
check_continue_61:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 62: MULHU unsigned high word
# ----------------------------------------------------------------------
test_62:
    BEGIN_CASE (62, 0x0062)
    li t0, 0xffffffff
    li t1, 0xffffffff
    mulhu t2, t0, t1
    li t6, 0xfffffffe
    beq t2, t6, check_continue_62
    j fail
check_continue_62:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 63: MULHSU signed by unsigned high word
# ----------------------------------------------------------------------
test_63:
    BEGIN_CASE (63, 0x0063)
    li t0, -2
    li t1, 0xffffffff
    mulhsu t2, t0, t1
    li t6, 0xfffffffe
    beq t2, t6, check_continue_63
    j fail
check_continue_63:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 64: DIV truncates toward zero
# ----------------------------------------------------------------------
test_64:
    BEGIN_CASE (64, 0x0064)
    li t0, -20
    li t1, 3
    div t2, t0, t1
    li t6, -6
    beq t2, t6, check_continue_64
    j fail
check_continue_64:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 65: DIVU unsigned division
# ----------------------------------------------------------------------
test_65:
    BEGIN_CASE (65, 0x0065)
    li t0, 0xfffffff0
    li t1, 16
    divu t2, t0, t1
    li t6, 0x0fffffff
    beq t2, t6, check_continue_65
    j fail
check_continue_65:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 66: REM follows dividend sign
# ----------------------------------------------------------------------
test_66:
    BEGIN_CASE (66, 0x0066)
    li t0, -20
    li t1, 3
    rem t2, t0, t1
    li t6, -2
    beq t2, t6, check_continue_66
    j fail
check_continue_66:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 67: REMU unsigned remainder
# ----------------------------------------------------------------------
test_67:
    BEGIN_CASE (67, 0x0067)
    li t0, 29
    li t1, 6
    remu t2, t0, t1
    li t6, 5
    beq t2, t6, check_continue_67
    j fail
check_continue_67:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 68: DIV by zero
# ----------------------------------------------------------------------
test_68:
    BEGIN_CASE (68, 0x0068)
    li t0, 123
    li t1, 0
    div t2, t0, t1
    li t6, 0xffffffff
    beq t2, t6, check_continue_68
    j fail
check_continue_68:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 69: DIVU by zero
# ----------------------------------------------------------------------
test_69:
    BEGIN_CASE (69, 0x0069)
    li t0, 123
    li t1, 0
    divu t2, t0, t1
    li t6, 0xffffffff
    beq t2, t6, check_continue_69
    j fail
check_continue_69:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 70: REM by zero preserves dividend
# ----------------------------------------------------------------------
test_70:
    BEGIN_CASE (70, 0x0070)
    li t0, -123
    li t1, 0
    rem t2, t0, t1
    li t6, -123
    beq t2, t6, check_continue_70
    j fail
check_continue_70:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 71: REMU by zero preserves dividend
# ----------------------------------------------------------------------
test_71:
    BEGIN_CASE (71, 0x0071)
    li t0, 0xabcdef01
    li t1, 0
    remu t2, t0, t1
    li t6, 0xabcdef01
    beq t2, t6, check_continue_71
    j fail
check_continue_71:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 72: DIV signed overflow
# ----------------------------------------------------------------------
test_72:
    BEGIN_CASE (72, 0x0072)
    li t0, 0x80000000
    li t1, -1
    div t2, t0, t1
    li t6, 0x80000000
    beq t2, t6, check_continue_72
    j fail
check_continue_72:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 73: REM signed overflow
# ----------------------------------------------------------------------
test_73:
    BEGIN_CASE (73, 0x0073)
    li t0, 0x80000000
    li t1, -1
    rem t2, t0, t1
    li t6, 0
    beq t2, t6, check_continue_73
    j fail
check_continue_73:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 74: DIV negative divisor
# ----------------------------------------------------------------------
test_74:
    BEGIN_CASE (74, 0x0074)
    li t0, 20
    li t1, -3
    div t2, t0, t1
    li t6, -6
    beq t2, t6, check_continue_74
    j fail
check_continue_74:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 75: REM positive dividend with negative divisor
# ----------------------------------------------------------------------
test_75:
    BEGIN_CASE (75, 0x0075)
    li t0, 20
    li t1, -3
    rem t2, t0, t1
    li t6, 2
    beq t2, t6, check_continue_75
    j fail
check_continue_75:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 76: MUL immediately supplies branch operand
# ----------------------------------------------------------------------
test_76:
    BEGIN_CASE (76, 0x0076)
    li t0, 6
    li t1, 7
    li t3, 42
    mul t2, t0, t1
    beq t2, t3, mul_branch_done
    j fail
mul_branch_done:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 77: MUL result immediately stored
# ----------------------------------------------------------------------
test_77:
    BEGIN_CASE (77, 0x0077)
    li t0, 13
    li t1, 9
    mul t2, t0, t1
    sw t2, 24(s0)
    lw t3, 24(s0)
    li t6, 117
    beq t3, t6, check_continue_76
    j fail
check_continue_76:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 78: Back-to-back dependent MUL DIV REM and ADD
# ----------------------------------------------------------------------
test_78:
    BEGIN_CASE (78, 0x0078)
    li t0, 7
    li t1, 9
    li t5, 5
    mul t2, t0, t1
    div t3, t2, t0
    rem t4, t2, t5
    add t2, t3, t4
    li t6, 12
    beq t2, t6, check_continue_77
    j fail
check_continue_77:
    li t6, 9
    beq t3, t6, check_continue_78
    j fail
check_continue_78:
    li t6, 3
    beq t4, t6, check_continue_79
    j fail
check_continue_79:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 79: Mispredicted path must not launch a DIV
# ----------------------------------------------------------------------
test_79:
    BEGIN_CASE (79, 0x0079)
    li t0, 1
    li t1, 0
    li s3, 99
    beq t0, t0, squash_div_done
    div s3, t0, t1
    addi s3, zero, 0
squash_div_done:
    li t6, 99
    beq s3, t6, check_continue_80
    j fail
check_continue_80:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 80: Branch target is its own PC plus 4
# ----------------------------------------------------------------------
test_80:
    BEGIN_CASE (80, 0x0080)
    li t0, 5
    beq t0, t0, same_next
same_next:
    addi t2, t0, 1
    li t6, 6
    beq t2, t6, check_continue_81
    j fail
check_continue_81:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 81: Same conditional branch uses all four counter states
# ----------------------------------------------------------------------
test_81:
    BEGIN_CASE (81, 0x0081)
    li s1, 0
    li s2, 0
counter_sequence:
    # Outcomes: N N N N T T T T N N N N T T T T.
    andi t0, s1, 4
    bne t0, zero, counter_taken
    j counter_join
counter_taken:
    addi s2, s2, 1
counter_join:
    addi s1, s1, 1
    slti t1, s1, 16
    bne t1, zero, counter_sequence
    li t6, 8
    beq s2, t6, check_continue_82
    j fail
check_continue_82:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 82: Wrong predicted-taken path cannot commit a store on loop exit
# ----------------------------------------------------------------------
test_82:
    BEGIN_CASE (82, 0x0082)
    li s1, 8
    li s2, 0
    sw zero, 28(s0)
    j exit_branch
exit_target:
    addi s2, s2, 1
    sw s2, 28(s0)
exit_branch:
    addi s1, s1, -1
    bne s1, zero, exit_target
    lw t2, 28(s0)
    li t6, 7
    beq s2, t6, check_continue_83
    j fail
check_continue_83:
    li t6, 7
    beq t2, t6, check_continue_84
    j fail
check_continue_84:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 83: Zero destination load must not corrupt x0
# ----------------------------------------------------------------------
test_83:
    BEGIN_CASE (83, 0x0083)
    li t0, 0x89abcdef
    sw t0, 0(s0)
    lw zero, 0(s0)
    addi t2, zero, 9
    li t6, 9
    beq t2, t6, check_continue_85
    j fail
check_continue_85:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 84: Load immediately supplies JALR target
# ----------------------------------------------------------------------
test_84:
    BEGIN_CASE (84, 0x0084)
    la t0, load_jalr_target
    sw t0, 8(s0)
    lw t1, 8(s0)
    jalr ra, 0(t1)
load_jalr_return:
    j fail
load_jalr_target:
    la t2, load_jalr_return
    beq ra, t2, check_continue_86
    j fail
check_continue_86:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 85: Consecutive opposite branches
# ----------------------------------------------------------------------
test_85:
    BEGIN_CASE (85, 0x0085)
    li t0, 1
    bne t0, zero, check_continue_87
    j fail
check_continue_87:
    bne t0, zero, consecutive_target
    j fail
consecutive_target:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 86: SH truncates source to 16 bits and preserves the other half
# ----------------------------------------------------------------------
test_86:
    BEGIN_CASE (86, 0x0086)
    li t0, 0x11223344
    sw t0, 0(s0)
    li t1, 0xdeadbeef
    sh t1, 2(s0)
    lw t2, 0(s0)
    li t6, 0xbeef3344
    beq t2, t6, check_continue_88
    j fail
check_continue_88:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 87: Half-word boundaries zero 7fff 8000 ffff
# ----------------------------------------------------------------------
test_87:
    BEGIN_CASE (87, 0x0087)
    sw zero, 0(s0)
    lhu t2, 0(s0)
    li t6, 0
    beq t2, t6, check_continue_89
    j fail
check_continue_89:
    li t0, 0x7fff
    sh t0, 0(s0)
    lh t2, 0(s0)
    li t6, 0x7fff
    beq t2, t6, check_continue_90
    j fail
check_continue_90:
    li t0, 0x8000
    sh t0, 0(s0)
    lh t2, 0(s0)
    li t6, 0xffff8000
    beq t2, t6, check_continue_91
    j fail
check_continue_91:
    lhu t2, 0(s0)
    li t6, 0x8000
    beq t2, t6, check_continue_92
    j fail
check_continue_92:
    li t0, -1
    sh t0, 0(s0)
    lh t2, 0(s0)
    li t6, -1
    beq t2, t6, check_continue_93
    j fail
check_continue_93:
    lhu t2, 0(s0)
    li t6, 0xffff
    beq t2, t6, check_continue_94
    j fail
check_continue_94:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 88: SB lanes 0 and 2 preserve other bytes
# ----------------------------------------------------------------------
test_88:
    BEGIN_CASE (88, 0x0088)
    li t0, 0x11223344
    sw t0, 0(s0)
    li t1, 0x12345680
    sb t1, 0(s0)
    li t1, 0x7f
    sb t1, 2(s0)
    lw t2, 0(s0)
    li t6, 0x117f3380
    beq t2, t6, check_continue_95
    j fail
check_continue_95:
    lb t2, 0(s0)
    li t6, -128
    beq t2, t6, check_continue_96
    j fail
check_continue_96:
    lbu t2, 0(s0)
    li t6, 128
    beq t2, t6, check_continue_97
    j fail
check_continue_97:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 89: Register shift masks shift amount to five bits
# ----------------------------------------------------------------------
test_89:
    BEGIN_CASE (89, 0x0089)
    li t0, 1
    li t1, 32
    sll t2, t0, t1
    li t6, 1
    beq t2, t6, check_continue_98
    j fail
check_continue_98:
    li t1, 63
    sll t2, t0, t1
    li t6, 0x80000000
    beq t2, t6, check_continue_99
    j fail
check_continue_99:
    srl t2, t2, t1
    li t6, 1
    beq t2, t6, check_continue_100
    j fail
check_continue_100:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 90: Signed versus unsigned branch limits and equality
# ----------------------------------------------------------------------
test_90:
    BEGIN_CASE (90, 0x0090)
    li t0, 0x80000000
    li t1, 0x7fffffff
    blt t0, t1, check_continue_101
    j fail
check_continue_101:
    bgeu t0, t1, check_continue_102
    j fail
check_continue_102:
    bge t0, t0, check_continue_103
    j fail
check_continue_103:
    bgeu t1, t1, check_continue_104
    j fail
check_continue_104:
    bge t0, t0, signed_equal_ok
    j fail
signed_equal_ok:
    bgeu t1, t1, unsigned_equal_ok
    j fail
unsigned_equal_ok:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 91: Multiply zero and signed minimum boundaries
# ----------------------------------------------------------------------
test_91:
    BEGIN_CASE (91, 0x0091)
    li t0, 0x80000000
    li t1, -1
    mul t2, t0, zero
    li t6, 0
    beq t2, t6, check_continue_105
    j fail
check_continue_105:
    mul t2, t0, t1
    li t6, 0x80000000
    beq t2, t6, check_continue_106
    j fail
check_continue_106:
    mulh t2, t0, t1
    li t6, 0
    beq t2, t6, check_continue_107
    j fail
check_continue_107:
    mulhu t2, t0, t1
    li t6, 0x7fffffff
    beq t2, t6, check_continue_108
    j fail
check_continue_108:
    mulhsu t2, t0, t1
    li t6, 0x80000000
    beq t2, t6, check_continue_109
    j fail
check_continue_109:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 92: Divide zero dividend and dividend smaller than divisor
# ----------------------------------------------------------------------
test_92:
    BEGIN_CASE (92, 0x0092)
    li t0, 5
    div t2, zero, t0
    li t6, 0
    beq t2, t6, check_continue_110
    j fail
check_continue_110:
    rem t2, zero, t0
    li t6, 0
    beq t2, t6, check_continue_111
    j fail
check_continue_111:
    li t0, -2
    li t1, 7
    div t2, t0, t1
    li t6, 0
    beq t2, t6, check_continue_112
    j fail
check_continue_112:
    rem t2, t0, t1
    li t6, -2
    beq t2, t6, check_continue_113
    j fail
check_continue_113:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 93: MUL and DIV writing x0 do not break following instructions
# ----------------------------------------------------------------------
test_93:
    BEGIN_CASE (93, 0x0093)
    li t0, 9
    li t1, 3
    mul zero, t0, t1
    div zero, t0, t1
    add t2, t0, t1
    li t6, 12
    beq t2, t6, check_continue_114
    j fail
check_continue_114:
    li t6, 0
    beq zero, t6, check_continue_115
    j fail
check_continue_115:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 94: DIV result immediately feeds a branch, then store
# ----------------------------------------------------------------------
test_94:
    BEGIN_CASE (94, 0x0094)
    li t0, 99
    li t1, 9
    li t3, 11
    div t2, t0, t1
    beq t2, t3, check_continue_116
    j fail
check_continue_116:
    sw t2, 32(s0)
    lw t4, 32(s0)
    li t6, 11
    beq t4, t6, check_continue_117
    j fail
check_continue_117:

    PASS_CASE

# ----------------------------------------------------------------------
# TEST 95: Nested calls and returns preserve both link addresses
# ----------------------------------------------------------------------
test_95:
    BEGIN_CASE (95, 0x0095)
    li s3, 0
    jal ra, nested_outer
nested_main_return:
    j nested_done
nested_outer:
    mv s5, ra
    addi s3, s3, 1
    jal ra, nested_inner
nested_outer_return:
    addi s3, s3, 10
    mv ra, s5
    jalr zero, 0(ra)
nested_inner:
    addi s3, s3, 100
    jalr zero, 0(ra)
nested_done:
    li t6, 111
    beq s3, t6, check_continue_118
    j fail
check_continue_118:

    PASS_CASE

# Person 3 directed cases (original IDs 1..96 become 96..191).
    lui x20, 0x10010
    lui x31, 0xffff0

# TEST 96: lb byte 00 at lane 0
    BEGIN_CASE (96, 0x0096)
    lui x7, 0x5aa54
    addi x7, x7, -1024
    sw x7, 0(x20)
    lb x5, 0(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_1
    jal x0, fail
sub_ok_1:

    PASS_CASE

# TEST 97: lbu byte 00 at lane 0
    BEGIN_CASE (97, 0x0097)
    lbu x5, 0(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_2
    jal x0, fail
sub_ok_2:

    PASS_CASE

# TEST 98: lb byte 7f at lane 0
    BEGIN_CASE (98, 0x0098)
    lui x7, 0x5aa54
    addi x7, x7, -897
    sw x7, 0(x20)
    lb x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, sub_ok_3
    jal x0, fail
sub_ok_3:

    PASS_CASE

# TEST 99: lbu byte 7f at lane 0
    BEGIN_CASE (99, 0x0099)
    lbu x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, sub_ok_4
    jal x0, fail
sub_ok_4:

    PASS_CASE

# TEST 100: lb byte 80 at lane 0
    BEGIN_CASE (100, 0x0100)
    lui x7, 0x5aa54
    addi x7, x7, -896
    sw x7, 0(x20)
    lb x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, -128
    beq x5, x6, sub_ok_5
    jal x0, fail
sub_ok_5:

    PASS_CASE

# TEST 101: lbu byte 80 at lane 0
    BEGIN_CASE (101, 0x0101)
    lbu x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, sub_ok_6
    jal x0, fail
sub_ok_6:

    PASS_CASE

# TEST 102: lb byte ff at lane 0
    BEGIN_CASE (102, 0x0102)
    lui x7, 0x5aa54
    addi x7, x7, -769
    sw x7, 0(x20)
    lb x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, sub_ok_7
    jal x0, fail
sub_ok_7:

    PASS_CASE

# TEST 103: lbu byte ff at lane 0
    BEGIN_CASE (103, 0x0103)
    lbu x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, 255
    beq x5, x6, sub_ok_8
    jal x0, fail
sub_ok_8:

    PASS_CASE

# TEST 104: lb byte 00 at lane 1
    BEGIN_CASE (104, 0x0104)
    lui x7, 0x5aa50
    addi x7, x7, 195
    sw x7, 0(x20)
    lb x5, 1(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_9
    jal x0, fail
sub_ok_9:

    PASS_CASE

# TEST 105: lbu byte 00 at lane 1
    BEGIN_CASE (105, 0x0105)
    lbu x5, 1(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_10
    jal x0, fail
sub_ok_10:

    PASS_CASE

# TEST 106: lb byte 7f at lane 1
    BEGIN_CASE (106, 0x0106)
    lui x7, 0x5aa58
    addi x7, x7, -61
    sw x7, 0(x20)
    lb x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, sub_ok_11
    jal x0, fail
sub_ok_11:

    PASS_CASE

# TEST 107: lbu byte 7f at lane 1
    BEGIN_CASE (107, 0x0107)
    lbu x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, sub_ok_12
    jal x0, fail
sub_ok_12:

    PASS_CASE

# TEST 108: lb byte 80 at lane 1
    BEGIN_CASE (108, 0x0108)
    lui x7, 0x5aa58
    addi x7, x7, 195
    sw x7, 0(x20)
    lb x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, -128
    beq x5, x6, sub_ok_13
    jal x0, fail
sub_ok_13:

    PASS_CASE

# TEST 109: lbu byte 80 at lane 1
    BEGIN_CASE (109, 0x0109)
    lbu x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, sub_ok_14
    jal x0, fail
sub_ok_14:

    PASS_CASE

# TEST 110: lb byte ff at lane 1
    BEGIN_CASE (110, 0x0110)
    lui x7, 0x5aa60
    addi x7, x7, -61
    sw x7, 0(x20)
    lb x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, sub_ok_15
    jal x0, fail
sub_ok_15:

    PASS_CASE

# TEST 111: lbu byte ff at lane 1
    BEGIN_CASE (111, 0x0111)
    lbu x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, 255
    beq x5, x6, sub_ok_16
    jal x0, fail
sub_ok_16:

    PASS_CASE

# TEST 112: lb byte 00 at lane 2
    BEGIN_CASE (112, 0x0112)
    lui x7, 0x5a004
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 2(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_17
    jal x0, fail
sub_ok_17:

    PASS_CASE

# TEST 113: lbu byte 00 at lane 2
    BEGIN_CASE (113, 0x0113)
    lbu x5, 2(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_18
    jal x0, fail
sub_ok_18:

    PASS_CASE

# TEST 114: lb byte 7f at lane 2
    BEGIN_CASE (114, 0x0114)
    lui x7, 0x5a7f4
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, sub_ok_19
    jal x0, fail
sub_ok_19:

    PASS_CASE

# TEST 115: lbu byte 7f at lane 2
    BEGIN_CASE (115, 0x0115)
    lbu x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, sub_ok_20
    jal x0, fail
sub_ok_20:

    PASS_CASE

# TEST 116: lb byte 80 at lane 2
    BEGIN_CASE (116, 0x0116)
    lui x7, 0x5a804
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, -128
    beq x5, x6, sub_ok_21
    jal x0, fail
sub_ok_21:

    PASS_CASE

# TEST 117: lbu byte 80 at lane 2
    BEGIN_CASE (117, 0x0117)
    lbu x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, sub_ok_22
    jal x0, fail
sub_ok_22:

    PASS_CASE

# TEST 118: lb byte ff at lane 2
    BEGIN_CASE (118, 0x0118)
    lui x7, 0x5aff4
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, sub_ok_23
    jal x0, fail
sub_ok_23:

    PASS_CASE

# TEST 119: lbu byte ff at lane 2
    BEGIN_CASE (119, 0x0119)
    lbu x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, 255
    beq x5, x6, sub_ok_24
    jal x0, fail
sub_ok_24:

    PASS_CASE

# TEST 120: lb byte 00 at lane 3
    BEGIN_CASE (120, 0x0120)
    lui x7, 0xa54
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 3(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_25
    jal x0, fail
sub_ok_25:

    PASS_CASE

# TEST 121: lbu byte 00 at lane 3
    BEGIN_CASE (121, 0x0121)
    lbu x5, 3(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_26
    jal x0, fail
sub_ok_26:

    PASS_CASE

# TEST 122: lb byte 7f at lane 3
    BEGIN_CASE (122, 0x0122)
    lui x7, 0x7fa54
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, sub_ok_27
    jal x0, fail
sub_ok_27:

    PASS_CASE

# TEST 123: lbu byte 7f at lane 3
    BEGIN_CASE (123, 0x0123)
    lbu x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, sub_ok_28
    jal x0, fail
sub_ok_28:

    PASS_CASE

# TEST 124: lb byte 80 at lane 3
    BEGIN_CASE (124, 0x0124)
    lui x7, 0x80a54
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, -128
    beq x5, x6, sub_ok_29
    jal x0, fail
sub_ok_29:

    PASS_CASE

# TEST 125: lbu byte 80 at lane 3
    BEGIN_CASE (125, 0x0125)
    lbu x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, sub_ok_30
    jal x0, fail
sub_ok_30:

    PASS_CASE

# TEST 126: lb byte ff at lane 3
    BEGIN_CASE (126, 0x0126)
    lui x7, 0xffa54
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, sub_ok_31
    jal x0, fail
sub_ok_31:

    PASS_CASE

# TEST 127: lbu byte ff at lane 3
    BEGIN_CASE (127, 0x0127)
    lbu x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, 255
    beq x5, x6, sub_ok_32
    jal x0, fail
sub_ok_32:

    PASS_CASE

# TEST 128: lh halfword 0000 at offset 0
    BEGIN_CASE (128, 0x0128)
    lui x7, 0xa55a0
    sw x7, 0(x20)
    lh x5, 0(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_33
    jal x0, fail
sub_ok_33:

    PASS_CASE

# TEST 129: lhu halfword 0000 at offset 0
    BEGIN_CASE (129, 0x0129)
    lhu x5, 0(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_34
    jal x0, fail
sub_ok_34:

    PASS_CASE

# TEST 130: lh halfword 7fff at offset 0
    BEGIN_CASE (130, 0x0130)
    lui x7, 0xa55a8
    addi x7, x7, -1
    sw x7, 0(x20)
    lh x5, 0(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, sub_ok_35
    jal x0, fail
sub_ok_35:

    PASS_CASE

# TEST 131: lhu halfword 7fff at offset 0
    BEGIN_CASE (131, 0x0131)
    lhu x5, 0(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, sub_ok_36
    jal x0, fail
sub_ok_36:

    PASS_CASE

# TEST 132: lh halfword 8000 at offset 0
    BEGIN_CASE (132, 0x0132)
    lui x7, 0xa55a8
    sw x7, 0(x20)
    lh x5, 0(x20)
    lui x6, 0xffff8
    beq x5, x6, sub_ok_37
    jal x0, fail
sub_ok_37:

    PASS_CASE

# TEST 133: lhu halfword 8000 at offset 0
    BEGIN_CASE (133, 0x0133)
    lhu x5, 0(x20)
    lui x6, 0x8
    beq x5, x6, sub_ok_38
    jal x0, fail
sub_ok_38:

    PASS_CASE

# TEST 134: lh halfword ffff at offset 0
    BEGIN_CASE (134, 0x0134)
    lui x7, 0xa55b0
    addi x7, x7, -1
    sw x7, 0(x20)
    lh x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, sub_ok_39
    jal x0, fail
sub_ok_39:

    PASS_CASE

# TEST 135: lhu halfword ffff at offset 0
    BEGIN_CASE (135, 0x0135)
    lhu x5, 0(x20)
    lui x6, 0x10
    addi x6, x6, -1
    beq x5, x6, sub_ok_40
    jal x0, fail
sub_ok_40:

    PASS_CASE

# TEST 136: lh halfword 0000 at offset 1
    BEGIN_CASE (136, 0x0136)
    lui x7, 0xa5000
    addi x7, x7, 60
    sw x7, 0(x20)
    lh x5, 1(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_41
    jal x0, fail
sub_ok_41:

    PASS_CASE

# TEST 137: lhu halfword 0000 at offset 1
    BEGIN_CASE (137, 0x0137)
    lhu x5, 1(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_42
    jal x0, fail
sub_ok_42:

    PASS_CASE

# TEST 138: lh halfword 7fff at offset 1
    BEGIN_CASE (138, 0x0138)
    lui x7, 0xa5800
    addi x7, x7, -196
    sw x7, 0(x20)
    lh x5, 1(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, sub_ok_43
    jal x0, fail
sub_ok_43:

    PASS_CASE

# TEST 139: lhu halfword 7fff at offset 1
    BEGIN_CASE (139, 0x0139)
    lhu x5, 1(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, sub_ok_44
    jal x0, fail
sub_ok_44:

    PASS_CASE

# TEST 140: lh halfword 8000 at offset 1
    BEGIN_CASE (140, 0x0140)
    lui x7, 0xa5800
    addi x7, x7, 60
    sw x7, 0(x20)
    lh x5, 1(x20)
    lui x6, 0xffff8
    beq x5, x6, sub_ok_45
    jal x0, fail
sub_ok_45:

    PASS_CASE

# TEST 141: lhu halfword 8000 at offset 1
    BEGIN_CASE (141, 0x0141)
    lhu x5, 1(x20)
    lui x6, 0x8
    beq x5, x6, sub_ok_46
    jal x0, fail
sub_ok_46:

    PASS_CASE

# TEST 142: lh halfword ffff at offset 1
    BEGIN_CASE (142, 0x0142)
    lui x7, 0xa6000
    addi x7, x7, -196
    sw x7, 0(x20)
    lh x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, sub_ok_47
    jal x0, fail
sub_ok_47:

    PASS_CASE

# TEST 143: lhu halfword ffff at offset 1
    BEGIN_CASE (143, 0x0143)
    lhu x5, 1(x20)
    lui x6, 0x10
    addi x6, x6, -1
    beq x5, x6, sub_ok_48
    jal x0, fail
sub_ok_48:

    PASS_CASE

# TEST 144: lh halfword 0000 at offset 2
    BEGIN_CASE (144, 0x0144)
    lui x7, 0xc
    addi x7, x7, 828
    sw x7, 0(x20)
    lh x5, 2(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_49
    jal x0, fail
sub_ok_49:

    PASS_CASE

# TEST 145: lhu halfword 0000 at offset 2
    BEGIN_CASE (145, 0x0145)
    lhu x5, 2(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_50
    jal x0, fail
sub_ok_50:

    PASS_CASE

# TEST 146: lh halfword 7fff at offset 2
    BEGIN_CASE (146, 0x0146)
    lui x7, 0x7fffc
    addi x7, x7, 828
    sw x7, 0(x20)
    lh x5, 2(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, sub_ok_51
    jal x0, fail
sub_ok_51:

    PASS_CASE

# TEST 147: lhu halfword 7fff at offset 2
    BEGIN_CASE (147, 0x0147)
    lhu x5, 2(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, sub_ok_52
    jal x0, fail
sub_ok_52:

    PASS_CASE

# TEST 148: lh halfword 8000 at offset 2
    BEGIN_CASE (148, 0x0148)
    lui x7, 0x8000c
    addi x7, x7, 828
    sw x7, 0(x20)
    lh x5, 2(x20)
    lui x6, 0xffff8
    beq x5, x6, sub_ok_53
    jal x0, fail
sub_ok_53:

    PASS_CASE

# TEST 149: lhu halfword 8000 at offset 2
    BEGIN_CASE (149, 0x0149)
    lhu x5, 2(x20)
    lui x6, 0x8
    beq x5, x6, sub_ok_54
    jal x0, fail
sub_ok_54:

    PASS_CASE

# TEST 150: lh halfword ffff at offset 2
    BEGIN_CASE (150, 0x0150)
    lui x7, 0xffffc
    addi x7, x7, 828
    sw x7, 0(x20)
    lh x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, sub_ok_55
    jal x0, fail
sub_ok_55:

    PASS_CASE

# TEST 151: lhu halfword ffff at offset 2
    BEGIN_CASE (151, 0x0151)
    lhu x5, 2(x20)
    lui x6, 0x10
    addi x6, x6, -1
    beq x5, x6, sub_ok_56
    jal x0, fail
sub_ok_56:

    PASS_CASE

# TEST 152: sb 00 lane 0; preserve neighbours
    BEGIN_CASE (152, 0x0152)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sb x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55ac
    addi x6, x6, 768
    beq x5, x6, sub_ok_57
    jal x0, fail
sub_ok_57:

    PASS_CASE

# TEST 153: sb 7f lane 0; preserve neighbours
    BEGIN_CASE (153, 0x0153)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 127
    sb x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55ac
    addi x6, x6, 895
    beq x5, x6, sub_ok_58
    jal x0, fail
sub_ok_58:

    PASS_CASE

# TEST 154: sb 80 lane 0; preserve neighbours
    BEGIN_CASE (154, 0x0154)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sb x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55ac
    addi x6, x6, 896
    beq x5, x6, sub_ok_59
    jal x0, fail
sub_ok_59:

    PASS_CASE

# TEST 155: sb ff lane 0; preserve neighbours
    BEGIN_CASE (155, 0x0155)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 255
    sb x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55ac
    addi x6, x6, 1023
    beq x5, x6, sub_ok_60
    jal x0, fail
sub_ok_60:

    PASS_CASE

# TEST 156: sb 00 lane 1; preserve neighbours
    BEGIN_CASE (156, 0x0156)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sb x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a0
    addi x6, x6, 60
    beq x5, x6, sub_ok_61
    jal x0, fail
sub_ok_61:

    PASS_CASE

# TEST 157: sb 7f lane 1; preserve neighbours
    BEGIN_CASE (157, 0x0157)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 127
    sb x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a8
    addi x6, x6, -196
    beq x5, x6, sub_ok_62
    jal x0, fail
sub_ok_62:

    PASS_CASE

# TEST 158: sb 80 lane 1; preserve neighbours
    BEGIN_CASE (158, 0x0158)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sb x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a8
    addi x6, x6, 60
    beq x5, x6, sub_ok_63
    jal x0, fail
sub_ok_63:

    PASS_CASE

# TEST 159: sb ff lane 1; preserve neighbours
    BEGIN_CASE (159, 0x0159)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 255
    sb x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa55b0
    addi x6, x6, -196
    beq x5, x6, sub_ok_64
    jal x0, fail
sub_ok_64:

    PASS_CASE

# TEST 160: sb 00 lane 2; preserve neighbours
    BEGIN_CASE (160, 0x0160)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sb x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xa500c
    addi x6, x6, 828
    beq x5, x6, sub_ok_65
    jal x0, fail
sub_ok_65:

    PASS_CASE

# TEST 161: sb 7f lane 2; preserve neighbours
    BEGIN_CASE (161, 0x0161)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 127
    sb x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xa57fc
    addi x6, x6, 828
    beq x5, x6, sub_ok_66
    jal x0, fail
sub_ok_66:

    PASS_CASE

# TEST 162: sb 80 lane 2; preserve neighbours
    BEGIN_CASE (162, 0x0162)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sb x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xa580c
    addi x6, x6, 828
    beq x5, x6, sub_ok_67
    jal x0, fail
sub_ok_67:

    PASS_CASE

# TEST 163: sb ff lane 2; preserve neighbours
    BEGIN_CASE (163, 0x0163)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 255
    sb x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xa5ffc
    addi x6, x6, 828
    beq x5, x6, sub_ok_68
    jal x0, fail
sub_ok_68:

    PASS_CASE

# TEST 164: sb 00 lane 3; preserve neighbours
    BEGIN_CASE (164, 0x0164)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sb x7, 3(x20)
    lw x5, 0(x20)
    lui x6, 0x5ac
    addi x6, x6, 828
    beq x5, x6, sub_ok_69
    jal x0, fail
sub_ok_69:

    PASS_CASE

# TEST 165: sb 7f lane 3; preserve neighbours
    BEGIN_CASE (165, 0x0165)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 127
    sb x7, 3(x20)
    lw x5, 0(x20)
    lui x6, 0x7f5ac
    addi x6, x6, 828
    beq x5, x6, sub_ok_70
    jal x0, fail
sub_ok_70:

    PASS_CASE

# TEST 166: sb 80 lane 3; preserve neighbours
    BEGIN_CASE (166, 0x0166)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sb x7, 3(x20)
    lw x5, 0(x20)
    lui x6, 0x805ac
    addi x6, x6, 828
    beq x5, x6, sub_ok_71
    jal x0, fail
sub_ok_71:

    PASS_CASE

# TEST 167: sb ff lane 3; preserve neighbours
    BEGIN_CASE (167, 0x0167)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 255
    sb x7, 3(x20)
    lw x5, 0(x20)
    lui x6, 0xff5ac
    addi x6, x6, 828
    beq x5, x6, sub_ok_72
    jal x0, fail
sub_ok_72:

    PASS_CASE

# TEST 168: sh 0000 offset 0; preserve neighbours
    BEGIN_CASE (168, 0x0168)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sh x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a0
    beq x5, x6, sub_ok_73
    jal x0, fail
sub_ok_73:

    PASS_CASE

# TEST 169: sh 7fff offset 0; preserve neighbours
    BEGIN_CASE (169, 0x0169)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    addi x7, x7, -1
    sh x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a8
    addi x6, x6, -1
    beq x5, x6, sub_ok_74
    jal x0, fail
sub_ok_74:

    PASS_CASE

# TEST 170: sh 8000 offset 0; preserve neighbours
    BEGIN_CASE (170, 0x0170)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    sh x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a8
    beq x5, x6, sub_ok_75
    jal x0, fail
sub_ok_75:

    PASS_CASE

# TEST 171: sh ffff offset 0; preserve neighbours
    BEGIN_CASE (171, 0x0171)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x10
    addi x7, x7, -1
    sh x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55b0
    addi x6, x6, -1
    beq x5, x6, sub_ok_76
    jal x0, fail
sub_ok_76:

    PASS_CASE

# TEST 172: sh 0000 offset 1; preserve neighbours
    BEGIN_CASE (172, 0x0172)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sh x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa5000
    addi x6, x6, 60
    beq x5, x6, sub_ok_77
    jal x0, fail
sub_ok_77:

    PASS_CASE

# TEST 173: sh 7fff offset 1; preserve neighbours
    BEGIN_CASE (173, 0x0173)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    addi x7, x7, -1
    sh x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa5800
    addi x6, x6, -196
    beq x5, x6, sub_ok_78
    jal x0, fail
sub_ok_78:

    PASS_CASE

# TEST 174: sh 8000 offset 1; preserve neighbours
    BEGIN_CASE (174, 0x0174)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    sh x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa5800
    addi x6, x6, 60
    beq x5, x6, sub_ok_79
    jal x0, fail
sub_ok_79:

    PASS_CASE

# TEST 175: sh ffff offset 1; preserve neighbours
    BEGIN_CASE (175, 0x0175)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x10
    addi x7, x7, -1
    sh x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa6000
    addi x6, x6, -196
    beq x5, x6, sub_ok_80
    jal x0, fail
sub_ok_80:

    PASS_CASE

# TEST 176: sh 0000 offset 2; preserve neighbours
    BEGIN_CASE (176, 0x0176)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sh x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xc
    addi x6, x6, 828
    beq x5, x6, sub_ok_81
    jal x0, fail
sub_ok_81:

    PASS_CASE

# TEST 177: sh 7fff offset 2; preserve neighbours
    BEGIN_CASE (177, 0x0177)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    addi x7, x7, -1
    sh x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0x7fffc
    addi x6, x6, 828
    beq x5, x6, sub_ok_82
    jal x0, fail
sub_ok_82:

    PASS_CASE

# TEST 178: sh 8000 offset 2; preserve neighbours
    BEGIN_CASE (178, 0x0178)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    sh x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0x8000c
    addi x6, x6, 828
    beq x5, x6, sub_ok_83
    jal x0, fail
sub_ok_83:

    PASS_CASE

# TEST 179: sh ffff offset 2; preserve neighbours
    BEGIN_CASE (179, 0x0179)
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x10
    addi x7, x7, -1
    sh x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xffffc
    addi x6, x6, 828
    beq x5, x6, sub_ok_84
    jal x0, fail
sub_ok_84:

    PASS_CASE

# TEST 180: sw/lw regression
    BEGIN_CASE (180, 0x0180)
    lui x7, 0x87654
    addi x7, x7, 801
    sw x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0x87654
    addi x6, x6, 801
    beq x5, x6, sub_ok_85
    jal x0, fail
sub_ok_85:

    PASS_CASE

# TEST 181: lh at crossing offset 3 returns zero
    BEGIN_CASE (181, 0x0181)
    lh x5, 3(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_86
    jal x0, fail
sub_ok_86:

    PASS_CASE

# TEST 182: lhu at crossing offset 3 returns zero
    BEGIN_CASE (182, 0x0182)
    lhu x5, 3(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_87
    jal x0, fail
sub_ok_87:

    PASS_CASE

# TEST 183: sh at crossing offset 3 leaves first word
    BEGIN_CASE (183, 0x0183)
    lui x7, 0x8
    addi x7, x7, -1
    sh x7, 3(x20)
    lw x5, 0(x20)
    lui x6, 0x87654
    addi x6, x6, 801
    beq x5, x6, sub_ok_88
    jal x0, fail
sub_ok_88:

    PASS_CASE

# TEST 184: sh at crossing offset 3 leaves next word
    BEGIN_CASE (184, 0x0184)
    lui x7, 0x12345
    addi x7, x7, 1656
    sw x7, 4(x20)
    sh x7, 3(x20)
    lw x5, 4(x20)
    lui x6, 0x12345
    addi x6, x6, 1656
    beq x5, x6, sub_ok_89
    jal x0, fail
sub_ok_89:

    PASS_CASE

# TEST 185: misaligned lw returns zero
    BEGIN_CASE (185, 0x0185)
    lw x5, 1(x20)
    lui x6, 0x0
    beq x5, x6, sub_ok_90
    jal x0, fail
sub_ok_90:

    PASS_CASE

# TEST 186: misaligned sw suppressed
    BEGIN_CASE (186, 0x0186)
    lui x7, 0x0
    addi x7, x7, 99
    sw x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0x87654
    addi x6, x6, 801
    beq x5, x6, sub_ok_91
    jal x0, fail
sub_ok_91:

    PASS_CASE

# TEST 187: lb immediate ALU use
    BEGIN_CASE (187, 0x0187)
    lui x7, 0x800
    sw x7, 0(x20)
    lb x8, 2(x20)
    addi x5, x8, 1
    lui x6, 0x0
    addi x6, x6, -127
    beq x5, x6, sub_ok_92
    jal x0, fail
sub_ok_92:

    PASS_CASE

# TEST 188: adjacent lb to sb forwarding
    BEGIN_CASE (188, 0x0188)
    sw x0, 8(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sw x7, 0(x20)
    lb x8, 0(x20)
    sb x8, 8(x20)
    lw x5, 8(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, sub_ok_93
    jal x0, fail
sub_ok_93:

    PASS_CASE

# TEST 189: adjacent lbu to sh forwarding
    BEGIN_CASE (189, 0x0189)
    sw x0, 8(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sw x7, 0(x20)
    lbu x8, 0(x20)
    sh x8, 8(x20)
    lw x5, 8(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, sub_ok_94
    jal x0, fail
sub_ok_94:

    PASS_CASE

# TEST 190: adjacent lh to sw forwarding
    BEGIN_CASE (190, 0x0190)
    lui x7, 0x8
    sw x7, 0(x20)
    lh x8, 0(x20)
    sw x8, 8(x20)
    lw x5, 8(x20)
    lui x6, 0xffff8
    beq x5, x6, sub_ok_95
    jal x0, fail
sub_ok_95:

    PASS_CASE

# TEST 191: adjacent lhu to sw forwarding
    BEGIN_CASE (191, 0x0191)
    lui x7, 0x8
    sw x7, 0(x20)
    lhu x8, 0(x20)
    sw x8, 8(x20)
    lw x5, 8(x20)
    lui x6, 0x8
    beq x5, x6, sub_ok_96
    jal x0, fail
sub_ok_96:

    PASS_CASE

# TEST 192: ALL 256 byte values at lane 0: SB preservation, LBU and LB
test_192:
    BEGIN_CASE (192, 0x0192)

    lui s0, 0x10010
    li s1, 0
    li s2, 256
byte_sweep_0:
    li t0, 0xa55ac33c
    sw t0, 0(s0)
    sb s1, 0(s0)
    lbu t1, 0(s0)
    EXPECT (t1, s1)
    lb t1, 0(s0)
    slli t2, s1, 24
    srai t2, t2, 24
    EXPECT (t1, t2)
    lw t1, 0(s0)
    slli t2, s1, 0
    li t3, 0xa55ac300
    or t2, t2, t3
    EXPECT (t1, t2)
    addi s1, s1, 1
    bne s1, s2, byte_sweep_0

    PASS_CASE

# TEST 193: ALL 256 byte values at lane 1: SB preservation, LBU and LB
test_193:
    BEGIN_CASE (193, 0x0193)

    lui s0, 0x10010
    li s1, 0
    li s2, 256
byte_sweep_1:
    li t0, 0xa55ac33c
    sw t0, 0(s0)
    sb s1, 1(s0)
    lbu t1, 1(s0)
    EXPECT (t1, s1)
    lb t1, 1(s0)
    slli t2, s1, 24
    srai t2, t2, 24
    EXPECT (t1, t2)
    lw t1, 0(s0)
    slli t2, s1, 8
    li t3, 0xa55a003c
    or t2, t2, t3
    EXPECT (t1, t2)
    addi s1, s1, 1
    bne s1, s2, byte_sweep_1

    PASS_CASE

# TEST 194: ALL 256 byte values at lane 2: SB preservation, LBU and LB
test_194:
    BEGIN_CASE (194, 0x0194)

    lui s0, 0x10010
    li s1, 0
    li s2, 256
byte_sweep_2:
    li t0, 0xa55ac33c
    sw t0, 0(s0)
    sb s1, 2(s0)
    lbu t1, 2(s0)
    EXPECT (t1, s1)
    lb t1, 2(s0)
    slli t2, s1, 24
    srai t2, t2, 24
    EXPECT (t1, t2)
    lw t1, 0(s0)
    slli t2, s1, 16
    li t3, 0xa500c33c
    or t2, t2, t3
    EXPECT (t1, t2)
    addi s1, s1, 1
    bne s1, s2, byte_sweep_2

    PASS_CASE

# TEST 195: ALL 256 byte values at lane 3: SB preservation, LBU and LB
test_195:
    BEGIN_CASE (195, 0x0195)

    lui s0, 0x10010
    li s1, 0
    li s2, 256
byte_sweep_3:
    li t0, 0xa55ac33c
    sw t0, 0(s0)
    sb s1, 3(s0)
    lbu t1, 3(s0)
    EXPECT (t1, s1)
    lb t1, 3(s0)
    slli t2, s1, 24
    srai t2, t2, 24
    EXPECT (t1, t2)
    lw t1, 0(s0)
    slli t2, s1, 24
    li t3, 0x005ac33c
    or t2, t2, t3
    EXPECT (t1, t2)
    addi s1, s1, 1
    bne s1, s2, byte_sweep_3

    PASS_CASE

# TEST 196: ALL 65536 halfword values at offset 0: SH preservation, LHU and LH
test_196:
    BEGIN_CASE (196, 0x0196)

    li s1, 0
    li s2, 65536
half_sweep_0:
    li t0, 0xa55ac33c
    sw t0, 0(s0)
    sh s1, 0(s0)
    lhu t1, 0(s0)
    EXPECT (t1, s1)
    lh t1, 0(s0)
    slli t2, s1, 16
    srai t2, t2, 16
    EXPECT (t1, t2)
    lw t1, 0(s0)
    slli t2, s1, 0
    li t3, 0xa55a0000
    or t2, t2, t3
    EXPECT (t1, t2)
    addi s1, s1, 1
    bne s1, s2, half_sweep_0

    PASS_CASE

# TEST 197: ALL 65536 halfword values at offset 1: SH preservation, LHU and LH
test_197:
    BEGIN_CASE (197, 0x0197)

    li s1, 0
    li s2, 65536
half_sweep_1:
    li t0, 0xa55ac33c
    sw t0, 0(s0)
    sh s1, 1(s0)
    lhu t1, 1(s0)
    EXPECT (t1, s1)
    lh t1, 1(s0)
    slli t2, s1, 16
    srai t2, t2, 16
    EXPECT (t1, t2)
    lw t1, 0(s0)
    slli t2, s1, 8
    li t3, 0xa500003c
    or t2, t2, t3
    EXPECT (t1, t2)
    addi s1, s1, 1
    bne s1, s2, half_sweep_1

    PASS_CASE

# TEST 198: ALL 65536 halfword values at offset 2: SH preservation, LHU and LH
test_198:
    BEGIN_CASE (198, 0x0198)

    li s1, 0
    li s2, 65536
half_sweep_2:
    li t0, 0xa55ac33c
    sw t0, 0(s0)
    sh s1, 2(s0)
    lhu t1, 2(s0)
    EXPECT (t1, s1)
    lh t1, 2(s0)
    slli t2, s1, 16
    srai t2, t2, 16
    EXPECT (t1, t2)
    lw t1, 0(s0)
    slli t2, s1, 16
    li t3, 0x0000c33c
    or t2, t2, t3
    EXPECT (t1, t2)
    addi s1, s1, 1
    bne s1, s2, half_sweep_2

    PASS_CASE

# TEST 199: Immediate LB to SB data forwarding and sentinel preservation
test_199:
    BEGIN_CASE (199, 0x0199)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lb t1, 0(s0)
    sb t1, 11(s0)
    lw t2, 8(s0)
    li t3, 0x805ac33c
    EXPECT (t2, t3)

    PASS_CASE

# TEST 200: Immediate LB to SH data forwarding and sentinel preservation
test_200:
    BEGIN_CASE (200, 0x0200)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lb t1, 0(s0)
    sh t1, 10(s0)
    lw t2, 8(s0)
    li t3, 0xff80c33c
    EXPECT (t2, t3)

    PASS_CASE

# TEST 201: Immediate LB to SW data forwarding and sentinel preservation
test_201:
    BEGIN_CASE (201, 0x0201)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lb t1, 0(s0)
    sw t1, 8(s0)
    lw t2, 8(s0)
    li t3, 0xffffff80
    EXPECT (t2, t3)

    PASS_CASE

# TEST 202: Immediate LBU to SB data forwarding and sentinel preservation
test_202:
    BEGIN_CASE (202, 0x0202)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lbu t1, 0(s0)
    sb t1, 11(s0)
    lw t2, 8(s0)
    li t3, 0x805ac33c
    EXPECT (t2, t3)

    PASS_CASE

# TEST 203: Immediate LBU to SH data forwarding and sentinel preservation
test_203:
    BEGIN_CASE (203, 0x0203)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lbu t1, 0(s0)
    sh t1, 10(s0)
    lw t2, 8(s0)
    li t3, 0x0080c33c
    EXPECT (t2, t3)

    PASS_CASE

# TEST 204: Immediate LBU to SW data forwarding and sentinel preservation
test_204:
    BEGIN_CASE (204, 0x0204)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lbu t1, 0(s0)
    sw t1, 8(s0)
    lw t2, 8(s0)
    li t3, 0x00000080
    EXPECT (t2, t3)

    PASS_CASE

# TEST 205: Immediate LH to SB data forwarding and sentinel preservation
test_205:
    BEGIN_CASE (205, 0x0205)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lh t1, 0(s0)
    sb t1, 11(s0)
    lw t2, 8(s0)
    li t3, 0x805ac33c
    EXPECT (t2, t3)

    PASS_CASE

# TEST 206: Immediate LH to SH data forwarding and sentinel preservation
test_206:
    BEGIN_CASE (206, 0x0206)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lh t1, 0(s0)
    sh t1, 10(s0)
    lw t2, 8(s0)
    li t3, 0x8080c33c
    EXPECT (t2, t3)

    PASS_CASE

# TEST 207: Immediate LH to SW data forwarding and sentinel preservation
test_207:
    BEGIN_CASE (207, 0x0207)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lh t1, 0(s0)
    sw t1, 8(s0)
    lw t2, 8(s0)
    li t3, 0xffff8080
    EXPECT (t2, t3)

    PASS_CASE

# TEST 208: Immediate LHU to SB data forwarding and sentinel preservation
test_208:
    BEGIN_CASE (208, 0x0208)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lhu t1, 0(s0)
    sb t1, 11(s0)
    lw t2, 8(s0)
    li t3, 0x805ac33c
    EXPECT (t2, t3)

    PASS_CASE

# TEST 209: Immediate LHU to SH data forwarding and sentinel preservation
test_209:
    BEGIN_CASE (209, 0x0209)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lhu t1, 0(s0)
    sh t1, 10(s0)
    lw t2, 8(s0)
    li t3, 0x8080c33c
    EXPECT (t2, t3)

    PASS_CASE

# TEST 210: Immediate LHU to SW data forwarding and sentinel preservation
test_210:
    BEGIN_CASE (210, 0x0210)

    li t0, 0x80808080
    sw t0, 0(s0)
    li t0, 0xa55ac33c
    sw t0, 8(s0)
    lhu t1, 0(s0)
    sw t1, 8(s0)
    lw t2, 8(s0)
    li t3, 0x00008080
    EXPECT (t2, t3)

    PASS_CASE

    li s0, 0x10010080
    jal ra, reset_irq_test

# TEST 211: Reset/initial quiescent controller and stack state
test_211:
    BEGIN_CASE (211, 0x0211)

    lw t0, 268(s8)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)
    li t0, 0x10010200
    EXPECT (sp, t0)
    lw t0, 0(s0)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 212: Timer period readback and ignored byte/halfword control writes
test_212:
    BEGIN_CASE (212, 0x0212)

    li t0, 1000
    sw t0, 256(s8)
    li t1, 99
    sb t1, 256(s8)
    sh t1, 256(s8)
    lw t2, 256(s8)
    EXPECT (t2, t0)
    li t1, 3
    sb t1, 268(s8)
    sh t1, 268(s8)
    lw t2, 268(s8)
    EXPECT (t2, zero)
    lw s1, 264(s8)
    sb t1, 260(s8)
    sh t1, 260(s8)
    jal ra, short_delay
    lw t2, 264(s8)
    EXPECT (t2, s1)

    PASS_CASE

# TEST 213: Enabled timer with period zero generates no ticks
test_213:
    BEGIN_CASE (213, 0x0213)

    sw zero, 256(s8)
    li t0, 1
    sw t0, 260(s8)
    lw s1, 264(s8)
    jal ra, short_delay
    lw t0, 264(s8)
    EXPECT (t0, s1)
    sw zero, 260(s8)

    PASS_CASE

# TEST 214: Masked periodic timer accumulates ticks and pending without handler entry
test_214:
    BEGIN_CASE (214, 0x0214)

    lw s1, 264(s8)
    li t0, 64
    sw t0, 256(s8)
    li t0, 1
    sw t0, 260(s8)
    jal ra, short_delay
    sw zero, 260(s8)
    nop
    nop
    lw t0, 264(s8)
    sub t0, t0, s1
    sltiu t1, t0, 2
    EXPECT (t1, zero)
    lw t0, 272(s8)
    li t1, 1
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 215: ACK zero, wrong source and subword writes preserve pending
test_215:
    BEGIN_CASE (215, 0x0215)

    sw zero, 276(s8)
    li t0, 2
    sw t0, 276(s8)
    li t0, 1
    sb t0, 276(s8)
    sh t0, 276(s8)
    lw t1, 272(s8)
    EXPECT (t1, t0)

    PASS_CASE

# TEST 216: Word ACK clears pending; stopped timer and cumulative tick count stay stable
test_216:
    BEGIN_CASE (216, 0x0216)

    li t0, 1
    sw t0, 276(s8)
    lw t1, 272(s8)
    EXPECT (t1, zero)
    lw s1, 264(s8)
    jal ra, short_delay
    lw t1, 264(s8)
    EXPECT (t1, s1)

    PASS_CASE

# TEST 217: Enable-mask readback truncates to two sources; write-only registers read zero
test_217:
    BEGIN_CASE (217, 0x0217)

    li t0, -1
    sw t0, 268(s8)
    lw t1, 268(s8)
    li t2, 3
    EXPECT (t1, t2)
    sw zero, 268(s8)
    lw t1, 260(s8)
    EXPECT (t1, zero)
    lw t1, 276(s8)
    EXPECT (t1, zero)

    PASS_CASE

# TEST 218: Period staging alone does not start timer; configuration preserves total ticks
test_218:
    BEGIN_CASE (218, 0x0218)

    lw s1, 264(s8)
    li t0, 200
    sw t0, 256(s8)
    jal ra, short_delay
    lw t1, 264(s8)
    EXPECT (t1, s1)
    sw zero, 260(s8)
    lw t1, 264(s8)
    EXPECT (t1, s1)

    PASS_CASE

# TEST 219: Pending timer survives unrelated mask; unmask services exactly once and returns
test_219:
    BEGIN_CASE (219, 0x0219)

    li t0, 32
    sw t0, 256(s8)
    li t0, 1
    sw t0, 260(s8)
    jal ra, short_delay
    sw zero, 260(s8)
    li t0, 2
    sw t0, 268(s8)
    jal ra, short_delay
    lw t0, 0(s0)
    EXPECT (t0, zero)
    li t0, 1
    sw t0, 268(s8)
    jal ra, wait_one_irq
    jal ra, short_delay
    lw t0, 0(s0)
    li t1, 1
    EXPECT (t0, t1)
    lw t0, 4(s0)
    EXPECT (t0, t1)
    lw t0, 272(s8)
    EXPECT (t0, zero)
    lw t0, 28(s0)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 220: Ticks while in delayed handler coalesce; pending after return is serviced without nesting
test_220:
    BEGIN_CASE (220, 0x0220)

    jal ra, reset_irq_test
    li t0, 2
    sw t0, 16(s0)
    li t0, 64
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
    li s1, 200000
wait_delayed_irq:
    lw t0, 4(s0)
    li t1, 2
    bgeu t0, t1, delayed_done
    addi s1, s1, -1
    bne s1, zero, wait_delayed_irq
    j fail
delayed_done:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 2
    EXPECT (t0, t1)
    lw t0, 32(s0)
    sltiu t0, t0, 2
    EXPECT (t0, zero)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 221: IRQ stress period 1: branches, subwords, load-use, MUL/DIV and exact foreground sum
test_221:
    BEGIN_CASE (221, 0x0221)

    jal ra, reset_irq_test
    li t0, 1
    sw t0, 16(s0)              # mode: continue timer until 8 services
    li t0, 8
    sw t0, 20(s0)
    li s1, 0
    li s2, 0
    li s3, 200
    li s4, 7
    li s5, 0x13579bdf
    li s6, 0x2468ace0
    li s7, 0x100100c0
    li t0, 0xa55ac33c
    sw t0, 0(s7)
    li t0, 1
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
stress_1:
    addi s1, s1, 1
    mul t0, s1, s4
    div t1, t0, s4
    EXPECT (t1, s1)
    add s2, s2, t1
    sb s1, 1(s7)
    lbu t2, 1(s7)
    EXPECT (t2, s1)
    sh t0, 2(s7)
    lhu t2, 2(s7)
    EXPECT (t2, t0)
    lw t3, 0(s7)
    sw t3, 4(s7)
    lw t4, 4(s7)
    EXPECT (t3, t4)
    andi t5, s1, 1
    beq t5, zero, stress_even_1
    j stress_join_1
stress_even_1:
    addi t6, s1, 0
    EXPECT (t6, s1)
stress_join_1:
    bne s1, s3, stress_1
    li t0, 20100
    EXPECT (s2, t0)
    li t0, 0x13579bdf
    EXPECT (s5, t0)
    li t0, 0x2468ace0
    EXPECT (s6, t0)
    li t0, 0x10010200
    EXPECT (sp, t0)
    li s1, 200000
stress_wait_1:
    lw t0, 4(s0)
    li t1, 8
    beq t0, t1, stress_done_1
    addi s1, s1, -1
    bne s1, zero, stress_wait_1
    j fail
stress_done_1:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 8
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, t1)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 222: IRQ stress period 2: branches, subwords, load-use, MUL/DIV and exact foreground sum
test_222:
    BEGIN_CASE (222, 0x0222)

    jal ra, reset_irq_test
    li t0, 1
    sw t0, 16(s0)              # mode: continue timer until 8 services
    li t0, 8
    sw t0, 20(s0)
    li s1, 0
    li s2, 0
    li s3, 200
    li s4, 7
    li s5, 0x13579bdf
    li s6, 0x2468ace0
    li s7, 0x100100c0
    li t0, 0xa55ac33c
    sw t0, 0(s7)
    li t0, 2
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
stress_2:
    addi s1, s1, 1
    mul t0, s1, s4
    div t1, t0, s4
    EXPECT (t1, s1)
    add s2, s2, t1
    sb s1, 1(s7)
    lbu t2, 1(s7)
    EXPECT (t2, s1)
    sh t0, 2(s7)
    lhu t2, 2(s7)
    EXPECT (t2, t0)
    lw t3, 0(s7)
    sw t3, 4(s7)
    lw t4, 4(s7)
    EXPECT (t3, t4)
    andi t5, s1, 1
    beq t5, zero, stress_even_2
    j stress_join_2
stress_even_2:
    addi t6, s1, 0
    EXPECT (t6, s1)
stress_join_2:
    bne s1, s3, stress_2
    li t0, 20100
    EXPECT (s2, t0)
    li t0, 0x13579bdf
    EXPECT (s5, t0)
    li t0, 0x2468ace0
    EXPECT (s6, t0)
    li t0, 0x10010200
    EXPECT (sp, t0)
    li s1, 200000
stress_wait_2:
    lw t0, 4(s0)
    li t1, 8
    beq t0, t1, stress_done_2
    addi s1, s1, -1
    bne s1, zero, stress_wait_2
    j fail
stress_done_2:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 8
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, t1)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 223: IRQ stress period 7: branches, subwords, load-use, MUL/DIV and exact foreground sum
test_223:
    BEGIN_CASE (223, 0x0223)

    jal ra, reset_irq_test
    li t0, 1
    sw t0, 16(s0)              # mode: continue timer until 8 services
    li t0, 8
    sw t0, 20(s0)
    li s1, 0
    li s2, 0
    li s3, 200
    li s4, 7
    li s5, 0x13579bdf
    li s6, 0x2468ace0
    li s7, 0x100100c0
    li t0, 0xa55ac33c
    sw t0, 0(s7)
    li t0, 7
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
stress_7:
    addi s1, s1, 1
    mul t0, s1, s4
    div t1, t0, s4
    EXPECT (t1, s1)
    add s2, s2, t1
    sb s1, 1(s7)
    lbu t2, 1(s7)
    EXPECT (t2, s1)
    sh t0, 2(s7)
    lhu t2, 2(s7)
    EXPECT (t2, t0)
    lw t3, 0(s7)
    sw t3, 4(s7)
    lw t4, 4(s7)
    EXPECT (t3, t4)
    andi t5, s1, 1
    beq t5, zero, stress_even_7
    j stress_join_7
stress_even_7:
    addi t6, s1, 0
    EXPECT (t6, s1)
stress_join_7:
    bne s1, s3, stress_7
    li t0, 20100
    EXPECT (s2, t0)
    li t0, 0x13579bdf
    EXPECT (s5, t0)
    li t0, 0x2468ace0
    EXPECT (s6, t0)
    li t0, 0x10010200
    EXPECT (sp, t0)
    li s1, 200000
stress_wait_7:
    lw t0, 4(s0)
    li t1, 8
    beq t0, t1, stress_done_7
    addi s1, s1, -1
    bne s1, zero, stress_wait_7
    j fail
stress_done_7:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 8
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, t1)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 224: IRQ stress period 17: branches, subwords, load-use, MUL/DIV and exact foreground sum
test_224:
    BEGIN_CASE (224, 0x0224)

    jal ra, reset_irq_test
    li t0, 1
    sw t0, 16(s0)              # mode: continue timer until 8 services
    li t0, 8
    sw t0, 20(s0)
    li s1, 0
    li s2, 0
    li s3, 200
    li s4, 7
    li s5, 0x13579bdf
    li s6, 0x2468ace0
    li s7, 0x100100c0
    li t0, 0xa55ac33c
    sw t0, 0(s7)
    li t0, 17
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
stress_17:
    addi s1, s1, 1
    mul t0, s1, s4
    div t1, t0, s4
    EXPECT (t1, s1)
    add s2, s2, t1
    sb s1, 1(s7)
    lbu t2, 1(s7)
    EXPECT (t2, s1)
    sh t0, 2(s7)
    lhu t2, 2(s7)
    EXPECT (t2, t0)
    lw t3, 0(s7)
    sw t3, 4(s7)
    lw t4, 4(s7)
    EXPECT (t3, t4)
    andi t5, s1, 1
    beq t5, zero, stress_even_17
    j stress_join_17
stress_even_17:
    addi t6, s1, 0
    EXPECT (t6, s1)
stress_join_17:
    bne s1, s3, stress_17
    li t0, 20100
    EXPECT (s2, t0)
    li t0, 0x13579bdf
    EXPECT (s5, t0)
    li t0, 0x2468ace0
    EXPECT (s6, t0)
    li t0, 0x10010200
    EXPECT (sp, t0)
    li s1, 200000
stress_wait_17:
    lw t0, 4(s0)
    li t1, 8
    beq t0, t1, stress_done_17
    addi s1, s1, -1
    bne s1, zero, stress_wait_17
    j fail
stress_done_17:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 8
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, t1)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 225: IRQ stress period 31: branches, subwords, load-use, MUL/DIV and exact foreground sum
test_225:
    BEGIN_CASE (225, 0x0225)

    jal ra, reset_irq_test
    li t0, 1
    sw t0, 16(s0)              # mode: continue timer until 8 services
    li t0, 8
    sw t0, 20(s0)
    li s1, 0
    li s2, 0
    li s3, 200
    li s4, 7
    li s5, 0x13579bdf
    li s6, 0x2468ace0
    li s7, 0x100100c0
    li t0, 0xa55ac33c
    sw t0, 0(s7)
    li t0, 31
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
stress_31:
    addi s1, s1, 1
    mul t0, s1, s4
    div t1, t0, s4
    EXPECT (t1, s1)
    add s2, s2, t1
    sb s1, 1(s7)
    lbu t2, 1(s7)
    EXPECT (t2, s1)
    sh t0, 2(s7)
    lhu t2, 2(s7)
    EXPECT (t2, t0)
    lw t3, 0(s7)
    sw t3, 4(s7)
    lw t4, 4(s7)
    EXPECT (t3, t4)
    andi t5, s1, 1
    beq t5, zero, stress_even_31
    j stress_join_31
stress_even_31:
    addi t6, s1, 0
    EXPECT (t6, s1)
stress_join_31:
    bne s1, s3, stress_31
    li t0, 20100
    EXPECT (s2, t0)
    li t0, 0x13579bdf
    EXPECT (s5, t0)
    li t0, 0x2468ace0
    EXPECT (s6, t0)
    li t0, 0x10010200
    EXPECT (sp, t0)
    li s1, 200000
stress_wait_31:
    lw t0, 4(s0)
    li t1, 8
    beq t0, t1, stress_done_31
    addi s1, s1, -1
    bne s1, zero, stress_wait_31
    j fail
stress_done_31:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 8
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, t1)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 226: IRQ stress period 64: branches, subwords, load-use, MUL/DIV and exact foreground sum
test_226:
    BEGIN_CASE (226, 0x0226)

    jal ra, reset_irq_test
    li t0, 1
    sw t0, 16(s0)              # mode: continue timer until 8 services
    li t0, 8
    sw t0, 20(s0)
    li s1, 0
    li s2, 0
    li s3, 200
    li s4, 7
    li s5, 0x13579bdf
    li s6, 0x2468ace0
    li s7, 0x100100c0
    li t0, 0xa55ac33c
    sw t0, 0(s7)
    li t0, 64
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
stress_64:
    addi s1, s1, 1
    mul t0, s1, s4
    div t1, t0, s4
    EXPECT (t1, s1)
    add s2, s2, t1
    sb s1, 1(s7)
    lbu t2, 1(s7)
    EXPECT (t2, s1)
    sh t0, 2(s7)
    lhu t2, 2(s7)
    EXPECT (t2, t0)
    lw t3, 0(s7)
    sw t3, 4(s7)
    lw t4, 4(s7)
    EXPECT (t3, t4)
    andi t5, s1, 1
    beq t5, zero, stress_even_64
    j stress_join_64
stress_even_64:
    addi t6, s1, 0
    EXPECT (t6, s1)
stress_join_64:
    bne s1, s3, stress_64
    li t0, 20100
    EXPECT (s2, t0)
    li t0, 0x13579bdf
    EXPECT (s5, t0)
    li t0, 0x2468ace0
    EXPECT (s6, t0)
    li t0, 0x10010200
    EXPECT (sp, t0)
    li s1, 200000
stress_wait_64:
    lw t0, 4(s0)
    li t1, 8
    beq t0, t1, stress_done_64
    addi s1, s1, -1
    bne s1, zero, stress_wait_64
    j fail
stress_done_64:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 8
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, t1)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 227: IRQ stress period 127: branches, subwords, load-use, MUL/DIV and exact foreground sum
test_227:
    BEGIN_CASE (227, 0x0227)

    jal ra, reset_irq_test
    li t0, 1
    sw t0, 16(s0)              # mode: continue timer until 8 services
    li t0, 8
    sw t0, 20(s0)
    li s1, 0
    li s2, 0
    li s3, 200
    li s4, 7
    li s5, 0x13579bdf
    li s6, 0x2468ace0
    li s7, 0x100100c0
    li t0, 0xa55ac33c
    sw t0, 0(s7)
    li t0, 127
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
stress_127:
    addi s1, s1, 1
    mul t0, s1, s4
    div t1, t0, s4
    EXPECT (t1, s1)
    add s2, s2, t1
    sb s1, 1(s7)
    lbu t2, 1(s7)
    EXPECT (t2, s1)
    sh t0, 2(s7)
    lhu t2, 2(s7)
    EXPECT (t2, t0)
    lw t3, 0(s7)
    sw t3, 4(s7)
    lw t4, 4(s7)
    EXPECT (t3, t4)
    andi t5, s1, 1
    beq t5, zero, stress_even_127
    j stress_join_127
stress_even_127:
    addi t6, s1, 0
    EXPECT (t6, s1)
stress_join_127:
    bne s1, s3, stress_127
    li t0, 20100
    EXPECT (s2, t0)
    li t0, 0x13579bdf
    EXPECT (s5, t0)
    li t0, 0x2468ace0
    EXPECT (s6, t0)
    li t0, 0x10010200
    EXPECT (sp, t0)
    li s1, 200000
stress_wait_127:
    lw t0, 4(s0)
    li t1, 8
    beq t0, t1, stress_done_127
    addi s1, s1, -1
    bne s1, zero, stress_wait_127
    j fail
stress_done_127:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 8
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, t1)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 228: IRQ stress period 257: branches, subwords, load-use, MUL/DIV and exact foreground sum
test_228:
    BEGIN_CASE (228, 0x0228)

    jal ra, reset_irq_test
    li t0, 1
    sw t0, 16(s0)              # mode: continue timer until 8 services
    li t0, 8
    sw t0, 20(s0)
    li s1, 0
    li s2, 0
    li s3, 200
    li s4, 7
    li s5, 0x13579bdf
    li s6, 0x2468ace0
    li s7, 0x100100c0
    li t0, 0xa55ac33c
    sw t0, 0(s7)
    li t0, 257
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
stress_257:
    addi s1, s1, 1
    mul t0, s1, s4
    div t1, t0, s4
    EXPECT (t1, s1)
    add s2, s2, t1
    sb s1, 1(s7)
    lbu t2, 1(s7)
    EXPECT (t2, s1)
    sh t0, 2(s7)
    lhu t2, 2(s7)
    EXPECT (t2, t0)
    lw t3, 0(s7)
    sw t3, 4(s7)
    lw t4, 4(s7)
    EXPECT (t3, t4)
    andi t5, s1, 1
    beq t5, zero, stress_even_257
    j stress_join_257
stress_even_257:
    addi t6, s1, 0
    EXPECT (t6, s1)
stress_join_257:
    bne s1, s3, stress_257
    li t0, 20100
    EXPECT (s2, t0)
    li t0, 0x13579bdf
    EXPECT (s5, t0)
    li t0, 0x2468ace0
    EXPECT (s6, t0)
    li t0, 0x10010200
    EXPECT (sp, t0)
    li s1, 200000
stress_wait_257:
    lw t0, 4(s0)
    li t1, 8
    beq t0, t1, stress_done_257
    addi s1, s1, -1
    bne s1, zero, stress_wait_257
    j fail
stress_done_257:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 8
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, t1)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 229: IRQ stress period 509: branches, subwords, load-use, MUL/DIV and exact foreground sum
test_229:
    BEGIN_CASE (229, 0x0229)

    jal ra, reset_irq_test
    li t0, 1
    sw t0, 16(s0)              # mode: continue timer until 8 services
    li t0, 8
    sw t0, 20(s0)
    li s1, 0
    li s2, 0
    li s3, 200
    li s4, 7
    li s5, 0x13579bdf
    li s6, 0x2468ace0
    li s7, 0x100100c0
    li t0, 0xa55ac33c
    sw t0, 0(s7)
    li t0, 509
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
stress_509:
    addi s1, s1, 1
    mul t0, s1, s4
    div t1, t0, s4
    EXPECT (t1, s1)
    add s2, s2, t1
    sb s1, 1(s7)
    lbu t2, 1(s7)
    EXPECT (t2, s1)
    sh t0, 2(s7)
    lhu t2, 2(s7)
    EXPECT (t2, t0)
    lw t3, 0(s7)
    sw t3, 4(s7)
    lw t4, 4(s7)
    EXPECT (t3, t4)
    andi t5, s1, 1
    beq t5, zero, stress_even_509
    j stress_join_509
stress_even_509:
    addi t6, s1, 0
    EXPECT (t6, s1)
stress_join_509:
    bne s1, s3, stress_509
    li t0, 20100
    EXPECT (s2, t0)
    li t0, 0x13579bdf
    EXPECT (s5, t0)
    li t0, 0x2468ace0
    EXPECT (s6, t0)
    li t0, 0x10010200
    EXPECT (sp, t0)
    li s1, 200000
stress_wait_509:
    lw t0, 4(s0)
    li t1, 8
    beq t0, t1, stress_done_509
    addi s1, s1, -1
    bne s1, zero, stress_wait_509
    j fail
stress_done_509:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 8
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, t1)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 230: IRQ stress period 1021: branches, subwords, load-use, MUL/DIV and exact foreground sum
test_230:
    BEGIN_CASE (230, 0x0230)

    jal ra, reset_irq_test
    li t0, 1
    sw t0, 16(s0)              # mode: continue timer until 8 services
    li t0, 8
    sw t0, 20(s0)
    li s1, 0
    li s2, 0
    li s3, 200
    li s4, 7
    li s5, 0x13579bdf
    li s6, 0x2468ace0
    li s7, 0x100100c0
    li t0, 0xa55ac33c
    sw t0, 0(s7)
    li t0, 1021
    sw t0, 256(s8)
    li t0, 1
    sw t0, 268(s8)
    sw t0, 260(s8)
stress_1021:
    addi s1, s1, 1
    mul t0, s1, s4
    div t1, t0, s4
    EXPECT (t1, s1)
    add s2, s2, t1
    sb s1, 1(s7)
    lbu t2, 1(s7)
    EXPECT (t2, s1)
    sh t0, 2(s7)
    lhu t2, 2(s7)
    EXPECT (t2, t0)
    lw t3, 0(s7)
    sw t3, 4(s7)
    lw t4, 4(s7)
    EXPECT (t3, t4)
    andi t5, s1, 1
    beq t5, zero, stress_even_1021
    j stress_join_1021
stress_even_1021:
    addi t6, s1, 0
    EXPECT (t6, s1)
stress_join_1021:
    bne s1, s3, stress_1021
    li t0, 20100
    EXPECT (s2, t0)
    li t0, 0x13579bdf
    EXPECT (s5, t0)
    li t0, 0x2468ace0
    EXPECT (s6, t0)
    li t0, 0x10010200
    EXPECT (sp, t0)
    li s1, 200000
stress_wait_1021:
    lw t0, 4(s0)
    li t1, 8
    beq t0, t1, stress_done_1021
    addi s1, s1, -1
    bne s1, zero, stress_wait_1021
    j fail
stress_done_1021:
    jal ra, short_delay
    lw t0, 4(s0)
    li t1, 8
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, t1)
    lw t0, 28(s0)
    EXPECT (t0, zero)
    lw t0, 24(s0)
    EXPECT (t0, zero)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 231: MANUAL: masked center press latches pending; held level is readable
test_231:
    BEGIN_CASE (231, 0x0231)

    jal ra, reset_irq_test
    li a0, 0
    li t0, 4
    sw t0, 96(s8)
    jal ra, wait_button_level   # ensure release before asking for press
    li t0, 3
    sw t0, 276(s8)
    li t0, 1
    sw t0, 96(s8)              # LED 01: PRESS AND HOLD
    li a0, 2
    jal ra, wait_button_level
    jal ra, short_delay
    lw t0, 272(s8)
    li t1, 2
    EXPECT (t0, t1)
    lw t0, 0(s0)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 232: MANUAL: enable button IRQ, then HOLD for one second without retrigger
test_232:
    BEGIN_CASE (232, 0x0232)

    li t0, 2
    sw t0, 96(s8)              # LED 02: KEEP HOLDING
    sw t0, 268(s8)
    jal ra, wait_one_irq
    lw s1, 160(s8)
hold_one_second:
    lw t0, 104(s8)
    andi t0, t0, 2
    li t1, 2
    EXPECT (t0, t1)
    lw t0, 0(s0)
    li t1, 1
    EXPECT (t0, t1)
    lw t0, 160(s8)
    sub t0, t0, s1
    li t1, CPU_HZ
    bltu t0, t1, hold_one_second
    lw t0, 8(s0)
    li t1, 1
    EXPECT (t0, t1)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 233: MANUAL: release creates no interrupt and rearms button
test_233:
    BEGIN_CASE (233, 0x0233)

    li t0, 4
    sw t0, 96(s8)              # LED 04: RELEASE
    li a0, 0
    jal ra, wait_button_level
    jal ra, short_delay
    lw t0, 0(s0)
    li t1, 1
    EXPECT (t0, t1)
    lw t0, 272(s8)
    EXPECT (t0, zero)

    PASS_CASE

# TEST 234: MANUAL: timer and second button press both pending; common handler services both
test_234:
    BEGIN_CASE (234, 0x0234)

    jal ra, reset_irq_test
    li t0, 64
    sw t0, 256(s8)
    li t0, 1
    sw t0, 260(s8)
    jal ra, short_delay
    sw zero, 260(s8)
    li t0, 8
    sw t0, 96(s8)              # LED 08: PRESS AND HOLD AGAIN
    li a0, 2
    jal ra, wait_button_level
    jal ra, short_delay
    lw t0, 272(s8)
    li t1, 3
    EXPECT (t0, t1)
    sw t1, 268(s8)
    jal ra, wait_one_irq
    jal ra, short_delay
    lw t0, 0(s0)
    li t1, 1
    EXPECT (t0, t1)
    lw t0, 4(s0)
    EXPECT (t0, t1)
    lw t0, 8(s0)
    EXPECT (t0, t1)
    lw t0, 12(s0)
    li t1, 3
    EXPECT (t0, t1)
    lw t0, 272(s8)
    EXPECT (t0, zero)
    lw t0, 28(s0)
    EXPECT (t0, zero)

    PASS_CASE

# All 234 cases passed, including physical button checks.
pass:
    sw zero, 268(s8)
    sw zero, 260(s8)
    li s10, 0xC001B33F
    lui t0, 0x10010
    sw s10, 64(t0)
    sw s10, 128(s8)
    li t0, 255
    sw t0, 96(s8)
pass_halt:
    j pass_halt

fail:
    lui s8, 0xffff0
    sw zero, 268(s8)
    sw zero, 260(s8)
    li s10, 0xDEAD0000
    or t1, s10, s11
    lui t0, 0x10010
    sw t1, 64(t0)
    or t1, s10, s9
    sw t1, 128(s8)
    sw s11, 96(s8)
fail_halt:
    j fail_halt

# Helpers below deliberately do not modify s-registers/test identifiers.
# Caller s0 = 10010080. Clears only ISR state; does not reset cumulative ticks.
reset_irq_test:
    sw zero, 268(s8)
    sw zero, 260(s8)
    nop
    nop
    li t0, 3
    sw t0, 276(s8)
    li t0, 0
    li t1, 64
reset_irq_state:
    add t2, s0, t0
    sw zero, 0(t2)
    addi t0, t0, 4
    bne t0, t1, reset_irq_state
    ret
short_delay:
    li t0, 2048
short_delay_loop:
    addi t0, t0, -1
    bne t0, zero, short_delay_loop
    ret
wait_one_irq:
    li t0, 200000
wait_one_loop:
    lw t1, 0(s0)
    bne t1, zero, wait_one_done
    addi t0, t0, -1
    bne t0, zero, wait_one_loop
    j fail
wait_one_done:
    ret
# a0 = requested center held level (0 or 2). Timeout wraps safely in 32 bits.
wait_button_level:
    lw t3, 160(s8)
    li t4, BUTTON_TIMEOUT
wait_button_loop:
    lw t0, 104(s8)
    andi t0, t0, 2
    beq t0, a0, wait_button_done
    lw t1, 160(s8)
    sub t1, t1, t3
    bltu t1, t4, wait_button_loop
    j fail
wait_button_done:
    ret

# IRQ state offsets: 0 entries, 4 timer services, 8 button services,
# 12 OR of serviced causes, 16 mode, 20 service target, 24 active marker,
# 28 handler error, 32 ticks elapsed during delayed handler, 36 entry tick.
# Mode 0 stops timer on timer service; mode 1 stops at target services;
# mode 2 delays first handler while timer runs, returns in mode 0.
irq_handler:
    addi sp, sp, -32
    sw t0, 0(sp)
    sw t1, 4(sp)
    sw t2, 8(sp)
    sw t3, 12(sp)
    sw t4, 16(sp)
    sw t5, 20(sp)
    sw t6, 24(sp)
    lui t0, 0xffff0
    li t1, 0x10010080
    lw t2, 24(t1)
    beq t2, zero, irq_not_nested
    li t2, 1
    sw t2, 28(t1)
irq_not_nested:
    li t2, 1
    sw t2, 24(t1)
    lw t2, 272(t0)
    lw t3, 268(t0)
    and t2, t2, t3             # service only enabled sources
    bne t2, zero, irq_has_source
    li t3, 2
    sw t3, 28(t1)
irq_has_source:
    lw t3, 0(t1)
    addi t3, t3, 1
    sw t3, 0(t1)
    lw t3, 12(t1)
    or t3, t3, t2
    sw t3, 12(t1)
    lw t3, 264(t0)
    sw t3, 36(t1)
    andi t3, t2, 2
    beq t3, zero, irq_timer
    lw t3, 8(t1)
    addi t3, t3, 1
    sw t3, 8(t1)
irq_timer:
    andi t3, t2, 1
    beq t3, zero, irq_ack
    lw t3, 4(t1)
    addi t3, t3, 1
    sw t3, 4(t1)
    lw t4, 16(t1)
    li t5, 2
    beq t4, t5, irq_delay
    beq t4, zero, irq_stop_timer
    lw t5, 20(t1)
    bltu t3, t5, irq_ack
irq_stop_timer:
    sw zero, 260(t0)
    nop
    nop
    j irq_ack
irq_delay:
    li t5, 2048
irq_delay_loop:
    addi t5, t5, -1
    bne t5, zero, irq_delay_loop
    lw t5, 264(t0)
    lw t6, 36(t1)
    sub t5, t5, t6
    sw t5, 32(t1)
    sw zero, 16(t1)            # next IRQ stops timer
irq_ack:
    sw t2, 276(t0)
    sw zero, 24(t1)
    lw t0, 0(sp)
    lw t1, 4(sp)
    lw t2, 8(sp)
    lw t3, 12(sp)
    lw t4, 16(sp)
    lw t5, 20(sp)
    lw t6, 24(sp)
    addi sp, sp, 32
    uret                       # CURRENT custom opcode-0x73 return; see header
    j fail                     # must be squashed on return
