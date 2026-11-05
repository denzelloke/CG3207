# Neon Space Defender -- CPU-owned gameplay on the team's RV32 pipeline.
# RARS 1.6, RV32. No OS/CSR dependencies. Custom return uses uret; see TESTING.md.
# MMIO constants and RAM layout are documented in demo/TESTING.md.
# s0=RAM base, s1=MMIO base, s2=reset-latched modes. t3..t6 are macro scratch.
# Modes: SW0 predictor, SW1 IRQ, SW2 direct subwords, SW3 600-update replay,
# SW5:4 difficulty. Mode changes require BTND reset; BTNU restarts a round.
# Packed record: x:u16,y:u16,health/active:u8,dx:i8,kind:u8,reserved:u8.
# Seven enemy slots at RAM+256, four player shots at +320, four hostile
# shots at +352. Globals +140/+144/+148: fire countdown/shooter/hit grace.

# These macros execute equivalent accesses on the SAME packed layout. The
# fallback never touches ISR-shared data. Macro labels are unique in RARS.
.macro L16 (%rd,%base,%off)
    andi t3,s2,4
    beq t3,zero,l16_word
    lhu %rd,%off(%base)
    j l16_done
l16_word:
    addi t4,%base,%off
    andi t5,t4,3
    slli t5,t5,3
    andi t4,t4,-4
    lw t6,0(t4)
    srl %rd,t6,t5
    slli %rd,%rd,16
    srli %rd,%rd,16
l16_done:
.end_macro
.macro L8 (%rd,%base,%off)
    andi t3,s2,4
    beq t3,zero,l8_word
    lbu %rd,%off(%base)
    j l8_done
l8_word:
    addi t4,%base,%off
    andi t5,t4,3
    slli t5,t5,3
    andi t4,t4,-4
    lw t6,0(t4)
    srl %rd,t6,t5
    andi %rd,%rd,255
l8_done:
.end_macro
.macro LS8 (%rd,%base,%off)
    andi t3,s2,4
    beq t3,zero,ls8_word
    lb %rd,%off(%base)
    j ls8_done
ls8_word:
    addi t4,%base,%off
    andi t5,t4,3
    slli t5,t5,3
    andi t4,t4,-4
    lw t6,0(t4)
    srl %rd,t6,t5
    slli %rd,%rd,24
    srai %rd,%rd,24
ls8_done:
.end_macro
.macro S16 (%rs,%base,%off)
    andi t3,s2,4
    beq t3,zero,s16_word
    sh %rs,%off(%base)
    j s16_done
s16_word:
    addi t4,%base,%off
    andi t5,t4,3
    slli t5,t5,3
    andi t4,t4,-4
    lw t6,0(t4)
    li t3,65535
    sll t3,t3,t5
    not t3,t3
    and t6,t6,t3
    slli t3,%rs,16
    srli t3,t3,16
    sll t3,t3,t5
    or t6,t6,t3
    sw t6,0(t4)
s16_done:
.end_macro
.macro S8 (%rs,%base,%off)
    andi t3,s2,4
    beq t3,zero,s8_word
    sb %rs,%off(%base)
    j s8_done
s8_word:
    addi t4,%base,%off
    andi t5,t4,3
    slli t5,t5,3
    andi t4,t4,-4
    lw t6,0(t4)
    li t3,255
    sll t3,t3,t5
    not t3,t3
    and t6,t6,t3
    andi t3,%rs,255
    sll t3,t3,t5
    or t6,t6,t3
    sw t6,0(t4)
s8_done:
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
irq_vector:
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
main:
    lui s0,0x10010
    lui s1,0xffff0
    li sp,0x10011000
    sw zero,268(s1)
    sw zero,260(s1)
    mv t0,s0
    li t1,1024
zero_ram:
    sw zero,0(t0)
    addi t0,t0,4
    addi t1,t1,-1
    bne t1,zero,zero_ram
    lw s2,100(s1)
    sw s2,56(s0)
    srli t0,s2,4
    andi t0,t0,3
    sw t0,60(s0)
    lw t0,820(s1)             # start event sequence
    sw t0,44(s0)
    jal ra,new_round
    andi t0,s2,8
    bne t0,zero,boot_play
    sw zero,0(s0)            # menu until BTNU
