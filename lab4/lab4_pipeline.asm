#----------------------------------------------------------------------------------
#-- (c) Rajesh Panicker
#-- License terms :
#-- You are free to use this code as long as you
#-- (i) DO NOT post it on any public repository;
#-- (ii) use it only for educational purposes;
#-- (iii) accept the responsibility to ensure that your implementation does not violate anyone's intellectual property.
#-- (iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
#-- (v) send an email to rajesh<dot>panicker<at>ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
#-- (vi) retain this notice in this file and any files derived from this.
#----------------------------------------------------------------------------------
# MMIO addresses follow the supplied course reference. Pipeline tests and result handling were adapted for this project.

.eqv MMIO_BASE 0xFFFF0000
.eqv SEVENSEG_OFF 0x80
.text
.globl main


# RV32 pipeline and multicycle smoke test. All instructions are 32-bit real instructions.

# Assemble text at 0x00400000. RAM base is 0x10010000; this matches the supplied testbench.

# x20 = RAM base; x28 = decimal display digits of test ID; x29 = expected; x30 = status; x31 = MMIO base.

# RAM +4: checkpoint value; +8: wrong-path sentinel; +56: failed display ID; +60: final status.

# Seven-segment MMIO = 0xFFFF0080. PASS = C001BEEF; failure = DEAD + four decimal test digits.

# For example: test 10 fails as DEAD0010, test 24 as DEAD0024. No ECALL is used.
main:
    addi   x0, x0, 0
    addi   x0, x0, 0
    lui    x31, 0xffff0
    sw     x0, SEVENSEG_OFF(x31)
    lui    x20, 0x10010
    sw     x0, 8(x20)

# TEST 01: M-to-E ALU forwarding
test_01:

# x28 holds display digits 0x0001 for test 1.
    addi   x28, x0, 1
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 12
    addi   x5, x0, 5
    addi   x6, x5, 7
    bne    x6, x29, fail
    sw     x6, 4(x20)

# TEST 02: W-to-E ALU forwarding
test_02:

# x28 holds display digits 0x0002 for test 2.
    addi   x28, x0, 2
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 18
    addi   x5, x0, 9
    addi   x0, x0, 0
    add    x6, x5, x5
    bne    x6, x29, fail
    sw     x6, 4(x20)

# TEST 03: W-to-D forwarding / register-file same-edge bypass
test_03:

# x28 holds display digits 0x0003 for test 3.
    addi   x28, x0, 3
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 23
    addi   x5, x0, 20
    addi   x0, x0, 0
    addi   x0, x0, 0
    addi   x6, x5, 3
    bne    x6, x29, fail
    sw     x6, 4(x20)

# TEST 04: M forwarding takes priority over older W result
test_04:

# x28 holds display digits 0x0004 for test 4.
    addi   x28, x0, 4
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 6
    addi   x5, x0, 1
    addi   x5, x5, 2
    add    x6, x5, x5
    bne    x6, x29, fail
    sw     x6, 4(x20)

# TEST 05: Load-use stall followed by ALU use
test_05:

# x28 holds display digits 0x0005 for test 5.
    addi   x28, x0, 5
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 84
    addi   x5, x0, 42
    sw     x5, 256(x20)
    lw     x6, 256(x20)
    add    x7, x6, x6
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 06: Adjacent load-to-store data forwarding (no rs2 store stall)
test_06:

# x28 holds display digits 0x0006 for test 6.
    addi   x28, x0, 6
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 77
    addi   x5, x0, 77
    sw     x5, 260(x20)
    lw     x6, 260(x20)
    sw     x6, 264(x20)
    lw     x7, 264(x20)
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 07: ALU result forwarded into store data
test_07:

# x28 holds display digits 0x0007 for test 7.
    addi   x28, x0, 7
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 91
    addi   x5, x0, 91
    sw     x5, 268(x20)
    lw     x6, 268(x20)
    bne    x6, x29, fail
    sw     x6, 4(x20)

# TEST 08: Taken BEQ/BNE and wrong-path store flushing
test_08:

# x28 holds display digits 0x0008 for test 8.
    addi   x28, x0, 8
    sw     x28, SEVENSEG_OFF(x31)
    addi   x5, x0, 1
    beq    x5, x5, beq_target
    sw     x28, 8(x20)
    sw     x28, 8(x20)
beq_target:
    bne    x5, x0, bne_target
    sw     x28, 8(x20)
    sw     x28, 8(x20)
bne_target:
    addi   x29, x0, 8
    addi   x6, x0, 8
    bne    x6, x29, fail
    sw     x6, 4(x20)

# TEST 09: Not-taken BEQ/BNE
test_09:

# x28 holds display digits 0x0009 for test 9.
    addi   x28, x0, 9
    sw     x28, SEVENSEG_OFF(x31)
    addi   x5, x0, 1
    beq    x5, x0, fail
    bne    x5, x5, fail
    addi   x29, x0, 9
    addi   x6, x0, 9
    bne    x6, x29, fail
    sw     x6, 4(x20)

# TEST 10: Signed BLT/BGE distinguish negative operands
test_10:

# x28 holds display digits 0x0010 for test 10.
    addi   x28, x0, 16
    sw     x28, SEVENSEG_OFF(x31)
    addi   x5, x0, -1
    addi   x6, x0, 1
    blt    x5, x6, blt_target
    jal    x0, fail
blt_target:
    bge    x6, x5, bge_target
    jal    x0, fail
bge_target:
    bge    x5, x6, fail
    blt    x6, x5, fail
    addi   x29, x0, 10
    addi   x7, x0, 10
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 11: Unsigned BLTU/BGEU distinguish high-bit operands
test_11:

# x28 holds display digits 0x0011 for test 11.
    addi   x28, x0, 17
    sw     x28, SEVENSEG_OFF(x31)
    addi   x5, x0, -1
    addi   x6, x0, 1
    bltu   x6, x5, bltu_target
    jal    x0, fail
bltu_target:
    bgeu   x5, x6, bgeu_target
    jal    x0, fail
bgeu_target:
    bltu   x5, x6, fail
    bgeu   x6, x5, fail
    addi   x29, x0, 11
    addi   x7, x0, 11
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 12: LUI value and immediate consumer
test_12:

# x28 holds display digits 0x0012 for test 12.
    addi   x28, x0, 18
    sw     x28, SEVENSEG_OFF(x31)
    lui    x29, 0x12345
    addi   x29, x29, 103
    lui    x5, 0x12345
    addi   x6, x5, 103
    bne    x6, x29, fail
    sw     x6, 4(x20)

# TEST 13: AUIPC uses the executing instruction PC
test_13:

# x28 holds display digits 0x0013 for test 13.
    addi   x28, x0, 19
    sw     x28, SEVENSEG_OFF(x31)
    lui    x29, 0x00401
    addi   x29, x29, 508
auipc_here:
    auipc  x5, 0x00001
    bne    x5, x29, fail
    sw     x5, 4(x20)

# TEST 14: JAL target, link PC+4, and wrong-path flushing
test_14:

# x28 holds display digits 0x0014 for test 14.
    addi   x28, x0, 20
    sw     x28, SEVENSEG_OFF(x31)
    lui    x29, 0x00400
    addi   x29, x29, 540
    jal    x6, jal_target
jal_return:
    sw     x28, 8(x20)
    sw     x28, 8(x20)
jal_target:
    bne    x6, x29, fail
    sw     x6, 4(x20)

# TEST 15: JALR forwarded base, bit-zero clearing, and link PC+4
test_15:

# x28 holds display digits 0x0015 for test 15.
    addi   x28, x0, 21
    sw     x28, SEVENSEG_OFF(x31)
    lui    x29, 0x00400
    addi   x29, x29, 584
jalr_base:
    auipc  x5, 0x00000
    addi   x5, x5, 21
    jalr   x6, 0(x5)
jalr_return:
    sw     x28, 8(x20)
    sw     x28, 8(x20)
jalr_target:
    bne    x6, x29, fail
    sw     x6, 4(x20)

# TEST 16: MUL and immediate result consumer
test_16:

# x28 holds display digits 0x0016 for test 16.
    addi   x28, x0, 22
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 43
    addi   x5, x0, 6
    addi   x6, x0, 7
    mul    x7, x5, x6
    addi   x8, x7, 1
    bne    x8, x29, fail
    sw     x8, 4(x20)

# TEST 17: Signed MULH high word
test_17:

# x28 holds display digits 0x0017 for test 17.
    addi   x28, x0, 23
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, -1
    addi   x5, x0, -7
    addi   x6, x0, 3
    mulh   x7, x5, x6
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 18: Unsigned MULHU high word
test_18:

# x28 holds display digits 0x0018 for test 18.
    addi   x28, x0, 24
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 1
    addi   x5, x0, -1
    addi   x6, x0, 2
    mulhu  x7, x5, x6
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 19: Signed DIV with a forwarded negative dividend
test_19:

# x28 holds display digits 0x0019 for test 19.
    addi   x28, x0, 25
    sw     x28, SEVENSEG_OFF(x31)
    addi   x5, x0, 7
    addi   x6, x0, 3
    addi   x29, x0, -2
    addi   x0, x0, 0
    addi   x5, x0, -7
    div    x7, x5, x6
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 20: Signed REM with a forwarded negative dividend
test_20:

# x28 holds display digits 0x0020 for test 20.
    addi   x28, x0, 32
    sw     x28, SEVENSEG_OFF(x31)
    addi   x5, x0, 7
    addi   x6, x0, 3
    addi   x29, x0, -1
    addi   x0, x0, 0
    addi   x5, x0, -7
    rem    x7, x5, x6
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 21: Unsigned DIVU
test_21:

# x28 holds display digits 0x0021 for test 21.
    addi   x28, x0, 33
    sw     x28, SEVENSEG_OFF(x31)
    lui    x29, 0x55555
    addi   x29, x29, 1365
    addi   x5, x0, -1
    addi   x6, x0, 3
    divu   x7, x5, x6
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 22: Unsigned REMU
test_22:

# x28 holds display digits 0x0022 for test 22.
    addi   x28, x0, 34
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 3
    addi   x5, x0, -1
    addi   x6, x0, 7
    remu   x7, x5, x6
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 23: Back-to-back dependent multiply and divide
test_23:

# x28 holds display digits 0x0023 for test 23.
    addi   x28, x0, 35
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, 8
    addi   x5, x0, 6
    addi   x6, x0, 7
    mul    x7, x5, x6
    div    x8, x7, x5
    addi   x9, x8, 1
    bne    x9, x29, fail
    sw     x9, 4(x20)

# TEST 24: Signed division by zero with negative dividend
test_24:

# x28 holds display digits 0x0024 for test 24.
    addi   x28, x0, 36
    sw     x28, SEVENSEG_OFF(x31)
    addi   x29, x0, -1
    addi   x5, x0, -7
    div    x7, x5, x0
    bne    x7, x29, fail
    sw     x7, 4(x20)

# TEST 25: Signed division overflow and zero remainder
test_25:

# x28 holds display digits 0x0025 for test 25.
    addi   x28, x0, 37
    sw     x28, SEVENSEG_OFF(x31)
    lui    x29, 0x80000
    addi   x29, x29, 0
    lui    x5, 0x80000
    addi   x6, x0, -1
    div    x7, x5, x6
    rem    x8, x5, x6
    bne    x8, x0, fail
    bne    x7, x29, fail
    sw     x7, 4(x20)

# Final sentinel check: report the test ID saved by any wrong-path store.
    lw     x5, 8(x20)
    beq    x5, x0, all_tests_passed
    addi   x28, x5, 0
    jal    x0, fail
all_tests_passed:
    lui    x30, 0xc001c
    addi   x30, x30, -273
    sw     x30, 60(x20)
    sw     x30, SEVENSEG_OFF(x31)
pass_loop:
    jal    x0, pass_loop
fail:
    sw     x28, 56(x20)
    lui    x30, 0xdead0
    or     x30, x30, x28
    sw     x30, 60(x20)
    sw     x30, SEVENSEG_OFF(x31)
fail_loop:
    jal    x0, fail_loop
