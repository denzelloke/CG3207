# CG3207 Lab 3 Tasks 1 and 2: processor arithmetic regression / board demo
# New test program, for educational use. No course RTL is embedded here.
# 42 self-checking cases. Required arithmetic: MUL, DIV, DIVU only.
# No MULHSU, MULH, REM, byte/halfword accesses, ECALL, or divide-by-zero.
# All instructions are real RV32 instructions (no LI/LA pseudoinstructions).
#
# PREREQUISITES IN RV.v:
#   Operand1/Operand2 must be [31:0]; MCycle instance must use width=32.
#   WE = RegWrite && WE_PC && !RESET; WE_PC = !Busy.
#   Decoder recognizes Opcode=0x33, Funct7=0x01 as ALUControl=0xf.
#
# RARS / Vivado workflow:
#   Use RV32 and default memory map: .text=0x00400000, .data=0x10010000.
#   Assemble this file. Dump .text as Hexadecimal Text to AA_IROM.mem.
#   Add the dump as a memory initialization source at the path Wrapper reads.
#   No .data initialization is needed: every location read is written first.
#   Wrapper still reads AA_DMEM.mem: retain an existing valid file, or use a
#   file with 128 lines of 00000000 for its 512-byte data memory.
#   Simulate test_Wrapper, not test_MCycle, to execute this program.
#   Rerun synthesis/implementation for a hardware bitstream after changing ROM.
#   MMIO stores are for this Wrapper; running this program in ordinary RARS
#   without matching MMIO can give an address error. Use RARS to assemble/dump.
#
# BOARD: after completion set DIP[7:0]=0 to see summary.
#   PASS: LEDs=FF, seven-segment=600D002A (42 tests, decimal).
#   FAIL: LEDs=failing test ID, seven-segment=BAD000xx (hex ID).
#   DIP[7:0]=1..42: inspect a completed test; seven-segment shows its result.
#   DIP[8]=0: actual result. DIP[8]=1: expected result. LEDs show test ID.
#   On failure, only IDs up to the failed test are valid.
#   Intermediate LED activity is not a pass indication. No UART is required.
#
# DMEM diagnostics (word-aligned):
#   0x10010000: status (0=running, 1=pass, 0xffffffff=fail)
#   0x10010004: last/current test ID
#   0x10010008: last actual result
#   0x1001000c: last expected result
#   0x10010010: number of successful tests
#   0x10010014: final display signature
#   0x10010040 + 8*(ID-1): actual; next word: expected
# Register roles: s0=DMEM, s1=MMIO, s2=ID, s3=pass count, s4=log pointer,
# s5=final ID, s6=summary signature, s7=summary LED pattern.
# Task 1 ALSO needs standalone MCycle HDL simulation; this program tests Task 2.
# Expected per-operation cycle counts for the current RTL: MUL=64 iterations
# in signed mode (32 if mapped to unsigned mode), DIV/DIVU=32, plus commit edge.
# A completed suite remains in a display loop; it intentionally never ECALLs.

.text
.globl main
main:
    lui s0, 0x10010
    lui s1, 0xffff0
    addi s3, x0, 0
    addi s4, s0, 64
    sw x0, 0(s0)
    sw x0, 4(s0)
    sw x0, 8(s0)
    sw x0, 12(s0)
    sw x0, 16(s0)
    sw x0, 20(s0)
    sw x0, 96(s1)
    sw x0, 128(s1)

# Test 01: Detect four-bit operand truncation
# MUL A=0x00000014, B=0x00000003; checked value=0x0000003C.
test_01:
    addi s2, x0, 1
    sw s2, 4(s0)
    addi t0, x0, 20
    addi t1, x0, 3
    addi t3, x0, 60
    mul t2, t0, t1
    jal ra, check_result

# Test 02: Zero multiplicand
# MUL A=0x00000000, B=0xFFFFFFFF; checked value=0x00000000.
test_02:
    addi s2, x0, 2
    sw s2, 4(s0)
    addi t0, x0, 0
    addi t1, x0, -1
    addi t3, x0, 0
    mul t2, t0, t1
    jal ra, check_result