boot_play:
    jal ra,publish
    lw t0,824(s1)            # firmware timer period from wrapper capability
    sw t0,256(s1)
    li t0,3
    sw t0,276(s1)
    andi t0,s2,2
    beq t0,zero,boot_poll
    li t0,3
    sw t0,268(s1)
boot_poll:
    li t0,1
    sw t0,260(s1)

main_loop:
    lw t0,820(s1)
    lw t1,44(s0)
    beq t0,t1,no_restart
    sw t0,44(s0)
    jal ra,new_round
no_restart:
    andi t0,s2,2
    beq t0,zero,poll_time
    lw t0,48(s0)             # ISR writes monotonic tick sequence
    j have_time
poll_time:
    lw t0,264(s1)
    li t1,3
    sw t1,276(s1)            # sequences preserve events even after ACK
have_time:
    lw t1,20(s0)
    sub t2,t0,t1             # unsigned wrapping elapsed ticks
    beq t2,zero,main_loop
    sw t0,20(s0)
    addi t2,t2,-1
    lw t1,36(s0)
    add t1,t1,t2
    sw t1,36(s0)             # missed deadlines: process one, record dropped ticks
    lw t0,0(s0)
    beq t0,zero,just_publish
    li t1,3
    beq t0,t1,just_publish
    li t1,2
    bne t0,t1,do_update
    andi t1,s2,8
    beq t1,zero,just_publish

do_update:
    lw s9,104(s1)            # held right/fire/left/start
    lw t0,816(s1)            # common hardware press sequence in both modes
    lw t1,40(s0)
    sw t0,40(s0)
    beq t0,t1,input_ready
    ori s9,s9,2              # preserve short fire presses between updates
input_ready:
    andi t0,s2,8
    beq t0,zero,measure_start
    lw t0,24(s0)             # deterministic replay: right/left every 64 ticks
    srli t0,t0,6
    andi t0,t0,1
    li s9,3                  # right + fire
    beq t0,zero,measure_start
    li s9,6                  # left + fire
measure_start:
    sw s9,96(s0)
    li t0,3                  # clear + enable
    sw t0,512(s1)
    jal ra,update_game
    lw t0,24(s0)
    addi t0,t0,1
    sw t0,24(s0)
    jal ra,state_checksum
    sw a0,80(s0)
    li t0,4                  # snapshot + stop
    sw t0,512(s1)
    lw t0,520(s1)
    lw t1,104(s0)
    add t1,t1,t0
    sw t1,104(s0)
    lw t0,524(s1)
    lw t1,116(s0)
    add t1,t1,t0
    sw t1,116(s0)
    lw t0,528(s1)
    lw t1,108(s0)
    add t1,t1,t0
    sw t1,108(s0)
    lw t0,532(s1)
    lw t1,112(s0)
    add t1,t1,t0
    sw t1,112(s0)
    andi t0,s2,8
    beq t0,zero,just_publish
    lw t0,24(s0)
    lw t1,828(s1)             # replay length from wrapper, normally 600
    bltu t0,t1,just_publish
    li t0,3
    sw t0,0(s0)              # freeze completed replay; UP starts identical run
just_publish:
    jal ra,publish
    j main_loop

# Round restart touches main-owned fields only; ISR counters stay monotonic.
new_round:
    addi sp,sp,-16
    sw ra,0(sp)
    li t0,1
    sw t0,0(s0)
    sw t0,12(s0)
    sw zero,4(s0)
    li t0,3
    sw t0,8(s0)
    li t0,308
    sw t0,16(s0)
    lw t0,264(s1)
    sw t0,20(s0)
    # Seed ISR sequence to current time while masked to avoid a stale subtraction.
    sw zero,268(s1)
    lw t0,264(s1)
    sw t0,48(s0)
    sw t0,20(s0)
    sw zero,24(s0)
    sw zero,28(s0)
    sw zero,36(s0)
    sw zero,80(s0)
    sw zero,104(s0)
    sw zero,108(s0)
    sw zero,112(s0)
    sw zero,116(s0)
    # HUD rates: independent snapshots; preserve cumulative replay metrics.
    lw t0,264(s1)
    sw t0,120(s0)           # start tick of rate window
    sw zero,124(s0)         # previous cumulative conditional misses
    sw zero,128(s0)         # previous completed updates
    sw zero,132(s0)         # displayed misses/second
    sw zero,136(s0)         # displayed updates/second
    sw zero,148(s0)         # damage grace period
    lw t0,816(s1)
    sw t0,40(s0)
    addi t0,s0,320
    li t1,16               # clear both projectile pools
