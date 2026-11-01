# RV32IM branch-prediction and datapath self-check
# Original test program. Intended for a little-endian, 32-bit, five-stage CPU.
# Assemble using RARS in RV32 mode (pseudoinstructions enabled).
# No ECALL, CSR, operating system, or stack is required.
# Uses the supplied Wrapper seven-segment MMIO register at 0xFFFF0080.
#
# PASS: s10/x26 = 0xC001BEEF, s11/x27 = 95 (number of tests).
# FAIL: s10/x26 = 0xDEAD0000 | test_number, s11/x27 = test_number.
# The same values are written to result_signature and result_test.
# Execution parks at pass_halt or fail_halt. A stalled/broken CPU needs an
# external simulation timeout; absence of PASS is not automatically a FAIL code.
#
# For FPGA: assemble and load BOTH the text and data images using addresses
# matching your instruction/data memory map. main must be at PC_INIT.
# RARS default text=0x00400000, data=0x10010000; verify against your wrapper.
# scratch uses 64 writable bytes; results use 8 bytes. No initialized data needed.
# Display: current decimal test digits, C001BEEF on pass, DEADdddd on failure.
# Example: test 25 fails as DEAD0025. RAM/s10 retain the binary test ID encoding.
# s8 is reserved for MMIO base, s9 for packed decimal display digits.
# Wrapper settings: IROM_DEPTH_BITS=13, DMEM_DEPTH_BITS=9, MMIO_DEPTH_BITS=8.
#
# These tests check architectural correctness WITH prediction enabled. RARS does
# not simulate your pipeline, hazards, BHT or BTB. PASS is not proof of accuracy.
# Inspect MispredictE / UpdateEnableE / PCF / PCE / predicted-next-PC signals.
# Correctly predicted branches should not flush; wrong-path stores must not commit.
# A 32-entry table using PC[6:2] is deliberately exercised with alias_a/alias_b.
# If your table index is wider, that test still checks control flow, not collision.
#
# Tests are sequential and stop on FIRST failure. Some subword tests intentionally
# reuse the preceding test's word to verify byte/half-word preservation.
# Reserved: s0 = scratch base; s10 = status; s11 = current test number.
#
# TEST MAP:
# 01  x0 remains zero
# 02  ADD and operand forwarding
# 03  SUB gives a negative result
# 04  32-bit addition wraps
# 05  ADDI sign extension
# 06  AND
# 07  OR
# 08  XOR
# 09  SLL register shift
# 10  SRL zero fills
# 11  SRA sign fills
# 12  SLT signed comparison
# 13  SLTU unsigned comparison
# 14  SLTI signed immediate
# 15  SLTIU sign-extended immediate
# 16  Immediate shifts and logical immediates
# 17  LUI
# 18  AUIPC uses this instruction's PC
# 19  Several consecutive ALU dependencies
# 20  Write-back to Decode operand forwarding
# 21  SW / LW full word
# 22  LW immediately followed by dependent ADD
# 23  LW immediately followed by SW of loaded data
# 24  LW supplies the following store address
# 25  LH lower half sign extension
# 26  LHU lower half zero extension
# 27  LH upper positive half
# 28  LHU upper negative-bit half
# 29  LH upper negative half
# 30  SH lower half preserves upper half
# 31  SH upper half preserves lower half
# 32  LH immediately followed by dependent ADD
# 33  LW-to-SH forwarding with upper-half mask
# 34  SB lane 1 preserves other bytes
# 35  SB lane 3 preserves other bytes
# 36  LB sign extends lane 3
# 37  LBU zero extends lane 3
# 38  LB sign extends lane 1
# 39  LBU zero extends lane 1
# 40  Negative load/store offsets
# 41  BEQ taken and not-taken outcomes
# 42  BNE taken and not-taken outcomes
# 43  BLT taken and not-taken outcomes
# 44  BGE taken and not-taken outcomes
# 45  BLTU taken and not-taken outcomes
# 46  BGEU taken and not-taken outcomes
# 47  Repeated taken loop then not-taken exit
# 48  Same branch repeatedly not taken, then taken
# 49  Alternating branch outcomes
# 50  Taken branch squashes wrong-path store and register write
# 51  LW immediately supplies branch comparison
# 52  LH sign-extended value immediately supplies branch
# 53  JAL return address and JALR return
# 54  JAL x0 squashes fall-through operations
# 55  JALR clears target bit 0 and writes link
# 56  Same JALR instruction alternates between two targets
# 57  32-entry BTB index collision: branch PCs differ by 128 bytes
# 58  MUL signed low word
# 59  MUL low-word overflow
# 60  MULH signed negative high word
# 61  MULH positive high word
# 62  MULHU unsigned high word
# 63  MULHSU signed by unsigned high word
# 64  DIV truncates toward zero
# 65  DIVU unsigned division
# 66  REM follows dividend sign
# 67  REMU unsigned remainder
# 68  DIV by zero
# 69  DIVU by zero
# 70  REM by zero preserves dividend
# 71  REMU by zero preserves dividend
# 72  DIV signed overflow
# 73  REM signed overflow
# 74  DIV negative divisor
# 75  REM positive dividend with negative divisor
# 76  MUL immediately supplies branch operand
# 77  MUL result immediately stored
# 78  Back-to-back dependent MUL DIV REM and ADD
# 79  Mispredicted path must not launch a DIV
# 80  Branch target is its own PC plus 4
# 81  Same conditional branch uses all four counter states
# 82  Wrong predicted-taken path cannot commit a store on loop exit
# 83  Zero destination load must not corrupt x0
# 84  Load immediately supplies JALR target
# 85  Consecutive opposite branches
# 86  SH truncates source to 16 bits and preserves the other half
# 87  Half-word boundaries zero 7fff 8000 ffff
# 88  SB lanes 0 and 2 preserve other bytes
# 89  Register shift masks shift amount to five bits
# 90  Signed versus unsigned branch limits and equality
# 91  Multiply zero and signed minimum boundaries
# 92  Divide zero dividend and dividend smaller than divisor
# 93  MUL and DIV writing x0 do not break following instructions
# 94  DIV result immediately feeds a branch, then store
# 95  Nested calls and returns preserve both link addresses

