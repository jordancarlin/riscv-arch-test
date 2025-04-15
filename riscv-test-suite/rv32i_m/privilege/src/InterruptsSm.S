// -----------
// Copyright (c) 2020. RISC-V International. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// -----------
//
// This assembly file tests the ecall instruction of the RISC-V I extension.
// 

#include "model_test.h"

#define ACCESS_FAULT_ADDRESS 0
#define CLINT_BASE_ADDR 0x02000000
#define PLIC_BASE_ADDR 0x0C000000
#define GPIO_BASE_ADDR 0x10060000

#define MTIME           (CLINT_BASE_ADDR + 0xBFF8)
#define MSIP            (CLINT_BASE_ADDR)
#define MTIMECMP        (CLINT_BASE_ADDR + 0x4000)
#define MTIMECMPH       (CLINT_BASE_ADDR + 0x4004)

#define THRESHOLD_0     (PLIC_BASE_ADDR + 0x200000)
#define THRESHOLD_1     (PLIC_BASE_ADDR + 0x201000)
#define INT_PRIORITY_3  (PLIC_BASE_ADDR + 0x00000C)
#define INT_EN_00       (PLIC_BASE_ADDR + 0x002000)
#define INT_EN_10       (PLIC_BASE_ADDR + 0x002080)

#define GPIO_OUTPUT_EN  (GPIO_BASE_ADDR + 0x08)
#define GPIO_OUTPUT_VAL (GPIO_BASE_ADDR + 0x0C)

#include "arch_test.h"

RVTEST_ISA("RV32I_Zicsr")

# Test code region
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN

#ifdef TEST_CASE_1
    RVTEST_CASE(1,"//check ISA:=regex(.*32.*); check ISA:=regex(.*I.*Zicsr.*); def rvtest_mtrap_routine=True; def rvtest_strap_routine=True; def rvtest_dtrap_routine=True; def TEST_CASE_1=True",interruptsM)

    #define rvtest_mtrap_routine
    #define rvtest_strap_routine
    #define rvtest_dtrap_routine

    ALL_MEM_PMP          		                  	                      	// set the PMP permissions for the whole memory
	csrw satp, zero  		                                        		// write satp with all zeros (bare mode)
    
    csrr sp, sscratch
    jal reset_mtimecmp

    RVTEST_GOTO_LOWER_MODE Smode

    ///////////////////////////////
    // cp_interrupts
    //
    // Cross of mstatus.MIE = {0/1}, mtvec.MODE = 00, mideleg = {0s/1s},
    // 6 walking 1s in mie, 6 walking 1s in mip (2 x 6 x 6 bins)
    ///////////////////////////////

    cp_interrupts:

        li a3, 2

        1:
        RVTEST_GOTO_MMODE
        li a0, 2
        li t1, -1
        csrrw t6, mideleg, zero
        addi a3, a3, -1
        bnez a3, 2f
        csrrw t6, mideleg, t1

            2:
            li a1, 6
            la s1, 8096
            csrrci t6, mtvec, 3
            csrrsi t6, mstatus, 8
            addi a0, a0, -1
            bnez a0, 3f
            csrrci t6, mstatus, 8

                3:
                li a2, 6
                la s2, 8096
                csrrc t6, mip, s1
                srli s1, s1, 2
                csrrs t6, mip, s1
            
                    4:
                    csrrc t6, mie, s2
                    srli s2, s2, 2
                    csrrs t6, mie, s2
                    addi a2, a2, -1
                    bnez a2, 3b
                
                addi a1, a1, -1
                bnez a1, 3b
                
            bnez a0, 2b

        bnez a3, 1b

    /////////////////////////////////
    // cp_vectored
    // Cross of mtvec.MODE = 01, mstatus.MIE=1, mideleg = 0s, all 3 of mie.STIE/SSIE/SEIE,
    // 3 walking 1s in mip.STIP/SSIP/SEIP (3 bins)
    /////////////////////////////////

    cp_vectored:

        csrrci t6, mtvec, 3
        csrrsi t6, mtvec, 1 # mtvec.MODE = 01

        csrrsi t6, mstatus, 8 # mstatus.MIE = 1
        csrrw t6, mie, zero     # clear all interrupt enables

        li s1, 0x0222
        csrrs t6, mie, s1       # set mie.SEIE/STIE/SSIE

        li s2, 3

        1:
        addi s2, s2, -1
        li t0, 2
        bne s2, t0, 2f
        csrrsi t6, mip, 2

        2:
        li t0, 1
        bne s2, t0, 3f
        li t1, 32
        csrrs t6, mip, t1

        3:
        bnez s2, 4f
        li t0, 512
        csrrs t6, mip, t0

        4:
        bnez s2, 1b

    ///////////////////////////////
    // cp_priority_mip
    //
    // Cross of 2^6 permutations of mip, mie=1s, mideleg = 0s.  
    // Set up with mstatus.MIE = 0, then it rises.
    ///////////////////////////////

    cp_priority_mip:
        li a0, 64
        
        1:
        RVTEST_GOTO_MMODE
        addi a0, a0, -1
        li t0, -1
        csrrw t6, mie, t0
        csrrw t6, mideleg, zero
        csrrci t6, mstatus, 8

        andi t0, a0, 32        
        beqz t0, 2f
        li t1, 32
        csrrs t6, mip, t1

        2:
        andi t0, a0, 16        
        beqz t0, 3f
        li t0, 512
        csrrs t6, mip, t0

        3:
        andi t0, a0, 8      
        beqz t0, 4f
        csrrsi t6, mip, 2
            
        4:
        andi t0, a0, 4        
        beqz t0, 5f
        jal cause_mtimer_interrupt_now

        5:
        andi t0, a0, 2        
        beqz t0, 6f
        jal cause_external_interrupt_M

        6:
        andi t0, a0, 1        
        beqz t0, 7f
        jal cause_msoftware_interrupt_clint

        7:
        csrrsi t6, mstatus, 8
        csrrw t6, mip, zero
        jal reset_msoftware_interrupt_clint
        jal reset_mtimecmp
        jal reset_external_interrupts
        bnez a0, 1b

    ///////////////////////////////
    // cp_priority_mie
    //
    // Cross of 2^6 permutations of mie, mip=1s, mideleg = 0s.  
    // Set up with mstatus.MIE = 0, then it rises.
    ///////////////////////////////

    cp_priority_mie_m:
        li a0, 64

        1:
        RVTEST_GOTO_MMODE
        addi a0, a0, -1
        li t0, -1
        csrrw t6, mip, t0
        csrrw t6, mideleg, zero
        csrrci t6, mstatus, 8
        jal cause_mtimer_interrupt_now
        jal cause_external_interrupt_M
        jal cause_msoftware_interrupt_clint

        andi t0, a0, 32        
        beqz t0, 2f
        csrrsi t6, mie, 2

        2:
        andi t0, a0, 16        
        beqz t0, 3f
        csrrsi t6, mie, 8

        3:
        andi t0, a0, 8      
        beqz t0, 4f
        li t1, 32
        csrrs t6, mie, t1
            
        4:
        andi t0, a0, 4        
        beqz t0, 5f
        li t0, 128
        csrrs t6, mie, t0

        5:
        andi t0, a0, 2        
        beqz t0, 6f
        li t0, 512
        csrrs t6, mie, t0

        6:
        andi t0, a0, 1        
        beqz t0, 7f
        li t0, 2048
        csrrs t6, mie, t0

        7:
        csrrsi t6, mstatus, 8
        csrrw t6, mie, zero
        bnez a0, 1b

    ///////////////////////////////
    // cp_wfi_m
    //
    // Cross Product of mstatus.MIE = {0/1}
    // Cross Product of mstatus.SIE = {0/1}
    // Cross product of mstatus.TW = {0/1}
    // Cross product of mideleg = 1s
    // mie.MTIE = 1
    // Set MTIMECMP = TIME + 0x100 to interrupt in the future
    // WFI Instruction
    ///////////////////////////////

    cp_wfi:
    
        li a0, 8
        RVTEST_GOTO_MMODE

        1:
        addi a0, a0, -1
        csrrci t6, mstatus, 8
        andi t0, a0, 4
        beqz t0, 2f
        csrrsi t6, mstatus, 8
        
        2:
        csrrci t6, mstatus, 2
        andi t0, a0, 2
        beqz t0, 3f
        csrrsi t6, mstatus, 2

        3:
        li t1, 1
        slli t1, t1, 21
        csrrc t6, mstatus, t1
        andi t0, a0, 1
        beqz t0, 4f 
        csrrs t6, mstatus, t1

        4:
        li t0, -1
        csrrw t6, mideleg, t0
        li t0, 128
        csrrs t6, mie, t0
        jal cause_mtimer_interrupt_soon
        wfi
        bnez a0, 1b

    /////////////////////////////////
    // cp_trigger_ssi_mip
    //
    // With mstatus.MIE = {0/1}, and mie = 1s, write sip.SSIP
    /////////////////////////////////

    cp_trigger_ssi_mip:
        RVTEST_GOTO_MMODE
        li t0, -1               # all 1s
        csrrw t6, mie, t0       # enable all interrupts

        # mstatus.MIE = 0 should not take interrupt
        csrrci t6, mstatus, 8   # mstatus.MIE = 0
        csrrsi t6, sip, 2
        csrrci t6, sip, 2       # reset sip.SSIP since the trap handler will not reset it if no interrupt occurs

        # mstatus.MIE = 1 should take interrupt
        csrrsi t6, mstatus, 8   # mstatus.MIE = 1
        csrrsi t6, sip, 2       # set sip.SSIP, expect interrupt
        csrrci t6, sip, 2

    /////////////////////////////////
    // cp_trigger_changingtom_mti
    // 
    // with mideleg = 0s, mie = 1s, use MTIMECMP to cause mip.MTIP to rise,
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_changingtom_mti:
    RVTEST_GOTO_MMODE
    li t0, -1
    csrrw t6, mideleg, zero
    csrrw t6, mie, t0
    RVTEST_GOTO_LOWER_MODE Smode
    jal cause_mtimer_interrupt_now
    RVTEST_GOTO_MMODE
    csrrsi t6, mstatus, 8
    csrrci t6, mstatus, 8
    jal reset_mtimecmp

    /////////////////////////////////
    // cp_trigger_changingtom_msi
    // 
    // with mideleg = 0s, mie = 1s, use CLINT.MSIP to cause mip.MSIP to rise,
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_changingtom_msi:
    RVTEST_GOTO_MMODE
    li t0, -1
    csrrw t6, mideleg, zero
    csrrw t6, mie, t0
    RVTEST_GOTO_LOWER_MODE Smode
    jal cause_msoftware_interrupt_clint
    RVTEST_GOTO_MMODE
    csrrsi t6, mstatus, 8
    csrrci t6, mstatus, 8
    jal reset_msoftware_interrupt_clint

    /////////////////////////////////
    // cp_trigger_changingtom_mei
    // 
    // with mideleg = 0s, mie = 1s, use PLIC to cause mip.MEIP to rise,
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_changingtom_mei:
    RVTEST_GOTO_MMODE
    li t0, -1
    csrrw t6, mideleg, zero
    csrrw t6, mie, t0
    RVTEST_GOTO_LOWER_MODE Smode
    jal cause_external_interrupt_M
    RVTEST_GOTO_MMODE
    csrrsi t6, mstatus, 8
    csrrci t6, mstatus, 8
    jal reset_external_interrupts

    /////////////////////////////////
    // cp_trigger_changingtom_sti
    // 
    // with mideleg = 0s, mie = 1s, mip.STIP=1, 
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_changingtom_sti:
    RVTEST_GOTO_MMODE
    li t0, -1
    csrrw t6, mideleg, zero
    csrrw t6, mie, t0
    RVTEST_GOTO_LOWER_MODE Smode
    li t1, 32
    csrrs t6, mip, t1
    RVTEST_GOTO_MMODE
    csrrsi t6, mstatus, 8
    csrrci t6, mstatus, 8
    li t1, 32
    csrrc t6, mip, t1

    /////////////////////////////////
    // cp_trigger_changingtom_ssi
    // 
    // with mideleg = 0s, mie = 1s, mip.SSIP=1, 
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_changingtom_ssi:
    RVTEST_GOTO_MMODE
    li t0, -1
    csrrw t6, mideleg, zero
    csrrw t6, mie, t0
    RVTEST_GOTO_LOWER_MODE Smode
    csrrsi t6, mip, 2
    RVTEST_GOTO_MMODE
    csrrsi t6, mstatus, 8
    csrrci t6, mstatus, 8
    csrrci t6, mip, 2

    /////////////////////////////////
    // cp_trigger_changingtom_sei
    // 
    // with mideleg = 0s, mie = 1s, use PLIC to cause mip.SEIP,
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_changingtom_sei:
    RVTEST_GOTO_MMODE
    li t0, -1
    csrrw t6, mideleg, zero
    csrrw t6, mie, t0
    RVTEST_GOTO_LOWER_MODE Smode
    jal cause_external_interrupt_S
    RVTEST_GOTO_MMODE
    csrrsi t6, mstatus, 8
    csrrci t6, mstatus, 8
    jal reset_external_interrupts

    /////////////////////////////////
    // cp_sei4
    // 
    // With mstatus.MIE=0, mip.SEIP=1, PLIC not activating SEIP,
    // use csrrc to clear mip.SEIP
    /////////////////////////////////

    cp_sei4:
        RVTEST_GOTO_MMODE
        csrrci t6, mstatus, 8
        li t0, 128
        csrrs t6, mip, t0
        csrrc t6, mip, t0

    /////////////////////////////////
    // cp_sei5
    // 
    // With mstatus.MIE=0, mip.SEIP=1 because of previous write,
    // PLIC activating SEIP, use csrrc to clear mip.SEIP
    /////////////////////////////////

    cp_sei5:
        RVTEST_GOTO_MMODE
        csrrci t6, mstatus, 8
        li t0, 128
        csrrs t6, mip, t0
        jal cause_external_interrupt_S
        csrrc t6, mip, t0
        jal reset_external_interrupts

    /////////////////////////////////
    // cp_sei6
    // 
    // With mstatus.MIE=0, no previous write 1 to mip.SEIP, 
    // PLIC activating SEIP, turn off PLIC.SEIP
    /////////////////////////////////

    cp_sei6:
        RVTEST_GOTO_MMODE
        csrrci t6, mstatus, 8
        jal cause_external_interrupt_S
        csrrc t6, mip, t0
        jal reset_external_interrupts

    /////////////////////////////////
    // cp_sei7
    // 
    // With mstatus.MIE=0, previous write 1 to mip.SEIP,
    // PLIC activating SEIP, turn off PLIC.SEIP
    /////////////////////////////////

    cp_sei7:
        RVTEST_GOTO_MMODE
        csrrci t6, mstatus, 8
        jal cause_external_interrupt_S
        jal reset_external_interrupts
        csrrc t6, mip, t0

    /////////////////////////////////
    // cp_global_ie
    // 
    // mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mip.MTIP/MSIP/MEIP = 1s,
    // mie.MTIE/MSIE/MEIE = 1s (2 x 2 x 3 bins)
    /////////////////////////////////

    cp_global_ie:
        li a0, 4
        li a1, 3
        
        1:
        addi a0, a0, -1

        2:
        jal cause_mtimer_interrupt_now
        jal cause_msoftware_interrupt_clint
        jal cause_external_interrupt_M
        csrrci t6, mstatus, 8
        andi t0, a0, 2
        bnez t0, 3f
        csrrsi t6, mstatus, 8

        3:
        csrrci t6, mstatus, 2
        andi t0, a0, 1
        bnez t0, 4f
        csrrsi t6, mstatus, 2

            4:
            addi a1, a1, -1
            li t0, 2
            bne t0, a1, 5f
            li t0, 512
            csrrs t6, mie, t0

            5:
            li t0, 1
            bne t0, a1, 6f
            li t1, 32
            csrrs t6, mie, t1

            6:
            bnez a1, 7f
            csrrsi t6, mie, 2

            7:
            bnez a1, 2b

        bnez a0, 1b

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

    reset_msoftware_interrupt_clint:
        la t0, CLINT_BASE_ADDR
        SREG zero, 0(t0) # write CLINT.msip = 1 for hart 0

        ret

    cross_interrupts_s_EP:
        // helper function for crossing mie.MEIE/MSIE/MTIE with mip.MEIP/MSIP/MTIP in Interrupts tests (enables and pending)
        li s1, 5                # iterate through setting mie.M/SEIE, M/SSIE, or M/STIE (5-0)
        li t1, -1

        addi sp, sp, 8
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
        addi sp, sp, -8
            
        ret

    raise_interrupts_s:
        // raises each of mip.M/SEIP/M/SSIP/M/STIP once in sequence

        addi sp, sp, 8
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
                jal cause_msoftware_interrupt_clint
                RVTEST_GOTO_LOWER_MODE Smode
                csrrci t6, sstatus, 2
                csrrsi t6, sstatus, 2
                RVTEST_GOTO_MMODE
                jal reset_msoftware_interrupt_clint

            case_end_vectored:
                addi s2, s2, -1
                bge s2, zero, for_mip

        LREG ra, 0(sp)
        addi sp, sp, -8

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

    cause_msoftware_interrupt_clint:
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