clear_bullets:
    sw zero,0(t0)
    addi t0,t0,4
    addi t1,t1,-1
    bne t1,zero,clear_bullets
    jal ra,new_wave
    andi t0,s2,2
    beq t0,zero,round_return
    li t0,3
    sw t0,268(s1)
round_return:
    lw ra,0(sp)
    addi sp,sp,16
    ret

new_wave:
    lw t0,60(s0)
    slli t0,t0,4
    li t1,90
    sub t0,t1,t0
    sw t0,140(s0)
    sw zero,144(s0)
    addi t0,s0,352
    li t1,8
clear_hostile_wave:
    sw zero,0(t0)
    addi t0,t0,4
    addi t1,t1,-1
    bne t1,zero,clear_hostile_wave
    addi s3,s0,256
    li s4,0
    li s5,64
wave_init:
    sw zero,0(s3)
    sw zero,4(s3)
    lw t0,60(s0)
    addi t0,t0,4
    bge s4,t0,wave_next
    S16 (s5,s3,0)
    andi t0,s4,1
    slli t0,t0,5
    addi t0,t0,144
    S16 (t0,s3,2)
    lw t0,60(s0)
    srli t0,t0,1
    addi t0,t0,1
    S8 (t0,s3,4)
    lw t0,60(s0)
    addi t0,t0,2
    andi t1,s4,1
    beq t1,zero,wave_velocity
    neg t0,t0
wave_velocity:
    S8 (t0,s3,5)
wave_next:
    addi s3,s3,8
    addi s5,s5,80
    addi s4,s4,1
    li t0,7
    bne s4,t0,wave_init
    ret

update_game:
    addi sp,sp,-16
    sw ra,0(sp)
    lw t0,0(s0)
    li t1,1
    bne t0,t1,update_return
    lw t0,148(s0)
    beq t0,zero,grace_done
    addi t0,t0,-1
    sw t0,148(s0)
grace_done:
    lw s5,16(s0)
    andi t0,s9,4
    beq t0,zero,move_right
    addi s5,s5,-5
move_right:
    andi t0,s9,1
    beq t0,zero,clamp_player
    addi s5,s5,5
clamp_player:
    li t0,16
    bge s5,t0,player_max
    mv s5,t0
player_max:
    li t0,600
    ble s5,t0,player_store
    mv s5,t0
player_store:
    sw s5,16(s0)
    lw t0,28(s0)
    beq t0,zero,try_fire
    addi t0,t0,-1
    sw t0,28(s0)
    j bullets_update
try_fire:
    andi t0,s9,2
    beq t0,zero,bullets_update
    addi s3,s0,320
    li s4,4
find_bullet:
    L8 (t0,s3,4)
    beq t0,zero,spawn_bullet
    addi s3,s3,8
    addi s4,s4,-1
    bne s4,zero,find_bullet
    j bullets_update
spawn_bullet:
    addi t0,s5,10
    S16 (t0,s3,0)
    li t0,430
    S16 (t0,s3,2)
    li t0,1
    S8 (t0,s3,4)
    li t0,6
    sw t0,28(s0)

bullets_update:
    addi s3,s0,320
    li s4,4
bullet_loop:
    L8 (t0,s3,4)
    beq t0,zero,bullet_next
    L16 (s5,s3,0)
    L16 (s6,s3,2)
    addi s6,s6,-8
    li t0,128
    blt s6,t0,bullet_off
    S16 (s6,s3,2)
    addi s7,s0,256
    li s8,7
collision_loop:
    L8 (t0,s7,4)
    beq t0,zero,collision_next
    L16 (t0,s7,0)
    addi t1,t0,24
    bge s5,t1,collision_next
    addi t1,s5,4
    bge t0,t1,collision_next
    L16 (t0,s7,2)
    addi t1,t0,16
    bge s6,t1,collision_next
    addi t1,s6,10
    bge t0,t1,collision_next
    L8 (t0,s7,4)
    addi t0,t0,-1
    S8 (t0,s7,4)
    bne t0,zero,bullet_off
    lw t0,4(s0)
    addi t0,t0,10
    sw t0,4(s0)
    j bullet_off
collision_next:
    addi s7,s7,8
    addi s8,s8,-1
    bne s8,zero,collision_loop
    j bullet_next
bullet_off:
    S8 (zero,s3,4)