.data
.align 2
scratch:
    .space 64
result_signature:
    .word 0
result_test:
    .word 0

.text
.globl main
main:
    lui s8, 0xffff0
    sw zero, 128(s8)
    la s0, scratch
    li s10, 0
    li s11, 0
    la t0, result_signature
    sw zero, 0(t0)
    sw zero, 4(t0)

# ----------------------------------------------------------------------
# TEST 1: x0 remains zero
# ----------------------------------------------------------------------
test_01:
    li s11, 1
    li s9, 0x0001
    sw s9, 128(s8)
    addi zero, zero, 123
    li t6, 0
    beq zero, t6, check_continue_1
    j fail
check_continue_1:
# ----------------------------------------------------------------------
# TEST 2: ADD and operand forwarding
# ----------------------------------------------------------------------
test_02:
    li s11, 2
    li s9, 0x0002
    sw s9, 128(s8)
    li t0, 123
    li t1, 456
    add t2, t0, t1
    li t6, 579
    beq t2, t6, check_continue_2
    j fail
check_continue_2:
# ----------------------------------------------------------------------
# TEST 3: SUB gives a negative result
# ----------------------------------------------------------------------
test_03:
    li s11, 3
    li s9, 0x0003
    sw s9, 128(s8)
    li t0, 3
    li t1, 10
    sub t2, t0, t1
    li t6, -7
    beq t2, t6, check_continue_3
    j fail
check_continue_3:
# ----------------------------------------------------------------------
# TEST 4: 32-bit addition wraps
# ----------------------------------------------------------------------
test_04:
    li s11, 4
    li s9, 0x0004
    sw s9, 128(s8)
    li t0, 0xffffffff
    addi t2, t0, 1
    li t6, 0
    beq t2, t6, check_continue_4
    j fail
check_continue_4:
# ----------------------------------------------------------------------
# TEST 5: ADDI sign extension
# ----------------------------------------------------------------------
test_05:
    li s11, 5
    li s9, 0x0005
    sw s9, 128(s8)
    li t0, 10
    addi t2, t0, -17
    li t6, -7
    beq t2, t6, check_continue_5
    j fail
check_continue_5:
# ----------------------------------------------------------------------
# TEST 6: AND
# ----------------------------------------------------------------------
test_06:
    li s11, 6
    li s9, 0x0006
    sw s9, 128(s8)
    li t0, 0x55aa55aa
    li t1, 0x0ff00ff0
    and t2, t0, t1
    li t6, 0x05a005a0
    beq t2, t6, check_continue_6
    j fail
check_continue_6:
# ----------------------------------------------------------------------
# TEST 7: OR
# ----------------------------------------------------------------------
test_07:
    li s11, 7
    li s9, 0x0007
    sw s9, 128(s8)
    li t0, 0x55005500
    li t1, 0x00aa00aa
    or t2, t0, t1
    li t6, 0x55aa55aa
    beq t2, t6, check_continue_7
    j fail
check_continue_7:
# ----------------------------------------------------------------------
# TEST 8: XOR
# ----------------------------------------------------------------------
test_08:
    li s11, 8
    li s9, 0x0008
    sw s9, 128(s8)
    li t0, 0x55aa55aa
    li t1, 0xffffffff
    xor t2, t0, t1
    li t6, 0xaa55aa55
    beq t2, t6, check_continue_8
    j fail
