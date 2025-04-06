// -----------
// Copyright (c) 2020. RISC-V International. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// -----------
//
// This assembly file tests the ecall instruction of the RISC-V I extension.
// 

#include "model_test.h"
#include "arch_test.h"

RVTEST_ISA("RV32I_Zicsr")

# Test code region
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN

#ifdef TEST_CASE_1
    RVTEST_CASE(1,"//check ISA:=regex(.*32.*); check ISA:=regex(.*I.*Zicsr.*); def rvtest_strap_routine=True; def TEST_CASE_1=True",interruptsSr)
    
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

    jal reset_mtimecmp

    RVTEST_GOTO_LOWER_MODE Smode

    ///////////////////////////////
    // cp_trigger_mti
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s}, 
    // and mie = 1s, use MTIMECMP to cause mip.MTIP to rise
    ///////////////////////////////

    cp_trigger_mti:

        li a0, 8

        1:
        RVTEST_GOTO_HIGHER_MODE Mmode
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 8
        beqz t0, 2f
        csrrw t6, mideleg, t1
        
        2:
        csrrci t6, mstatus, 8
        andi t0, a0, 4
        beqz t0, 3f
        csrrsi t6, mstatus, 8
        
        3:
        csrrci t6, mstatus, 2
        andi t0, a0, 2
        beqz t0, 4f 
        csrrsi t6, mstatus, 2

        4:
        RVTEST_GOTO_LOWER_MODE Smode
        jal cause_mtimer_interrupt_now
        jal reset_mtimecmp # reset mtimecmp to avoid premature interrupt in next test
        addi a0, a0, -1
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_msi
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s}, 
    // and mie = 1s, use CLINT.MSIP to cause mip.MSIP to rise
    ///////////////////////////////

    cp_trigger_msi:

        li a0, 8

        1:
        RVTEST_GOTO_HIGHER_MODE Mmode
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 8
        beqz t0, 2f
        csrrw t6, mideleg, t1
        
        2:
        csrrci t6, mstatus, 8
        andi t0, a0, 4
        beqz t0, 3f
        csrrsi t6, mstatus, 8
        
        3:
        csrrci t6, mstatus, 2
        andi t0, a0, 2
        beqz t0, 4f 
        csrrsi t6, mstatus, 2

        4:
        RVTEST_GOTO_LOWER_MODE Smode
        jal cause_msoftware_interrupt_clint
        jal reset_msoftware_interrupt_clint # reset msip to avoid premature interrupt in next test
        addi a0, a0, -1
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_mei
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s}, 
    // and mie = 1s, use PLIC or other EIC to cause mip.MEIP to rise
    ///////////////////////////////

    cp_trigger_mei:
    
        li a0, 8

        1:
        RVTEST_GOTO_HIGHER_MODE Mmode
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 8
        beqz t0, 2f
        csrrw t6, mideleg, t1
        
        2:
        csrrci t6, mstatus, 8
        andi t0, a0, 4
        beqz t0, 3f
        csrrsi t6, mstatus, 8
        
        3:
        csrrci t6, mstatus, 2
        andi t0, a0, 2
        beqz t0, 4f 
        csrrsi t6, mstatus, 2

        4:
        RVTEST_GOTO_LOWER_MODE Smode
        jal cause_external_interrupt_M
        jal reset_external_interrupts       # reset external interrupts to avoid premature interrupt in next test
        addi a0, a0, -1
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_sti
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s},
    // and mie = 1s, mip.STIP=1, change to supervisor mode
    ///////////////////////////////

    cp_trigger_sti:
    
        li a0, 4

        1:
        RVTEST_GOTO_HIGHER_MODE Mmode
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 8
        beqz t0, 2f
        csrrw t6, mideleg, t1
        
        2:
        csrrci t6, mstatus, 8
        andi t0, a0, 4
        beqz t0, 3f
        csrrsi t6, mstatus, 8
        
        3:
        csrrci t6, mstatus, 2
        andi t0, a0, 2
        beqz t0, 4f 
        csrrsi t6, mstatus, 2

        4:
        csrrsi t6, mip, 32
        RVTEST_GOTO_LOWER_MODE Smode
        nop
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mip, 32
        RVTEST_GOTO_LOWER_MODE Smode
        addi a0, a0, -1
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_ssi_mip
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s},
    // and mie = 1s, mip.SSIP=1, change to supervisor mode
    ///////////////////////////////

    cp_trigger_ssi_mip:
    
        li a0, 8

        1:
        RVTEST_GOTO_HIGHER_MODE Mmode
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 8
        beqz t0, 2f
        csrrw t6, mideleg, t1
        
        2:
        csrrci t6, mstatus, 8
        andi t0, a0, 4
        beqz t0, 3f
        csrrsi t6, mstatus, 8
        
        3:
        csrrci t6, mstatus, 2
        andi t0, a0, 2
        beqz t0, 4f 
        csrrsi t6, mstatus, 2

        4:
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrsi t6, mip, 2
        RVTEST_GOTO_LOWER_MODE Smode
        nop
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mip, 2
        RVTEST_GOTO_LOWER_MODE Smode
        addi a0, a0, -1
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_ssi_sip
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s},
    // and mie = 1s, sip.SSIP=1, change to supervisor mode
    ///////////////////////////////

    cp_trigger_ssi_sip:
    
        li a0, 8

        1:
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 8
        beqz t0, 2f
        csrrw t6, mideleg, t1
        
        2:
        csrrci t6, mstatus, 8
        andi t0, a0, 4
        beqz t0, 3f
        csrrsi t6, mstatus, 8
        
        3:
        csrrci t6, mstatus, 2
        andi t0, a0, 2
        beqz t0, 4f 
        csrrsi t6, mstatus, 2

        4:
        csrrsi t6, sip, 2
        csrrci t6, sip, 2
        addi a0, a0, -1
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_sei
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s},
    // and mie = 1s, use PLIC or other EIC to cause sip.SEIP to rise
    ///////////////////////////////

    cp_trigger_sei:
    
        li a0, 8

        1:
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 8
        beqz t0, 2f
        csrrw t6, mideleg, t1
        
        2:
        csrrci t6, mstatus, 8
        andi t0, a0, 4
        beqz t0, 3f
        csrrsi t6, mstatus, 8
        
        3:
        csrrci t6, mstatus, 2
        andi t0, a0, 2
        beqz t0, 4f 
        csrrsi t6, mstatus, 2

        4:
        jal cause_external_interrupt_S
        jal reset_external_interrupts
        addi a0, a0, -1
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_sei_seip
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s},
    // and mie = 1s, write mip.SEIP=1
    ///////////////////////////////

    cp_trigger_sei_seip:
    
        li a0, 8

        1:
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 8
        beqz t0, 2f
        csrrw t6, mideleg, t1
        
        2:
        csrrci t6, mstatus, 8
        andi t0, a0, 4
        beqz t0, 3f
        csrrsi t6, mstatus, 8
        
        3:
        csrrci t6, mstatus, 2
        andi t0, a0, 2
        beqz t0, 4f 
        csrrsi t6, mstatus, 2

        4:
        RVTEST_GOTO_HIGHER_MODE Mmode
        li t0, 512
        csrrs t6, mip, t0
        RVTEST_GOTO_LOWER_MODE Smode
        nop
        RVTEST_GOTO_HIGHER_MODE Mmode
        li t0, 512
        csrrc t6, mip, t0
        RVTEST_GOTO_LOWER_MODE Smode
        addi a0, a0, -1
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_changingtos_mti
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.MTIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_mti:
    
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, zero
        csrrw t6, mie, t1
        jal cause_mtimer_interrupt_now
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        jal reset_mtimecmp

        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, t1
        csrrw t6, mie, t1
        jal cause_mtimer_interrupt_now
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        jal reset_mtimecmp

    ///////////////////////////////
    // cp_trigger_changingtos_msi
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.MSIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_msi:
    
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, zero
        csrrw t6, mie, t1
        csrrs t6, mip, 8
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrc t6, mip, 8

        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, t1
        csrrs t6, mip, 8
        jal cause_mtimer_interrupt_now
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrc t6, mip, 8

    ///////////////////////////////
    // cp_trigger_changingtos_mei
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.MEIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_mei:
    
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, zero
        csrrw t6, mie, t1
        cause_external_interrupt_M
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        reset_external_interrupts

        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, t1
        cause_external_interrupt_M
        jal cause_mtimer_interrupt_now
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        reset_external_interrupts

    ///////////////////////////////
    // cp_trigger_changingtos_sti
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.STIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_sti:
    
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, zero
        csrrw t6, mie, t1
        csrrsi t6, mip, 32
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mip, 32

        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, t1
        csrrsi t6, mip, 32
        jal cause_mtimer_interrupt_now
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mip, 32

    ///////////////////////////////
    // cp_trigger_changingtos_ssi
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.SSIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_ssi:
    
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, zero
        csrrw t6, mie, t1
        csrrsi t6, mip, 2
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mip, 2

        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, t1
        csrrsi t6, mip, 2
        jal cause_mtimer_interrupt_now
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mip, 2

    ///////////////////////////////
    // cp_trigger_changingtos_sei
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.SEIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_sei:
    
        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, zero
        csrrw t6, mie, t1
        li t0, 512
        csrrs t6, mip, t0
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        li t0, 512
        csrrc t6, mip, t0

        RVTEST_GOTO_HIGHER_MODE Mmode
        csrrci t6, mstatus, 8
        li t1, -1
        csrrw t6, mideleg, t1
        li t0, 512
        csrrs t6, mip, t0
        jal cause_mtimer_interrupt_now
        RVTEST_GOTO_LOWER_MODE Smode
        csrrsi t6, sstatus, 2
        csrrci t6, sstatus, 2
        RVTEST_GOTO_HIGHER_MODE Mmode
        li t0, 512
        csrrc t6, mip, t0

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