bullet_next:
    addi s3,s3,8
    addi s4,s4,-1
    bne s4,zero,bullet_loop

    lw t0,24(s0)
    andi t0,t0,3             # movement every fourth update
    bne t0,zero,hostile_update
    addi s3,s0,256
    li s4,7
enemy_loop:
    L8 (t0,s3,4)
    beq t0,zero,enemy_next
    L16 (s5,s3,0)
    L16 (s6,s3,2)
    LS8 (s7,s3,5)
    # Staggered zigzags and vertical bob; descend at each phase boundary.
    li t0,7
    sub t0,t0,s4
    slli t0,t0,3
    lw t1,24(s0)
    add t0,t0,t1
    andi t1,t0,63
    bne t1,zero,enemy_bob
    neg s7,s7
    S8 (s7,s3,5)
    lw t1,60(s0)
    addi t1,t1,4
    add s6,s6,t1
enemy_bob:
    andi t0,t0,32
    li t1,1
    beq t0,zero,enemy_bob_apply
    li t1,-1
enemy_bob_apply:
    add s6,s6,t1
    add s5,s5,s7
    li t0,16
    blt s5,t0,enemy_reverse
    li t0,600
    bgt s5,t0,enemy_reverse
    j enemy_store
enemy_reverse:
    sub s5,s5,s7
    neg s7,s7
    S8 (s7,s3,5)
    lw t0,12(s0)
    li t1,12
    bltu t0,t1,descent_ready
    mv t0,t1
descent_ready:
    addi t0,t0,16
    add s6,s6,t0
enemy_store:
    S16 (s5,s3,0)
    S16 (s6,s3,2)
    li t0,420
    blt s6,t0,enemy_next
    S8 (zero,s3,4)
    lw t0,8(s0)
    beq t0,zero,enemy_next
    addi t0,t0,-1
    sw t0,8(s0)
    bne t0,zero,enemy_next
    li t0,2
    sw t0,0(s0)
enemy_next:
    addi s3,s3,8
    addi s4,s4,-1
    bne s4,zero,enemy_loop
hostile_update:
    # Move existing shots before firing: new shots appear at the muzzle.
    addi s3,s0,352
    li s4,4
hostile_loop:
    L8 (t0,s3,4)
    beq t0,zero,hostile_next
    L16 (s5,s3,0)
    L16 (s6,s3,2)
    LS8 (s7,s3,5)
    add s5,s5,s7
    lw t0,60(s0)
    addi t0,t0,3
    add s6,s6,t0
    li t0,16
    blt s5,t0,hostile_off
    li t0,620
    bgt s5,t0,hostile_off
    li t0,460
    bge s6,t0,hostile_off
    S16 (s5,s3,0)
    S16 (s6,s3,2)
    lw t0,16(s0)
    addi t1,t0,24
    bge s5,t1,hostile_next
    addi t1,s5,4
    bge t0,t1,hostile_next
    li t0,456
    bge s6,t0,hostile_next
    addi t1,s6,10
    li t0,440
    bge t0,t1,hostile_next
    lw t0,148(s0)
    bne t0,zero,hostile_off
    lw t0,8(s0)
    beq t0,zero,hostile_off
    addi t0,t0,-1
    sw t0,8(s0)
    li t1,45
    sw t1,148(s0)
    bne t0,zero,hostile_off
    li t0,2
    sw t0,0(s0)
hostile_off:
    S8 (zero,s3,4)
hostile_next:
    addi s3,s3,8
    addi s4,s4,-1
    bne s4,zero,hostile_loop
    lw t0,8(s0)
    beq t0,zero,count_enemies
    lw t0,140(s0)
    addi t0,t0,-1
    sw t0,140(s0)
    bgt t0,zero,count_enemies
    lw t0,60(s0)
    slli t0,t0,4
    li t1,90
    sub t0,t1,t0
    sw t0,140(s0)
    addi s3,s0,352
    li s4,4
hostile_free:
    L8 (t0,s3,4)
    beq t0,zero,find_shooter
    addi s3,s3,8
    addi s4,s4,-1
    bne s4,zero,hostile_free
    j count_enemies
find_shooter:
    li s8,7
shooter_loop:
    lw t0,144(s0)
    slli t1,t0,3
    addi s7,s0,256
    add s7,s7,t1
    addi t0,t0,1
    li t1,7
    blt t0,t1,shooter_cursor
    li t0,0
