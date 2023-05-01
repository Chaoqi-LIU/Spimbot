################################################################################
################################################################################
################################################################################
#                                constants                                     #
################################################################################
################################################################################
################################################################################
# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

OTHER_X                 = 0xffff00a0
OTHER_Y                 = 0xffff00a4

TIMER                   = 0xffff001c
GET_MAP                 = 0xffff2008
GET_TILE_INFO 			= 0xffff200c

REQUEST_PUZZLE          = 0xffff00d0  ## Puzzle
SUBMIT_SOLUTION         = 0xffff00d4  ## Puzzle

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK      = 0xffff00d8  ## Puzzle

FALLING_INT_MASK        = 0x200
FALLING_ACK             = 0xffff00f4

STOP_FALLING_INT_MASK   = 0x400
STOP_FALLING_ACK        = 0xffff00f8

OUT_OF_WATER_INT_MASK 	= 0x2000	
OUT_OF_WATER_ACK 		= 0xffff00f0

POWERWASH_ON            = 0xffff2000
POWERWASH_OFF           = 0xffff2004

GET_WATER_LEVEL         = 0xffff201c

GET_SEED 				= 0xffff2040

MMIO_STATUS             = 0xffff204c

.data
.align 4
puzzlewrapper:  .space 1600000
has_puzzle:     .word 0
puzzle_solved:  .word 0
puzzle_submitted: .word 0

has_timer:      .byte 0
puzzle_which:   .byte 1 
puzzle_groupa:  .byte 0
puzzle_groupb:  .byte 0
has_bonked:     .byte 0
has_falling:    .byte 0

three:          .float  3.0
five:           .float  5.0
PI:             .float  3.141592
F180:           .float  180.0


################################################################################
################################################################################
################################################################################
#                                main                                          #
################################################################################
################################################################################
################################################################################
.text
main:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

    # Construct interrupt mask
    li      $t4, 0
    or      $t4, $t4, TIMER_INT_MASK            # enable timer interrupt
    or      $t4, $t4, BONK_INT_MASK             # enable bonk interrupt
    or      $t4, $t4, REQUEST_PUZZLE_INT_MASK   # enable puzzle interrupt
    or      $t4, $t4, FALLING_INT_MASK          # enable falling interrupt
    or      $t4, $t4, STOP_FALLING_INT_MASK     # enable stop falling interrupt
    or      $t4, $t4, 1                         # global enable
    mtc0    $t4, $12
    
    jal stop_copying_our_path_and_be_innovative
    
    lw  $ra, 0($sp)
    add $sp, $sp, 4
    
loop: # Once done, enter an infinite loop so that your bot can be graded by QtSpimbot once 10,000,000 cycles have elapsed
    j loop
    
################################################################################
################################################################################
################################################################################
#                                kernal                                        #
################################################################################
################################################################################
################################################################################
.kdata
chunkIH:    .space 40
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
    move    $k1, $at        # Save $at
                            # NOTE: Don't touch $k1 or else you destroy $at!
.set at
    la      $k0, chunkIH
    sw      $a0, 0($k0)        # Get some free registers
    sw      $v0, 4($k0)        # by storing them to a global variable
    sw      $t0, 8($k0)
    sw      $t1, 12($k0)
    sw      $t2, 16($k0)
    sw      $t3, 20($k0)
    sw      $t4, 24($k0)
    sw      $t5, 28($k0)

    # Save coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    mfhi    $t0
    sw      $t0, 32($k0)
    mflo    $t0
    sw      $t0, 36($k0)

    mfc0    $k0, $13                # Get Cause register
    srl     $a0, $k0, 2
    and     $a0, $a0, 0xf           # ExcCode field
    bne     $a0, 0, non_intrpt



interrupt_dispatch:                 # Interrupt:
    mfc0    $k0, $13                # Get Cause register, again
    beq     $k0, 0, done            # handled all outstanding interrupts

    and     $a0, $k0, BONK_INT_MASK     # is there a bonk interrupt?
    bne     $a0, 0, bonk_interrupt

    and     $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne     $a0, 0, timer_interrupt

    and     $a0, $k0, REQUEST_PUZZLE_INT_MASK
    bne     $a0, 0, request_puzzle_interrupt

    and     $a0, $k0, FALLING_INT_MASK
    bne     $a0, 0, falling_interrupt

    and     $a0, $k0, STOP_FALLING_INT_MASK
    bne     $a0, 0, stop_falling_interrupt

    li      $v0, PRINT_STRING       # Unhandled interrupt types
    la      $a0, unhandled_str
    syscall
    j       done

bonk_interrupt:
    sw      $0, BONK_ACK
    la      $t0, has_bonked
    li      $t1, 1
    sb      $t1, 0($t0)
    li      $t0, 180
    sw      $t0, ANGLE              # turn around
    sw      $zero, ANGLE_CONTROL
    li      $t0, 1
    sw      $t0, VELOCITY           # slow down (velocity = 1)
    j       interrupt_dispatch      # see if other interrupts are waiting

timer_interrupt:
    sw      $0, TIMER_ACK
    la      $t0, has_timer          
    li      $t1, 1
    sb      $t1, 0($t0)             # setup has_timer flag
    sw      $zero, VELOCITY
    sw      $zero, POWERWASH_OFF
    j       interrupt_dispatch      # see if other interrupts are waiting

request_puzzle_interrupt:
    sw  $0, REQUEST_PUZZLE_ACK
    lw  $t0, has_puzzle
    add $t0, $t0, 1
    sw  $t0, has_puzzle
    j   interrupt_dispatch

falling_interrupt:
    sw      $0, FALLING_ACK
    li      $t0, 1
    sb      $t0, has_falling
    j       interrupt_dispatch

stop_falling_interrupt:
    sw      $0, STOP_FALLING_ACK
    sb      $0, has_falling
    j       interrupt_dispatch

