# RV32 self-checking subword regression; real 32-bit instructions only.
# RAM 0x10010000, seven-segment MMIO 0xFFFF0080.
# PASS C001BEEF; FAIL DEADxxxx where xxxx is hexadecimal case ID.
# Halfword offsets 0/1/2 work; offset 3 load = 0, store suppressed.
# Word accesses require offset 0. No trap handling is tested.
.text
.globl main
main:
    addi x0, x0, 0
    addi x0, x0, 0
    lui x20, 0x10010
    lui x31, 0xffff0
    sw x0, 128(x31)

# Case 001: lb byte 00 at lane 0
    addi x28, x0, 1
    lui x7, 0x5aa54
    addi x7, x7, -1024
    sw x7, 0(x20)
    lb x5, 0(x20)
    lui x6, 0x0
    beq x5, x6, ok_1
    jal x0, fail
ok_1:

# Case 002: lbu byte 00 at lane 0
    addi x28, x0, 2
    lbu x5, 0(x20)
    lui x6, 0x0
    beq x5, x6, ok_2
    jal x0, fail
ok_2:

# Case 003: lb byte 7f at lane 0
    addi x28, x0, 3
    lui x7, 0x5aa54
    addi x7, x7, -897
    sw x7, 0(x20)
    lb x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, ok_3
    jal x0, fail
ok_3:

# Case 004: lbu byte 7f at lane 0
    addi x28, x0, 4
    lbu x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, ok_4
    jal x0, fail
ok_4:

# Case 005: lb byte 80 at lane 0
    addi x28, x0, 5
    lui x7, 0x5aa54
    addi x7, x7, -896
    sw x7, 0(x20)
    lb x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, -128
    beq x5, x6, ok_5
    jal x0, fail
ok_5:

# Case 006: lbu byte 80 at lane 0
    addi x28, x0, 6
    lbu x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, ok_6
    jal x0, fail
ok_6:

# Case 007: lb byte ff at lane 0
    addi x28, x0, 7
    lui x7, 0x5aa54
    addi x7, x7, -769
    sw x7, 0(x20)
    lb x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, ok_7
    jal x0, fail
ok_7:

# Case 008: lbu byte ff at lane 0
    addi x28, x0, 8
    lbu x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, 255
    beq x5, x6, ok_8
    jal x0, fail
ok_8:

# Case 009: lb byte 00 at lane 1
    addi x28, x0, 9
    lui x7, 0x5aa50
    addi x7, x7, 195
    sw x7, 0(x20)
    lb x5, 1(x20)
    lui x6, 0x0
    beq x5, x6, ok_9
    jal x0, fail
ok_9:

# Case 010: lbu byte 00 at lane 1
    addi x28, x0, 10
    lbu x5, 1(x20)
    lui x6, 0x0
    beq x5, x6, ok_10
    jal x0, fail
ok_10:

# Case 011: lb byte 7f at lane 1
    addi x28, x0, 11
    lui x7, 0x5aa58
    addi x7, x7, -61
    sw x7, 0(x20)
    lb x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, ok_11
    jal x0, fail
ok_11:

# Case 012: lbu byte 7f at lane 1
    addi x28, x0, 12
    lbu x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, ok_12
    jal x0, fail
ok_12:

# Case 013: lb byte 80 at lane 1
    addi x28, x0, 13
    lui x7, 0x5aa58
    addi x7, x7, 195
    sw x7, 0(x20)
    lb x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, -128
    beq x5, x6, ok_13
    jal x0, fail
ok_13:

# Case 014: lbu byte 80 at lane 1
    addi x28, x0, 14
    lbu x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, ok_14
    jal x0, fail
ok_14:

# Case 015: lb byte ff at lane 1
    addi x28, x0, 15
    lui x7, 0x5aa60
    addi x7, x7, -61
    sw x7, 0(x20)
    lb x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, ok_15
    jal x0, fail
ok_15:

# Case 016: lbu byte ff at lane 1
    addi x28, x0, 16
    lbu x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, 255
    beq x5, x6, ok_16
    jal x0, fail