check_continue_8:
# ----------------------------------------------------------------------
# TEST 9: SLL register shift
# ----------------------------------------------------------------------
test_09:
    li s11, 9
    li s9, 0x0009
    sw s9, 128(s8)
    li t0, 3
    li t1, 4
    sll t2, t0, t1
    li t6, 48
    beq t2, t6, check_continue_9
    j fail
check_continue_9:
# ----------------------------------------------------------------------
# TEST 10: SRL zero fills
# ----------------------------------------------------------------------
test_10:
    li s11, 10
    li s9, 0x0010
    sw s9, 128(s8)
    li t0, 0x80000000
    li t1, 4
    srl t2, t0, t1
    li t6, 0x08000000
    beq t2, t6, check_continue_10
    j fail
check_continue_10:
# ----------------------------------------------------------------------
# TEST 11: SRA sign fills
# ----------------------------------------------------------------------
test_11:
    li s11, 11
    li s9, 0x0011
    sw s9, 128(s8)
    li t0, 0x80000000
    li t1, 4
    sra t2, t0, t1
    li t6, 0xf8000000
    beq t2, t6, check_continue_11
    j fail
check_continue_11:
# ----------------------------------------------------------------------
# TEST 12: SLT signed comparison
# ----------------------------------------------------------------------
test_12:
    li s11, 12
    li s9, 0x0012
    sw s9, 128(s8)
    li t0, -1
    li t1, 1
    slt t2, t0, t1
    li t6, 1
    beq t2, t6, check_continue_12
    j fail
check_continue_12:
# ----------------------------------------------------------------------
# TEST 13: SLTU unsigned comparison
# ----------------------------------------------------------------------
test_13:
    li s11, 13
    li s9, 0x0013
    sw s9, 128(s8)
    li t0, -1
    li t1, 1
    sltu t2, t0, t1
    li t6, 0
    beq t2, t6, check_continue_13
    j fail
check_continue_13:
# ----------------------------------------------------------------------
# TEST 14: SLTI signed immediate
# ----------------------------------------------------------------------
test_14:
    li s11, 14
    li s9, 0x0014
    sw s9, 128(s8)
    li t0, -3
    slti t2, t0, -2
    li t6, 1
    beq t2, t6, check_continue_14
    j fail
check_continue_14:
# ----------------------------------------------------------------------
# TEST 15: SLTIU sign-extended immediate
# ----------------------------------------------------------------------
test_15:
    li s11, 15
    li s9, 0x0015
    sw s9, 128(s8)
    li t0, 1
    sltiu t2, t0, -1
    li t6, 1
    beq t2, t6, check_continue_15
    j fail
check_continue_15:
# ----------------------------------------------------------------------
# TEST 16: Immediate shifts and logical immediates
# ----------------------------------------------------------------------
test_16:
    li s11, 16
    li s9, 0x0016
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 17: LUI
# ----------------------------------------------------------------------
test_17:
    li s11, 17
    li s9, 0x0017
    sw s9, 128(s8)
    lui t2, 0x12345
    li t6, 0x12345000
    beq t2, t6, check_continue_17
    j fail
check_continue_17:
# ----------------------------------------------------------------------
# TEST 18: AUIPC uses this instruction's PC
# ----------------------------------------------------------------------
test_18:
    li s11, 18
    li s9, 0x0018
    sw s9, 128(s8)
    auipc t0, 0
    auipc t1, 1
    sub t2, t1, t0
    li t6, 0x1004
    beq t2, t6, check_continue_18
    j fail
check_continue_18:
# ----------------------------------------------------------------------
# TEST 19: Several consecutive ALU dependencies
# ----------------------------------------------------------------------
test_19:
    li s11, 19
    li s9, 0x0019
    sw s9, 128(s8)
    li t0, 7
    add t1, t0, t0
    add t2, t1, t0
    sub t2, t2, t1
    li t6, 7
    beq t2, t6, check_continue_19
    j fail
check_continue_19:
# ----------------------------------------------------------------------
# TEST 20: Write-back to Decode operand forwarding
# ----------------------------------------------------------------------
test_20:
    li s11, 20
    li s9, 0x0020
    sw s9, 128(s8)
    addi t0, zero, 17
    addi t3, zero, 1
    addi t4, zero, 2
    add t2, t0, t0
    li t6, 34
    beq t2, t6, check_continue_20
    j fail
