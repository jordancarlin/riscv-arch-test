///////////////////////////////////////////
// InterruptsS_M.S
//
// Written: Hjamal@hmc.edu       6 April 2025
//
// Purpose: Functional coverage tests for Supervisor-mode Interrupts running in Supervisor mode
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

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
    RVTEST_CASE(1,"//check ISA:=regex(.*32.*); check ISA:=regex(.*I.*Zicsr.*); def rvtest_mtrap_routine=True; def rvtest_strap_routine=True; def rvtest_dtrap_routine=True; def TEST_CASE_1=True",interruptsM)

    #define rvtest_mtrap_routine
    #define rvtest_strap_routine
    #define rvtest_dtrap_routine
    
    ALL_MEM_PMP          		                  	                      	// set the PMP permissions for the whole memory
	csrw satp, zero  		                                        		// write satp with all zeros (bare mode)
    
    la sp, topofstack
    jal reset_mtimecmp

    ///////////////////////////////
    // cp_trigger_mti
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s}, 
    // and mie = 1s, use CLINT.MTIMECMP to cause mip.MTIP to rise
    ///////////////////////////////

    cp_trigger_mti:

        li a0, 8                    # use a0 as bitfield {mideleg, mstatus.MIE, mstatus.SIE}
        RVTEST_GOTO_MMODE           # start in m-mode to control CSRs

        1:
        addi a0, a0, -1
        li t1, -1
        csrrw t6, mie, t1           # enable all interrupts
        csrrw t6, mideleg, zero     # disable delegation
        andi t0, a0, 4              # toggle mideleg using bit 2 of a0
        beqz t0, 2f
        li t1, 0x222
        csrrw t6, mideleg, t1
        
        2:
        li t0, 8
        csrrc t6, mstatus, t0
        andi t0, a0, 2              # toggle mstatus.MIE using bit 1 of a0
        beqz t0, 3f
        li t0, 8
        csrrs t6, mstatus, t0
        
        3:
        li t0, 2
        csrrc t6, mstatus, t0
        andi t0, a0, 1              # toggle mstatus.SIE using bit 0 of a0
        beqz t0, 4f 
        li t0, 2
        csrrs t6, mstatus, t0

        4:
        
        RVTEST_GOTO_LOWER_MODE Smode
        jal cause_mtimer_interrupt_now   # expect m-mode interrupt here if mstatus.MIE=1, and mideleg.MTI=0 or mstatus.SIE=0
        nop                              # expect s-mode interrupt if mideleg.MTI=1 and mstatus.SIE=1 (impossible on wally)
        RVTEST_GOTO_MMODE
        jal reset_mtimecmp          # reset mtimecmp to avoid premature interrupt in next test
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_msi
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s}, 
    // and mie = 1s, use CLINT.MSIP to cause mip.MSIP to rise
    ///////////////////////////////

    cp_trigger_msi:

        li a0, 8                    # use a0 as bitfield
        RVTEST_GOTO_MMODE           # start in m-mode to control CSRs

        1:
        addi a0, a0, -1
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 4
        beqz t0, 2f
        li t1, 0x222
        csrrw t6, mideleg, t1
        
        2:
        li t0, 8
        csrrc t6, mstatus, t0
        andi t0, a0, 2
        beqz t0, 3f
        li t0, 8
        csrrs t6, mstatus, t0
        
        3:
        li t0, 2
        csrrc t6, mstatus, t0
        andi t0, a0, 1
        beqz t0, 4f 
        li t0, 2
        csrrs t6, mstatus, t0

        4:
        RVTEST_GOTO_LOWER_MODE Smode
        jal cause_msoftware_interrupt   # expect m-mode interrupt here if mstatus.MIE=1, and mideleg.MSI=0 or mstatus.SIE=0
        nop                             # expect s-mode interrupt if mideleg.MSI=1 and mstatus.SIE=1 (impossible on wally)
        RVTEST_GOTO_MMODE
        jal reset_msoftware_interrupt # reset msip to avoid premature interrupt in next test
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_mei
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s}, 
    // and mie = 1s, use PLIC or other EIC to cause mip.MEIP to rise
    ///////////////////////////////

    cp_trigger_mei:
    
        li a0, 8                    # use a0 as bitfield
        RVTEST_GOTO_MMODE           # start in m-mode to control CSRs

        1:
        addi a0, a0, -1
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 4
        beqz t0, 2f
        li t1, 0x222
        csrrw t6, mideleg, t1
        
        2:
        li t0, 8
        csrrc t6, mstatus, t0
        andi t0, a0, 2
        beqz t0, 3f
        li t0, 8
        csrrs t6, mstatus, t0
        
        3:
        li t0, 2
        csrrc t6, mstatus, t0
        andi t0, a0, 1
        beqz t0, 4f 
        li t0, 2
        csrrs t6, mstatus, t0

        4:
        RVTEST_GOTO_LOWER_MODE Smode
        jal cause_external_interrupt_M   # expect m-mode interrupt here if mstatus.MIE=1, and mideleg.MEI=0 or mstatus.SIE=0
        nop                         # expect s-mode interrupt if mideleg.MEI=1 and mstatus.SIE=1 (impossible on wally)
        RVTEST_GOTO_MMODE
        jal reset_external_interrupts       # reset external interrupts to avoid premature interrupt in next test
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_sti
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s},
    // and mie = 1s, mip.STIP=1, change to supervisor mode
    ///////////////////////////////

    cp_trigger_sti:
    
        li a0, 8                    # use a0 as bitfield
        RVTEST_GOTO_MMODE           # start in m-mode to control CSRs

        1:
        addi a0, a0, -1
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 4
        beqz t0, 2f
        li t1, 0x222
        csrrw t6, mideleg, t1
        
        2:
        li t0, 8
        csrrc t6, mstatus, t0
        andi t0, a0, 2
        beqz t0, 3f
        li t0, 8
        csrrs t6, mstatus, t0
        
        3:
        li t0, 2
        csrrc t6, mstatus, t0
        andi t0, a0, 1
        beqz t0, 4f 
        li t0, 2
        csrrs t6, mstatus, t0

        4:
        li t1, 32
        csrrs t6, mip, t1   # expect m-mode interrupt here if mstatus.MIE=1, and mideleg.STI=0 or mstatus.SIE=0
        RVTEST_GOTO_LOWER_MODE Smode
        nop                         # expect s-mode interrupt if mideleg.STI=1 and mstatus.SIE=1
        RVTEST_GOTO_MMODE
        li t1, 32
        csrrc t6, mip, t1
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_ssi_mip
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s},
    // and mie = 1s, mip.SSIP=1, change to supervisor mode
    ///////////////////////////////

    cp_trigger_ssi_mip:
    
        li a0, 8                    # use a0 as bitfield
        RVTEST_GOTO_MMODE           # start in m-mode to control CSRs

        1:
        addi a0, a0, -1
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 4              # toggle mideleg using bit 3
        beqz t0, 2f
        li t1, 0x222
        csrrw t6, mideleg, t1
        
        2:
        li t0, 8
        csrrc t6, mstatus, t0
        andi t0, a0, 2              # toggle mstatus.MIE using bit 2
        beqz t0, 3f
        li t0, 8
        csrrs t6, mstatus, t0
        
        3:
        li t0, 2
        csrrc t6, mstatus, t0
        andi t0, a0, 1              # toggle mstatus.SIE using bit 1
        beqz t0, 4f 
        li t0, 2
        csrrs t6, mstatus, t0

        4:
        li t0, 2
        csrrs t6, mip, t0   # expect m-mode interrupt here if mstatus.MIE=1, and mideleg.SSI=0 or mstatus.SIE=0
        RVTEST_GOTO_LOWER_MODE Smode
        nop                         # expect s-mode interrupt if mideleg.SSI=1 and mstatus.SIE=1
        RVTEST_GOTO_MMODE
        li t0, 2
        csrrc t6, mip, t0
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_ssi_sip
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s},
    // and mie = 1s, sip.SSIP=1, change to supervisor mode
    ///////////////////////////////
/*
    cp_trigger_ssi_sip:
    
        li a0, 8                    # use a0 as bitfield
        RVTEST_GOTO_MMODE           # start in m-mode to control CSRs

        1:
        addi a0, a0, -1
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 4              # toggle mideleg using bit 3
        beqz t0, 2f
        li t1, 0x222
        csrrw t6, mideleg, t1
        
        2:
        li t0, 8
        csrrc t6, mstatus, t0
        andi t0, a0, 2              # toggle mstatus.MIE using bit 2
        beqz t0, 3f
        li t0, 8
        csrrs t6, mstatus, t0
        
        3:
        li t0, 2
        csrrc t6, mstatus, t0
        andi t0, a0, 1              # toggle mstatus.SIE using bit 1
        beqz t0, 4f 
        li t0, 2
        csrrs t6, mstatus, t0

        4:
        RVTEST_GOTO_LOWER_MODE Smode    # expect m-mode interrupt here if mstatus.MIE=1, mideleg.SSI=1, and mstatus.SIE=0
        li t0, 2
        csrrs t6, sip, t0               # expect s-mode interrupt if mideleg.SSI=1 and mstatus.SIE=1
        csrrc t6, sip, t0   
        RVTEST_GOTO_MMODE
        bnez a0, 1b
*/
    ///////////////////////////////
    // cp_trigger_sei
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s},
    // and mie = 1s, use PLIC or other EIC to cause sip.SEIP to rise
    ///////////////////////////////

    cp_trigger_sei:
    
        li a0, 8                    # use a0 as bitfield
        RVTEST_GOTO_MMODE           # start in m-mode to control CSRs

        1:
        addi a0, a0, -1
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 4              # toggle mideleg using bit 3
        beqz t0, 2f
        li t1, 0x222
        csrrw t6, mideleg, t1
        
        2:
        li t0, 8
        csrrc t6, mstatus, t0
        andi t0, a0, 2              # toggle mstatus.MIE using bit 2
        beqz t0, 3f
        li t0, 8
        csrrs t6, mstatus, t0
        
        3:
        li t0, 2
        csrrc t6, mstatus, t0
        andi t0, a0, 1              # toggle mstatus.SIE using bit 1
        beqz t0, 4f 
        li t0, 2
        csrrs t6, mstatus, t0

        4:
        jal cause_external_interrupt_S   # expect m-mode interrupt here if mstatus.MIE=1, and mideleg.SEI=0 or mstatus.SIE=0
        RVTEST_GOTO_LOWER_MODE Smode
        nop                         # expect s-mode interrupt if mideleg.SEI=1 and mstatus.SIE=1
        RVTEST_GOTO_MMODE
        jal reset_external_interrupts
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_sei_seip
    //
    // With mstatus.MIE = {0/1}, mstatus.SIE = {0/1}, mideleg = {0s/1s},
    // and mie = 1s, write mip.SEIP=1
    ///////////////////////////////

    cp_trigger_sei_seip:
    
        li a0, 8                    # use a0 as bitfield
        RVTEST_GOTO_MMODE           # start in m-mode to control CSRs

        1:
        addi a0, a0, -1
        li t1, -1
        csrrw t6, mie, t1
        csrrw t6, mideleg, zero
        andi t0, a0, 4              # toggle mideleg using bit 3
        beqz t0, 2f
        li t1, 0x222
        csrrw t6, mideleg, t1
        
        2:
        li t0, 8
        csrrc t6, mstatus, t0
        andi t0, a0, 2              # toggle mstatus.MIE using bit 2
        beqz t0, 3f
        li t0, 8
        csrrs t6, mstatus, t0
        
        3:
        li t0, 2
        csrrc t6, mstatus, t0
        andi t0, a0, 1              # toggle mstatus.SIE using bit 1
        beqz t0, 4f 
        li t0, 2
        csrrs t6, mstatus, t0

        4:
        li t0, 512
        csrrs t6, mip, t0   # expect m-mode interrupt here if mstatus.MIE=1, and mideleg.SEI=0 or mstatus.SIE=0
        RVTEST_GOTO_LOWER_MODE Smode
        nop                         # expect s-mode interrupt if mideleg.SEI=1 and mstatus.SIE=1
        RVTEST_GOTO_MMODE
        li t0, 512
        csrrc t6, mip, t0
        bnez a0, 1b

    ///////////////////////////////
    // cp_trigger_changingtos_mti
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.MTIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_mti:
    
        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, -1
        csrrw t6, mideleg, zero         # disable delegation of all interrupts
        csrrw t6, mie, t1               # enable all interrupts
        jal cause_mtimer_interrupt_now  # raise mtimer interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode    
        li t0, 2
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should not trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear mtimer interrupt pending
        jal reset_mtimecmp

        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, 0x222
        csrrw t6, mideleg, t1           # enable delegation of all interrupts
        li t1, -1
        csrrw t6, mie, t1               # enable all interrupts
        jal cause_mtimer_interrupt_now  # raise mtimer interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode
        li t0, 2
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear mtimer interrupt pending if trap handler fails
        jal reset_mtimecmp

    ///////////////////////////////
    // cp_trigger_changingtos_msi
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.MSIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_msi:
    
        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, -1
        csrrw t6, mideleg, zero         # disable delegation of all interrupts
        csrrw t6, mie, t1               # enable all interrupts
        jal cause_msoftware_interrupt     # raise msoftware interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode    
        li t0, 2
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should not trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear msoftware interrupt pending
        jal reset_msoftware_interrupt

        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, 0x222
        csrrw t6, mideleg, t1           # enable delegation of all interrupts
        li t1, -1
        csrrw t6, mie, t1               # enable all interrupts
        jal cause_msoftware_interrupt     # raise msoftware interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode    
        li t0, 2
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear msoftware interrupt pending
        jal reset_msoftware_interrupt

    ///////////////////////////////
    // cp_trigger_changingtos_mei
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.MEIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_mei:
    
        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, -1
        csrrw t6, mideleg, zero         # disable delegation of all interrupts
        csrrw t6, mie, t1               # enable all interrupts
        jal cause_external_interrupt_M  # raise mexternal interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode    
        li t0, 2
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should not trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear mexternal interrupt pending
        jal reset_external_interrupts

        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, 0x222
        csrrw t6, mideleg, t1           # enable delegation of all interrupts
        li t1, -1
        csrrw t6, mie, t1               # enable all interrupts
        jal cause_mtimer_interrupt_now  # raise mexternal interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode   
        li t0, 2
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear mexternal interrupt pending
        jal reset_external_interrupts

    ///////////////////////////////
    // cp_trigger_changingtos_sti
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.STIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_sti:
    
        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, -1
        csrrw t6, mideleg, zero         # disable delegation of all interrupts
        csrrw t6, mie, t1               # enable all interrupts
        li t1, 32
        csrrs t6, mip, t1               # raise stimer interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode 
        li t0, 2   
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should not trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear stimer interrupt pending
        li t1, 32
        csrrc t6, mip, t1

        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, 0x222
        csrrw t6, mideleg, t1           # enable delegation of all interrupts
        li t1, -1
        csrrw t6, mie, t1               # enable all interrupts
        li t1, 32
        csrrs t6, mip, t1               # raise stimer interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode   
        li t0, 2 
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear stimer interrupt pending
        li t1, 32
        csrrc t6, mip, t1

    ///////////////////////////////
    // cp_trigger_changingtos_ssi
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.SSIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_ssi:
    
        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, -1
        csrrw t6, mideleg, zero         # disable delegation of all interrupts
        csrrw t6, mie, t1               # enable all interrupts
        li t0, 2
        csrrs t6, mip, t0               # raise ssoftware interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode   
        li t0, 2 
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should not trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear ssoftware interrupt pending
        li t0, 2
        csrrc t6, mip, t0

        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, 0x222
        csrrw t6, mideleg, t1           # enable delegation of all interrupts
        li t1, -1
        csrrw t6, mie, t1               # enable all interrupts
        li t0, 2
        csrrs t6, mip, t0               # raise ssoftware interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode  
        li t0, 2  
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear ssoftware interrupt pending
        li t0, 2
        csrrc t6, mip, t0

    ///////////////////////////////
    // cp_trigger_changingtos_sei
    //
    // with mstatus.MIE=0, mideleg={0s/1s}, mie=1s, set mip.SEIP, 
    // then change to supervisor mode, then write sstatus.SIE=1
    ///////////////////////////////

    cp_trigger_changingtos_sei:
    
        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, -1
        csrrw t6, mideleg, zero         # disable delegation of all interrupts
        csrrw t6, mie, t1               # enable all interrupts
        li t0, 512
        csrrs t6, mip, t0               # raise sexternal interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode    
        li t0, 2
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should not trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear sexternal interrupt pending
        li t0, 512
        csrrc t6, mip, t0

        RVTEST_GOTO_MMODE
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        li t1, 0x222
        csrrw t6, mideleg, t1           # enable delegation of all interrupts
        li t1, -1
        csrrw t6, mie, t1               # enable all interrupts
        li t0, 512
        csrrs t6, mip, t0               # raise sexternal interrupt in M-mode, should not trigger interrupt
        RVTEST_GOTO_LOWER_MODE Smode    
        li t0, 2
        csrrs t6, sstatus, t0           # set sstatus.SIE = 1, should trigger interrupt
        csrrc t6, sstatus, t0           # clean up for future tests
        RVTEST_GOTO_MMODE               # return to M-mode to clear sexternal interrupt pending
        li t0, 512
        csrrc t6, mip, t0

    ///////////////////////////////
    // cp_interrupts_s
    //
    // Cross of mstatus.MIE = {0/1}, mtvec.MODE = 00, mideleg = 0s,
    // 6 walking 1s in mie, 6 walking 1s in mip (2 x 6 x 6 bins)
    ///////////////////////////////

    cp_interrupts_s:

        RVTEST_GOTO_MMODE # Need to be in M-mode to set mideleg

        li t1, 0x222
        csrrw t6, mideleg, t1 # Set mideleg to {SEI,STI,SSI}
        
        li t0, 8
        csrrc t6, mstatus, t0       # do first test with mstatus.MIE = 0
        jal cross_interrupts_s_EP   # expect this to hit M-mode cp_priority coverpoints too

        csrrw t6, mideleg, zero # Set mideleg to 0s

        li t0, 8
        csrrc t6, mstatus, t0       # do second test with mstatus.MIE = 0
        jal cross_interrupts_s_EP   # expect this to hit M-mode cp_priority coverpoints too

    ///////////////////////////////
    // cp_vectored
    //
    // Cross of stvec.MODE = 00/01, mstatus.MIE=1, mie = 1s, mideleg = 1s, 
    // 6 different interrupts walking in mip, change to supervisor mode then 
    // write sstatus.SIE={0/1}
    ///////////////////////////////

    cp_vectored:

        RVTEST_GOTO_MMODE
        li t0, 3
        csrrc t6, stvec, t0         # stvec.MODE = 00
        li t0, 8
        csrrs t6, mstatus, t0       # mstatus.MIE = 1
        li t0, -1                   # load all 1s for mie and mideleg
        csrrs t6, mie, t0           # enable all interrupts
        csrrs t6, mideleg, t0       # enable delegation of all interrupts
        jal cross_interrupts_s_EP   # helper function does sstatus.SIE = 0 and 1

        RVTEST_GOTO_MMODE
        li t0, 3
        csrrc t6, stvec, t0
        li t0, 1
        csrrs t6, stvec, t0         # stvec.MODE = 01
        li t0, 8
        csrrs t6, mstatus, t0       # mstatus.MIE = 1
        li t0, -1                   # load all 1s for mie and mideleg
        csrrs t6, mie, t0           # enable all interrupts
        csrrs t6, mideleg, t0       # enable delegation of all interrupts
        jal cross_interrupts_s_EP   # helper function does sstatus.SIE = 0 and 1

    ///////////////////////////////
    // cp_priority_mip_m
    //
    // Cross of 2^6 permutations of mip, mie=1s, mideleg = 0s.  
    // Set up with mstatus.MIE = 0, and change to supervisor,
    // then write sstatus.SIE=1
    ///////////////////////////////

    cp_priority_mip_m: # TODO: change raising mip order to match bitfield order in mip/mie
        li a0, 63           # use a0 as bitfield for {STIP, SEIP, SSIP, MTIP, MEIP, MSIP}
        RVTEST_GOTO_MMODE   # start test in M-mode to control CSRs
        
        1:
        li t0, -1                   # load all 1s for mie
        csrrw t6, mie, t0           # enable all interrupts
        csrrw t6, mideleg, zero     # disable delegation of all interrupts
        li t0, 8
        csrrc t6, mstatus, t0       # set up with mstatus.MIE = 0

        andi t0, a0, 32             
        beqz t0, 2f                 # toggle stimer int with bit 5
        li t1, 32
        csrrs t6, mip, t1

        2:
        andi t0, a0, 16        
        beqz t0, 3f                 # toggle sext int with bit 4
        li t0, 512
        csrrs t6, mip, t0

        3:
        andi t0, a0, 8      
        beqz t0, 4f                 # toggle ssw int with bit 3
        li t0, 2
        csrrs t6, mip, t0
            
        4:
        andi t0, a0, 4        
        beqz t0, 5f                 # toggle mtimer int with bit 2
        jal cause_mtimer_interrupt_now

        5:
        andi t0, a0, 2        
        beqz t0, 6f                 # toggle mext int with bit 1
        jal cause_external_interrupt_M

        6:
        andi t0, a0, 1        
        beqz t0, 7f                 # toggle msw int with bit 0
        jal cause_msoftware_interrupt

        7:
        RVTEST_GOTO_LOWER_MODE Smode    # move to S-mode before attempting triggers
        li t0, 2
        csrrs t6, sstatus, t0           # write sstatus.SIE, should trigger all pending interrupts
        csrrc t6, sstatus, t0
        RVTEST_GOTO_MMODE               # return to M-mode and clean up for next test
        csrrw t6, mip, zero             # clear mip.S*IP
        jal reset_msoftware_interrupt
        jal reset_mtimecmp
        jal reset_external_interrupts
        addi a0, a0, -1
        bgez a0, 1b                     # if no interrupts attempted, move to next coverpoint

    ///////////////////////////////
    // cp_priority_mie_m
    //
    // Cross of 2^6 permutations of mie, mip=1s, mideleg = 0s.  
    // Set up with mstatus.MIE = 0, and change to supervisor,
    // then write sstatus.SIE=1
    ///////////////////////////////

    cp_priority_mie_m:
        li a0, 63           # use a0 as bitfield
        RVTEST_GOTO_MMODE   # start test in M-mode to control CSRs

        1:
        li t0, 0x222                # 1 in SEIP, STIP, and SSIP
        csrrw t6, mideleg, zero     # disable delegation of all interrupts
        li t0, 8
        csrrc t6, mstatus, t0       # set up with mstatus.MIE = 0
        csrrw t6, mip, t0           # raise mip.S*IP
        jal cause_mtimer_interrupt_now
        jal cause_external_interrupt_M
        jal cause_msoftware_interrupt

        andi t0, a0, 32        
        beqz t0, 2f                 # toggle ssw int with bit 5
        li t0, 2
        csrrs t6, mie, t0

        2:
        andi t0, a0, 16        
        beqz t0, 3f                 # toggle msw int with bit 4
        li t0, 8
        csrrs t6, mie, t0

        3:
        andi t0, a0, 8      
        beqz t0, 4f                 # toggle stimer int with bit 3
        li t1, 32
        csrrs t6, mie, t1
            
        4:
        andi t0, a0, 4        
        beqz t0, 5f                 # toggle mtimer int with bit 2
        li t0, 128
        csrrs t6, mie, t0

        5:
        andi t0, a0, 2        
        beqz t0, 6f                 # toggle sext int with bit 1
        li t0, 512
        csrrs t6, mie, t0

        6:
        andi t0, a0, 1        
        beqz t0, 7f
        li t0, 2048                 # toggle mext int with bit 0
        csrrs t6, mie, t0

        7:
        RVTEST_GOTO_LOWER_MODE Smode    # move to S-mode before attempting triggers
        li t0, 2
        csrrs t6, sstatus, t0           # write sstatus.SIE, should trigger all enabled interrupts
        csrrc t6, sstatus, t0
        RVTEST_GOTO_MMODE               # return to M-mode and clean up for next test
        csrrw t6, mie, zero             # reset all interrupt enables
        addi a0, a0, -1
        bgez a0, 1b                     # if no interrupts attempted, move to next coverpoint

    ///////////////////////////////
    // cp_priority_both_m
    //
    // Cross of 2^6 permutations of mie, mip=mie, mideleg = 0s.  
    // Set up with mstatus.MIE = 0, and change to supervisor,
    // then write sstatus.SIE=1
    ///////////////////////////////

    cp_priority_both_m:
        
        li a0, 63           # use a0 as bitfield
        RVTEST_GOTO_MMODE   # start test in M-mode to control CSRs

        1:
        csrrw t6, mip, zero         # start with no interrupts pending
        csrrw t6, mideleg, zero     # disable delegation for all interrupts
        li t0, 8
        csrrc t6, mstatus, t0       # set up with mstatus.MIE = 0

        andi t0, a0, 32        
        beqz t0, 2f                 # toggle ssw int with bit 5
        li t0, 2
        csrrs t6, mie, t0
        csrrs t6, mip, t0

        2:
        andi t0, a0, 16        
        beqz t0, 3f                 # toggle msw int with bit 4
        li t0, 8
        csrrs t6, mie, t0
        jal cause_msoftware_interrupt

        3:
        andi t0, a0, 8      
        beqz t0, 4f                 # toggle stimer int with bit 3
        li t1, 32
        csrrs t6, mie, t1
        csrrs t6, mip, t1
            
        4:
        andi t0, a0, 4        
        beqz t0, 5f                 # toggle mtimer int with bit 2
        li t0, 128
        csrrs t6, mie, t0
        jal cause_mtimer_interrupt_now

        5:
        andi t0, a0, 2        
        beqz t0, 6f                 # toggle sext int with bit 1
        li t0, 512
        csrrs t6, mie, t0
        csrrs t6, mip, t0

        6:
        andi t0, a0, 1        
        beqz t0, 7f                 # toggle mext int with bit 0
        li t0, 8
        csrrs t6, mstatus, t0
        li t0, 2048
        csrrs t6, mie, t0
        jal cause_external_interrupt_M

        7:
        RVTEST_GOTO_LOWER_MODE Smode    # move to S-mode before attempting triggers
        li t0, 2
        csrrs t6, sstatus, t0           # write sstatus.SIE, should trigger all enabled/pending interrupts
        csrrc t6, sstatus, t0
        RVTEST_GOTO_MMODE               # return to M-mode and clean up for next test
        csrrw t6, mie, zero             # clear mip and mie
        csrrw t6, mip, zero
        jal reset_msoftware_interrupt
        jal reset_mtimecmp
        jal reset_external_interrupts
        addi a0, a0, -1
        bgez a0, 1b                     # if no interrupts attempted, move to next coverpoint

    ///////////////////////////////
    // cp_priority_mip_s
    //
    // Cross of 2^6 permutations of mip, mie=1s, mideleg = 1s.  
    // Set up with mstatus.MIE = 1, and change to supervisor,
    // then write sstatus.SIE=1
    ///////////////////////////////