ok_16:

# Case 017: lb byte 00 at lane 2
    addi x28, x0, 17
    lui x7, 0x5a004
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 2(x20)
    lui x6, 0x0
    beq x5, x6, ok_17
    jal x0, fail
ok_17:

# Case 018: lbu byte 00 at lane 2
    addi x28, x0, 18
    lbu x5, 2(x20)
    lui x6, 0x0
    beq x5, x6, ok_18
    jal x0, fail
ok_18:

# Case 019: lb byte 7f at lane 2
    addi x28, x0, 19
    lui x7, 0x5a7f4
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, ok_19
    jal x0, fail
ok_19:

# Case 020: lbu byte 7f at lane 2
    addi x28, x0, 20
    lbu x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, ok_20
    jal x0, fail
ok_20:

# Case 021: lb byte 80 at lane 2
    addi x28, x0, 21
    lui x7, 0x5a804
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, -128
    beq x5, x6, ok_21
    jal x0, fail
ok_21:

# Case 022: lbu byte 80 at lane 2
    addi x28, x0, 22
    lbu x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, ok_22
    jal x0, fail
ok_22:

# Case 023: lb byte ff at lane 2
    addi x28, x0, 23
    lui x7, 0x5aff4
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, ok_23
    jal x0, fail
ok_23:

# Case 024: lbu byte ff at lane 2
    addi x28, x0, 24
    lbu x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, 255
    beq x5, x6, ok_24
    jal x0, fail
ok_24:

# Case 025: lb byte 00 at lane 3
    addi x28, x0, 25
    lui x7, 0xa54
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 3(x20)
    lui x6, 0x0
    beq x5, x6, ok_25
    jal x0, fail
ok_25:

# Case 026: lbu byte 00 at lane 3
    addi x28, x0, 26
    lbu x5, 3(x20)
    lui x6, 0x0
    beq x5, x6, ok_26
    jal x0, fail
ok_26:

# Case 027: lb byte 7f at lane 3
    addi x28, x0, 27
    lui x7, 0x7fa54
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, ok_27
    jal x0, fail
ok_27:

# Case 028: lbu byte 7f at lane 3
    addi x28, x0, 28
    lbu x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, 127
    beq x5, x6, ok_28
    jal x0, fail
ok_28:

# Case 029: lb byte 80 at lane 3
    addi x28, x0, 29
    lui x7, 0x80a54
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, -128
    beq x5, x6, ok_29
    jal x0, fail
ok_29:

# Case 030: lbu byte 80 at lane 3
    addi x28, x0, 30
    lbu x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, ok_30
    jal x0, fail
ok_30:

# Case 031: lb byte ff at lane 3
    addi x28, x0, 31
    lui x7, 0xffa54
    addi x7, x7, -829
    sw x7, 0(x20)
    lb x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, ok_31
    jal x0, fail
ok_31:

# Case 032: lbu byte ff at lane 3
    addi x28, x0, 32
    lbu x5, 3(x20)
    lui x6, 0x0
    addi x6, x6, 255
    beq x5, x6, ok_32
    jal x0, fail
ok_32:

# Case 033: lh halfword 0000 at offset 0
    addi x28, x0, 33
    lui x7, 0xa55a0
    sw x7, 0(x20)
    lh x5, 0(x20)
    lui x6, 0x0
    beq x5, x6, ok_33
    jal x0, fail
ok_33:

# Case 034: lhu halfword 0000 at offset 0
    addi x28, x0, 34
    lhu x5, 0(x20)
    lui x6, 0x0
    beq x5, x6, ok_34
    jal x0, fail
ok_34:

# Case 035: lh halfword 7fff at offset 0
    addi x28, x0, 35
    lui x7, 0xa55a8
    addi x7, x7, -1
    sw x7, 0(x20)
    lh x5, 0(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, ok_35
    jal x0, fail
ok_35:

# Case 036: lhu halfword 7fff at offset 0
    addi x28, x0, 36
    lhu x5, 0(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, ok_36
    jal x0, fail
ok_36:

# Case 037: lh halfword 8000 at offset 0
    addi x28, x0, 37
    lui x7, 0xa55a8
    sw x7, 0(x20)
    lh x5, 0(x20)
    lui x6, 0xffff8
    beq x5, x6, ok_37
    jal x0, fail
ok_37:

# Case 038: lhu halfword 8000 at offset 0
    addi x28, x0, 38
    lhu x5, 0(x20)
    lui x6, 0x8
    beq x5, x6, ok_38
    jal x0, fail
ok_38:

# Case 039: lh halfword ffff at offset 0
    addi x28, x0, 39
    lui x7, 0xa55b0
    addi x7, x7, -1
    sw x7, 0(x20)
    lh x5, 0(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, ok_39
    jal x0, fail
ok_39:

# Case 040: lhu halfword ffff at offset 0
    addi x28, x0, 40
    lhu x5, 0(x20)
    lui x6, 0x10
    addi x6, x6, -1
    beq x5, x6, ok_40
    jal x0, fail
ok_40:

# Case 041: lh halfword 0000 at offset 1
    addi x28, x0, 41
    lui x7, 0xa5000
    addi x7, x7, 60
    sw x7, 0(x20)
    lh x5, 1(x20)
    lui x6, 0x0
    beq x5, x6, ok_41
    jal x0, fail
ok_41:

# Case 042: lhu halfword 0000 at offset 1
    addi x28, x0, 42
    lhu x5, 1(x20)
    lui x6, 0x0
    beq x5, x6, ok_42
    jal x0, fail
ok_42:

# Case 043: lh halfword 7fff at offset 1
    addi x28, x0, 43
    lui x7, 0xa5800
    addi x7, x7, -196
    sw x7, 0(x20)
    lh x5, 1(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, ok_43
    jal x0, fail
ok_43:

# Case 044: lhu halfword 7fff at offset 1
    addi x28, x0, 44
    lhu x5, 1(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, ok_44
    jal x0, fail
ok_44:

# Case 045: lh halfword 8000 at offset 1
    addi x28, x0, 45
    lui x7, 0xa5800
    addi x7, x7, 60
    sw x7, 0(x20)
    lh x5, 1(x20)
    lui x6, 0xffff8
    beq x5, x6, ok_45
    jal x0, fail
ok_45:

# Case 046: lhu halfword 8000 at offset 1
    addi x28, x0, 46
    lhu x5, 1(x20)
    lui x6, 0x8
    beq x5, x6, ok_46
    jal x0, fail
ok_46:

# Case 047: lh halfword ffff at offset 1
    addi x28, x0, 47
    lui x7, 0xa6000
    addi x7, x7, -196
    sw x7, 0(x20)
    lh x5, 1(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, ok_47
    jal x0, fail
ok_47:

# Case 048: lhu halfword ffff at offset 1
    addi x28, x0, 48
    lhu x5, 1(x20)
    lui x6, 0x10
    addi x6, x6, -1
    beq x5, x6, ok_48
    jal x0, fail
ok_48:

# Case 049: lh halfword 0000 at offset 2
    addi x28, x0, 49
    lui x7, 0xc
    addi x7, x7, 828
    sw x7, 0(x20)
    lh x5, 2(x20)
    lui x6, 0x0
    beq x5, x6, ok_49
    jal x0, fail
ok_49:

# Case 050: lhu halfword 0000 at offset 2
    addi x28, x0, 50
    lhu x5, 2(x20)
    lui x6, 0x0
    beq x5, x6, ok_50
    jal x0, fail
ok_50:

# Case 051: lh halfword 7fff at offset 2
    addi x28, x0, 51
    lui x7, 0x7fffc
    addi x7, x7, 828
    sw x7, 0(x20)
    lh x5, 2(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, ok_51
    jal x0, fail
ok_51:

# Case 052: lhu halfword 7fff at offset 2
    addi x28, x0, 52
    lhu x5, 2(x20)
    lui x6, 0x8
    addi x6, x6, -1
    beq x5, x6, ok_52
    jal x0, fail
ok_52:

# Case 053: lh halfword 8000 at offset 2
    addi x28, x0, 53
    lui x7, 0x8000c
    addi x7, x7, 828
    sw x7, 0(x20)
    lh x5, 2(x20)
    lui x6, 0xffff8
    beq x5, x6, ok_53
    jal x0, fail
ok_53:

# Case 054: lhu halfword 8000 at offset 2
    addi x28, x0, 54
    lhu x5, 2(x20)
    lui x6, 0x8
    beq x5, x6, ok_54
    jal x0, fail
ok_54:

# Case 055: lh halfword ffff at offset 2
    addi x28, x0, 55
    lui x7, 0xffffc
    addi x7, x7, 828
    sw x7, 0(x20)
    lh x5, 2(x20)
    lui x6, 0x0
    addi x6, x6, -1
    beq x5, x6, ok_55
    jal x0, fail
ok_55:

# Case 056: lhu halfword ffff at offset 2
    addi x28, x0, 56
    lhu x5, 2(x20)
    lui x6, 0x10
    addi x6, x6, -1
    beq x5, x6, ok_56
    jal x0, fail
ok_56:

# Case 057: sb 00 lane 0; preserve neighbours
    addi x28, x0, 57
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sb x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55ac
    addi x6, x6, 768
    beq x5, x6, ok_57
    jal x0, fail
ok_57:

# Case 058: sb 7f lane 0; preserve neighbours
    addi x28, x0, 58
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 127
    sb x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55ac
    addi x6, x6, 895
    beq x5, x6, ok_58
    jal x0, fail
ok_58:

# Case 059: sb 80 lane 0; preserve neighbours
    addi x28, x0, 59
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sb x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55ac
    addi x6, x6, 896
    beq x5, x6, ok_59
    jal x0, fail
ok_59:

# Case 060: sb ff lane 0; preserve neighbours
    addi x28, x0, 60
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 255
    sb x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55ac
    addi x6, x6, 1023
    beq x5, x6, ok_60
    jal x0, fail
ok_60:

# Case 061: sb 00 lane 1; preserve neighbours
    addi x28, x0, 61
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sb x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a0
    addi x6, x6, 60
    beq x5, x6, ok_61
    jal x0, fail
ok_61:

# Case 062: sb 7f lane 1; preserve neighbours
    addi x28, x0, 62
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 127
    sb x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a8
    addi x6, x6, -196
    beq x5, x6, ok_62
    jal x0, fail
ok_62:

# Case 063: sb 80 lane 1; preserve neighbours
    addi x28, x0, 63
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sb x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a8
    addi x6, x6, 60
    beq x5, x6, ok_63
    jal x0, fail
ok_63:

# Case 064: sb ff lane 1; preserve neighbours
    addi x28, x0, 64
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 255
    sb x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa55b0
    addi x6, x6, -196
    beq x5, x6, ok_64
    jal x0, fail
ok_64:

# Case 065: sb 00 lane 2; preserve neighbours
    addi x28, x0, 65
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sb x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xa500c
    addi x6, x6, 828
    beq x5, x6, ok_65
    jal x0, fail
ok_65:

# Case 066: sb 7f lane 2; preserve neighbours
    addi x28, x0, 66
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 127
    sb x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xa57fc
    addi x6, x6, 828
    beq x5, x6, ok_66
    jal x0, fail
ok_66:

# Case 067: sb 80 lane 2; preserve neighbours
    addi x28, x0, 67
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sb x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xa580c
    addi x6, x6, 828
    beq x5, x6, ok_67
    jal x0, fail
ok_67:

# Case 068: sb ff lane 2; preserve neighbours
    addi x28, x0, 68
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 255
    sb x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xa5ffc
    addi x6, x6, 828
    beq x5, x6, ok_68
    jal x0, fail
ok_68:

# Case 069: sb 00 lane 3; preserve neighbours
    addi x28, x0, 69
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sb x7, 3(x20)
    lw x5, 0(x20)
    lui x6, 0x5ac
    addi x6, x6, 828
    beq x5, x6, ok_69
    jal x0, fail
ok_69:

# Case 070: sb 7f lane 3; preserve neighbours
    addi x28, x0, 70
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 127
    sb x7, 3(x20)
    lw x5, 0(x20)
    lui x6, 0x7f5ac
    addi x6, x6, 828
    beq x5, x6, ok_70
    jal x0, fail
ok_70:

# Case 071: sb 80 lane 3; preserve neighbours
    addi x28, x0, 71
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sb x7, 3(x20)
    lw x5, 0(x20)
    lui x6, 0x805ac
    addi x6, x6, 828
    beq x5, x6, ok_71
    jal x0, fail
ok_71:

# Case 072: sb ff lane 3; preserve neighbours
    addi x28, x0, 72
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    addi x7, x7, 255
    sb x7, 3(x20)
    lw x5, 0(x20)
    lui x6, 0xff5ac
    addi x6, x6, 828
    beq x5, x6, ok_72
    jal x0, fail
ok_72:

# Case 073: sh 0000 offset 0; preserve neighbours
    addi x28, x0, 73
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sh x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a0
    beq x5, x6, ok_73
    jal x0, fail
ok_73:

# Case 074: sh 7fff offset 0; preserve neighbours
    addi x28, x0, 74
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    addi x7, x7, -1
    sh x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a8
    addi x6, x6, -1
    beq x5, x6, ok_74
    jal x0, fail
ok_74:

# Case 075: sh 8000 offset 0; preserve neighbours
    addi x28, x0, 75
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    sh x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55a8
    beq x5, x6, ok_75
    jal x0, fail
ok_75:

# Case 076: sh ffff offset 0; preserve neighbours
    addi x28, x0, 76
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x10
    addi x7, x7, -1
    sh x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0xa55b0
    addi x6, x6, -1
    beq x5, x6, ok_76
    jal x0, fail
ok_76:

# Case 077: sh 0000 offset 1; preserve neighbours
    addi x28, x0, 77
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sh x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa5000
    addi x6, x6, 60
    beq x5, x6, ok_77
    jal x0, fail
ok_77:

# Case 078: sh 7fff offset 1; preserve neighbours
    addi x28, x0, 78
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    addi x7, x7, -1
    sh x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa5800
    addi x6, x6, -196
    beq x5, x6, ok_78
    jal x0, fail
ok_78:

# Case 079: sh 8000 offset 1; preserve neighbours
    addi x28, x0, 79
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    sh x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa5800
    addi x6, x6, 60
    beq x5, x6, ok_79
    jal x0, fail
ok_79:

# Case 080: sh ffff offset 1; preserve neighbours
    addi x28, x0, 80
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x10
    addi x7, x7, -1
    sh x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0xa6000
    addi x6, x6, -196
    beq x5, x6, ok_80
    jal x0, fail
ok_80:

# Case 081: sh 0000 offset 2; preserve neighbours
    addi x28, x0, 81
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x0
    sh x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xc
    addi x6, x6, 828
    beq x5, x6, ok_81
    jal x0, fail
ok_81:

# Case 082: sh 7fff offset 2; preserve neighbours
    addi x28, x0, 82
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    addi x7, x7, -1
    sh x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0x7fffc
    addi x6, x6, 828
    beq x5, x6, ok_82
    jal x0, fail
ok_82:

# Case 083: sh 8000 offset 2; preserve neighbours
    addi x28, x0, 83
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x8
    sh x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0x8000c
    addi x6, x6, 828
    beq x5, x6, ok_83
    jal x0, fail
ok_83:

# Case 084: sh ffff offset 2; preserve neighbours
    addi x28, x0, 84
    lui x7, 0xa55ac
    addi x7, x7, 828
    sw x7, 0(x20)
    lui x7, 0x10
    addi x7, x7, -1
    sh x7, 2(x20)
    lw x5, 0(x20)
    lui x6, 0xffffc
    addi x6, x6, 828
    beq x5, x6, ok_84
    jal x0, fail
ok_84:

# Case 085: sw/lw regression
    addi x28, x0, 85
    lui x7, 0x87654
    addi x7, x7, 801
    sw x7, 0(x20)
    lw x5, 0(x20)
    lui x6, 0x87654
    addi x6, x6, 801
    beq x5, x6, ok_85
    jal x0, fail
ok_85:

# Case 086: lh at crossing offset 3 returns zero
    addi x28, x0, 86
    lh x5, 3(x20)
    lui x6, 0x0
    beq x5, x6, ok_86
    jal x0, fail
ok_86:

# Case 087: lhu at crossing offset 3 returns zero
    addi x28, x0, 87
    lhu x5, 3(x20)
    lui x6, 0x0
    beq x5, x6, ok_87
    jal x0, fail
ok_87:

# Case 088: sh at crossing offset 3 leaves first word
    addi x28, x0, 88
    lui x7, 0x8
    addi x7, x7, -1
    sh x7, 3(x20)
    lw x5, 0(x20)
    lui x6, 0x87654
    addi x6, x6, 801
    beq x5, x6, ok_88
    jal x0, fail
ok_88:

# Case 089: sh at crossing offset 3 leaves next word
    addi x28, x0, 89
    lui x7, 0x12345
    addi x7, x7, 1656
    sw x7, 4(x20)
    sh x7, 3(x20)
    lw x5, 4(x20)
    lui x6, 0x12345
    addi x6, x6, 1656
    beq x5, x6, ok_89
    jal x0, fail
ok_89:

# Case 090: misaligned lw returns zero
    addi x28, x0, 90
    lw x5, 1(x20)
    lui x6, 0x0
    beq x5, x6, ok_90
    jal x0, fail
ok_90:

# Case 091: misaligned sw suppressed
    addi x28, x0, 91
    lui x7, 0x0
    addi x7, x7, 99
    sw x7, 1(x20)
    lw x5, 0(x20)
    lui x6, 0x87654
    addi x6, x6, 801
    beq x5, x6, ok_91
    jal x0, fail
ok_91:

# Case 092: lb immediate ALU use
    addi x28, x0, 92
    lui x7, 0x800
    sw x7, 0(x20)
    lb x8, 2(x20)
    addi x5, x8, 1
    lui x6, 0x0
    addi x6, x6, -127
    beq x5, x6, ok_92
    jal x0, fail
ok_92:

# Case 093: adjacent lb to sb forwarding
    addi x28, x0, 93
    sw x0, 8(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sw x7, 0(x20)
    lb x8, 0(x20)
    sb x8, 8(x20)
    lw x5, 8(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, ok_93
    jal x0, fail
ok_93:

# Case 094: adjacent lbu to sh forwarding
    addi x28, x0, 94
    sw x0, 8(x20)
    lui x7, 0x0
    addi x7, x7, 128
    sw x7, 0(x20)
    lbu x8, 0(x20)
    sh x8, 8(x20)
    lw x5, 8(x20)
    lui x6, 0x0
    addi x6, x6, 128
    beq x5, x6, ok_94
    jal x0, fail
ok_94:

# Case 095: adjacent lh to sw forwarding
    addi x28, x0, 95
    lui x7, 0x8
    sw x7, 0(x20)
    lh x8, 0(x20)
    sw x8, 8(x20)
    lw x5, 8(x20)
    lui x6, 0xffff8
    beq x5, x6, ok_95
    jal x0, fail
ok_95:

# Case 096: adjacent lhu to sw forwarding
    addi x28, x0, 96
    lui x7, 0x8
    sw x7, 0(x20)
    lhu x8, 0(x20)
    sw x8, 8(x20)
    lw x5, 8(x20)
    lui x6, 0x8
    beq x5, x6, ok_96
    jal x0, fail
ok_96:

pass:
    lui x29, 0xc001c
    addi x29, x29, -273
    sw x29, 128(x31)
pass_loop:
    jal x0, pass_loop

fail:
    lui x29, 0xdead0
    or x29, x29, x28
    sw x29, 128(x31)
fail_loop:
    jal x0, fail_loop