check_continue_20:
# ----------------------------------------------------------------------
# TEST 21: SW / LW full word
# ----------------------------------------------------------------------
test_21:
    li s11, 21
    li s9, 0x0021
    sw s9, 128(s8)
    li t0, 0x89abcdef
    sw t0, 0(s0)
    lw t2, 0(s0)
    li t6, 0x89abcdef
    beq t2, t6, check_continue_21
    j fail
check_continue_21:
# ----------------------------------------------------------------------
# TEST 22: LW immediately followed by dependent ADD
# ----------------------------------------------------------------------
test_22:
    li s11, 22
    li s9, 0x0022
    sw s9, 128(s8)
    li t0, 21
    sw t0, 0(s0)
    lw t1, 0(s0)
    add t2, t1, t1
    li t6, 42
    beq t2, t6, check_continue_22
    j fail
check_continue_22:
# ----------------------------------------------------------------------
# TEST 23: LW immediately followed by SW of loaded data
# ----------------------------------------------------------------------
test_23:
    li s11, 23
    li s9, 0x0023
    sw s9, 128(s8)
    li t0, 0x13579bdf
    sw t0, 0(s0)
    lw t1, 0(s0)
    sw t1, 4(s0)
    lw t2, 4(s0)
    li t6, 0x13579bdf
    beq t2, t6, check_continue_23
    j fail
check_continue_23:
# ----------------------------------------------------------------------
# TEST 24: LW supplies the following store address
# ----------------------------------------------------------------------
test_24:
    li s11, 24
    li s9, 0x0024
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 25: LH lower half sign extension
# ----------------------------------------------------------------------
test_25:
    li s11, 25
    li s9, 0x0025
    sw s9, 128(s8)
    li t0, 0x7fff8001
    sw t0, 0(s0)
    lh t2, 0(s0)
    li t6, 0xffff8001
    beq t2, t6, check_continue_25
    j fail
check_continue_25:
# ----------------------------------------------------------------------
# TEST 26: LHU lower half zero extension
# ----------------------------------------------------------------------
test_26:
    li s11, 26
    li s9, 0x0026
    sw s9, 128(s8)
    lhu t2, 0(s0)
    li t6, 0x8001
    beq t2, t6, check_continue_26
    j fail
check_continue_26:
# ----------------------------------------------------------------------
# TEST 27: LH upper positive half
# ----------------------------------------------------------------------
test_27:
    li s11, 27
    li s9, 0x0027
    sw s9, 128(s8)
    lh t2, 2(s0)
    li t6, 0x7fff
    beq t2, t6, check_continue_27
    j fail
check_continue_27:
# ----------------------------------------------------------------------
# TEST 28: LHU upper negative-bit half
# ----------------------------------------------------------------------
test_28:
    li s11, 28
    li s9, 0x0028
    sw s9, 128(s8)
    li t0, 0x80011234
    sw t0, 0(s0)
    lhu t2, 2(s0)
    li t6, 0x8001
    beq t2, t6, check_continue_28
    j fail
check_continue_28:
# ----------------------------------------------------------------------
# TEST 29: LH upper negative half
# ----------------------------------------------------------------------
test_29:
    li s11, 29
    li s9, 0x0029
    sw s9, 128(s8)
    lh t2, 2(s0)
    li t6, 0xffff8001
    beq t2, t6, check_continue_29
    j fail
check_continue_29:
# ----------------------------------------------------------------------
# TEST 30: SH lower half preserves upper half
# ----------------------------------------------------------------------
test_30:
    li s11, 30
    li s9, 0x0030
    sw s9, 128(s8)
    li t0, 0x11223344
    sw t0, 0(s0)
    li t1, 0xa1b2
    sh t1, 0(s0)
    lw t2, 0(s0)
    li t6, 0x1122a1b2
    beq t2, t6, check_continue_30
    j fail
check_continue_30:
# ----------------------------------------------------------------------
# TEST 31: SH upper half preserves lower half
# ----------------------------------------------------------------------
test_31:
    li s11, 31
    li s9, 0x0031
    sw s9, 128(s8)
    li t1, 0xc3d4
    sh t1, 2(s0)
    lw t2, 0(s0)
    li t6, 0xc3d4a1b2
    beq t2, t6, check_continue_31
    j fail
check_continue_31:
# ----------------------------------------------------------------------
# TEST 32: LH immediately followed by dependent ADD
# ----------------------------------------------------------------------
test_32:
    li s11, 32
    li s9, 0x0032
    sw s9, 128(s8)
    lh t1, 0(s0)
    addi t2, t1, 1
    li t6, 0xffffa1b3
    beq t2, t6, check_continue_32
    j fail
check_continue_32:
# ----------------------------------------------------------------------
# TEST 33: LW-to-SH forwarding with upper-half mask
# ----------------------------------------------------------------------
test_33:
    li s11, 33
    li s9, 0x0033
    sw s9, 128(s8)
    li t0, 0x12345678
    sw t0, 0(s0)
    lw t1, 0(s0)
    sh t1, 2(s0)
    lw t2, 0(s0)
    li t6, 0x56785678
    beq t2, t6, check_continue_33
    j fail