# Test 03: Multiply by one
# MUL A=0x00000001, B=0x12345678; checked value=0x12345678.
test_03:
    addi s2, x0, 3
    sw s2, 4(s0)
    addi t0, x0, 1
    lui t1, 0x12345
    addi t1, t1, 1656
    lui t3, 0x12345
    addi t3, t3, 1656
    mul t2, t0, t1
    jal ra, check_result

# Test 04: Negative times positive
# MUL A=0xFFFFFFF9, B=0x00000003; checked value=0xFFFFFFEB.
test_04:
    addi s2, x0, 4
    sw s2, 4(s0)
    addi t0, x0, -7
    addi t1, x0, 3
    addi t3, x0, -21
    mul t2, t0, t1
    jal ra, check_result

# Test 05: Positive times negative
# MUL A=0x00000007, B=0xFFFFFFFD; checked value=0xFFFFFFEB.
test_05:
    addi s2, x0, 5
    sw s2, 4(s0)
    addi t0, x0, 7
    addi t1, x0, -3
    addi t3, x0, -21
    mul t2, t0, t1
    jal ra, check_result

# Test 06: Two negative operands
# MUL A=0xFFFFFFF9, B=0xFFFFFFFD; checked value=0x00000015.
test_06:
    addi s2, x0, 6
    sw s2, 4(s0)
    addi t0, x0, -7
    addi t1, x0, -3
    addi t3, x0, 21
    mul t2, t0, t1
    jal ra, check_result

# Test 07: Full-width positive product
# MUL A=0x12345678, B=0x00000003; checked value=0x369D0368.
test_07:
    addi s2, x0, 7
    sw s2, 4(s0)
    lui t0, 0x12345
    addi t0, t0, 1656
    addi t1, x0, 3
    lui t3, 0x369d0
    addi t3, t3, 872
    mul t2, t0, t1
    jal ra, check_result

# Test 08: Low-word overflow: product is 0x00000001_00000000
# MUL A=0x00010000, B=0x00010000; checked value=0x00000000.
test_08:
    addi s2, x0, 8
    sw s2, 4(s0)
    lui t0, 0x00010
    addi t0, t0, 0
    lui t1, 0x00010
    addi t1, t1, 0
    addi t3, x0, 0
    mul t2, t0, t1
    jal ra, check_result

# Test 09: Low-word wraparound
# MUL A=0x7FFFFFFF, B=0x00000002; checked value=0xFFFFFFFE.
test_09:
    addi s2, x0, 9
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, -1
    addi t1, x0, 2
    addi t3, x0, -2
    mul t2, t0, t1
    jal ra, check_result

# Test 10: Minimum signed value times one
# MUL A=0x80000000, B=0x00000001; checked value=0x80000000.
test_10:
    addi s2, x0, 10
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, 0
    addi t1, x0, 1
    lui t3, 0x80000
    addi t3, t3, 0
    mul t2, t0, t1
    jal ra, check_result

# Test 11: Minimum signed value times minus one
# MUL A=0x80000000, B=0xFFFFFFFF; checked value=0x80000000.
test_11:
    addi s2, x0, 11
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, 0
    addi t1, x0, -1
    lui t3, 0x80000
    addi t3, t3, 0
    mul t2, t0, t1
    jal ra, check_result

# Test 12: All-ones times all-ones
# MUL A=0xFFFFFFFF, B=0xFFFFFFFF; checked value=0x00000001.
test_12:
    addi s2, x0, 12
    sw s2, 4(s0)
    addi t0, x0, -1
    addi t1, x0, -1
    addi t3, x0, 1
    mul t2, t0, t1
    jal ra, check_result

# Test 13: Positive non-exact division
# DIV A=0x00000064, B=0x00000007; checked value=0x0000000E.
test_13:
    addi s2, x0, 13
    sw s2, 4(s0)
    addi t0, x0, 100
    addi t1, x0, 7
    addi t3, x0, 14
    div t2, t0, t1
    jal ra, check_result