non_intrpt:                         # was some non-interrupt
    li      $v0, PRINT_STRING
    la      $a0, non_intrpt_str
    syscall                         # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH

    # Restore coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    lw      $t0, 32($k0)
    mthi    $t0
    lw      $t0, 36($k0)
    mtlo    $t0

    lw      $a0, 0($k0)             # Restore saved registers
    lw      $v0, 4($k0)
    lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw      $t4, 24($k0)
    lw      $t5, 28($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret

################################################################################
################################################################################
################################################################################
#                                functions                                     #
################################################################################
################################################################################
################################################################################
.text
################################################################################
# function stop_copying_our_path
# param:
#       void
# return:
#       void
################################################################################
stop_copying_our_path_and_be_innovative:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

    jal request_puzzles

# while_water_in_short:
#     lw  $t0, GET_WATER_LEVEL
#     bge $t0, 600000, end_water_in_short
#     jal get_water
#     j   while_water_in_short
# end_water_in_short:

    lw  $t0, BOT_X
    bgt $t0, 160, right

left:
    j no_more_cheating            # uncomment this if test right side

    li  $a0, 4
    li  $a1, 270
    jal move_bot

    jal clean_sides

    li  $a0, 20
    li  $a1, 180
    jal move_bot
    li  $a0, 4
    li  $a1, 90
    jal move_bot

    jal traverse_map

    jal run_around

    j   no_more_cheating

right:

    li  $a0, 4
    li  $a1, 270
    jal move_bot

    jal clean_sides

    li  $a0, 20
    li  $a1, 0
    jal move_bot
    li  $a0, 4
    li  $a1, 90
    jal move_bot

    jal traverse_map

    jal run_around

    jal get_dirty_window

no_more_cheating:
    lw  $ra, 0($sp)
    add $sp, $sp, 4
    jr  $ra
################################################################################
# function request_puzzles
# param:
#       void
# return:
#       void
# expect after state:
#       enough puzzle for this round
################################################################################
request_puzzles:
    la  $t0, puzzlewrapper
    add $t1, $t0, 1200000 # 3000 puzzles
request_puzzles_loop:
    bge $t0, $t1, request_puzzles_end
    sw  $t0, REQUEST_PUZZLE
    add $t0, $t0, 400
    j   request_puzzles_loop
request_puzzles_end:
    jr $ra
################################################################################
# function get_water
# param:
#       void
# return:
#       void
# expect after state:
#       solve 1 puzzle or submit 1 solved puzzle
################################################################################
get_water:
    lw $t0, puzzle_solved
    lw $t1, puzzle_submitted
    bge $t1, $t0, solve_new

    # submit solved puzzle
    la $v1, puzzlewrapper
    mul $t2, $t1, 400
    add $v1, $v1, $t2
    sw $v1, SUBMIT_SOLUTION

    addi $t1, $t1, 1
    sw $t1, puzzle_submitted

    jr $ra
    # submit solved puzzle end

solve_new:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    la $v1, puzzlewrapper
get_water_wait_start:
    lw $t1, has_puzzle
    blt $t0, $t1, get_water_wait_end
    j get_water_wait_start
get_water_wait_end:
    mul $t0, $t0, 400
    add $v1, $v1, $t0
    lw $a0 4($v1)
    lw $a1 0($v1)
    lw $a2 8($v1)
    lw $a3 12($v1)
    jal solve_queens
    sw $v1, SUBMIT_SOLUTION
    lw $t0, puzzle_solved
    addi $t0, $t0, 1
    sw $t0, puzzle_solved
    lw $t1, puzzle_submitted
    addi $t1, $t1, 1
    sw $t1, puzzle_submitted

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

################################################################################
# function solve_puzzle_no_submit
# param:
#       void
# return:
#       void
################################################################################
solve_puzzle_no_submit:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t0, puzzle_solved
solve_puzzle_wait_start_no_submit:
    lw $t1, has_puzzle
    blt $t0, $t1, solve_puzzle_wait_end_no_submit
    j solve_puzzle_wait_start_no_submit
solve_puzzle_wait_end_no_submit:
    la $v1, puzzlewrapper
    mul $t0, $t0, 400
    add $v1, $v1, $t0
    lw $a0 4($v1)
    lw $a1 0($v1)
    lw $a2 8($v1)
    lw $a3 12($v1)
    jal solve_queens
    lw $t0, puzzle_solved
    addi $t0, $t0, 1
    sw $t0, puzzle_solved

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
################################################################################
# function move_bot_no
# param:
#       $a0: # pixels to move
#       $a1: # abs angle to move
# return:
#       void
# expect after state:
#       vel set to 0
################################################################################
move_bot_no:
    addi    $sp, $sp, -8
    sw      $ra, 0($sp)
    sw      $s1, 4($sp)

    lw      $s1, POWERWASH_ON

    sw      $a1, ANGLE                          # set face angle
    li      $t1, 1
    sw      $t1, ANGLE_CONTROL 

    li      $t1, 8000                           # set timer interrupt
    mul     $t1, $t1, $a0
    lw      $t0, TIMER
    add     $t0, $t0, $t1
    sw      $t0, TIMER      

    li      $t0, 10                             # set velocity
    sw      $t0, VELOCITY                    

move_in_progress_no:
    lb      $t1, has_timer                         
    beq     $t1, 1, move_end_no
    j       move_in_progress_no

move_end_no:
    sb      $zero, has_timer                       # set has_timer flag to 0
    sw      $zero, VELOCITY

    sw      $s1, POWERWASH_ON

    lw      $ra, 0($sp)
    lw      $s1, 4($sp)
    addi    $sp, $sp, 8
    jr      $ra                                 # return
################################################################################
# function move_bot_velocity
# param:
#       $a0: # pixels to move
#       $a1: # abs angle to move
#       $a2: # velocity
# return:
#       void
# expect after state:
#       vel set to 0
################################################################################
move_bot_velocity:
    addi    $sp, $sp, -8
    sw      $ra, 0($sp)
    sw      $s1, 4($sp)

    lw      $s1, POWERWASH_ON

    sw      $a1, ANGLE                          # set face angle
    li      $t1, 1
    sw      $t1, ANGLE_CONTROL 

    li      $t1, 1000                           # set timer interrupt
    mul     $t1, $t1, $a0
    lw      $t0, TIMER
    add     $t0, $t0, $t1
    sw      $t0, TIMER      

    sw      $a2, VELOCITY                    

move_in_progress_velocity:
    lb      $t1, has_timer                         
    beq     $t1, 1, move_end_velocity
    jal     solve_puzzle_no_submit
    j       move_in_progress_velocity

move_end_velocity:
    sb      $zero, has_timer                       # set has_timer flag to 0
    sw      $zero, VELOCITY

    while_water_in_short_after_move_velocity:
    lw  $t0, GET_WATER_LEVEL
    bge $t0, 800000, end_water_in_short_after_move_velocity
    jal get_water
    j   while_water_in_short_after_move_velocity
    end_water_in_short_after_move_velocity:

    sw      $s1, POWERWASH_ON

    lw      $ra, 0($sp)
    lw      $s1, 4($sp)
    addi    $sp, $sp, 8

    jr      $ra                                 # return
################################################################################
# function move_bot
# param:
#       $a0: # pixels to move
#       $a1: # abs angle to move
# return:
#       void
# expect after state:
#       vel set to 0
################################################################################
move_bot:
    addi    $sp, $sp, -8
    sw      $ra, 0($sp)
    sw      $s1, 4($sp)

    lw      $s1, POWERWASH_ON

    sw      $a1, ANGLE                          # set face angle
    li      $t1, 1
    sw      $t1, ANGLE_CONTROL 

    li      $t1, 1000                           # set timer interrupt
    mul     $t1, $t1, $a0
    lw      $t0, TIMER
    add     $t0, $t0, $t1
    sw      $t0, TIMER      

    li      $t0, 10                             # set velocity
    sw      $t0, VELOCITY                    

move_in_progress:
    lb      $t1, has_timer                         
    beq     $t1, 1, move_end
    jal     solve_puzzle_no_submit
    j       move_in_progress

move_end:
    sb      $zero, has_timer                       # set has_timer flag to 0
    sw      $zero, VELOCITY

    while_water_in_short_after_move:
    lw  $t0, GET_WATER_LEVEL
    bge $t0, 500000, end_water_in_short_after_move
    jal get_water
    j   while_water_in_short_after_move
    end_water_in_short_after_move:

    sw      $s1, POWERWASH_ON

    lw      $ra, 0($sp)
    lw      $s1, 4($sp)
    addi    $sp, $sp, 8

    jr      $ra                                 # return
################################################################################
# function move_bot_special
# param:
#       $a0: # pixels to move
#       $a1: # abs angle to move
# return:
#       void
# expect after state:
#       vel set to 0
################################################################################
move_bot_special:
    addi    $sp, $sp, -8
    sw      $ra, 0($sp)
    sw      $s1, 4($sp)

    lw      $s1, POWERWASH_ON

    sw      $a1, ANGLE                          # set face angle
    li      $t1, 1
    sw      $t1, ANGLE_CONTROL 

    li      $t1, 1000                           # set timer interrupt
    mul     $t1, $t1, $a0
    lw      $t0, TIMER
    add     $t0, $t0, $t1
    sw      $t0, TIMER      

    li      $t0, 10                             # set velocity
    sw      $t0, VELOCITY                    

move_in_progress_special:
    lb      $t1, has_timer                         
    beq     $t1, 1, move_end_special
    jal     solve_puzzle_no_submit
    j       move_in_progress_special

move_end_special:
    sb      $zero, has_timer                       # set has_timer flag to 0
    sw      $zero, VELOCITY

    while_water_in_short_after_move_special:
    lw  $t0, GET_WATER_LEVEL
    bge $t0, 1000000, end_water_in_short_after_move_special
    jal get_water
    j   while_water_in_short_after_move_special
    end_water_in_short_after_move_special:

    sw      $s1, POWERWASH_ON

    lw      $ra, 0($sp)
    lw      $s1, 4($sp)
    addi    $sp, $sp, 8
    jr      $ra                                 # return
################################################################################
# function run_around
# param:
#       void
# return:
#       void
# ###############################################################################
run_around:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

    lw  $t0, BOT_X
    bgt $t0, 160, right_run

left_run:
    # ========== water on ==========
    li  $t0, 0x0002FE00
    sw  $t0, POWERWASH_ON

    li  $a0, 280
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li  $t0, 0x00020200
    sw  $t0, POWERWASH_ON

    li  $a0, 280
    li  $a1, 180
    jal move_bot

    j   end_run

right_run:
    # ========== water on ==========
    li  $t0, 0x00020200
    sw  $t0, POWERWASH_ON

    li  $a0, 280
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li  $t0, 0x0002FE00
    sw  $t0, POWERWASH_ON

    li  $a0, 280
    li  $a1, 0
    jal move_bot

end_run:
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    lw  $ra, 0($sp)
    add $sp, $sp, 4
    jr  $ra
################################################################################
# function clean_sides
# param:
#       void
# return:
#       void
# ###############################################################################
clean_sides:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

    lw  $t0, BOT_X
    bgt $t0, 160, right_clean_sides

left_clean_sides:

    # north 12 splitted
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    # east 5
    li  $a0, 40
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li  $t0, 0x00040200
    sw  $t0, POWERWASH_ON

    # north 24 splitted
    li  $a0, 128
    li  $a1, 270
    li  $a2, 5
    jal move_bot_velocity
    li  $a0, 128
    li  $a1, 270
    li  $a2, 5
    jal move_bot_velocity
    li  $a0, 64
    li  $a1, 270
    jal move_bot_special                    # <<< special move bot
    # ========== water on ==========
    li $t0, 0x00020000                  # <<<<<<<<<<<< radius
    sw $t0, POWERWASH_ON
    # jump
    li  $a0, 175
    li  $a1, 180
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF
    
    # do that again
    li  $a0, 20
    li  $a1, 0
    jal move_bot
    # north 12 splitted
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    # east 5
    li  $a0, 40
    li  $a1, 0
    jal move_bot
    # north 24 splitted
    li  $a0, 64
    li  $a1, 270
    jal move_bot
    li  $a0, 64
    li  $a1, 270
    jal move_bot
    li  $a0, 64
    li  $a1, 270
    jal move_bot_special                    # <<< special move bot
    # ========== water on ==========
    li $t0, 0x00040000                  # <<<<<<<<<<<< radius
    sw $t0, POWERWASH_ON
    # jump
    li  $a0, 175
    li  $a1, 180
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # ========= to right side =========
    # east a little bit
    li  $a0, 20
    li  $a1, 0
    jal move_bot
    # north 12 splitted
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    # east 5
    li  $a0, 40
    li  $a1, 0
    jal move_bot
    # north 10 splitted
    li  $a0, 35
    li  $a1, 270
    jal move_bot
    li  $a0, 35
    li  $a1, 270
    jal move_bot_special
    # ========== water on ==========
    li  $t0, 0x00020002
    sw  $t0, POWERWASH_ON
    # to the east end
    li  $a0, 200
    li  $a1, 0
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF
    # =================================

    # north 14 splitted
    li  $a0, 55
    li  $a1, 270
    jal move_bot
    li  $a0, 59
    li  $a1, 270
    jal move_bot_special                    # <<< special move bot

    # ========== water on ==========
    li $t0, 0x00020000                  # <<<<<<<<<<<< radius
    sw $t0, POWERWASH_ON
    # jump
    li  $a0, 175
    li  $a1, 0
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # do that again
    li  $a0, 20
    li  $a1, 180
    jal move_bot

    # north 12 splitted
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    # west 5
    li  $a0, 40
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FE00 
    sw $t0, POWERWASH_ON 

    # north 24 splitted
    li  $a0, 128
    li  $a1, 270
    li  $a2, 5
    jal move_bot_velocity
    li  $a0, 128
    li  $a1, 270
    li  $a2, 5
    jal move_bot_velocity
    li  $a0, 128
    li  $a1, 270
    jal move_bot_special                    # <<< special move bot
    # ========== water on ==========
    li $t0, 0x00040000                  # <<<<<<<<<<<< radius
    sw $t0, POWERWASH_ON
    # jump
    li  $a0, 175
    li  $a1, 0
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    j   end_clean_sides

right_clean_sides:

    # north 12 splitted
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    # west 5
    li  $a0, 40
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li  $t0, 0x0004FE00
    sw  $t0, POWERWASH_ON

    # north 24 splitted
    li  $a0, 128
    li  $a1, 270
    li  $a2, 5
    jal move_bot_velocity
    li  $a0, 128
    li  $a1, 270
    li  $a2, 5
    jal move_bot_velocity
    li  $a0, 64
    li  $a1, 270
    jal move_bot_special                    # <<< special move bot
    # ========== water on ==========
    li $t0, 0x00020000                  # <<<<<<<<<<<< radius
    sw $t0, POWERWASH_ON
    # jump
    li  $a0, 175
    li  $a1, 0
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # do that again
    li  $a0, 20
    li  $a1, 180
    jal move_bot
    # north 12 splitted
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    # west 5
    li  $a0, 40
    li  $a1, 180
    jal move_bot
    # north 24 splitted
    li  $a0, 64
    li  $a1, 270
    jal move_bot
    li  $a0, 64
    li  $a1, 270
    jal move_bot
    li  $a0, 64
    li  $a1, 270
    jal move_bot_special                    # <<< special move bot
    # ========== water on ==========
    li $t0, 0x00040000                  # <<<<<<<<<<<< radius
    sw $t0, POWERWASH_ON
    # jump
    li  $a0, 175
    li  $a1, 0
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # ========= to left side =========
    # east a little bit
    li  $a0, 20
    li  $a1, 180
    jal move_bot
    # north 12 splitted
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    # west 5
    li  $a0, 40
    li  $a1, 180
    jal move_bot
    # north 10 splitted
    li  $a0, 35
    li  $a1, 270
    jal move_bot
    li  $a0, 35
    li  $a1, 270
    jal move_bot_special
    # ========== water on ==========
    li  $t0, 0x00020002
    sw  $t0, POWERWASH_ON
    # to the west end
    li  $a0, 200
    li  $a1, 180
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF
    # =================================

    # north 14 splitted
    li  $a0, 55
    li  $a1, 270
    jal move_bot
    li  $a0, 59
    li  $a1, 270
    jal move_bot_special                    # <<< special move bot

    # ========== water on ==========
    li $t0, 0x00040000                  # <<<<<<<<<<<< radius
    sw $t0, POWERWASH_ON
    # jump
    li  $a0, 175
    li  $a1, 180
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # do that again
    li  $a0, 20
    li  $a1, 0
    jal move_bot

    # north 12 splitted
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    li  $a0, 45
    li  $a1, 270
    jal move_bot
    # east 5
    li  $a0, 40
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040200 
    sw $t0, POWERWASH_ON 

    # north 24 splitted
    li  $a0, 128
    li  $a1, 270
    li  $a2, 5
    jal move_bot_velocity
    li  $a0, 128
    li  $a1, 270
    li  $a2, 5
    jal move_bot_velocity
    li  $a0, 128
    li  $a1, 270
    jal move_bot_special                    # <<< special move bot
    # ========== water on ==========
    li $t0, 0x00040000                  # <<<<<<<<<<<< radius
    sw $t0, POWERWASH_ON
    # jump
    li  $a0, 175
    li  $a1, 180
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

end_clean_sides:
    lw  $ra, 0($sp)
    add $sp, $sp, 4
    jr  $ra
################################################################################
# function traverse_map
# param:
#       void
# return:/
#       void
################################################################################
traverse_map:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

    lw  $t0, BOT_X
    bgt $t0, 160, right_init

left_init:

    # ========== water on ==========
    li $t0, 0x00040100
    sw $t0, POWERWASH_ON

    # # north 12
    # li  $a0, 96
    # li  $a1, 270
    # jal move_bot
    # north 12 splitted
    li  $a0, 48
    li  $a1, 270
    jal move_bot
    li  $a0, 48
    li  $a1, 270
    jal move_bot
    
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # east 5
    li  $a0, 40
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li  $t0, 0x0004FE00
    sw  $t0, POWERWASH_ON

    # # north 22
    # li  $a0, 176
    # li  $a1, 270
    # jal move_bot
    # north 22 splitted
    li  $a0, 55
    li  $a1, 270
    jal move_bot
    li  $a0, 55
    li  $a1, 270
    jal move_bot
    li  $a0, 66
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040200
    sw $t0, POWERWASH_ON

    # jump on the ladder
    li  $a0, 150
    li  $a1, 290
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040200
    sw $t0, POWERWASH_ON

    # move till the end of the ladder
    lw  $t0, BOT_X 
    sub $a0, $t0, 110
    neg $a0, $a0
    li  $a1, 0
    jal move_bot

    # south jump
    li  $a0, 150
    li  $a1, 90
    li  $a2, 2
    jal move_bot_velocity

    # ========== water on ==========
    li $t0, 0x000402FE
    sw $t0, POWERWASH_ON

    # jump a little bit
    li  $a0, 140
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000400FE 
    sw $t0, POWERWASH_ON

    # east 
    lw  $t0, BOT_X
    sub $a0, $t0, 136
    neg $a0, $a0
    li  $a1, 0
    jal move_bot

    # jump to central vine
    li  $a0, 80
    li  $a1, 315
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000400FE
    sw $t0, POWERWASH_ON

    # move to vine top
    lw  $t0, BOT_Y
    sub $a0, $t0, 88
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FEFE
    sw $t0, POWERWASH_ON
    # jump a little bit
    li  $a0, 140
    li  $a1, 270
    jal move_bot
    # ========== water on ==========
    li $t0, 0x000402FE
    sw $t0, POWERWASH_ON
    # jump a little bit
    li  $a0, 140
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040002
    sw $t0, POWERWASH_ON

    # move to vine down
    li  $a0, 56
    li  $a1, 90
    jal move_bot

    # east
    lw  $t0, BOT_X
    sub $a0, $t0, 184
    neg $a0, $a0
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000400FE
    sw $t0, POWERWASH_ON

    # move to next end
    lw  $t0, BOT_X
    sub $a0, $t0, 260
    neg $a0, $a0
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040200
    sw $t0, POWERWASH_ON

    # # north 12
    # li  $a0, 96
    # li  $a1, 270
    # jal move_bot
    # north 12 splitted
    li  $a0, 48
    li  $a1, 270
    jal move_bot
    li  $a0, 48
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FE00
    sw $t0, POWERWASH_ON

    # jump on the ladder
    li  $a0, 150
    li  $a1, 250
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FE00
    sw $t0, POWERWASH_ON

    # move till the end of the ladder
    lw  $t0, BOT_X
    sub $a0, $t0, 210
    li  $a1, 180
    jal move_bot

    # south jump
    li  $a0, 150
    li  $a1, 90
    li  $a2, 2
    jal move_bot_velocity

    # # ========== water on ==========
    # li $t0, 0x0004FEFE
    # sw $t0, POWERWASH_ON

    # jump a little bit
    li  $a0, 140
    li  $a1, 270
    jal move_bot

    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # east
    lw  $t0, BOT_X
    sub $a0, $t0, 260
    neg $a0, $a0
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040200
    sw $t0, POWERWASH_ON

    # south down
    li  $a0, 72
    li  $a1, 90
    jal move_bot

    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # east
    lw  $t0, BOT_X
    sub $a0, $t0, 300
    neg $a0, $a0
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FF00
    sw $t0, POWERWASH_ON

    # south jump down
    li  $a0, 96
    li  $a1, 90
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000400FE
    sw $t0, POWERWASH_ON

    # west
    lw  $t0, BOT_X
    sub $a0, $t0, 188
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040100
    sw $t0, POWERWASH_ON

    # # north 11
    # li  $a0, 92
    # li  $a1, 270
    # jal move_bot
    # north 11 splitted
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    li  $a0, 46
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FEFE
    sw $t0, POWERWASH_ON

    # east 6
    li  $a0, 56
    li  $a1, 0
    jal move_bot

    # # ========== water on ==========
    # li  $t0, 0x000400FE
    # sw  $t0, POWERWASH_ON

    # # jump a little bit
    # li  $a0, 140
    # li  $a1, 270
    # jal move_bot

    # ========== water on ==========
    li  $t0, 0x00040000
    sw  $t0, POWERWASH_ON

    # south jump down
    li  $a0, 100
    li  $a1, 90
    jal move_bot

    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # west 6
    li  $a0, 56
    li  $a1, 180
    jal move_bot

    # # north 11
    # li  $a0, 92
    # li  $a1, 270
    # jal move_bot
    # north 11 splitted
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    li  $a0, 46
    li  $a1, 270
    jal move_bot

    # east 6
    li  $a0, 56
    li  $a1, 0
    jal move_bot
    # ========== water on ==========
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON
    # south jump down
    li  $a0, 100
    li  $a1, 90
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # west 6
    li  $a0, 56
    li  $a1, 180
    jal move_bot
    # # north 11
    # li  $a0, 92
    # li  $a1, 270
    # jal move_bot
    # north 11 splitted
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    
    # ========== water on ==========
    li $t0, 0x000400FE
    sw $t0, POWERWASH_ON

    # south-west jump
    li  $a0, 40
    li  $a1, 135
    jal move_bot

    # add-on central jump
    li  $a0, 140
    li  $a1, 270
    jal move_bot

    # south jump down
    li  $a0, 64
    li  $a1, 90
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000400FE
    sw $t0, POWERWASH_ON

    # move to next ladder
    lw  $t0, BOT_X
    sub $a0, $t0, 132
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FF00
    sw $t0, POWERWASH_ON

    # # north 11
    # li  $a0, 92
    # li  $a1, 270
    # jal move_bot
    # north 11 splitted
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    li  $a0, 46
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000402FE
    sw $t0, POWERWASH_ON

    # west 7
    li  $a0, 56
    li  $a1, 180
    jal move_bot

    # # ========== water on ==========
    # li $t0, 0x000400FE
    # sw $t0, POWERWASH_ON

    # # jump a little bit
    # li  $a0, 140
    # li  $a1, 270
    # jal move_bot

    # ========== water on ==========
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON

    # south jump down
    li  $a0, 100
    li  $a1, 90
    jal move_bot

    # east 6
    li  $a0, 56
    li  $a1, 0
    jal move_bot
    # # north 11
    # li  $a0, 92
    # li  $a1, 270
    # jal move_bot
    # north 11 splitted
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    # west 7
    li  $a0, 56
    li  $a1, 180
    jal move_bot
    # ========== water on ==========
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON
    # south jump down
    li  $a0, 100
    li  $a1, 90
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # ========== water on ==========
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON

    # back to init
    li  $a0, 56
    li  $a1, 180
    jal move_bot

    j   end_traverse

right_init:
    # ========== water on ==========
    li $t0, 0x0004FF00
    sw $t0, POWERWASH_ON

    # # north 12
    # li  $a0, 96
    # li  $a1, 270
    # jal move_bot
    # north 12 splitted
    li  $a0, 48
    li  $a1, 270
    jal move_bot
    li  $a0, 48
    li  $a1, 270
    jal move_bot

    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # west 5
    li  $a0, 40
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li  $t0, 0x00040200
    sw  $t0, POWERWASH_ON

    # # north 22
    # li  $a0, 176
    # li  $a1, 270
    # jal move_bot
    # north 22 splitted
    li  $a0, 55
    li  $a1, 270
    jal move_bot
    li  $a0, 55
    li  $a1, 270
    jal move_bot
    li  $a0, 66
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FE00
    sw $t0, POWERWASH_ON

    # jump on the ladder
    li  $a0, 150
    li  $a1, 248
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FE00
    sw $t0, POWERWASH_ON

    # move till the end of the ladder
    lw  $t0, BOT_X
    sub $a0, $t0, 210
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li  $t0, 0x00040200
    sw  $t0, POWERWASH_ON

    # south jump down
    li  $a0, 100
    li  $a1, 90
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FEFE
    sw $t0, POWERWASH_ON

    # jump a little bit
    li  $a0, 140
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040002 
    sw $t0, POWERWASH_ON

    # west
    lw  $t0, BOT_X
    sub $a0, $t0, 184
    li  $a1, 180
    jal move_bot

    # jump to central vine
    li  $a0, 80
    li  $a1, 225
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000400FE
    sw $t0, POWERWASH_ON

    # move to vine top
    lw  $t0, BOT_Y
    sub $a0, $t0, 88
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000402FE
    sw $t0, POWERWASH_ON
    # jump a little bit
    li  $a0, 140
    li  $a1, 270
    jal move_bot
    # ========== water on ==========
    li $t0, 0x0004FEFE
    sw $t0, POWERWASH_ON
    # jump a little bit
    li  $a0, 140
    li  $a1, 270
    jal move_bot

    # # ========== water off ==========
    # sw  $zero, POWERWASH_OFF

    # # move to vine almost down
    # li  $a0, 40
    # li  $a1, 90
    # jal move_bot

    # # ========== water on ==========
    # li $t0, 0x00040002
    # sw $t0, POWERWASH_ON

    # # move to vine down
    # li  $a0, 16
    # li  $a1, 90
    # jal move_bot

    # ========== water on ==========
    li $t0, 0x00040002
    sw $t0, POWERWASH_ON

    # move to vine down
    li  $a0, 56
    li  $a1, 90
    jal move_bot

    # west
    lw  $t0, BOT_X
    sub $a0, $t0, 128
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000400FE
    sw $t0, POWERWASH_ON

    # move to next end
    lw  $t0, BOT_X
    sub $a0, $t0, 56
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FE00
    sw $t0, POWERWASH_ON

    # # north 12
    # li  $a0, 96
    # li  $a1, 270
    # jal move_bot
    # north 12 splitted
    li  $a0, 48
    li  $a1, 270
    jal move_bot
    li  $a0, 48
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040200
    sw $t0, POWERWASH_ON

    # jump on the ladder
    li  $a0, 150
    li  $a1, 292
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040200
    sw $t0, POWERWASH_ON

    # move till the end of the ladder
    lw  $t0, BOT_X
    sub $a0, $t0, 110
    neg $a0, $a0
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FE00
    sw $t0, POWERWASH_ON

    # south jump
    li  $a0, 80
    li  $a1, 90
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000402FE
    sw $t0, POWERWASH_ON

    # jump a little bit
    li  $a0, 140
    li  $a1, 270
    jal move_bot

    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # west
    lw  $t0, BOT_X
    sub $a0, $t0, 58
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FE00
    sw $t0, POWERWASH_ON

    # south down
    li  $a0, 72
    li  $a1, 90
    jal move_bot

    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # west
    lw  $t0, BOT_X
    sub $a0, $t0, 20
    li  $a1, 180
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040100
    sw $t0, POWERWASH_ON

    # south jump down
    li  $a0, 96
    li  $a1, 90
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000400FE
    sw $t0, POWERWASH_ON

    # east
    lw  $t0, BOT_X
    sub $a0, $t0, 132
    neg $a0, $a0
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FF00
    sw $t0, POWERWASH_ON

    # # north 11
    # li  $a0, 92
    # li  $a1, 270
    # jal move_bot
    # north 11 splitted
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    li  $a0, 46
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000402FE
    sw $t0, POWERWASH_ON

    # west 6
    li  $a0, 56
    li  $a1, 180
    jal move_bot

    # # ========== water on ==========
    # li $t0, 0x000400FE
    # sw $t0, POWERWASH_ON

    # # jump a little bit
    # li  $a0, 140
    # li  $a1, 270
    # jal move_bot

    # ========== water on ==========
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON

    # south jump down
    li  $a0, 100
    li  $a1, 90
    jal move_bot

    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # east 6
    li  $a0, 56
    li  $a1, 0
    jal move_bot

    # # north 11
    # li  $a0, 92
    # li  $a1, 270
    # jal move_bot
    # north 11 splitted
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    li  $a0, 46
    li  $a1, 270
    jal move_bot

    # west 6
    li  $a0, 56
    li  $a1, 180
    jal move_bot
    # ========== water on ==========
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON
    # south jump down
    li  $a0, 100
    li  $a1, 90
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF
    
    # east 6
    li  $a0, 56
    li  $a1, 0
    jal move_bot
    # # north 11
    # li  $a0, 92
    # li  $a1, 270
    # jal move_bot
    # north 11 splitted
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    li  $a0, 46
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000400FE
    sw $t0, POWERWASH_ON

    # south-east jump
    li  $a0, 40
    li  $a1, 45
    jal move_bot

    # add-on central jump
    li  $a0, 140
    li  $a1, 270
    jal move_bot

    # south jump down
    li  $a0, 64
    li  $a1, 90
    jal move_bot

    # ========== water on ==========
    li $t0, 0x000400FE
    sw $t0, POWERWASH_ON

    # move to next ladder
    lw  $t0, BOT_X
    sub $a0, $t0, 188
    neg $a0, $a0
    li  $a1, 0
    jal move_bot

    # ========== water on ==========
    li $t0, 0x00040100
    sw $t0, POWERWASH_ON

    # # north 11
    # li  $a0, 92
    # li  $a1, 270
    # jal move_bot
    # north 11 splitted
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    li  $a0, 46
    li  $a1, 270
    jal move_bot

    # ========== water on ==========
    li $t0, 0x0004FEFE
    sw $t0, POWERWASH_ON

    # east 8
    li  $a0, 56
    li  $a1, 0
    jal move_bot

    # # ========== water on ==========
    # li $t0, 0x000400FE
    # sw $t0, POWERWASH_ON

    # # jump a little bit
    # li  $a0, 140
    # li  $a1, 270
    # jal move_bot

    # ========== water on ==========
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON

    # south jump down
    li  $a0, 100
    li  $a1, 90
    jal move_bot

    # west 6
    li  $a0, 56
    li  $a1, 180
    jal move_bot
    # # north 11
    # li  $a0, 92
    # li  $a1, 270
    # jal move_bot
    # north 11 splitted
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    li  $a0, 46
    li  $a1, 270
    jal move_bot
    # east 7
    li  $a0, 56
    li  $a1, 0
    jal move_bot
    # ========== water on ==========
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON
    # south jump down
    li  $a0, 100
    li  $a1, 90
    jal move_bot
    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    # ========== water on ==========
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON

    # back to init
    li  $a0, 56
    li  $a1, 0
    jal move_bot

end_traverse:

    # ========== water off ==========
    sw  $zero, POWERWASH_OFF

    lw  $ra, 0($sp)
    add $sp, $sp, 4
    jr  $ra

################################################################################
# function get_dirty_window
# param:
#       void
# return:
#       $v0 - row of the dirty window
#       $v1 - col of the dirty window
################################################################################
get_dirty_window:
    li $t0, 40       
    li $t1, 0        
    li $t2, 0     
    la $s0, map_info
    sw $s0, GET_MAP
row_loop:
    li $t2, 0
    column_loop:       
        mul $t5, $t1, $t0
        add $t5, $t5, $t2
        sll $t5, $t5, 1
        add $s1, $s0, $t5
        lh $s2, 0($s1)
        srl $s3, $s2, 4
        blez $s3, continue_column_loop
        andi $t6, $s2, 0x1
        bne $t6, 1, continue_column_loop
        move $v0, $t1
        move $v1, $t2
        j end_loop
        continue_column_loop:
        addi $t2, $t2, 1
        blt $t2, $t0, column_loop
    addi $t1, $t1, 1
    blt $t1, $t0, row_loop
end_loop:
    jr $ra
################################################################################
#                               puzzle                                         #
################################################################################
.data
# puzzle max 10 x 10, but I want some more spaceeeeeee (I'm using sw to reset them, so at least 12 for row/col)
.align 4
col_q: .space 16
.align 4
row_q: .space 16
.align 4
left_diag: .space 32
.align 4
right_diag: .space 32

.text
# .globl is_attacked
# is_attacked:
#     sub $t8,$a1,1 # $t8 = n - 1

#     lb $t0,col_q($a3)
#     bne $t0,$0,return1

#     # WE DON'T NEED TO CHECK ROW HERE SINCE WE DID IT IN place_queen_step
#     # lb $t0,row_q($a2)
#     # bne $t0,$0,return1

#     sub $t0,$a3,$a2 # $t0 = col - row
#     add $t0,$t0,$t8 # $t0 += n - 1
#     lb $t0,left_diag($t0)
#     bne $t0,$0,return1

#     sub $t1,$a1,$a3 # $t1 = n - col
#     sub $t0,$t1,$a2 # $t0 = n - col - row
#     add $t0,$t0,$t8 # $t0 += n - 1
#     lb $t0,right_diag($t0)
#     bne $t0,$0,return1

# return0:
#     li $v0,0            # output 0
#     jr $ra              # return
    
# return1:
#     li $v0,1            # output 1
#     jr $ra              # return

.globl place_queen_step
place_queen_step:
    beq     $a3, $0, pqs_return1_direct     # if (queens_left == 0)

pqs_prologue: 
    sub     $sp, $sp, 36 
    sw      $s0, 0($sp)
    sw      $s1, 4($sp)
    sw      $s2, 8($sp)
    sw      $s3, 12($sp)
    sw      $s4, 16($sp)
    sw      $s5, 20($sp)
    sw      $s6, 24($sp)
    sw      $s7, 28($sp)
    sw      $ra, 32($sp)
    # $s0 for left_diag, $s1 for right_diag

    #move    $s0, $a0                # $s0 = board
    #move    $s1, $a1                # $s1 = n
    move    $s3, $a3                # $s3 = queens_left
    move    $s4, $a2                # $s4 = row
    sub     $s2, $a1, 1 # $s2 = n - 1

pqs_for_new_start:
    #li $s5, 0 # curr col

    sll     $s6, $s4, 2             # $s6 = row * 4
    add     $s6, $s6, $a0           # $s6 = &board[row] = board + row * 4

pqs_for_new_outer:
    bge $s4,$a1,pqs_for_end # row >= n, break outer loop

    li $s5, 0 # reset col

    # check row first!!!
    lb $t1,row_q($s4)
    bne $t1,$0,pqs_for_new_outer_next
    
    # COL MUST BE 0 HERE!!! WE DON'T ADD COL
    lw      $s7, 0($s6)             # $s7 = board[row] + col(0)

    # inner loop
    pqs_for_new_inner:
    # we check if col >= n at the end of loop since in the first iteration col must be 0 but n > 0!

    # board[row][col] never be 1 since we've already checked this row!!!
    # lb      $t1, 0($s7)             # $t1 = board[row][col]
    # bne     $t1, $0, pqs_for_new_inner_next    # skip if !(board[row][col] == 0)

    # BOARD and N NEVER CHANGE
    # move    $a0, $s0                # board
    # move    $a1, $s1                # n

    # call is_attacked
    # move    $a2, $s4                # row
    # move    $a3, $s5                # col
    # jal     is_attacked             # call is_attacked(board, n, row, col)

    # bne     $v0, $0, pqs_for_new_inner_next    # skip if !(is_attacked(board, n, row, col) == 0)

    # ------- inline is_attacked -------

    # sub $t8,$a1,1 # $t8 = n - 1

    lb $t0,col_q($s5)
    bne $t0,$0,pqs_for_new_inner_next

    sub $s0,$s5,$s4 # $s0 = col - row
    add $s0,$s0,$s2 # $s0 += n - 1
    lb $t0,left_diag($s0)
    bne $t0,$0,pqs_for_new_inner_next

    sub $s1,$a1,$s5 # $s1 = n - col
    sub $s1,$s1,$s4 # $s1 = n - col - row
    add $s1,$s1,$s2 # $s1 += n - 1
    lb $t0,right_diag($s1)
    bne $t0,$0,pqs_for_new_inner_next

    # ------- inline is_attacked end -------

    li      $t0, 1
    sb      $t0, 0($s7)             # board[row][col] = 1
    # place a queen in row_q and col_q, left_diag, right_diag
    sb      $t0, row_q($s4)
    sb      $t0, col_q($s5)

    # $s0 for left_diag, $s1 for right_diag
    # sub $t8,$a1,1 # $t8 = n - 1
    # sub $s0,$s5,$s4 # $s0 = col - row
    # add $s0,$s0,$s2 # $s0 += n - 1

    # sub $s1,$a1,$s5 # $s1 = n - col
    # sub $s1,$s1,$s4 # $s1 = n - col - row
    # add $s1,$s1,$s2 # $s1 += n - 1

    sb      $t0, left_diag($s0)
    sb      $t0, right_diag($s1)


    # BOARD and N NEVER CHANGE
    # move    $a0, $s0                # board
    # move    $a1, $s1                # n
    # move    $a2, $s4                # row
    addi    $a2, $s4, 1             # row + 1 (next row)
    sub     $a3, $s3, 1             # queens_left - 1
    jal     place_queen_step        # call place_queen_step(board, n, row + 1, queens_left - 1)

    beq     $v0, $0, pqs_inner_reset_square       # skip return if !(place_queen_step(board, n, row + 1, queens_left - 1) == 0)

    # $v0 must be 1 now
    #li      $v0, 1
    j       pqs_epilogue            # return 1

    pqs_inner_reset_square:
    sb      $0, 0($s7)              # board[row][col] = 0
    # reset row_q and col_q, left_diag, right_diag
    sb      $0, row_q($s4)
    sb      $0, col_q($s5)
    sb      $0, left_diag($s0)
    sb      $0, right_diag($s1)



    pqs_for_new_inner_next:
    addi $s5,$s5,1
    addi $s7,$s7,1 # board next col
    blt $s5,$a1,pqs_for_new_inner # col >= n, break inner loop

pqs_for_new_outer_next:
    addi $s4,$s4,1
    addi $s6,$s6,4 # next row
    j pqs_for_new_outer

pqs_for_end:
    move    $v0, $0                  # return 0

pqs_epilogue:
    lw      $s0, 0($sp)
    lw      $s1, 4($sp)
    lw      $s2, 8($sp)
    lw      $s3, 12($sp)
    lw      $s4, 16($sp)
    lw      $s5, 20($sp)
    lw      $s6, 24($sp)
    lw      $s7, 28($sp)
    lw      $ra, 32($sp)
    add     $sp, $sp, 36 
    jr      $ra
pqs_return1_direct:
    li $v0,1
    jr $ra

.globl solve_queens
solve_queens:
sq_prologue:
    # sub     $sp, $sp, 20
    # sw      $s0, 0($sp)
    # sw      $s1, 4($sp)
    # sw      $s2, 8($sp)
    # sw      $s3, 12($sp)
    # sw      $ra, 16($sp)

    sub $sp, $sp, 4
    sw  $ra, 0($sp)

    # move    $s0, $a0
    # move    $s1, $a1
    # move    $s2, $a2
    # move    $s3, $a3

    # reset row_q and col_q, left_diag, right_diag
    li $t0, 0
    sw $0,row_q($t0)
    sw $0,col_q($t0)
    sw $0,left_diag($t0)
    sw $0,right_diag($t0)

    ble $a1,4,reset_one_more_diag # n <= 4, there is no branch penalty in SPIM!!!

    addi $t0,$t0,4
    sw $0,row_q($t0)
    sw $0,col_q($t0)
    sw $0,left_diag($t0)
    sw $0,right_diag($t0)

    ble $a1,8,reset_two_more_diag # n <= 8

    addi $t0,$t0,4
    sw $0,row_q($t0)
    sw $0,col_q($t0)
    sw $0,left_diag($t0)
    sw $0,right_diag($t0)
reset_two_more_diag:
    addi $t0,$t0,4
    sw $0,left_diag($t0)
    sw $0,right_diag($t0)
reset_one_more_diag:
    addi $t0,$t0,4
    sw $0,left_diag($t0)
    sw $0,right_diag($t0)

    li      $t0, 0      # $t0 is i
    move    $t3, $a0    # $t3 = &board[i], i = 0

sq_for_i:
    beq     $t0, $a1, sq_end_for_i
    li      $t1, 0      # $t1 is j

    lw      $t7, 0($t3) # $t7 = board[i][j], j = 0

    # # reset row_q and col_q, left_diag, right_diag
    # sb $0,row_q($t0)
    # sb $0,col_q($t0)
    # sb $0,left_diag($t0)
    # sb $0,right_diag($t0)
    # add $t9,$t0,$s1
    # sb $0,left_diag($t9)
    # sb $0,right_diag($t9)

sq_for_j:
    beq     $t1, $a1, sq_end_for_j

    # sll     $t3, $t0, 2             # $t3 = i * 4
    # add     $t3, $t3, $s0           # $t3 = &board[i] = board + i * 4
    # lw      $t3, 0($t3)             # $t3 = board[i]

    # add     $t3, $t3, $t1           # $t3 = &board[i][j] = board[i] + j
    sb      $0, 0($t7)              # board[i][j] = 0

    addi    $t1, $t1, 1     # ++j
    addi    $t7, $t7, 1     # board[i][j], +1
    j       sq_for_j

sq_end_for_j:
    addi    $t0, $t0, 1     # ++i
    addi    $t3, $t3, 4     # &board[i], +1*4
    j       sq_for_i

sq_end_for_i:
sq_ll_setup:
    li $t9,1 # use it to set 1, don't change its value
    sub $t8,$a1,1 # $t8 = n - 1
    move    $t5, $a2        # $t5 is curr

sq_ll_for:
    beq     $t5, $0, sq_ll_end
    
    lw      $t6, 0($t5)         # $t6 = curr->pos

    # div     $t0, $t6, $s1       # $t0 = row = pos / n
    # rem     $t1, $t6, $s1       # $t1 = col = pos % n
    div $t6,$a1
    mflo $t0 # row
    mfhi $t1 # col

    # set placed queen
    sb $t9,row_q($t0)
    sb $t9,col_q($t1)
    
    sub $t4,$t1,$t0 # $t4 = col - row
    add $t4,$t4,$t8 # $t4 += n - 1
    sb $t9,left_diag($t4)

    sub $t4,$a1,$t1 # $t4 = n - col
    sub $t4,$t4,$t0 # $t4 = n - col - row
    add $t4,$t4,$t8 # $t4 += n - 1
    sb $t9,right_diag($t4)

    
    sll     $t3, $t0, 2             # $t3 = row * 4
    add     $t3, $t3, $a0           # $t3 = &board[row] = board + row * 4
    lw      $t3, 0($t3)             # $t3 = board[row]

    add     $t3, $t3, $t1           # $t3 = &board[row][col] = board[row] + col
    #li      $t7, 1
    sb      $t9, 0($t3)             # board[row][col] = 1

    lw      $t5, 4($t5)             # curr = curr->next

    j       sq_ll_for

sq_ll_end:
    move    $a2, $0
    jal     place_queen_step        # call place_queen_step(sol_board, n, 0, queens_to_place)

sq_epilogue:
    # lw      $s0, 0($sp)
    # lw      $s1, 4($sp)
    # lw      $s2, 8($sp)
    # lw      $s3, 12($sp)
    # lw      $ra, 16($sp)

    # add     $sp, $sp, 20
    lw      $ra, 0($sp)
    addi    $sp, $sp, 4
    jr      $ra