check_continue_33:
# ----------------------------------------------------------------------
# TEST 34: SB lane 1 preserves other bytes
# ----------------------------------------------------------------------
test_34:
    li s11, 34
    li s9, 0x0034
    sw s9, 128(s8)
    li t0, 0x11223344
    sw t0, 0(s0)
    li t1, 0xaa
    sb t1, 1(s0)
    lw t2, 0(s0)
    li t6, 0x1122aa44
    beq t2, t6, check_continue_34
    j fail
check_continue_34:
# ----------------------------------------------------------------------
# TEST 35: SB lane 3 preserves other bytes
# ----------------------------------------------------------------------
test_35:
    li s11, 35
    li s9, 0x0035
    sw s9, 128(s8)
    li t1, 0xfe
    sb t1, 3(s0)
    lw t2, 0(s0)
    li t6, 0xfe22aa44
    beq t2, t6, check_continue_35
    j fail
check_continue_35:
# ----------------------------------------------------------------------
# TEST 36: LB sign extends lane 3
# ----------------------------------------------------------------------
test_36:
    li s11, 36
    li s9, 0x0036
    sw s9, 128(s8)
    lb t2, 3(s0)
    li t6, -2
    beq t2, t6, check_continue_36
    j fail
check_continue_36:
# ----------------------------------------------------------------------
# TEST 37: LBU zero extends lane 3
# ----------------------------------------------------------------------
test_37:
    li s11, 37
    li s9, 0x0037
    sw s9, 128(s8)
    lbu t2, 3(s0)
    li t6, 254
    beq t2, t6, check_continue_37
    j fail
check_continue_37:
# ----------------------------------------------------------------------
# TEST 38: LB sign extends lane 1
# ----------------------------------------------------------------------
test_38:
    li s11, 38
    li s9, 0x0038
    sw s9, 128(s8)
    lb t2, 1(s0)
    li t6, -86
    beq t2, t6, check_continue_38
    j fail
check_continue_38:
# ----------------------------------------------------------------------
# TEST 39: LBU zero extends lane 1
# ----------------------------------------------------------------------
test_39:
    li s11, 39
    li s9, 0x0039
    sw s9, 128(s8)
    lbu t2, 1(s0)
    li t6, 170
    beq t2, t6, check_continue_39
    j fail
check_continue_39:
# ----------------------------------------------------------------------
# TEST 40: Negative load/store offsets
# ----------------------------------------------------------------------
test_40:
    li s11, 40
    li s9, 0x0040
    sw s9, 128(s8)
    addi t0, s0, 8
    li t1, 0x76543210
    sw t1, -4(t0)
    lw t2, -4(t0)
    li t6, 0x76543210
    beq t2, t6, check_continue_40
    j fail
check_continue_40:
# ----------------------------------------------------------------------
# TEST 41: BEQ taken and not-taken outcomes
# ----------------------------------------------------------------------
test_41:
    li s11, 41
    li s9, 0x0041
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 42: BNE taken and not-taken outcomes
# ----------------------------------------------------------------------
test_42:
    li s11, 42
    li s9, 0x0042
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 43: BLT taken and not-taken outcomes
# ----------------------------------------------------------------------
test_43:
    li s11, 43
    li s9, 0x0043
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 44: BGE taken and not-taken outcomes
# ----------------------------------------------------------------------
test_44:
    li s11, 44
    li s9, 0x0044
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 45: BLTU taken and not-taken outcomes
# ----------------------------------------------------------------------
test_45:
    li s11, 45
    li s9, 0x0045
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 46: BGEU taken and not-taken outcomes
# ----------------------------------------------------------------------
test_46:
    li s11, 46
    li s9, 0x0046
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 47: Repeated taken loop then not-taken exit
# ----------------------------------------------------------------------
test_47:
    li s11, 47
    li s9, 0x0047
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 48: Same branch repeatedly not taken, then taken
# ----------------------------------------------------------------------
test_48:
    li s11, 48
    li s9, 0x0048
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 49: Alternating branch outcomes
# ----------------------------------------------------------------------
test_49:
    li s11, 49
    li s9, 0x0049
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 50: Taken branch squashes wrong-path store and register write
# ----------------------------------------------------------------------
test_50:
    li s11, 50
    li s9, 0x0050
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 51: LW immediately supplies branch comparison
# ----------------------------------------------------------------------
test_51:
    li s11, 51
    li s9, 0x0051
    sw s9, 128(s8)
    li t0, 37
    sw t0, 0(s0)
    lw t1, 0(s0)
    beq t1, t0, load_branch_done
    j fail