shooter_cursor:
    sw t0,144(s0)
    L8 (t0,s7,4)
    bne t0,zero,hostile_spawn
    addi s8,s8,-1
    bne s8,zero,shooter_loop
    j count_enemies
hostile_spawn:
    L16 (s5,s7,0)
    addi s5,s5,10
    L16 (s6,s7,2)
    addi s6,s6,16
    S16 (s5,s3,0)
    S16 (s6,s3,2)
    li t0,1
    S8 (t0,s3,4)
    li t0,0
    lw t1,60(s0)
    beq t1,zero,hostile_aimed
    lw t1,16(s0)
    addi t1,t1,10
    beq t1,s5,hostile_aimed
    li t0,1
    bgt t1,s5,hostile_aimed
    li t0,-1
hostile_aimed:
    S8 (t0,s3,5)
count_enemies:
    li s5,0
    addi s3,s0,256
    li s4,7
count_loop:
    L8 (t0,s3,4)
    add s5,s5,t0
    addi s3,s3,8
    addi s4,s4,-1
    bne s4,zero,count_loop
    bne s5,zero,update_return
    lw t0,8(s0)
    beq t0,zero,update_return
    lw t0,12(s0)
    addi t0,t0,1
    sw t0,12(s0)
    jal ra,new_wave
update_return:
    lw ra,0(sp)
    addi sp,sp,16
    ret

# Checksum includes score/health/wave/player, cooldown, updates and packed objects.
# Excludes modes, scheduling, performance, display, and ISR-owned fields.
state_checksum:
    li a0,0x4e454f4e
    addi t0,s0,4
    li t1,4
hash_globals:
    lw t2,0(t0)
    slli t3,a0,5
    srli t4,a0,27
    or a0,t3,t4
    xor a0,a0,t2
    addi t0,t0,4
    addi t1,t1,-1
    bne t1,zero,hash_globals
    lw t2,24(s0)
    xor a0,a0,t2
    lw t2,28(s0)
    xor a0,a0,t2
    # Scheduling and grace affect future gameplay, so hash them too.
    addi t0,s0,140
    li t1,3
hash_combat:
    lw t2,0(t0)
    slli t3,a0,5
    srli t4,a0,27
    or a0,t3,t4
    xor a0,a0,t2
    addi t0,t0,4
    addi t1,t1,-1
    bne t1,zero,hash_combat
    addi t0,s0,256
    li t1,14
hash_enemies:
    lw t2,0(t0)
    slli t3,a0,5
    srli t4,a0,27
    or a0,t3,t4
    xor a0,a0,t2
    addi t0,t0,4
    addi t1,t1,-1
    bne t1,zero,hash_enemies
    addi t0,s0,320
    li t1,16               # player and enemy shots
hash_bullets:
    lw t2,0(t0)
    slli t3,a0,5
    srli t4,a0,27
    or a0,t3,t4
    xor a0,a0,t2
    addi t0,t0,4
    addi t1,t1,-1
    bne t1,zero,hash_bullets
    ret

# Eight decimal digits packed for the existing hexadecimal segment/font decoder.
bcd:
    li t0,0
    li t1,0
    li t2,10
bcd_loop:
    remu t3,a0,t2
    divu a0,a0,t2
    sll t3,t3,t1
    or t0,t0,t3
    addi t1,t1,4
    li t4,32
    bne t1,t4,bcd_loop
    mv a0,t0
    ret

publish:
    lw t0,768(s1)
    bne t0,zero,publish_skip
    addi sp,sp,-16
    sw ra,0(sp)
    # Refresh rates after >=60 timer ticks (~1 second on the board).
    # Normalize by actual elapsed ticks if publication was delayed.
    # Run outside the performance window; bcd may freely clobber t0..t4 later.
    lw t0,264(s1)
    lw t1,120(s0)
    sub t2,t0,t1
    li t3,60
    bltu t2,t3,publish_rate_done
    sw t0,120(s0)
    lw t0,112(s0)
    lw t1,124(s0)
    sw t0,124(s0)
    sub t0,t0,t1
    mul t0,t0,t3
    divu t0,t0,t2
    sw t0,132(s0)
    lw t0,24(s0)
    lw t1,128(s0)
    sw t0,128(s0)
    sub t0,t0,t1
    mul t0,t0,t3
    divu t0,t0,t2
    sw t0,136(s0)