/*
    cp_priority_mip_s: # TODO: change raising mip order to match bitfield order in mip/mie
        li a0, 63           # use a0 as bitfield
        RVTEST_GOTO_MMODE   # start test in M-mode to control CSRs
        
        1:
        li t0, -1                   # load all 1s for mie
        csrrw t6, mie, t0           # enable all interrupts
        csrrw t6, mideleg, t1       # allow delegation of all interrupts
        li t0, 8
        csrrs t6, mstatus, t0       # set up with mstatus.MIE = 1

        andi t0, a0, 32             
        beqz t0, 2f                 # toggle stimer int with bit 5
        li t1, 32
        csrrs t6, mip, t1

        2:
        andi t0, a0, 16        
        beqz t0, 3f                 # toggle sext int with bit 4
        li t0, 512
        csrrs t6, mip, t0

        3:
        andi t0, a0, 8      
        beqz t0, 4f                 # toggle ssw int with bit 3
        li t0, 2
        csrrs t6, mip, t0
            
        4:
        andi t0, a0, 4        
        beqz t0, 5f                 # toggle mtimer int with bit 2
        jal cause_mtimer_interrupt_now

        5:
        andi t0, a0, 2        
        beqz t0, 6f                 # toggle mext int with bit 1
        jal cause_external_interrupt_M

        6:
        andi t0, a0, 1        
        beqz t0, 7f                 # toggle msw int with bit 0
        jal cause_msoftware_interrupt

        7:
        RVTEST_GOTO_LOWER_MODE Smode    # move to S-mode before attempting triggers
        li t0, 2
        csrrs t6, sstatus, t0           # write sstatus.SIE, should trigger all pending interrupts
        csrrc t6, sstatus, t0
        RVTEST_GOTO_MMODE               # return to M-mode and clean up for next test
        csrrw t6, mip, zero             # clear mip.S*IP
        jal reset_msoftware_interrupt
        jal reset_mtimecmp
        jal reset_external_interrupts
        addi a0, a0, -1
        bgez a0, 1b                     # if no interrupts attempted, move to next coverpoint
*/
    ///////////////////////////////
    // cp_priority_mie_s
    //
    // Cross of 2^6 permutations of mie, mip=1s, mideleg = 1s.  
    // Set up with mstatus.MIE = 1, and change to supervisor,
    // then write sstatus.SIE=1
    ///////////////////////////////

    cp_priority_mie_s:
        li a0, 63           # use a0 as bitfield
        RVTEST_GOTO_MMODE   # start test in M-mode to control CSRs

        1:
        li t0, 0x222                # 1 in SEIP, STIP, SSIP
        csrrw t6, mideleg, t1       # enable delegation of all interrupts
        li t0, 8
        csrrs t6, mstatus, t0       # set up with mstatus.MIE = 1
        csrrw t6, mip, t0           # raise mip.S*IP
        jal cause_mtimer_interrupt_now
        jal cause_external_interrupt_M
        jal cause_msoftware_interrupt

        andi t0, a0, 32        
        beqz t0, 2f                 # toggle ssw int with bit 5
        li t0, 2
        csrrs t6, mie, t0

        2:
        andi t0, a0, 16        
        beqz t0, 3f                 # toggle msw int with bit 4
        li t0, 8
        csrrs t6, mie, t0

        3:
        andi t0, a0, 8      
        beqz t0, 4f                 # toggle stimer int with bit 3
        li t1, 32
        csrrs t6, mie, t1
            
        4:
        andi t0, a0, 4        
        beqz t0, 5f                 # toggle mtimer int with bit 2
        li t0, 128
        csrrs t6, mie, t0

        5:
        andi t0, a0, 2        
        beqz t0, 6f                 # toggle sext int with bit 1
        li t0, 512
        csrrs t6, mie, t0

        6:
        andi t0, a0, 1        
        beqz t0, 7f
        li t0, 2048                 # toggle mext int with bit 0
        csrrs t6, mie, t0

        7:
        RVTEST_GOTO_LOWER_MODE Smode    # move to S-mode before attempting triggers
        li t0, 2
        csrrs t6, sstatus, t0           # write sstatus.SIE, should trigger all enabled interrupts
        csrrc t6, sstatus, t0
        RVTEST_GOTO_MMODE               # return to M-mode and clean up for next test
        csrrw t6, mie, zero             # reset all interrupt enables
        addi a0, a0, -1
        bgez a0, 1b                     # if no interrupts attempted, move to next coverpoint

    ///////////////////////////////
    // cp_priority_both_s
    //
    // Cross of 2^6 permutations of mie, mip=mie, mideleg = 1s.  
    // Set up with mstatus.MIE = 1, and change to supervisor,
    // then write sstatus.SIE=1
    ///////////////////////////////

    cp_priority_both_s:
        
        li a0, 63           # use a0 as bitfield
        RVTEST_GOTO_MMODE   # start test in M-mode to control CSRs

        1:
        csrrw t6, mip, zero         # start with no interrupts pending
        csrrw t6, mideleg, t1       # enable delegation for all interrupts
        li t0, 8
        csrrs t6, mstatus, t0       # set up with mstatus.MIE = 0

        andi t0, a0, 32        
        beqz t0, 2f                 # toggle ssw int with bit 5
        li t0, 2
        csrrs t6, mie, t0
        csrrs t6, mip, t0

        2:
        andi t0, a0, 16        
        beqz t0, 3f                 # toggle msw int with bit 4
        li t0, 8
        csrrs t6, mie, t0
        jal cause_msoftware_interrupt

        3:
        andi t0, a0, 8      
        beqz t0, 4f                 # toggle stimer int with bit 3
        li t1, 32
        csrrs t6, mie, t1
        csrrs t6, mip, t1
            
        4:
        andi t0, a0, 4        
        beqz t0, 5f                 # toggle mtimer int with bit 2
        li t0, 128
        csrrs t6, mie, t0
        jal cause_mtimer_interrupt_now

        5:
        andi t0, a0, 2        
        beqz t0, 6f                 # toggle sext int with bit 1
        li t0, 512
        csrrs t6, mie, t0
        csrrs t6, mip, t0

        6:
        andi t0, a0, 1        
        beqz t0, 7f                 # toggle mext int with bit 0
        li t0, 8
        csrrs t6, mstatus, t0
        li t0, 2048
        csrrs t6, mie, t0
        jal cause_external_interrupt_M

        7:
        RVTEST_GOTO_LOWER_MODE Smode    # move to S-mode before attempting triggers
        li t0, 2
        csrrs t6, sstatus, t0           # write sstatus.SIE, should trigger all enabled/pending interrupts
        csrrc t6, sstatus, t0
        RVTEST_GOTO_MMODE               # return to M-mode and clean up for next test
        csrrw t6, mie, zero             # clear mip and mie
        csrrw t6, mip, zero
        jal reset_msoftware_interrupt
        jal reset_mtimecmp
        jal reset_external_interrupts
        addi a0, a0, -1
        bgez a0, 1b                     # if no interrupts attempted, move to next coverpoint

    ///////////////////////////////
    // cp_priority_mideleg_m
    //
    // Cross of 2^3 permutations of mideleg, mip=1s, mie=1s.  
    // Set up with mstatus.MIE = 0, and change to supervisor,
    // then write sstatus.SIE=1
    ///////////////////////////////

    cp_priority_mideleg_m:
        li a0, 7            # use a0 as bitfield for mideleg.{SEI, STI, SSI}
        RVTEST_GOTO_MMODE   # start test in M-mode to control CSRs

        1:
        li t0, -1                       # load all 1s for mie
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        csrrw t6, mie, t0               # mie = 1s
        li t0, 0x222                    # 1 in SEIP, STIP, SSIP
        csrrw t6, mip, t0               # mip.S*IP = 1
        jal cause_mtimer_interrupt_now
        jal cause_external_interrupt_M
        jal cause_msoftware_interrupt

        andi t0, a0, 4        
        beqz t0, 2f                     # toggle sext int with bit 2
        li t1, 512
        csrrs t6, mideleg, t1

        2:
        andi t0, a0, 2        
        beqz t0, 3f                     # toggle stimer int with bit 1
        li t1, 32
        csrrs t6, mideleg, t1

        3:
        andi t0, a0, 1      
        beqz t0, 4f                     # toggle ssw int with bit 0
        li t0, 2
        csrrs t6, mideleg, t0
            
        4:
        RVTEST_GOTO_LOWER_MODE Smode    # move to S-mode before attempting triggers
        li t0, 2
        csrrs t6, sstatus, t0           # write sstatus.SIE, should trigger all enabled/pending interrupts
        csrrc t6, sstatus, t0
        RVTEST_GOTO_MMODE               # return to M-mode and clean up for next test
        csrrw t6, mideleg, zero         # reset mideleg
        addi a0, a0, -1
        bgez a0, 1b                     # if no interrupts attempted, move to next coverpoint

    ///////////////////////////////
    // cp_priority_mideleg_s
    //
    // Cross of 2^3 permutations of mideleg, mie=mideleg, mip=1s.  
    // Set up with mstatus.MIE = 0, and change to supervisor,
    // then write sstatus.SIE=1
    ///////////////////////////////

    cp_priority_mideleg_s:
        li a0, 7            # use a0 as bitfield for mideleg/mie.{SEI, STI, SSI}
        RVTEST_GOTO_MMODE   # start test in M-mode to control CSRs

        1:
        li t0, 0x222                    # 1 in SEIP, STIP, SSIP
        li t0, 8
        csrrc t6, mstatus, t0           # mstatus.MIE = 0
        csrrw t6, mip, t0               # raise mip.S*IP
        jal cause_mtimer_interrupt_now
        jal cause_external_interrupt_M
        jal cause_msoftware_interrupt

        andi t0, a0, 4        
        beqz t0, 2f                     # toggle sext int with bit 2
        li t1, 512
        csrrs t6, mideleg, t1
        csrrs t6, mie, t1

        2:
        andi t0, a0, 2        
        beqz t0, 3f                     # toggle stimer int with bit 1
        li t1, 32
        csrrs t6, mideleg, t1
        csrrs t6, mie, t1

        3:
        andi t0, a0, 1      
        beqz t0, 4f                     # toggle ssw int with bit 0
        li t0, 2
        csrrs t6, mideleg, t0
        csrrs t6, mie, t0

        4:
        RVTEST_GOTO_LOWER_MODE Smode    # move to S-mode before attempting triggers
        li t0, 2
        csrrs t6, sstatus, t0           # write sstatus.SIE, should trigger all enabled/pending interrupts
        csrrc t6, sstatus, t0
        RVTEST_GOTO_MMODE               # return to M-mode and clean up for next test
        csrrw t6, mie, zero             # reset mie
        csrrw t6, mideleg, zero         # reset mideleg
        addi a0, a0, -1
        bgez a0, 1b                     # if no interrupts attempted, move to next coverpoint

    ///////////////////////////////
    // cp_wfi
    //
    // Cross Product of mstatus.MIE = {0/1}
    // Cross Product of mstatus.SIE = {0/1}
    // Cross product of mideleg = 0s/1s
    // Cross product of mstatus.TW = {0/1}
    // mie.MTIE = 1
    // Set MTIMECMP = TIME + 0x100 to interrupt in the future
    // mode = cross product of {user, supervisor, machine}
    // WFI Instruction
    ///////////////////////////////

    cp_wfi:
    
        li a0, 16           # use a0 as bitfield
        li a1, 3            # use a3 as index variable for priv mode
        RVTEST_GOTO_MMODE   # start test in M-mode to control CSRs

        1:
        addi a0, a0, -1
        li t0, 8
        csrrc t6, mstatus, t0
        andi t0, a0, 8
        beqz t0, 2f                     # use bit 3 to toggle mstatus.MIE
        li t0, 8
        csrrs t6, mstatus, t0
        
        2:
        li t0, 2
        csrrc t6, mstatus, t0
        andi t0, a0, 4
        beqz t0, 3f                     # use bit 2 to toggle mstatus.SIE
        li t0, 2
        csrrs t6, mstatus, t0
        
        3:
        li t1, -1
        csrrc t6, mideleg, t1
        andi t0, a0, 2
        beqz t0, 4f                     # use bit 1 to toggle mideleg = 0s/1s
        csrrs t6, mideleg, t1

        4:
        li t1, 1
        slli t1, t1, 21
        csrrc t6, mstatus, t1
        andi t0, a0, 1
        beqz t0, 5f                     # use bit 0 to toggle mstatus.TW
        csrrs t6, mstatus, t1

        5:
        li t0, 128
        csrrs t6, mie, t0               # enable timer interrupts
        jal cause_mtimer_interrupt_soon # set up mtimecmp to interrupt in 256 cycles

        addi a1, a1, -1
        li t0, 2
        bne a1, t0, 6f                  # if a1 = 2, run wfi in S-mode
        RVTEST_GOTO_LOWER_MODE Smode

        6:
        li t0, 1
        bne a1, t0, 7f                  # if a1 = 1, run wfi in U-mode
        RVTEST_GOTO_LOWER_MODE Umode

        7:
        wfi                             # else, run wfi in M-mode, do not expect timeout
        bnez a0, 1b                     # loop back to next case

    ///////////////////////////////
    // cp_wfi_timeout
    //
    // Cross Product of mstatus.MIE = {0/1}
    // Cross Product of mstatus.SIE = {0/1}
    // Cross product of mideleg = 0s/1s
    // Cross product of mstatus.TW = 1
    // mie.MTIE = {0/1}
    // Set MTIMECMP = MAX so timeout occurs
    // mode = cross product of {user, supervisor}
    // WFI Instruction
    ///////////////////////////////

    cp_wfi_timeout:
    
        li a0, 16           # use a0 as bitfield
        li a1, 3            # use a3 as index variable for priv mode
        RVTEST_GOTO_MMODE   # start test in M-mode to control CSRs

        1:
        addi a0, a0, -1
        li t0, 8
        csrrc t6, mstatus, t0
        andi t0, a0, 8
        beqz t0, 2f                         # use bit 3 to toggle mstatus.MIE
        li t0, 8
        csrrs t6, mstatus, t0
        
        2:
        li t0, 2
        csrrc t6, mstatus, t0
        andi t0, a0, 4
        beqz t0, 3f                         # use bit 2 to toggle mstatus.SIE
        li t0, 2
        csrrs t6, mstatus, t0
        
        3:
        li t1, -1
        csrrc t6, mideleg, t1
        andi t0, a0, 2
        beqz t0, 4f                         # use bit 1 to toggle mideleg = 0s/1s
        csrrs t6, mideleg, t1

        4:
        li t1, 128
        csrrc t6, mie, t1
        andi t0, a0, 1
        beqz t0, 5f                         # use bit 0 to toggle mie.MTIE
        csrrs t6, mie, t1

        5:
        li t1, 1
        slli t1, t1, 21
        csrrc t6, mstatus, t1               # always use mstatus.TW = 1
        jal reset_mtimecmp                  # set mtimecmp = MAX so timer interrupt will never trigger

        RVTEST_GOTO_LOWER_MODE Smode        # run wfi in S-mode by default
        addi a1, a1, -1
        li t0, 1
        bne a1, t0, 6f                      # if a1 = 1, run in U-mode instead
        RVTEST_GOTO_LOWER_MODE Umode

        6:
        wfi                 # wfi instruction, expect timeout trap
        RVTEST_GOTO_MMODE   # go back to M-mode after test cases to allow access to CSRs
        bnez a0, 1b         # loop to next case

    j test_end

    reset_mtimecmp:

        addi sp, sp, -8
        SREG ra, 0(sp)

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

        SREG ra, 0(sp)
        addi sp, sp, 8

        ret

    reset_external_interrupts:

        addi sp, sp, -8
        SREG ra, 0(sp)

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

        SREG ra, 0(sp)
        addi sp, sp, 8

        ret

    reset_msoftware_interrupt:

        addi sp, sp, -8
        SREG ra, 0(sp)

        la t0, CLINT_BASE_ADDR
        SREG zero, 0(t0) # write CLINT.msip = 1 for hart 0

        SREG ra, 0(sp)
        addi sp, sp, 8

        ret

    cross_interrupts_s_EP:
        // helper function for crossing mie.MEIE/SEIE/M/STIE/M/SSIE with mip.M/SEIP/MTIP/MSIP in Interrupts tests (enables and pending)
        li s0, 5                # iterate through setting mie.MEIE (5), SEIE (4), MTIE (3), STIE (2), MSIE (1), or SSIE (0)

        addi sp, sp, -8
        SREG ra, 0(sp)

        for_mie_s:
        
            slli t3, s0, 1      # setting mie.M/SEIE, M/STIE, or M/SSIE based on s0 value
            li t4, 2
            sll t4, t4, t3      # put a 1 in bit (1+(2*s0))
            csrrw t6, mie, t4   # set enable for interrupt type of interest, clear all others
        
            jal raise_interrupts_s
        
            addi s0, s0, -1     
            bge s0, zero, for_mie_s # iterate through interrupt types to be enabled

        
        LREG ra, 0(sp)
        addi sp, sp, 8

        ret

    raise_interrupts_s:
        // raises each of mip.M/SEIP/M/SSIP/M/STIP once in sequence

        addi sp, sp, -8     # store return address to stack
        SREG ra, 0(sp)

        li s2, 5            # RVTEST_GOTO_LOWER_MODE macro wipes s1 so use s2 instead

        for_mip_s:
            
            # based on s2 value, set mie.MEIE (5), SEIE (4), MTIE (3), STIE (2), MSIE (1), or SSIE (0)
            # includes resets in case interrupt is not triggered
            # To trigger interrupts in S-mode, raise mstatus.SIE and switch to S-mode 
            # TODO: Fix ordering of interrupt triggers to match order in mip/mie

            for_mip_s_stip:
                li t3, 5
                bne s2, t3, for_mip_s_seip    # if s2 == 5, trigger stimer interrupt
                csrr t6, mie                    # trap handler resets mie, so preserve it for future tests
                li t1, 32
                csrs mip, t1               # set mip.STIP
                li t0, 2
                csrs mstatus, t0                # set mstatus.SIE
                RVTEST_GOTO_LOWER_MODE Smode    # t6 is preserved by mode changes, expect interrupt here
                nop
                RVTEST_GOTO_MMODE
                li t0, 2
                csrc mstatus, t0                # clear mstatus.SIE
                csrw mie, t6                    # restore mie value for next test
                li t1, 32
                csrrc t6, mip, t1

            for_mip_s_seip:
                li t3, 4
                bne s2, t3, for_mip_s_ssip    # if s2 == 4, trigger sexternal interrupt
                csrr t6, mie                    # trap handler resets mie, so preserve it for future tests
                li t0, 512
                csrs mip, t0               # set mip.SEIP
                li t0, 2
                csrs mstatus, t0                # set mstatus.SIE
                RVTEST_GOTO_LOWER_MODE Smode    # t6 is preserved by mode changes, expect interrupt here
                nop
                RVTEST_GOTO_MMODE
                li t0, 2
                csrc mstatus, t0                # clear mstatus.SIE
                csrw mie, t6                    # restore mie value for next test
                li t0, 512
                csrrc t6, mip, t0
            
            for_mip_s_ssip:
                li t3, 3
                bne s2, t3, for_mip_s_mtip    # if s2 = 3, trigger ssoftware interrupt
                csrr t6, mie                    # trap handler resets mie, so preserve it for future tests
                li t0, 2
                csrs mip, t0                    # set mip.SSIP
                csrs mstatus, t0                # set mstatus.SIE
                RVTEST_GOTO_LOWER_MODE Smode    # t6 is preserved by mode changes, expect interrupt here
                nop
                RVTEST_GOTO_MMODE
                li t0, 2
                csrc mstatus, t0                # clear mstatus.SIE
                csrw mie, t6                    # restore mie value for next test
                li t0, 2
                csrrc t6, mip, t0
            
            for_mip_s_mtip:
                li t3, 2
                bne s2, t3, for_mip_s_meip    # if s2 == 2, trigger mtimer interrupt
                csrr t6, mie                    # trap handler resets mie, so preserve it for future tests
                jal cause_mtimer_interrupt_now  # set mip.MTIP
                li t0, 2
                csrs mstatus, t0                # set mstatus.SIE
                RVTEST_GOTO_LOWER_MODE Smode    # t6 is preserved by mode changes, expect interrupt here
                nop
                RVTEST_GOTO_MMODE
                li t0, 2
                csrc mstatus, t0                # clear mstatus.SIE
                csrw mie, t6                    # restore mie value for next test
                jal reset_mtimecmp

            for_mip_s_meip:
                li t3, 1
                bne s2, t3, for_mip_s_msip    # if s2 == 1, trigger mexternal interrupt
                csrr t6, mie                    # trap handler resets mie, so preserve it for future tests
                jal cause_external_interrupt_M  # set mip.MEIP
                li t0, 2
                csrs mstatus, t0                # set mstatus.SIE
                RVTEST_GOTO_LOWER_MODE Smode    # t6 is preserved by mode changes, expect interrupt here
                nop
                RVTEST_GOTO_MMODE
                li t0, 2
                csrc mstatus, t0                # clear mstatus.SIE
                csrw mie, t6                    # restore mie value for next test
                jal reset_external_interrupts

            for_mip_s_msip:
                li t3, 0
                bne s2, t3, for_mip_s_end # if s2 = 0, trigger msoftware interrupt
                csrr t6, mie                    # trap handler resets mie, so preserve it for future tests
                jal cause_msoftware_interrupt   # set mip.MSIP
                li t0, 2
                csrs mstatus, t0                # set mstatus.SIE
                RVTEST_GOTO_LOWER_MODE Smode    # t6 is preserved by mode changes, expect interrupt here
                nop
                RVTEST_GOTO_MMODE
                li t0, 2
                csrc mstatus, t0                # clear mstatus.SIE
                csrw mie, t6                    # restore mie value for next test
                jal reset_msoftware_interrupt

            for_mip_s_end:
                addi s2, s2, -1
                bgez s2, for_mip_s

        LREG ra, 0(sp)      # restore return address from stack
        addi sp, sp, 8

        ret

    cause_mtimer_interrupt_now:

        addi sp, sp, -8
        SREG ra, 0(sp)

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

        SREG ra, 0(sp)
        addi sp, sp, 8

        ret

    cause_mtimer_interrupt_soon:

        addi sp, sp, -8
        SREG ra, 0(sp)

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

        SREG ra, 0(sp)
        addi sp, sp, 8

        ret

    cause_msoftware_interrupt:

        addi sp, sp, -8
        SREG ra, 0(sp)

        la t0, CLINT_BASE_ADDR
        la t1, 1
        SREG t1, 0(t0) # write CLINT.msip = 1 for hart 0

        SREG ra, 0(sp)
        addi sp, sp, 8

        ret

    cause_external_interrupt_M:

        addi sp, sp, -8
        SREG ra, 0(sp)

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

        SREG ra, 0(sp)
        addi sp, sp, 8

        ret

    cause_external_interrupt_S:

        addi sp, sp, -8
        SREG ra, 0(sp)

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

        SREG ra, 0(sp)
        addi sp, sp, 8

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