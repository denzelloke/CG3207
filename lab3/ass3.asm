#----------------------------------------------------------------------------------
#-- (c) Rajesh Panicker
#--	License terms :
#--	You are free to use this code as long as you
#--		(i) DO NOT post it on any public repository;
#--		(ii) use it only for educational purposes;
#--		(iii) accept the responsibility to ensure that your implementation does not violate anyone's intellectual property.
#--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
#--		(v) send an email to rajesh<dot>panicker<at>ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
#--		(vi) retain this notice in this file and any files derived from this.
#----------------------------------------------------------------------------------

# This sample program for RISC-V simulation using RARS

.eqv MMIO_BASE 0xFFFF0000
# Memory-mapped peripheral register offsets
.eqv UART_RX_VALID_OFF 			0x00 #RO, status bit
.eqv UART_RX_OFF			0x04 #RO
.eqv UART_TX_READY_OFF			0x08 #RO, status bit
.eqv UART_TX_OFF			0x0C #WO
.eqv OLED_COL_OFF			0x20 #WO
.eqv OLED_ROW_OFF			0x24 #WO
.eqv OLED_DATA_OFF			0x28 #WO
.eqv OLED_CTRL_OFF			0x2C #WO
.eqv ACCEL_DATA_OFF			0x40 #RO
.eqv ACCEL_DREADY_OFF			0x44 #RO, status bit
.eqv DIP_OFF				0x64 #RO
.eqv PB_OFF				0x68 #RO
.eqv LED_OFF				0x60 #WO
.eqv SEVENSEG_OFF			0x80 #WO
.eqv CYCLECOUNT_OFF			0xA0 #RO

.text	
.globl main

main:
    # x31 = peripheral base address
    # Keep x1–x14 available for the original tests.
    lui x31, 0xFFFF0

    # Clear displays.
    sw x0, LED_OFF(x31)
    sw x0, SEVENSEG_OFF(x31)

    # ----------------------------------
    # Original MCycle tests
    # ----------------------------------

    addi x1, x0, 20
    addi x2, x0, 3

    mul  x3, x1, x2          # 60
    div  x4, x1, x2          # 6
    rem  x5, x1, x2          # 2

    addi x6, x0, -20
    addi x7, x0, 3

    div  x8, x6, x7          # -6
    rem  x9, x6, x7          # -2

    addi x10, x0, 20
    addi x11, x0, 3

    mul  x12, x10, x11       # 60
    divu x13, x10, x11       # 6
    remu x14, x10, x11       # 2

    # ----------------------------------
    # Build LED pass mask in x20.
    # Bit i = 1 means test i passed.
    # x21 holds expected values.
    # ----------------------------------

    addi x20, x0, 0

    addi x21, x0, 60
    bne  x3, x21, check1
    addi x20, x20, 1         # LED0: mul passed

check1:
    addi x21, x0, 6
    bne  x4, x21, check2
    addi x20, x20, 2         # LED1: div passed

check2:
    addi x21, x0, 2
    bne  x5, x21, check3
    addi x20, x20, 4         # LED2: rem passed

check3:
    addi x21, x0, -6
    bne  x8, x21, check4
    addi x20, x20, 8         # LED3: negative div passed

check4:
    addi x21, x0, -2
    bne  x9, x21, check5
    addi x20, x20, 16        # LED4: negative rem passed

check5:
    addi x21, x0, 60
    bne  x12, x21, check6
    addi x20, x20, 32        # LED5: second mul passed

check6:
    addi x21, x0, 6
    bne  x13, x21, check7
    addi x20, x20, 64        # LED6: divu passed

check7:
    addi x21, x0, 2
    bne  x14, x21, checks_done
    addi x20, x20, 128       # LED7: remu passed

checks_done:
    sw x20, LED_OFF(x31)

    # ----------------------------------
    # Read SW2:SW0 to select a result.
    # Other switches are ignored.
    # x22 = selection
    # x23 = comparison temporary
    # x24 = selected result
    # ----------------------------------

display_loop:
    lw   x22, DIP_OFF(x31)
    andi x22, x22, 7

    beq  x22, x0, show0

    addi x23, x0, 1
    beq  x22, x23, show1

    addi x23, x0, 2
    beq  x22, x23, show2

    addi x23, x0, 3
    beq  x22, x23, show3

    addi x23, x0, 4
    beq  x22, x23, show4

    addi x23, x0, 5
    beq  x22, x23, show5

    addi x23, x0, 6
    beq  x22, x23, show6

    # Selection 7
    addi x24, x14, 0
    jal  x0, write_display

show0:
    addi x24, x3, 0
    jal  x0, write_display

show1:
    addi x24, x4, 0
    jal  x0, write_display

show2:
    addi x24, x5, 0
    jal  x0, write_display

show3:
    addi x24, x8, 0
    jal  x0, write_display

show4:
    addi x24, x9, 0
    jal  x0, write_display

show5:
    addi x24, x12, 0
    jal  x0, write_display

show6:
    addi x24, x13, 0

write_display:
    sw x24, SEVENSEG_OFF(x31)
    jal x0, display_loop

halt:
    jal x0, halt
				
# ------- <code memory (Instruction Memory ROM) ends>			
				
								
#------- <Data Memory begins>									
.data  ## DMEM segment: DMEM_BASE to DMEM_BASE+2^DMEM_DEPTH_BITS-1
# Total number of constants+variables should not exceed 2^DMEM_DEPTH_BITS/4 (128 if DMEM_DEPTH_BITS=9).

DMEM:

delay_val: .word 4	# a constant, at location DMEM+0x00
string1:
.asciz "\r\nWelcome to CG3207..\r\n"	# string, from DMEM+0x4 to DMEM+0x18 (word address, including null character. The last character is at a byte address 0x1B). # correction: 0x18/0x1B, not 0x1F
var1: .word	1 		# a statically allocated variable (which can have an initial value, say 1), at location DMEM+0x20
#correction: 0x20, not 0x60
# Food for thought: What will be the address of var1 if string1 had one extra character, say  "..." instead of ".."? Hint: words are word-aligned.

.align 9	# To set the address at this point to be 512-byte aligned, i.e., DMEM+0x200
STACK_INIT:	# Stack pointer can be initialised to this location - DMEM+0x200 (i.e., the address of stack_top)
			# stack grows downwards, so stack pointer should be decremented when pushing and incremented when popping (if the stack is full-descending). Stack can be used for function calls and local variables.
		# Not allocating any heap, as it is unlikely to be used in this simple program. If we need dynamic memory allocation,we need to allocate memory and imeplement a heap manager.
#------- <Data Memory ends>													