load_branch_done:


# ----------------------------------------------------------------------
# TEST 52: LH sign-extended value immediately supplies branch
# ----------------------------------------------------------------------
test_52:
    li s11, 52
    li s9, 0x0052
    sw s9, 128(s8)
    li t0, -2
    sh t0, 0(s0)
    lh t1, 0(s0)
    beq t1, t0, half_branch_done
    j fail
half_branch_done:


# ----------------------------------------------------------------------
# TEST 53: JAL return address and JALR return
# ----------------------------------------------------------------------
test_53:
    li s11, 53
    li s9, 0x0053
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 54: JAL x0 squashes fall-through operations
# ----------------------------------------------------------------------
test_54:
    li s11, 54
    li s9, 0x0054
    sw s9, 128(s8)
    li s3, 0
    jal zero, jump_zero_done
    addi s3, s3, 1
    addi s3, s3, 1
jump_zero_done:
    li t6, 0
    beq s3, t6, check_continue_54
    j fail
check_continue_54:
# ----------------------------------------------------------------------
# TEST 55: JALR clears target bit 0 and writes link
# ----------------------------------------------------------------------
test_55:
    li s11, 55
    li s9, 0x0055
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 56: Same JALR instruction alternates between two targets
# ----------------------------------------------------------------------
test_56:
    li s11, 56
    li s9, 0x0056
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 57: 32-entry BTB index collision: branch PCs differ by 128 bytes
# ----------------------------------------------------------------------
test_57:
    li s11, 57
    li s9, 0x0057
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 58: MUL signed low word
# ----------------------------------------------------------------------
test_58:
    li s11, 58
    li s9, 0x0058
    sw s9, 128(s8)
    li t0, 7
    li t1, -9
    mul t2, t0, t1
    li t6, -63
    beq t2, t6, check_continue_58
    j fail
check_continue_58:
# ----------------------------------------------------------------------
# TEST 59: MUL low-word overflow
# ----------------------------------------------------------------------
test_59:
    li s11, 59
    li s9, 0x0059
    sw s9, 128(s8)
    li t0, 0x80000000
    li t1, 2
    mul t2, t0, t1
    li t6, 0
    beq t2, t6, check_continue_59
    j fail
check_continue_59:
# ----------------------------------------------------------------------
# TEST 60: MULH signed negative high word
# ----------------------------------------------------------------------
test_60:
    li s11, 60
    li s9, 0x0060
    sw s9, 128(s8)
    li t0, -2
    li t1, 3
    mulh t2, t0, t1
    li t6, 0xffffffff
    beq t2, t6, check_continue_60
    j fail
check_continue_60:
# ----------------------------------------------------------------------
# TEST 61: MULH positive high word
# ----------------------------------------------------------------------
test_61:
    li s11, 61
    li s9, 0x0061
    sw s9, 128(s8)
    li t0, 0x40000000
    li t1, 4
    mulh t2, t0, t1
    li t6, 1
    beq t2, t6, check_continue_61
    j fail
check_continue_61:
# ----------------------------------------------------------------------
# TEST 62: MULHU unsigned high word
# ----------------------------------------------------------------------
test_62:
    li s11, 62
    li s9, 0x0062
    sw s9, 128(s8)
    li t0, 0xffffffff
    li t1, 0xffffffff
    mulhu t2, t0, t1
    li t6, 0xfffffffe
    beq t2, t6, check_continue_62
    j fail
check_continue_62:
# ----------------------------------------------------------------------
# TEST 63: MULHSU signed by unsigned high word
# ----------------------------------------------------------------------
test_63:
    li s11, 63
    li s9, 0x0063
    sw s9, 128(s8)
    li t0, -2
    li t1, 0xffffffff
    mulhsu t2, t0, t1
    li t6, 0xfffffffe
    beq t2, t6, check_continue_63
    j fail
check_continue_63:
# ----------------------------------------------------------------------
# TEST 64: DIV truncates toward zero
# ----------------------------------------------------------------------
test_64:
    li s11, 64
    li s9, 0x0064
    sw s9, 128(s8)
    li t0, -20
    li t1, 3
    div t2, t0, t1
    li t6, -6
    beq t2, t6, check_continue_64
    j fail
check_continue_64:
# ----------------------------------------------------------------------
# TEST 65: DIVU unsigned division
# ----------------------------------------------------------------------
test_65:
    li s11, 65
    li s9, 0x0065
    sw s9, 128(s8)
    li t0, 0xfffffff0
    li t1, 16
    divu t2, t0, t1
    li t6, 0x0fffffff
    beq t2, t6, check_continue_65
    j fail
