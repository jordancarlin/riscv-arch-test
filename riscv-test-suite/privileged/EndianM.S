///////////////////////////////////////////
// EndianM.S
//
// Written: David_Harris@hmc.edu 19 November 2024
//
// Purpose: Functional coverage tests for endianness in machine mode
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
    RVTEST_CASE(1,"//check ISA:=regex(.*I.*Zicsr.*); def rvtest_mtrap_routine=True; def rvtest_strap_routine=True; def rvtest_dtrap_routine=True; def TEST_CASE_1=True",EndianM)

RVTEST_SIGBASE( x3,signature_base)

	.attribute unaligned_access, 0
	.attribute stack_align, 16
  	.align	2   
  	.option norvc
    
main:
/////////////////////////////////
// Endianness testing
// cp_mstatush_mbe_endianness
// cp_mstatus_mbe_endianness
//
// Goal is to store a pattern to a scratch location in memory
// using each endianness, and stores of every size.  Then
// read back the value using each endianness and loads of
// every size.  Stress that endianness works for every access.
//
// Saving and restoring from the stack is tricky because the
// code must work for both RV32 and RV64, and the endianness
// is constantly changing.  Therefore, we use s6 and s7 (found in priv-endian.h)for
// return addresses instead.
//
// Registers used:
//   s0: saved value of mstatus
//   s1: a 1 in bit 5 to set/clear mstatush.MBE (RV32) or bit 37 to set/clear mstatus.MBE (RV64)
//   s3: scratch address
//   s4: endianness for write test
//   s5: endianness for read test
//   s10: 0 to set/clear sstatus.UBE  (any other value otherwisse )
//   s11: To switch back to running privilege mode once set/clear endianness
//   t5: signature pointer
//   x3: pointer to signature base
///////////////////////////////////////////////
    // save mstatus
    // prep s1 with bits to set/clear MBE for RV32/RV64
    // always do both.  One or the other will trap, but this
    // avoids needing separate code for the two architectures
    // code assumes s registers are saved during these tests
    // saving and restoring mstatus based on endianness
    // calling WALLY-priv-endian.h to store and load

    csrr s0, mstatus    # save CSR
    //mv t5, x3  # 
    #ifdef __riscv_xlen
        #if __riscv_xlen == 64
            li s1, 0x2000000000     # 1 in bit 37 for mstatus.MBE
        #elif __riscv_xlen == 32
            li s1, 0x20             # 1 in bit 5 for mstatush.MBE
        #endif
    #else
        ERROR: __riscv_xlen not defined
    #endif
    la s3, scratch  # s3 = pointer to scratch
    li s10, 1
    li s11, 3       # passing privilige mode: machine
    RVTEST_SIGWRITE(x3,s11)

    // iterate over each endianness, doing all sizes of stores and loads
    li s4, 0        # endianness for write
    RVTEST_SIGWRITE(x3, s4)
    li s5, 0        # endianness for read
    RVTEST_SIGWRITE(x3, s5)
    jal s6, endiantest  # test little-endian read and write

    li s4, 1        # endianness for write
    RVTEST_SIGWRITE(x3, s4)
    jal s6, endiantest  # test big-endian write, little-endian read

    li s5, 1        # endianness for read
    RVTEST_SIGWRITE(x3, s5)
    jal s6, endiantest  # test big-endian read and write

    li s4, 0        # endianness for write
    RVTEST_SIGWRITE(x3, s4)
    jal s6, endiantest  # test little-endian write, big-endian read

    post_cp_mstatus_mbe_endianness:
        csrrw t6, mstatus, s0    # restore CSR
        jal s6, test_end


#include "priv-endian.h" 

test_end: //finish



#endif

 # ---------------------------------------------------------------------------------------------
    # HALT

RVTEST_CODE_END
RVMODEL_HALT

# Allocate scratch memory in .bss section
.section .bss
.align 4
scratch:
    .space 136  # Reserve 136 bytes of uninitialized memory

# scratch:
# .fill 4,4,0x0
# # Initialize stack with room for 512 bytes
# .bss
#     .space 512
# topofstack:

RVTEST_DATA_BEGIN
# Input data section.
.data
.align 4
rvtest_data:
.word 0xb0bacafe
.word 0xb0bacafe
RVTEST_DATA_END

# Output data section.
RVMODEL_DATA_BEGIN
rvtest_sig_begin:
sig_begin_canary:
CANARY;
signature_base:
    .fill 600*(XLEN/32),4,0xdeadbeef
    
# test_A_res:
#     .fill 2, 4, 0xdeadbeef

#ifdef rvtest_mtrap_routine
tsig_begin_canary:
CANARY;
mtrap_sigptr:
    .fill 15*(XLEN/32),4,0xb0bacafe
#Prof Harris mentioned we should probably start with 10000
tsig_end_canary:
CANARY;

#endif

#ifdef rvtest_gpr_save
gpr_save:
  .fill 32*(XLEN/32), 4, 0xdeadbeef
#endif



sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END

