///////////////////////////////////////////
// InterruptsS_M.S
//
// Written: Hjamal@hmc.edu       6 April 2025
//
// Purpose: Functional coverage tests for Supervisor-mode Interrupts running in Machine mode
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
    RVTEST_CASE(1,"//check ISA:=regex(.*I.*S.*Zicsr.*); def rvtest_mtrap_routine=True; def rvtest_strap_routine=True; def rvtest_dtrap_routine=True; def TEST_CASE_1=True",interruptsS_M)

    ALL_MEM_PMP          		                  	                      	// set the PMP permissions for the whole memory
	csrw satp, zero  		                                        		// write satp with all zeros (bare mode)
    
    la sp, topofstack
    jal reset_mtimecmp

    ///////////////////////////////
    // cp_interrupts_m
    //
    // Cross of mstatus.MIE = {0/1}, mtvec.MODE = 00, mideleg = {0s/STI+SEI+SSI},
    // 6 walking 1s in mie, 6 walking 1s in mip (2 x 2 x 6 x 6 bins)
    ///////////////////////////////

    cp_interrupts_m:

        li t0, 8
        csrrc t6, mstatus, t0       # mstatus.MIE = 0

        li t1, 0x222
        csrrw t6, mideleg, t1       # Set mideleg to {SEI,STI,SSI}
        jal cross_interrupts_m_EP   # Try 36 combinations of enable and pending

        csrrw t6, mideleg, zero     # Set mideleg to 0s
        jal cross_interrupts_m_EP   # Try 36 combinations of enable and pending

        li t0, 8
        csrrs t6, mstatus, t0       # mstatus.MIE = 1

        li t1, 0x222
        csrrw t6, mideleg, t1       # Set mideleg to {SEI,STI,SSI}
        jal cross_interrupts_m_EP   # Try 36 combinations of enable and pending

        csrrw t6, mideleg, zero     # Set mideleg to 0s
        jal cross_interrupts_m_EP   # Try 36 combinations of enable and pending

    /////////////////////////////////
    // cp_vectored
    // Cross of mtvec.MODE = 01, mstatus.MIE=1, mideleg = 0s, all 3 of mie.STIE/SSIE/SEIE,
    // 3 walking 1s in mip.STIP/SSIP/SEIP (3 bins)
    /////////////////////////////////

    cp_vectored:

        li t0, 3
        csrrc t6, mtvec, t0
        li t0, 1
        csrrs t6, mtvec, t0 # mtvec.MODE = 01

        li t0, 8
        csrrs t6, mstatus, t0   # mstatus.MIE = 1
        csrrw t6, mie, zero     # clear all interrupt enables

        li s1, 0x0222
        csrrs t6, mie, s1       # set mie.SEIE/STIE/SSIE

        li s2, 3                # use as index for mip cases

        1:
        addi s2, s2, -1
        li t0, 2
        bne s2, t0, 2f          # case 2: set mip.SSIP
        csrr t6, mie            # trap handler clears mie, so make sure it is preserved
        li t0, 2
        csrs mip, t0
        csrw mie, t6            # restore mie for other cases

        2:
        li t0, 1
        bne s2, t0, 3f
        li t1, 32               # case 1: set mip.STIP
        csrr t6, mie            # trap handler clears mie, so make sure it is preserved
        csrs mip, t1
        csrw mie, t6            # restore mie for other cases

        3:
        bnez s2, 4f
        li t0, 512              # case 0: set mip.SEIP
        csrr t6, mie            # trap handler clears mie, so make sure it is preserved
        csrs mip, t1
        csrw mie, t6            # restore mie for other cases

        4:
        bnez s2, 1b             # go to next case unless no interrupts were attempted

    ///////////////////////////////
    // cp_priority_mip
    //
    // Cross of 2^6 permutations of mip, mie=1s, mideleg = 0s.  
    // Set up with mstatus.MIE = 0, then it rises.
    ///////////////////////////////

    cp_priority_mip:
        li a0, 63           # set up bitfield to iterate through mip permutations
        RVTEST_GOTO_MMODE   # set up everything in M-mode
        
        1:
        li t0, -1
        csrrw t6, mie, t0           # set mie = 1s
        csrrw t6, mideleg, zero     # use mideleg = 0s
        li t0, 2
        csrrc t6, mstatus, t0       # start with mstatus.MIE = 0

        andi t0, a0, 32             # use bit 5 for stimer
        beqz t0, 2f                 
        li t1, 32                   
        csrrs t6, mip, t1           # set mip.STIP

        2:
        andi t0, a0, 16             # use bit 4 for sexternal
        beqz t0, 3f
        li t0, 512
        csrrs t6, mip, t0           # set mip.SEIP

        3:
        andi t0, a0, 8              # use bit 3 for ssoftware
        beqz t0, 4f
        li t0, 2
        csrrs t6, mip, t0           # set mip.SSIP
            
        4:
        andi t0, a0, 4                  # use bit 2 for mtimer
        beqz t0, 5f
        jal cause_mtimer_interrupt_now

        5:
        andi t0, a0, 2                  # use bit 1 for mexternal
        beqz t0, 6f
        jal cause_external_interrupt_M

        6:
        andi t0, a0, 1                  # use bit 0 for msoftware
        beqz t0, 7f
        jal cause_msoftware_interrupt

        7:
        li t0, 8
        csrrs t6, mstatus, t0           # set mstatus.MIE = 1, expect interrupts in priority order
        csrrw t6, mip, zero             # this and next 3 lines clear whatever isn't taken
        jal reset_msoftware_interrupt
        jal reset_mtimecmp
        jal reset_external_interrupts
        addi a0, a0, -1
        bgez a0, 1b                     # go to next case unless no interrupts were attempted

    ///////////////////////////////
    // cp_priority_mie
    //
    // Cross of 2^6 permutations of mie, mip=1s, mideleg = 0s.  
    // Set up with mstatus.MIE = 0, then it rises.
    ///////////////////////////////

    cp_priority_mie_m:
        li a0, 63           # set up bitfield to iterate through mip permutations
        RVTEST_GOTO_MMODE   # set up everything in M-mode

        1:
        li t0, 8
        csrrc t6, mstatus, t0           # set up with mstatus.MIE = 0
        li t0, 0x222                    # 1 in SEIP, STIP, SSIP
        csrrw t6, mip, t0               # set all supervisor interrupts
        csrrw t6, mideleg, zero         # do not delegate
        jal cause_mtimer_interrupt_now  # set machine interrupts one by one
        jal cause_external_interrupt_M
        jal cause_msoftware_interrupt

        andi t0, a0, 32                 # use bit 5 for ssoftware
        beqz t0, 2f
        li t0, 2
        csrrs t6, mie, t0

        2:
        andi t0, a0, 16                 # use bit 4 for msoftware
        beqz t0, 3f
        li t0, 8
        csrrs t6, mie, t0

        3:
        andi t0, a0, 8                  # use bit 3 for stimer
        beqz t0, 4f
        li t1, 32
        csrrs t6, mie, t1
            
        4:
        andi t0, a0, 4                  # use bit 2 for mtimer
        beqz t0, 5f
        li t0, 128
        csrrs t6, mie, t0

        5:
        andi t0, a0, 2                  # use bit 1 for sexternal
        beqz t0, 6f
        li t0, 512
        csrrs t6, mie, t0

        6:
        andi t0, a0, 1                  # use bit 0 for mexternal
        beqz t0, 7f
        li t0, 2048
        csrrs t6, mie, t0

        7:
        li t0, 8
        csrrs t6, mstatus, t0           # raise mstatus.MIE, expect all interrupts to trigger in priority order
        csrrw t6, mie, zero             # clear mie before next test
        li t0, -1
        csrrc t6, mip, t0               # clear all supervisor interrupts pending
        jal reset_mtimecmp              # clear machine interrupts one by one
        jal reset_external_interrupts
        jal reset_msoftware_interrupt
        addi a0, a0, -1
        bgez a0, 1b                     # go to next case unless no interrupts were attempted

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
    
        li a0, 7
        RVTEST_GOTO_MMODE               # perform whole test in M-mode

        1:
        li t0, 8
        csrrc t6, mstatus, t0           # toggle mstatus.MIE based on bit 2
        andi t0, a0, 4
        beqz t0, 2f
        li t0, 8
        csrrs t6, mstatus, t0
        
        2:
        li t0, 2
        csrrc t6, mstatus, t0           # toggle mstatus.SIE based on bit 1
        andi t0, a0, 2
        beqz t0, 3f
        li t0, 2
        csrrs t6, mstatus, t0

        3:
        li t1, 1
        slli t1, t1, 21
        csrrc t6, mstatus, t1           # toggle mstatus.TW based on bit 0
        andi t0, a0, 1
        beqz t0, 4f 
        csrrs t6, mstatus, t1

        4:
        li t0, -1
        csrrw t6, mideleg, t0           # mideleg = 1s
        li t0, 128                      
        csrrs t6, mie, t0               # enable mtimer interrupts
        jal cause_mtimer_interrupt_soon
        wfi                             # wfi should wait until timer interrupt triggers
        addi a0, a0, -1
        bgez a0, 1b                     # repeat until all cases are tested

    /////////////////////////////////
    // cp_trigger_ssi_sip
    //
    // With mstatus.MIE = {0/1}, mideleg.SSI=1, and mie = 1s, write sip.SSIP
    /////////////////////////////////
    /*
    cp_trigger_ssi_sip:
        RVTEST_GOTO_MMODE
        li t0, -1               # all 1s
        csrrw t6, mie, t0       # enable all interrupts
        csrrs t6, mideleg, 2    # delegate ssoftware interrupts

        # mstatus.MIE = 0 should not take interrupt
        li t0, 8
        csrrc t6, mstatus, t0   # mstatus.MIE = 0
        li t0, 2
        csrrs t6, sip, t0       # set sip.SSIP, do not expect interrupt
        csrrc t6, sip, t0       # reset sip.SSIP since the trap handler will not reset it if no interrupt occurs

        # mstatus.MIE = 1 should take interrupt
        li t0, 8
        csrrs t6, mstatus, t0   # mstatus.MIE = 1
        li t0, 2
        csrrs t6, sip, t0       # set sip.SSIP, expect interrupt
        csrrc t6, sip, t0
    */
    /////////////////////////////////
    // cp_trigger_mti
    // 
    // with mideleg = 0s, mie = 1s, use MTIMECMP to cause mip.MTIP to rise,
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_mti:
        RVTEST_GOTO_MMODE               # perform test in M-mode
        li t0, -1
        csrrw t6, mideleg, zero         # do not delegate interrupts
        csrrw t6, mie, t0               # enable all interrupts
        jal cause_mtimer_interrupt_now
        li t0, 8
        csrrs t6, mstatus, t0           # set mstatus.MIE = 1, expect interrupt here
        csrrc t6, mstatus, t0           # clear mstatus.MIE to clean up for future tests
        jal reset_mtimecmp
    
    /////////////////////////////////
    // cp_trigger_changingtom_msi
    // 
    // with mideleg = 0s, mie = 1s, use CLINT.MSIP to cause mip.MSIP to rise,
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_msi:
        RVTEST_GOTO_MMODE               # perform test in M-mode
        li t0, -1
        csrrw t6, mideleg, zero         # do not delegate interrupts
        csrrw t6, mie, t0               # enable all interrupts
        jal cause_msoftware_interrupt
        li t0, 8
        csrrs t6, mstatus, t0           # set mstatus.MIE = 1, expect interrupt here
        csrrc t6, mstatus, t0           # clear mstatus.MIE to clean up for future tests
        jal reset_msoftware_interrupt

    /////////////////////////////////
    // cp_trigger_mei
    // 
    // with mideleg = 0s, mie = 1s, use PLIC to cause mip.MEIP to rise,
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_mei:
        RVTEST_GOTO_MMODE               # perform test in M-mode
        li t0, -1
        csrrw t6, mideleg, zero         # do not delegate interrupts
        csrrw t6, mie, t0               # enable all interrupts
        jal cause_external_interrupt_M
        li t0, 8
        csrrs t6, mstatus, t0           # set mstatus.MIE = 1, expect interrupt here
        csrrc t6, mstatus, t0           # clear mstatus.MIE to clean up for future tests
        jal reset_external_interrupts

    /////////////////////////////////
    // cp_trigger_sti
    // 
    // with mideleg = 0s, mie = 1s, mip.STIP=1, 
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_sti:
        RVTEST_GOTO_MMODE               # perform test in M-mode
        li t0, -1
        csrrw t6, mideleg, zero         # do not delegate interrupts
        csrrw t6, mie, t0               # enable all interrupts
        li t1, 32
        csrrs t6, mip, t1               # set mip.STIP = 1
        li t0, 8
        csrrs t6, mstatus, t0           # set mstatus.MIE = 1, expect interrupt here
        csrrc t6, mstatus, t0           # clear mstatus.MIE to clean up for future tests
        li t1, 32
        csrrc t6, mip, t1

    /////////////////////////////////
    // cp_trigger_ssi
    // 
    // with mideleg = 0s, mie = 1s, mip.SSIP=1, 
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_ssi:
        RVTEST_GOTO_MMODE               # perform test in M-mode
        li t0, -1
        csrrw t6, mideleg, zero         # do not delegate interrupts
        csrrw t6, mie, t0               # enable all interrupts
        li t0, 2
        csrrs t6, mip, t0               # set mip.SSIP = 1
        li t0, 8
        csrrs t6, mstatus, t0           # set mstatus.MIE = 1, expect interrupt here
        csrrc t6, mstatus, t0           # clear mstatus.MIE to clean up for future tests
        li t0, 2
        csrrc t6, mip, t0

    /////////////////////////////////
    // cp_trigger_sei
    // 
    // with mideleg = 0s, mie = 1s, use PLIC to cause mip.SEIP,
    // then change to machine mode, then write mstatus.MIE
    /////////////////////////////////

    cp_trigger_sei:
        RVTEST_GOTO_MMODE               # perform test in M-mode
        li t0, -1
        csrrw t6, mideleg, zero         # do not delegate interrupts
        csrrw t6, mie, t0               # enable all interrupts
        jal cause_external_interrupt_S
        li t0, 8
        csrrs t6, mstatus, t0           # set mstatus.MIE = 1, expect interrupt here
        csrrc t6, mstatus, t0           # clear mstatus.MIE to clean up for future tests
        jal reset_external_interrupts

    /////////////////////////////////
    // cp_sei4
    // 
    // With mstatus.MIE=0, mip.SEIP=1, PLIC not activating SEIP,
    // use csrrc to clear mip.SEIP
    /////////////////////////////////

    cp_sei4:
        RVTEST_GOTO_MMODE           # perform test in M-mode
        li t0, 8
        csrrc t6, mstatus, t0       # reset mstatus.MIE
        li t0, 128                  
        csrrs t6, mip, t0           # set mip.SEIP = 1, do not expect interrupt
        csrrc t6, mip, t0           # clear interrupt pending

    /////////////////////////////////
    // cp_sei5
    // 
    // With mstatus.MIE=0, mip.SEIP=1 because of previous write,
    // PLIC activating SEIP, use csrrc to clear mip.SEIP
    /////////////////////////////////

    cp_sei5:
        RVTEST_GOTO_MMODE               # perform test in M-mode
        li t0, 8
        csrrc t6, mstatus, t0           # clear mstatus.MIE
        li t0, 128
        csrrs t6, mip, t0               # Previous write to mip.SEIP
        jal cause_external_interrupt_S  # PLIC activate SEIP
        csrrc t6, mip, t0               # clear using csrrc
        jal reset_external_interrupts   # clear through PLIC to make sure other tests aren't affected

    /////////////////////////////////
    // cp_sei6
    // 
    // With mstatus.MIE=0, no previous write 1 to mip.SEIP, 
    // PLIC activating SEIP, turn off PLIC.SEIP
    /////////////////////////////////

    cp_sei6:
        RVTEST_GOTO_MMODE               # same as cp_sei_5 but no previous write and only clear with PLIC
        li t0, 8
        csrrc t6, mstatus, t0
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
        RVTEST_GOTO_MMODE               # same as cp_sei_6 except with previous write
        li t0, 8
        csrrc t6, mstatus, t0
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
        li a0, 3            # bitfield for {mstatus.MIE, SIE}
        
        2:
        li a1, 2                            # index var for MEIE (2), MTIE (1), MSIE (0)
        jal cause_mtimer_interrupt_now      # raise all pending machine mode interrupts
        jal cause_msoftware_interrupt
        jal cause_external_interrupt_M
        li t0, 8
        csrrc t6, mstatus, t0               # toggle mstatus.MIE based on bit 1 of a0
        andi t0, a0, 2
        beqz t0, 3f
        li t0, 8
        csrrs t6, mstatus, t0

        3:
        li t0, 2
        csrrc t6, mstatus, t0               # toggle mstatus.SIE based on bit 0 of a0
        andi t0, a0, 1
        beqz t0, 4f
        li t0, 2
        csrrs t6, mstatus, t0

            4:
            li t0, 2
            bne t0, a1, 5f                  # case 2: set mie.MEIE
            li t0, 2048
            csrrs t6, mie, t0

            5:
            li t0, 1
            bne t0, a1, 6f                  # case 1: set mie.MTIE
            li t1, 128
            csrrs t6, mie, t1

            6:
            bnez a1, 7f                     # case 0: set mie.MSIE
            li t0, 8
            csrrs t6, mie, t0

            7:
            addi a1, a1, -1
            bgez a1, 4b

        addi a0, a0, -1
        bgez a0, 2b

    j test_end

    ///////////////////////////////
    // helper functions
    ///////////////////////////////

    #include "trickbox.S"

    cross_interrupts_m_EP:
        // helper function for crossing mie.MEIE/SEIE/M/STIE/M/SSIE with mip.M/SEIP/MTIP/MSIP in Interrupts tests (enables and pending)
        li s0, 5                # iterate through setting mie.MEIE (5), SEIE (4), MTIE (3), STIE (2), MSIE (1), or SSIE (0)

        addi sp, sp, -8         # save ra before next function call
        SREG ra, 0(sp)

        for_mie_m:
        
            slli t3, s0, 1      # setting mie.M/SEIE, M/STIE, or M/SSIE based on s0 value
            li t4, 2
            sll t4, t4, t3      # put a 1 in bit (1+(2*s0))
            csrrw t6, mie, t4   # set enable for interrupt type of interest, clear all others
        
            jal raise_interrupts_m
        
            addi s0, s0, -1     
            bge s0, zero, for_mie_m # iterate through interrupt types to be enabled

        
        LREG ra, 0(sp)              # restore ra
        addi sp, sp, 8

        ret

    raise_interrupts_m:
        // raises each of mip.M/SEIP/M/SSIP/M/STIP once in sequence

        addi sp, sp, -16     # store return address to stack
        csrr t6, mie         # save mie on stack because trap handler may reset it
        SREG t6, 8(sp)
        SREG ra, 0(sp)

        li s2, 5            # RVTEST_GOTO_LOWER_MODE macro wipes s1 so use s2 instead

        for_mip_m:
            
            # based on s2 value, set mip.MEIP (5), SEIP (4), MTIP (3), STIP (2), MSIP (1), or SSIP (0)
            # includes clearing mip in case interrupt is not triggered
            # To trigger interrupts in S-mode, raise mstatus.SIE and switch to S-mode 

            for_mip_m_meip:
                li t3, 5
                bne s2, t3, for_mip_m_seip      # if s2 == 5, trigger mexternal interrupt
                jal cause_external_interrupt_M  # set mip.MEIP
                nop
                jal reset_external_interrupts   # clear mip.MEIP

            for_mip_m_seip:
                li t3, 4
                bne s2, t3, for_mip_m_mtip      # if s2 == 4, trigger sexternal interrupt
                li t0, 512
                csrs mip, t0                    # set mip.SEIP
                nop
                li t0, 512
                csrrc t6, mip, t0               # clear mip.SEIP
            
            for_mip_m_mtip:
                li t3, 3
                bne s2, t3, for_mip_m_stip      # if s2 == 3, trigger mtimer interrupt
                jal cause_mtimer_interrupt_now  # set mip.MTIP
                nop
                jal reset_mtimecmp              # clear mip.STIP

            for_mip_m_stip:
                li t3, 2
                bne s2, t3, for_mip_m_msip      # if s2 == 2, trigger stimer interrupt
                li t1, 32
                csrs mip, t1                    # set mip.STIP
                nop
                li t1, 32                       # clear mip.STIP
                csrrc t6, mip, t1

            for_mip_m_msip:
                li t3, 1
                bne s2, t3, for_mip_m_ssip      # if s2 = 1, trigger msoftware interrupt
                jal cause_msoftware_interrupt   # set mip.MSIP
                nop
                jal reset_msoftware_interrupt   # clear mip.MSIP

            for_mip_m_ssip:
                li t3, 0
                bne s2, t3, for_mip_m_end      # if s2 = 0, trigger ssoftware interrupt
                li t0, 2
                csrs mip, t0                    # set mip.SSIP
                nop
                li t0, 2                        # clear mip.SSIP
                csrrc t6, mip, t0
            
            for_mip_m_end:
                LREG t6, 8(sp)                  # restore mie value for next test
                csrw mie, t6                    # restore mie value for next test
                addi s2, s2, -1                 # decrement loop counter
                bgez s2, for_mip_m

        LREG ra, 0(sp)      # restore return address from stack
        addi sp, sp, 16

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