check_continue_65:
# ----------------------------------------------------------------------
# TEST 66: REM follows dividend sign
# ----------------------------------------------------------------------
test_66:
    li s11, 66
    li s9, 0x0066
    sw s9, 128(s8)
    li t0, -20
    li t1, 3
    rem t2, t0, t1
    li t6, -2
    beq t2, t6, check_continue_66
    j fail
check_continue_66:
# ----------------------------------------------------------------------
# TEST 67: REMU unsigned remainder
# ----------------------------------------------------------------------
test_67:
    li s11, 67
    li s9, 0x0067
    sw s9, 128(s8)
    li t0, 29
    li t1, 6
    remu t2, t0, t1
    li t6, 5
    beq t2, t6, check_continue_67
    j fail
check_continue_67:
# ----------------------------------------------------------------------
# TEST 68: DIV by zero
# ----------------------------------------------------------------------
test_68:
    li s11, 68
    li s9, 0x0068
    sw s9, 128(s8)
    li t0, 123
    li t1, 0
    div t2, t0, t1
    li t6, 0xffffffff
    beq t2, t6, check_continue_68
    j fail
check_continue_68:
# ----------------------------------------------------------------------
# TEST 69: DIVU by zero
# ----------------------------------------------------------------------
test_69:
    li s11, 69
    li s9, 0x0069
    sw s9, 128(s8)
    li t0, 123
    li t1, 0
    divu t2, t0, t1
    li t6, 0xffffffff
    beq t2, t6, check_continue_69
    j fail
check_continue_69:
# ----------------------------------------------------------------------
# TEST 70: REM by zero preserves dividend
# ----------------------------------------------------------------------
test_70:
    li s11, 70
    li s9, 0x0070
    sw s9, 128(s8)
    li t0, -123
    li t1, 0
    rem t2, t0, t1
    li t6, -123
    beq t2, t6, check_continue_70
    j fail
check_continue_70:
# ----------------------------------------------------------------------
# TEST 71: REMU by zero preserves dividend
# ----------------------------------------------------------------------
test_71:
    li s11, 71
    li s9, 0x0071
    sw s9, 128(s8)
    li t0, 0xabcdef01
    li t1, 0
    remu t2, t0, t1
    li t6, 0xabcdef01
    beq t2, t6, check_continue_71
    j fail
check_continue_71:
# ----------------------------------------------------------------------
# TEST 72: DIV signed overflow
# ----------------------------------------------------------------------
test_72:
    li s11, 72
    li s9, 0x0072
    sw s9, 128(s8)
    li t0, 0x80000000
    li t1, -1
    div t2, t0, t1
    li t6, 0x80000000
    beq t2, t6, check_continue_72
    j fail
check_continue_72:
# ----------------------------------------------------------------------
# TEST 73: REM signed overflow
# ----------------------------------------------------------------------
test_73:
    li s11, 73
    li s9, 0x0073
    sw s9, 128(s8)
    li t0, 0x80000000
    li t1, -1
    rem t2, t0, t1
    li t6, 0
    beq t2, t6, check_continue_73
    j fail
check_continue_73:
# ----------------------------------------------------------------------
# TEST 74: DIV negative divisor
# ----------------------------------------------------------------------
test_74:
    li s11, 74
    li s9, 0x0074
    sw s9, 128(s8)
    li t0, 20
    li t1, -3
    div t2, t0, t1
    li t6, -6
    beq t2, t6, check_continue_74
    j fail
check_continue_74:
# ----------------------------------------------------------------------
# TEST 75: REM positive dividend with negative divisor
# ----------------------------------------------------------------------
test_75:
    li s11, 75
    li s9, 0x0075
    sw s9, 128(s8)
    li t0, 20
    li t1, -3
    rem t2, t0, t1
    li t6, 2
    beq t2, t6, check_continue_75
    j fail
check_continue_75:
# ----------------------------------------------------------------------
# TEST 76: MUL immediately supplies branch operand
# ----------------------------------------------------------------------
test_76:
    li s11, 76
    li s9, 0x0076
    sw s9, 128(s8)
    li t0, 6
    li t1, 7
    li t3, 42
    mul t2, t0, t1
    beq t2, t3, mul_branch_done
    j fail
mul_branch_done:


# ----------------------------------------------------------------------
# TEST 77: MUL result immediately stored
# ----------------------------------------------------------------------
test_77:
    li s11, 77
    li s9, 0x0077
    sw s9, 128(s8)
    li t0, 13
    li t1, 9
    mul t2, t0, t1
    sw t2, 24(s0)
    lw t3, 24(s0)
    li t6, 117
    beq t3, t6, check_continue_76
    j fail