# Test 14: Negative dividend; truncate toward zero
# DIV A=0xFFFFFF9C, B=0x00000007; checked value=0xFFFFFFF2.
test_14:
    addi s2, x0, 14
    sw s2, 4(s0)
    addi t0, x0, -100
    addi t1, x0, 7
    addi t3, x0, -14
    div t2, t0, t1
    jal ra, check_result

# Test 15: Negative divisor; truncate toward zero
# DIV A=0x00000064, B=0xFFFFFFF9; checked value=0xFFFFFFF2.
test_15:
    addi s2, x0, 15
    sw s2, 4(s0)
    addi t0, x0, 100
    addi t1, x0, -7
    addi t3, x0, -14
    div t2, t0, t1
    jal ra, check_result

# Test 16: Both operands negative
# DIV A=0xFFFFFF9C, B=0xFFFFFFF9; checked value=0x0000000E.
test_16:
    addi s2, x0, 16
    sw s2, 4(s0)
    addi t0, x0, -100
    addi t1, x0, -7
    addi t3, x0, 14
    div t2, t0, t1
    jal ra, check_result

# Test 17: Zero dividend
# DIV A=0x00000000, B=0xFFFFFFFD; checked value=0x00000000.
test_17:
    addi s2, x0, 17
    sw s2, 4(s0)
    addi t0, x0, 0
    addi t1, x0, -3
    addi t3, x0, 0
    div t2, t0, t1
    jal ra, check_result

# Test 18: Dividend smaller than divisor
# DIV A=0x00000003, B=0x00000009; checked value=0x00000000.
test_18:
    addi s2, x0, 18
    sw s2, 4(s0)
    addi t0, x0, 3
    addi t1, x0, 9
    addi t3, x0, 0
    div t2, t0, t1
    jal ra, check_result

# Test 19: Negative small dividend gives zero
# DIV A=0xFFFFFFFD, B=0x00000009; checked value=0x00000000.
test_19:
    addi s2, x0, 19
    sw s2, 4(s0)
    addi t0, x0, -3
    addi t1, x0, 9
    addi t3, x0, 0
    div t2, t0, t1
    jal ra, check_result

# Test 20: Minimum signed dividend
# DIV A=0x80000000, B=0x00000001; checked value=0x80000000.
test_20:
    addi s2, x0, 20
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, 0
    addi t1, x0, 1
    lui t3, 0x80000
    addi t3, t3, 0
    div t2, t0, t1
    jal ra, check_result

# Test 21: Signed overflow: width-bit quotient is 0x80000000
# DIV A=0x80000000, B=0xFFFFFFFF; checked value=0x80000000.
test_21:
    addi s2, x0, 21
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, 0
    addi t1, x0, -1
    lui t3, 0x80000
    addi t3, t3, 0
    div t2, t0, t1
    jal ra, check_result

# Test 22: Minimum signed dividend divided by three
# DIV A=0x80000000, B=0x00000003; checked value=0xD5555556.
test_22:
    addi s2, x0, 22
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, 0
    addi t1, x0, 3
    lui t3, 0xd5555
    addi t3, t3, 1366
    div t2, t0, t1
    jal ra, check_result

# Test 23: Maximum signed dividend divided by minus one
# DIV A=0x7FFFFFFF, B=0xFFFFFFFF; checked value=0x80000001.
test_23:
    addi s2, x0, 23
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, -1
    addi t1, x0, -1
    lui t3, 0x80000
    addi t3, t3, 1
    div t2, t0, t1
    jal ra, check_result

# Test 24: Equal minimum signed operands
# DIV A=0x80000000, B=0x80000000; checked value=0x00000001.
test_24:
    addi s2, x0, 24
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, 0
    lui t1, 0x80000
    addi t1, t1, 0
    addi t3, x0, 1
    div t2, t0, t1
    jal ra, check_result

# Test 25: Large-magnitude negative divisor
# DIV A=0x00000007, B=0x80000000; checked value=0x00000000.
test_25:
    addi s2, x0, 25
    sw s2, 4(s0)
    addi t0, x0, 7
    lui t1, 0x80000
    addi t1, t1, 0
    addi t3, x0, 0
    div t2, t0, t1
    jal ra, check_result

# Test 26: Unsigned non-exact division
# DIVU A=0x00000064, B=0x00000007; checked value=0x0000000E.
test_26:
    addi s2, x0, 26
    sw s2, 4(s0)
    addi t0, x0, 100
    addi t1, x0, 7
    addi t3, x0, 14
    divu t2, t0, t1
    jal ra, check_result

# Test 27: All-ones is a large positive unsigned dividend
# DIVU A=0xFFFFFFFF, B=0x00000003; checked value=0x55555555.
test_27:
    addi s2, x0, 27
    sw s2, 4(s0)
    addi t0, x0, -1
    addi t1, x0, 3
    lui t3, 0x55555
    addi t3, t3, 1365
    divu t2, t0, t1
    jal ra, check_result

# Test 28: Unsigned dividend has bit 31 set
# DIVU A=0x80000000, B=0x00000002; checked value=0x40000000.
test_28:
    addi s2, x0, 28
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, 0
    addi t1, x0, 2
    lui t3, 0x40000
    addi t3, t3, 0
    divu t2, t0, t1
    jal ra, check_result

# Test 29: Largest unsigned quotient
# DIVU A=0xFFFFFFFF, B=0x00000001; checked value=0xFFFFFFFF.
test_29:
    addi s2, x0, 29
    sw s2, 4(s0)
    addi t0, x0, -1
    addi t1, x0, 1
    addi t3, x0, -1
    divu t2, t0, t1
    jal ra, check_result

# Test 30: Zero divided by largest unsigned divisor
# DIVU A=0x00000000, B=0xFFFFFFFF; checked value=0x00000000.
test_30:
    addi s2, x0, 30
    sw s2, 4(s0)
    addi t0, x0, 0
    addi t1, x0, -1
    addi t3, x0, 0
    divu t2, t0, t1
    jal ra, check_result

# Test 31: Unsigned dividend smaller than divisor
# DIVU A=0x00000003, B=0x00000009; checked value=0x00000000.
test_31:
    addi s2, x0, 31
    sw s2, 4(s0)
    addi t0, x0, 3
    addi t1, x0, 9
    addi t3, x0, 0
    divu t2, t0, t1
    jal ra, check_result

# Test 32: Equal largest operands
# DIVU A=0xFFFFFFFF, B=0xFFFFFFFF; checked value=0x00000001.
test_32:
    addi s2, x0, 32
    sw s2, 4(s0)
    addi t0, x0, -1
    addi t1, x0, -1
    addi t3, x0, 1
    divu t2, t0, t1
    jal ra, check_result

# Test 33: Equal operands with bit 31 set
# DIVU A=0x80000000, B=0x80000000; checked value=0x00000001.
test_33:
    addi s2, x0, 33
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, 0
    lui t1, 0x80000
    addi t1, t1, 0
    addi t3, x0, 1
    divu t2, t0, t1
    jal ra, check_result

# Test 34: Divisor has bit 31 set
# DIVU A=0xFFFFFFFF, B=0x80000000; checked value=0x00000001.
test_34:
    addi s2, x0, 34
    sw s2, 4(s0)
    addi t0, x0, -1
    lui t1, 0x80000
    addi t1, t1, 0
    addi t3, x0, 1
    divu t2, t0, t1
    jal ra, check_result

# Test 35: High-bit divisor exceeds dividend
# DIVU A=0x7FFFFFFF, B=0x80000000; checked value=0x00000000.
test_35:
    addi s2, x0, 35
    sw s2, 4(s0)
    lui t0, 0x80000
    addi t0, t0, -1
    lui t1, 0x80000
    addi t1, t1, 0
    addi t3, x0, 0
    divu t2, t0, t1
    jal ra, check_result

# Test 36: Full-width multi-bit operands
# DIVU A=0x12345678, B=0x00001234; checked value=0x00010004.
test_36:
    addi s2, x0, 36
    sw s2, 4(s0)
    lui t0, 0x12345
    addi t0, t0, 1656
    lui t1, 0x00001
    addi t1, t1, 564
    lui t3, 0x00010
    addi t3, t3, 4
    divu t2, t0, t1
    jal ra, check_result