publish_rate_done:
    # Player: packed x/y, kind, RGB444, visibility
    lw t0,16(s0)
    li t1,0x01b80000         # y=440
    or t0,t0,t1
    sw t0,1024(s1)
    li t0,1
    sw t0,1028(s1)
    lw t1,148(s0)
    srli t1,t1,2
    andi t1,t1,1
    xor t0,t0,t1            # flash the ship during damage grace
    sw t0,1036(s1)
    li t0,0x0ef
    sw t0,1032(s1)
    addi s3,s0,256
    addi s4,s1,1040
    li s5,7
publish_enemy:
    L16 (t0,s3,0)
    L16 (t1,s3,2)
    slli t1,t1,16
    or t0,t0,t1
    sw t0,0(s4)
    li t0,2
    sw t0,4(s4)
    li t0,0xf3b
    sw t0,8(s4)
    L8 (t0,s3,4)
    snez t0,t0
    sw t0,12(s4)
    addi s3,s3,8
    addi s4,s4,16
    addi s5,s5,-1
    bne s5,zero,publish_enemy
    addi s3,s0,320
    li s5,4
publish_bullet:
    L16 (t0,s3,0)
    L16 (t1,s3,2)
    slli t1,t1,16
    or t0,t0,t1
    sw t0,0(s4)
    li t0,3
    sw t0,4(s4)
    li t0,0xfe4
    sw t0,8(s4)
    L8 (t0,s3,4)
    sw t0,12(s4)
    addi s3,s3,8
    addi s4,s4,16
    addi s5,s5,-1
    bne s5,zero,publish_bullet
    addi s3,s0,352
    li s5,4
publish_hostile:
    L16 (t0,s3,0)
    L16 (t1,s3,2)
    slli t1,t1,16
    or t0,t0,t1
    sw t0,0(s4)
    li t0,4
    sw t0,4(s4)
    li t0,0xf52
    sw t0,8(s4)
    L8 (t0,s3,4)
    sw t0,12(s4)
    addi s3,s3,8
    addi s4,s4,16
    addi s5,s5,-1
    bne s5,zero,publish_hostile
    lw t0,0(s0)
    sw t0,832(s1)           # HUD[0] state
    lw a0,4(s0)
    jal ra,bcd
    sw a0,836(s1)
    sw a0,128(s1)           # 7seg shows decimal score
    lw t0,8(s0)
    sw t0,840(s1)
    sw t0,96(s1)            # LED low bits show health numerically
    lw a0,12(s0)
    jal ra,bcd
    sw a0,844(s1)
    sw s2,848(s1)
    # Average measured cycles/update. Display formatting is outside measurement.
    lw a0,104(s0)
    lw t0,24(s0)
    beq t0,zero,publish_cycles
    divu a0,a0,t0
publish_cycles:
    jal ra,bcd
    sw a0,852(s1)
    lw a0,116(s0)
    lw t0,24(s0)
    beq t0,zero,publish_retired
    divu a0,a0,t0
publish_retired:
    jal ra,bcd
    sw a0,856(s1)
    lw a0,108(s0)
    jal ra,bcd
    sw a0,860(s1)
    lw a0,132(s0)           # recent measured conditional misses/second
    jal ra,bcd
    sw a0,864(s1)
    lw a0,136(s0)           # recent completed updates/second
    jal ra,bcd
    sw a0,868(s1)
    lw a0,36(s0)
    jal ra,bcd
    sw a0,872(s1)
    lw t0,80(s0)
    sw t0,876(s1)
    lw a0,896(s1)
    jal ra,bcd
    sw a0,880(s1)
    lw t0,60(s0)
    sw t0,884(s1)
    li t0,1
    sw t0,768(s1)
    lw ra,0(sp)
    addi sp,sp,16
publish_skip:
    ret

# Saves all registers it modifies. Main does not clear ISR-produced tick sequence.
irq_handler:
    addi sp,sp,-16
    sw t0,0(sp)
    sw t1,4(sp)
    sw t2,8(sp)
    lui t0,0xffff0
    lui t1,0x10010
    lw t2,264(t0)
    sw t2,48(t1)
    lw t2,816(t0)
    sw t2,52(t1)
    lw t2,272(t0)
    sw t2,276(t0)
    lw t0,0(sp)
    lw t1,4(sp)
    lw t2,8(sp)
    addi sp,sp,16
    uret
    j boot                    # unreachable; no fallthrough side effects