check_continue_76:
# ----------------------------------------------------------------------
# TEST 78: Back-to-back dependent MUL DIV REM and ADD
# ----------------------------------------------------------------------
test_78:
    li s11, 78
    li s9, 0x0078
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 79: Mispredicted path must not launch a DIV
# ----------------------------------------------------------------------
test_79:
    li s11, 79
    li s9, 0x0079
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 80: Branch target is its own PC plus 4
# ----------------------------------------------------------------------
test_80:
    li s11, 80
    li s9, 0x0080
    sw s9, 128(s8)
    li t0, 5
    beq t0, t0, same_next
same_next:
    addi t2, t0, 1
    li t6, 6
    beq t2, t6, check_continue_81
    j fail
check_continue_81:
# ----------------------------------------------------------------------
# TEST 81: Same conditional branch uses all four counter states
# ----------------------------------------------------------------------
test_81:
    li s11, 81
    li s9, 0x0081
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 82: Wrong predicted-taken path cannot commit a store on loop exit
# ----------------------------------------------------------------------
test_82:
    li s11, 82
    li s9, 0x0082
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 83: Zero destination load must not corrupt x0
# ----------------------------------------------------------------------
test_83:
    li s11, 83
    li s9, 0x0083
    sw s9, 128(s8)
    li t0, 0x89abcdef
    sw t0, 0(s0)
    lw zero, 0(s0)
    addi t2, zero, 9
    li t6, 9
    beq t2, t6, check_continue_85
    j fail
check_continue_85:
# ----------------------------------------------------------------------
# TEST 84: Load immediately supplies JALR target
# ----------------------------------------------------------------------
test_84:
    li s11, 84
    li s9, 0x0084
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 85: Consecutive opposite branches
# ----------------------------------------------------------------------
test_85:
    li s11, 85
    li s9, 0x0085
    sw s9, 128(s8)
    li t0, 1
    bne t0, zero, check_continue_87
    j fail
check_continue_87:
    bne t0, zero, consecutive_target
    j fail
consecutive_target:


# ----------------------------------------------------------------------
# TEST 86: SH truncates source to 16 bits and preserves the other half
# ----------------------------------------------------------------------
test_86:
    li s11, 86
    li s9, 0x0086
    sw s9, 128(s8)
    li t0, 0x11223344
    sw t0, 0(s0)
    li t1, 0xdeadbeef
    sh t1, 2(s0)
    lw t2, 0(s0)
    li t6, 0xbeef3344
    beq t2, t6, check_continue_88
    j fail
check_continue_88:
# ----------------------------------------------------------------------
# TEST 87: Half-word boundaries zero 7fff 8000 ffff
# ----------------------------------------------------------------------
test_87:
    li s11, 87
    li s9, 0x0087
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 88: SB lanes 0 and 2 preserve other bytes
# ----------------------------------------------------------------------
test_88:
    li s11, 88
    li s9, 0x0088
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 89: Register shift masks shift amount to five bits
# ----------------------------------------------------------------------
test_89:
    li s11, 89
    li s9, 0x0089
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 90: Signed versus unsigned branch limits and equality
# ----------------------------------------------------------------------
test_90:
    li s11, 90
    li s9, 0x0090
    sw s9, 128(s8)
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


# ----------------------------------------------------------------------
# TEST 91: Multiply zero and signed minimum boundaries
# ----------------------------------------------------------------------
test_91:
    li s11, 91
    li s9, 0x0091
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 92: Divide zero dividend and dividend smaller than divisor
# ----------------------------------------------------------------------
test_92:
    li s11, 92
    li s9, 0x0092
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 93: MUL and DIV writing x0 do not break following instructions
# ----------------------------------------------------------------------
test_93:
    li s11, 93
    li s9, 0x0093
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 94: DIV result immediately feeds a branch, then store
# ----------------------------------------------------------------------
test_94:
    li s11, 94
    li s9, 0x0094
    sw s9, 128(s8)
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
# ----------------------------------------------------------------------
# TEST 95: Nested calls and returns preserve both link addresses
# ----------------------------------------------------------------------
test_95:
    li s11, 95
    li s9, 0x0095
    sw s9, 128(s8)
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
# All checks passed.
pass:
    li s10, 0xC001BEEF
    li s11, 95
    la t0, result_signature
    sw s10, 0(t0)
    sw s11, 4(t0)
    sw s10, 128(s8)
pass_halt:
    j pass_halt

# s11 identifies the first failing test. Do not change it here.
fail:
    li s10, 0xDEAD0000
    or s10, s10, s11
    la t0, result_signature
    sw s10, 0(t0)
    sw s11, 4(t0)
    lui t1, 0xdead0
    or t1, t1, s9
    sw t1, 128(s8)
fail_halt:
    j fail_halt