# Test 37: Destination overlaps first source
# MUL A=0x12345678, B=0x00000003; checked value=0x369D0368.
test_37:
    addi s2, x0, 37
    sw s2, 4(s0)
    lui t0, 0x12345
    addi t0, t0, 1656
    addi t1, x0, 3
    lui t3, 0x369d0
    addi t3, t3, 872
    mul t0, t0, t1
    addi t2, t0, 0
    jal ra, check_result

# Test 38: Destination overlaps negative dividend; detects premature writes
# DIV A=0xFFFFFF9C, B=0x00000007; checked value=0xFFFFFFF2.
test_38:
    addi s2, x0, 38
    sw s2, 4(s0)
    addi t0, x0, -100
    addi t1, x0, 7
    addi t3, x0, -14
    div t0, t0, t1
    addi t2, t0, 0
    jal ra, check_result

# Test 39: Destination overlaps negative divisor; detects premature writes
# DIV A=0x00000064, B=0xFFFFFFF9; checked value=0xFFFFFFF2.
test_39:
    addi s2, x0, 39
    sw s2, 4(s0)
    addi t0, x0, 100
    addi t1, x0, -7
    addi t3, x0, -14
    div t1, t0, t1
    addi t2, t1, 0
    jal ra, check_result

# Test 40: Unsigned destination overlaps dividend
# DIVU A=0xFFFFFFFF, B=0x00000003; checked value=0x55555555.
test_40:
    addi s2, x0, 40
    sw s2, 4(s0)
    addi t0, x0, -1
    addi t1, x0, 3
    lui t3, 0x55555
    addi t3, t3, 1365
    divu t0, t0, t1
    addi t2, t0, 0
    jal ra, check_result

# Test 41: Writing x0 must be ignored
# MUL A=0x00000007, B=0x00000003; checked value=0x00000000.
test_41:
    addi s2, x0, 41
    sw s2, 4(s0)
    addi t0, x0, 7
    addi t1, x0, 3
    addi t3, x0, 0
    mul x0, t0, t1
    addi t2, x0, 0
    jal ra, check_result

# Test 42: back-to-back dependent multicycle instructions, no separating NOPs.
# MUL gives 63; DIV gives 9; DIVU gives 1. Also overlaps rd with rs1.
test_42:
    addi s2, x0, 42
    sw s2, 4(s0)
    addi t0, x0, 9
    addi t1, x0, 7
    addi t3, x0, 1
    mul t2, t0, t1
    div t2, t2, t1
    divu t2, t2, t1
    jal ra, check_result

    # All comparisons passed.
    addi t4, x0, 1
    sw t4, 0(s0)
    lui s6, 0x600d0
    addi s6, s6, 42
    addi s7, x0, 255
    addi s5, s2, 0
    sw s6, 20(s0)
    jal x0, show_summary

# Called only after each test result is available in t2; expected is in t3.
# Does not modify t0/t1/t2/t3 or ra, except returning via ra.
check_result:
    sw t2, 8(s0)
    sw t3, 12(s0)
    sw t2, 0(s4)
    sw t3, 4(s4)
    bne t2, t3, failed
    addi s3, s3, 1
    sw s3, 16(s0)
    addi s4, s4, 8
    jalr x0, ra, 0

failed:
    addi t4, x0, -1
    sw t4, 0(s0)
    lui s6, 0xbad00
    or s6, s6, s2
    addi s7, s2, 0
    addi s5, s2, 0
    sw s6, 20(s0)

show_summary:
    sw s7, 96(s1)
    sw s6, 128(s1)

# Read DIP only after testing completes. DIP[8] chooses actual/expected.
browse:
    lw t4, 100(s1)
    andi t5, t4, 255
    beq t5, x0, show_summary
    bltu s5, t5, show_summary
    addi t6, t5, -1
    slli t6, t6, 3
    add t6, t6, s0
    addi t6, t6, 64
    andi t4, t4, 256
    beq t4, x0, load_selected
    addi t6, t6, 4
load_selected:
    lw t4, 0(t6)
    sw t5, 96(s1)
    sw t4, 128(s1)
    jal x0, browse
