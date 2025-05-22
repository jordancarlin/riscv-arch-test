///////////////////////////////////////////
// InterruptsS_M.S
//
// Written: Hjamal@hmc.edu       6 April 2025
//
// Purpose: Functional coverage tests for Supervisor-mode Interrupts running in User mode
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "model_test.h"

#include "arch_test.h"

RVTEST_ISA("RV32I_Zicsr, RV64I_Zicsr")

# Test code region
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN

#ifdef TEST_CASE_1
    RVTEST_CASE(1,"//check ISA:=regex(.*I.*S.*Zicsr.*BLOCKED.*); def rvtest_mtrap_routine=True; def rvtest_strap_routine=True; def rvtest_dtrap_routine=True; def TEST_CASE_1=True",interruptsS_U)

    #define rvtest_mtrap_routine
    #define rvtest_strap_routine
    #define rvtest_dtrap_routine
    
    ALL_MEM_PMP          		                  	                      	// set the PMP permissions for the whole memory
	csrw satp, zero  		                                        		// write satp with all zeros (bare mode)
    
    la sp, topofstack
    jal reset_mtimecmp

    RVTEST_GOTO_LOWER_MODE Smode

    ///////////////////////////////
    // cp_user_mti
    //
    // Cross of mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, 
    // stvec.MODE={00/01}, mideleg.MTI = {0/1}, mie.MTIE = 1, 
    // set MTIMECMP to trigger interrupt
    ///////////////////////////////

    cp_user_mti:
        
        li a0, 16           # use a0 as bitfield
        RVTEST_GOTO_MMODE   # start test in M-mode to set CSRs

        1:
        addi a0, a0, -1
        andi t0, a0, 8
        csrrci t6, mstatus, 8
        bnez t0, 2f             # set mstatus.MIE with bit 3 of a0
        csrrsi t6, mstatus, 8

        2:
        andi t0, a0, 4
        csrrci t6, mstatus, 2
        bnez t0, 3f             # set mstatus.SIE with bit 2 of a0
        csrrsi t6, mstatus, 2

        3:
        andi t0, a0, 2
        csrrci t6, stvec, 3
        bnez t0, 4f             # set stvec.MODE[0] with bit 1 of a0
        csrrsi t6, stvec, 1

        4:
        andi t0, a0, 1
        li t1, 128
        csrrc t6, mideleg, t1
        bnez t0, 5f             # set mideleg.MTI with bit 0 of a0
        csrrs t6, mideleg, t1

        5:
        li t1, 128
        csrrs t6, mie, t1       # set mie.MTIE = 1
        jal cause_mtimer_interrupt_now  # set mip.MTIP = 1
        RVTEST_GOTO_LOWER_MODE Umode    # switch to U-mode
        nop                             # expect interrupt if mstatus.SIE = 1
        RVTEST_GOTO_MMODE               # return to M-mode for cleanup
        jal reset_mtimecmp              # clear mip.MTIP
        bnez a0, 1b                     # loop to next case

    ///////////////////////////////
    // cp_user_msi
    //
    // Cross of mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, 
    // stvec.MODE={00/01}, mideleg.MSI = {0/1}, mie.MSIE = 1,
    // set CLINT.MSIP to trigger interrupt
    ///////////////////////////////

    cp_user_msi:
        
        li a0, 16           # use a0 as bitfield
        RVTEST_GOTO_MMODE   # start test in M-mode to set CSRs

        1:
        addi a0, a0, -1
        andi t0, a0, 8
        csrrci t6, mstatus, 8
        bnez t0, 2f             # set mstatus.MIE with bit 3 of a0
        csrrsi t6, mstatus, 8

        2:
        andi t0, a0, 4
        csrrci t6, mstatus, 2
        bnez t0, 3f             # set mstatus.SIE with bit 2 of a0
        csrrsi t6, mstatus, 2

        3:
        andi t0, a0, 2
        csrrci t6, stvec, 3
        bnez t0, 4f             # set stvec.MODE[0] with bit 1 of a0
        csrrsi t6, stvec, 1

        4:
        andi t0, a0, 1
        csrrci t6, mideleg, 8
        bnez t0, 5f             # set mideleg.MSI with bit 0 of a0
        csrrsi t6, mideleg, 8

        5:
        csrrsi t6, mie, 8       # set mie.MSIE = 1
        jal cause_msoftware_interrupt  # set mip.MSIP = 1
        RVTEST_GOTO_LOWER_MODE Umode    # switch to U-mode
        nop                             # expect interrupt if mstatus.SIE = 1
        RVTEST_GOTO_MMODE               # return to M-mode for cleanup
        jal reset_msoftware_interrupt              # clear mip.MSIP
        bnez a0, 1b                     # loop to next case

    ///////////////////////////////
    // cp_user_mei
    //
    // Cross of mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, 
    // stvec.MODE={00/01}, mideleg.MEI = {0/1}, mie.MEIE = 1,
    // set PLIC to trigger ME interrupt
    ///////////////////////////////

    cp_user_mei:
        
        li a0, 16           # use a0 as bitfield
        RVTEST_GOTO_MMODE   # start test in M-mode to set CSRs

        1:
        addi a0, a0, -1
        andi t0, a0, 8
        csrrci t6, mstatus, 8
        bnez t0, 2f             # set mstatus.MIE with bit 3 of a0
        csrrsi t6, mstatus, 8

        2:
        andi t0, a0, 4
        csrrci t6, mstatus, 2
        bnez t0, 3f             # set mstatus.SIE with bit 2 of a0
        csrrsi t6, mstatus, 2

        3:
        andi t0, a0, 2
        csrrci t6, stvec, 3
        bnez t0, 4f             # set stvec.MODE[0] with bit 1 of a0
        csrrsi t6, stvec, 1

        4:
        andi t0, a0, 1
        li t1, 2048
        csrrc t6, mideleg, t1
        bnez t0, 5f             # set mideleg.MSI with bit 0 of a0
        csrrs t6, mideleg, t1

        5:
        li t1, 2048
        csrrs t6, mie, t1       # set mie.MEIE = 1
        jal cause_external_interrupt_M  # set mip.MEIP = 1
        RVTEST_GOTO_LOWER_MODE Umode    # switch to U-mode
        nop                             # expect interrupt if mstatus.SIE = 1
        RVTEST_GOTO_MMODE               # return to M-mode for cleanup
        jal reset_external_interrupts   # clear mip.MEIP
        bnez a0, 1b                     # loop to next case

    ///////////////////////////////
    // cp_user_sei
    //
    // Cross of mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, 
    // stvec.MODE={00/01}, mideleg.SEI = {0/1}, mie.SEIE = 1,
    // set PLIC to trigger SE interrupt
    ///////////////////////////////

    cp_user_sei:
        
        li a0, 16           # use a0 as bitfield
        RVTEST_GOTO_MMODE   # start test in M-mode to set CSRs

        1:
        addi a0, a0, -1
        andi t0, a0, 8
        csrrci t6, mstatus, 8
        bnez t0, 2f             # set mstatus.MIE with bit 3 of a0
        csrrsi t6, mstatus, 8

        2:
        andi t0, a0, 4
        csrrci t6, mstatus, 2
        bnez t0, 3f             # set mstatus.SIE with bit 2 of a0
        csrrsi t6, mstatus, 2

        3:
        andi t0, a0, 2
        csrrci t6, stvec, 3
        bnez t0, 4f             # set stvec.MODE[0] with bit 1 of a0
        csrrsi t6, stvec, 1

        4:
        andi t0, a0, 1
        li t1, 512
        csrrc t6, mideleg, t1
        bnez t0, 5f             # set mideleg.MSI with bit 0 of a0
        csrrs t6, mideleg, t1

        5:
        li t1, 512
        csrrs t6, mie, t1       # set mie.SEIE = 1
        jal cause_external_interrupt_S  # set mip.SEIP = 1
        RVTEST_GOTO_LOWER_MODE Umode    # switch to U-mode
        nop                             # expect interrupt if mstatus.SIE = 1
        RVTEST_GOTO_MMODE               # return to M-mode for cleanup
        jal reset_external_interrupts   # clear mip.SEIP
        bnez a0, 1b                     # loop to next case

    j test_end

    reset_mtimecmp:
        // resets M-mode timer compare register to prevent further M-mode timer interrupts
        li t0, -1               # set mtimecmp to biggest number so it doesnt interrupt again
        la t1, MTIMECMP
        SREG t0, 0(t1)
        #ifdef __riscv_xlen
            #if __riscv_xlen == 32
                sw t0, 4(t1)
            #endif
        #else
            ERROR: __riscv_xlen not defined
        #endif

        ret

    reset_external_interrupts:
        # set M-mode interrupt threshold to 7
        la t0, THRESHOLD_0
        li t1, 7
        sw t1, 0(t0)
        
        # set S-mode interrupt threshold to 7
        la t0, THRESHOLD_1
        li t1, 7
        sw t1, 0(t0)

        // disable GPIO's sufficient priority to trigger interrupt
        la t0, INT_PRIORITY_3
        sw zero, 0(t0)

        // disable interrupts from source 3 (GPIO) in M-mode
        la t0, INT_EN_00
        sw zero, 0(t0)

        // clear all interrupt enables to make sure interrupt doesn't go off prematurely
        la t0, GPIO_BASE_ADDR
        sw zero, 0x18(t0) # clear rise
        sw zero, 0x20(t0) # clear fall
        sw zero, 0x28(t0) # clear high
        sw zero, 0x30(t0) # clear low

        ret

    reset_msoftware_interrupt:
        la t0, CLINT_BASE_ADDR
        SREG zero, 0(t0) # write CLINT.msip = 1 for hart 0

        ret

    cross_interrupts_s_EP:
        // helper function for crossing mie.MEIE/MSIE/MTIE with mip.MEIP/MSIP/MTIP in Interrupts tests (enables and pending)
        li s1, 5                # iterate through setting mie.M/SEIE, M/SSIE, or M/STIE (5-0)
        li t1, -1

        addi sp, sp, -8
        SREG ra, 0(sp)

        for_mie:
        
            slli t3, s1, 1      # setting mie.M/SEIE, M/SSIE, or M/STIE based on s1 value
            li t4, 2
            sll t4, t4, t3
            csrrw t6, mie, t4   # set enable for interrupt type of interest, clear all others
        
            jal raise_interrupts_s
        
            addi s1, s1, -1     
            bge s1, zero, for_mie # iterate through interrupt types to be enabled

        LREG ra, 0(sp)
        addi sp, sp, 8
            
        ret

    raise_interrupts_s:
        // raises each of mip.M/SEIP/M/SSIP/M/STIP once in sequence

        addi sp, sp, -8
        SREG ra, 0(sp)

        li s2, 5

        for_mip:
            
            # based on s2 value, attempt to trigger one of M/SEIP, M/SSIP, or M/STIP
            # includes resets in case interrupt is not triggered

            case5_vectored:
                li t3, 5
                bne s2, t3, case4_vectored
                
                li t1, 32
                csrrs t6, mip, t1
                RVTEST_GOTO_LOWER_MODE Smode
                csrrci t6, sstatus, 2
                csrrsi t6, sstatus, 2
                RVTEST_GOTO_MMODE
                li t1, 32
                csrrc t6, mip, t1

            case4_vectored:
                li t3, 4
                bne s2, t3, case3_vectored
                li t0, 512
                csrrs t6, mip, t0
                RVTEST_GOTO_LOWER_MODE Smode
                csrrci t6, sstatus, 2
                csrrsi t6, sstatus, 2
                RVTEST_GOTO_MMODE
                li t0, 512
                csrrc t6, mip, t0
            
            case3_vectored:
                li t3, 3
                bne s2, t3, case3_vectored
                csrrsi t6, mip, 2
                RVTEST_GOTO_LOWER_MODE Smode
                csrrci t6, sstatus, 2
                csrrsi t6, sstatus, 2
                RVTEST_GOTO_MMODE
                csrrci t6, mip, 2
            
            case2_vectored:
                li t3, 2
                bne s2, t3, case1_vectored      # if s2 == 2, trigger timer interrupt
                jal cause_mtimer_interrupt_now
                RVTEST_GOTO_LOWER_MODE Smode
                csrrci t6, sstatus, 2
                csrrsi t6, sstatus, 2
                RVTEST_GOTO_MMODE
                jal reset_mtimecmp

            case1_vectored:
                li t3, 1
                bne s2, t3, case0_vectored      # if s2 == 1, trigger external interrupt
                jal cause_external_interrupt_M
                RVTEST_GOTO_LOWER_MODE Smode
                csrrci t6, sstatus, 2
                csrrsi t6, sstatus, 2
                RVTEST_GOTO_MMODE
                jal reset_external_interrupts

            case0_vectored:
                li t3, 0
                bne s2, t3, case_end_vectored   # if s2 = 0, trigger software interrupt
                jal cause_msoftware_interrupt
                RVTEST_GOTO_LOWER_MODE Smode
                csrrci t6, sstatus, 2
                csrrsi t6, sstatus, 2
                RVTEST_GOTO_MMODE
                jal reset_msoftware_interrupt

            case_end_vectored:
                addi s2, s2, -1
                bge s2, zero, for_mip

        LREG ra, 0(sp)
        addi sp, sp, 8

        ret

    cause_mtimer_interrupt_now:
        // raises an M-mode timer interrupt using CLINT, interrupt is raised as soon as the function writes to MTIMECMP(H)

        la t0, MTIME
        la t1, MTIMECMP
        LREG t2, 0(t0) # read MTIME
        SREG t2, 0(t1) # set MTIMECMP = MTIME to cause timer interrupt

        #ifdef __riscv_xlen
            #if __riscv_xlen == 32
                    lw t2, 4(t0) # high word of MTIME
                    sw t2, 4(t1) # MTIMECMP high word = MTIME high word
            #endif
        #else
            ERROR: __riscv_xlen not defined
        #endif

        ret

    cause_mtimer_interrupt_soon:
        // raises an M-mode timer interrupt using CLINT, interrupt is raised 256 (255) cycles after write to MTIMECMP(H)
        la t0, MTIME
        la t4, MTIMECMP

        #ifdef __riscv_xlen
            #if __riscv_xlen == 64
                    ld t0, 0(t0)                    # read MTIME
                    
                    addi t0, t0, 0x100              # create a delay
                    
                    sd t0, 0(t4)         # set MTIMECMP = MTIME + 0x100 to cause timer interrupt later

            #elif __riscv_xlen == 32
                    lw t1, 0(t0)                    # low word of MTIME
                    lw t2, 4(t0)                    # high word of MTIME
                    
                    addi t3, t1, 0x100              # add 0x100 to MTIME value
                    bgtu t1, t3, MTIME_overflow     # if overflow occurred, carry the 1 to MTIME high word
                    j write_MTIMECMP                # otherwise, leave MTIME high word untouched
                    
                    MTIME_overflow:
                    addi t2, t2, 1
                    
                    write_MTIMECMP:
                    sw t3, 0(t4)          # MTIMECMP = MTIME + 0x100
                    sw t2, 4(t4)          
            #endif
            
        #else
            ERROR: __riscv_xlen not defined
        #endif

        ret

    cause_msoftware_interrupt:
        la t0, CLINT_BASE_ADDR
        la t1, 1
        SREG t1, 0(t0) # write CLINT.msip = 1 for hart 0

        ret

    cause_external_interrupt_M:
        // raises an external M-mode interrupt using GPIO
        # set M-mode interrupt threshold to 0
        la t0, THRESHOLD_0
        sw zero, 0(t0)
        
        # set S-mode interrupt threshold to 7
        la t0, THRESHOLD_1
        li t1, 7
        sw t1, 0(t0)

        # give GPIO sufficient priority to trigger interrupt
        la t0, INT_PRIORITY_3
        li t1, 1
        sw t1, 0(t0)

        # clear all interrupt enables to make sure interrupt doesn't go off prematurely
        la t0, GPIO_BASE_ADDR
        li t1, 1
        sw t1, 0x08(t0) # enable output on pin 1
        sw t1, 0x04(t0) # enable input on pin 1

        sw zero, 0x18(t0) # clear rise enable
        sw zero, 0x20(t0) # clear fall enable
        sw zero, 0x28(t0) # clear high enable
        sw zero, 0x30(t0) # clear low enable

        # enable interrupts from source 3 (GPIO) in M-mode
        la t0, INT_EN_00
        li t1, 0b1000
        sw t1, 0(t0)

        # enable interrupts from high output
        la t0, GPIO_BASE_ADDR
        li t1, 1
        sw t1, 0x28(t0) # enable high interrupt for pin 1
        sw t1, 0x0C(t0) # write 1 to pin 1, this should cause interrupt

        ret

    cause_external_interrupt_S:
        // raises an external S-mode interrupt using GPIO
        # set M-mode interrupt threshold to 7
        la t0, THRESHOLD_0
        li t1, 7
        sw t1, 0(t0)
        
        # set S-mode interrupt threshold to 0
        la t0, THRESHOLD_1
        sw zero, 0(t0)

        # give GPIO sufficient priority to trigger interrupt
        la t0, INT_PRIORITY_3
        li t1, 1
        sw t1, 0(t0)

        # clear all interrupt enables to make sure interrupt doesn't go off prematurely
        la t0, GPIO_BASE_ADDR
        li t1, 1
        sw t1, 0x08(t0) # enable output on pin 1
        sw t1, 0x04(t0) # enable input on pin 1

        sw zero, 0x18(t0) # clear rise enable
        sw zero, 0x20(t0) # clear fall enable
        sw zero, 0x28(t0) # clear high enable
        sw zero, 0x30(t0) # clear low enable

        # enable interrupts from source 3 (GPIO) in S-mode
        la t0, INT_EN_10
        li t1, 0b1000
        sw t1, 0(t0)

        # enable interrupts from high output
        la t0, GPIO_BASE_ADDR
        li t1, 1
        sw t1, 0x28(t0) # enable high interrupt for pin 1
        sw t1, 0x0C(t0) # write 1 to pin 1, this should cause interrupt

        ret

    test_end:

    RVMODEL_IO_WRITE_STR(x30, "# Test part A - test InterruptsS\n");

    RVMODEL_IO_WRITE_STR(x30, "# Test End\n")

#endif

 # ---------------------------------------------------------------------------------------------
    # HALT

RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
# Input data section.
    .data
    .align 4
RVTEST_DATA_END

# Output data section.
RVMODEL_DATA_BEGIN
rvtest_sig_begin:
sig_begin_canary:
CANARY;

test_A_res:
    .fill 2, 4, 0xdeadbeef

mtrap_sigptr:
  .fill 4, 4, 0xdeadbeef

#ifdef rvtest_gpr_save
gpr_save:
  .fill 32*(XLEN/32), 4, 0xdeadbeef
#endif

sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END

scratch:
.fill 4,4,0x0

# Initialize stack with room for 512 bytes
.bss
    .space 512
topofstack:
