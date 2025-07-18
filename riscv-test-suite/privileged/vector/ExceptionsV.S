///////////////////////////////////////////
// /home/gtai/cvw/addins/cvw-arch-verif/tests/priv/vector/ExceptionsV.S
// David_Harris@hmc.edu

# testgen_header_vector_priv.S
//
// Copyright (C) 2024 Harvey Mudd College & Oklahoma State University, Habib University, UET Lahore
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

// Define special purpose registers before including test_macros_vector.h
#define DATA_BASE x4
#define SIG_BASE x3
#define VLENB_CACHE x5
#define HELPER_GPR x6

#include "test_macros_vector.h"

RVTEST_ISA("RV32IMV_Zicsr, RV64IMV_Zicsr")

# Test code region
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN

#ifdef TEST_CASE_1

RVTEST_CASE(1,"//check ISA:=regex(.*I.*M.*V.*Zicsr.*BLOCKED.*); def rvtest_mtrap_routine=True; def rvtest_strap_routine=True; def rvtest_dtrap_routine=True; def TEST_CASE_1=True",ZicsrV)

RVTEST_V_ENABLE()
RVTEST_SIGBASE(SIG_BASE, signature_base)

#define SEWMIN 8
#define ELEN 64

#if SEWMIN == 64
    #define SEWSIZE e64
    #define VLESEWMIN vle64.v
    #define RVTEST_SIGUPD_V_SEWMIN(BR, TMPR, AVL, VREG) RVTEST_SIGUPD_V(BR, TMPR, AVL, 64, VREG)
#elif SEWMIN == 32
    #define SEWSIZE e32
    #define VLESEWMIN vle32.v
    #define RVTEST_SIGUPD_V_SEWMIN(BR, TMPR, AVL, VREG) RVTEST_SIGUPD_V(BR, TMPR, AVL, 32, VREG)
#elif SEWMIN == 16
    #define SEWSIZE e16
    #define VLESEWMIN vle16.v
    #define RVTEST_SIGUPD_V_SEWMIN(BR, TMPR, AVL, VREG) RVTEST_SIGUPD_V(BR, TMPR, AVL, 16, VREG)
#else
    #define SEWSIZE e8
    #define VLESEWMIN vle8.v
    #define RVTEST_SIGUPD_V_SEWMIN(BR, TMPR, AVL, VREG) RVTEST_SIGUPD_V(BR, TMPR, AVL, 8, VREG)
#endif



///////////////////////////////////////////
// ExceptionsV tests for vadd.vv
///////////////////////////////////////////

# Testcase cp_vill
vsetivli x8, 1, SEWSIZE, m1, tu, mu               # initialize vl = 1, LMUL = 1, SEW = SEWMIN
la x2, random_mask_0                              # load a random vector 
VLESEWMIN v8, (x2)                                # load to initialize vd (v8) 
VLESEWMIN v16, (x2)                               # load to initialize vs2 (v16)
VLESEWMIN v24, (x2)                               # load to initialize vs1 (v24)
vsetivli  x8, 1, e64, mf8, tu, mu                 # SEW = 64 and LMUL = 1/8, illegal config which sets vill = 1
vadd.vv v8, v16, v24
nop                                               # nop after possible trap
vsetivli x8, 1, SEWSIZE, m1, tu, mu               # re-initialize vl = 1, LMUL = 1, SEW = SEWMIN for signature
RVTEST_SIGUPD_V_SEWMIN(x3, x6, 1, v8)             # stores v8 (sew = SEWMIN, AVL = 1) in signature with base (x3) and helper (x6) register


///////////////////////////////////////////
// ExceptionsV tests for vadd.vx
///////////////////////////////////////////

# Testcase cp_vill
vsetivli x8, 1, SEWSIZE, m1, tu, mu               # initialize vl = 1, LMUL = 1, SEW = SEWMIN
la x2, random_mask_0                              # load a random vector 
VLESEWMIN v8, (x2)                                # load to initialize vd (v8) 
VLESEWMIN v16, (x2)                               # load to initialize vs2 (v16)
vsetivli  x8, 1, e64, mf8, tu, mu                 # SEW = 64 and LMUL = 1/8, illegal config which sets vill = 1
li x7, 0x1aecb288e32e1060                         # Load immediate value into integer register
vadd.vx v8, v16, x7
nop                                               # nop after possible trap
vsetivli x8, 1, SEWSIZE, m1, tu, mu               # re-initialize vl = 1, LMUL = 1, SEW = SEWMIN for signature
RVTEST_SIGUPD_V_SEWMIN(x3, x6, 1, v8)             # stores v8 (sew = SEWMIN, AVL = 1) in signature with base (x3) and helper (x6) register


///////////////////////////////////////////
// ExceptionsV tests for vadd.vi
///////////////////////////////////////////

# Testcase cp_vill
vsetivli x8, 1, SEWSIZE, m1, tu, mu               # initialize vl = 1, LMUL = 1, SEW = SEWMIN
la x2, random_mask_0                              # load a random vector 
VLESEWMIN v8, (x2)                                # load to initialize vd (v8) 
VLESEWMIN v16, (x2)                               # load to initialize vs2 (v16)
vsetivli  x8, 1, e64, mf8, tu, mu                 # SEW = 64 and LMUL = 1/8, illegal config which sets vill = 1
vadd.vi v8, v16, -4
nop                                               # nop after possible trap
vsetivli x8, 1, SEWSIZE, m1, tu, mu               # re-initialize vl = 1, LMUL = 1, SEW = SEWMIN for signature
RVTEST_SIGUPD_V_SEWMIN(x3, x6, 1, v8)             # stores v8 (sew = SEWMIN, AVL = 1) in signature with base (x3) and helper (x6) register

# cp_vstart_gt_vl_setup.S
///////////////////////////////////////////
// cp_vstart_gt_vl_setup.S
//
// Set up function of vstart and vl for cp_vstart_gt_vl_setup in ExceptionsV
// Goal: generate vl and vstart where VLMAX > vstart > vl > 0
///////////////////////////////////////////
j    end_cp_vstart_gt_vl_setup       # jump pass the function when not called

cp_vstart_gt_vl_setup:
vsetvli x8, x0, SEWSIZE, m4, tu, mu  # x8 = VLMAX
remu a0, a0, x8                      # ensure that a0 < VLMAX by a0 % VLMAX
remu a1, a1, x8                      # ensure that a1 < VLMAX by a1 % VLMAX

zero_check:  # ensure that both vstart and vl are greater than 0
beqz a0, add_a0                      # add to a0 if a0 == 0
remu a0, a0, x8                      # ensure that a0 < VLMAX by a0 % VLMAX
beqz a1, add_a1                      # add to a1 if a1 == 0
remu a1, a1, x8                      # ensure that a1 < VLMAX by a1 % VLMAX
j    compare

add_a0:      # add to a0 to make a0 > 0
addi a0, a0, 1
j    zero_check                      # jump back to zero_check to ensure that both a0, a1 > 0

add_a1:      # add to a1 to make a1 > 0
addi a1, a1, 1
j    zero_check                      # jump back to zero_check to ensure that both a0, a1 > 0

compare:     # compare place holder values to assign CSRs accordingly
blt  a1, a0, a0a1_swap               # if a1 < a0, jump to assign vl = a1 and vstart = a0
beq  a1, a0, a0a1_equal              # if a1 = a0, jump to modify one of the placeholder values
j    a0a1_keep                       # if a1 > a0, jump to assign vstart = a1 and vl = a0

a0a1_equal:  # VLMAX > a1 = a0, modify one of the placeholder values
addi a1, a1, 1                       # add to a1 (vstart place holder) to create a1 > a0
remu a1, a1, x8                      # ensure that a1 < VLMAX by a1 % VLMAX
j    zero_check                      # compare again in case a1 = 0 after the rem operation

a0a1_keep:   # VLMAX > a1 > a0, assign CSRs such that VLMAX > vstart > vl
vsetvli x8, a0, SEWSIZE, m4, tu, mu  # set vl = a0
csrw vstart, a1                      # set vstart = v4
ret                                  # return to cp_vstart_gt_vl test after set up

a0a1_swap:   # VLMAX > a0 > a1, assign CSRs such that VLMAX > vstart > vl
vsetvli x8, a1, SEWSIZE, m4, tu, mu  # set vl = a1
csrw vstart, a0                      # set vstart = a0
ret                                  # return to cp_vstart_gt_vl test after set up

end_cp_vstart_gt_vl_setup:


# testgen_footer_vector1.S

#endif


RVTEST_CODE_END
RVMODEL_HALT

# Allocate scratch memory in .bss section
.section .bss
.align 4
scratch:
    .space 136  # Reserve 136 bytes of uninitialized memory

RVTEST_DATA_BEGIN
.align 4

rvtest_data:
.word 0xb0bacafe
.word 0xb0bacafe

vector_data:

    .align 3
random_mask_0:
    .word 0xf58be48b
    .word 0xc60c62ea
    .word 0xc6a22fc3
    .word 0xe26a544c
    .word 0x6c292def
    .word 0xc68fa837
    .word 0xce0ea035
    .word 0xe16aadc9
    .word 0x511ecba2
    .word 0xaacafafe
    .word 0xdf6750e0
    .word 0x4f1c6e71
    .word 0x23892f87
    .word 0x20063ad7
    .word 0x4c428c38
    .word 0xe674d14f
random_mask_1:
    .word 0xd607782a
    .word 0x1cb3aac7
    .word 0x8f6e673c
    .word 0x970c09bd
    .word 0xc685ee92
    .word 0xd90e18bf
    .word 0xc623d757
    .word 0x802d0e45
    .word 0xc5c83caf
    .word 0x7da40376
    .word 0xb4b1080b
    .word 0x0d1c9793
    .word 0x98df50be
    .word 0xf21eb7a4
    .word 0xe8ce55ba
    .word 0x920e6fca
random_mask_2:
    .word 0x6e2cda5a
    .word 0xc448eaba
    .word 0x2f9ac970
    .word 0x3bc1b2cb
    .word 0xcf400664
    .word 0xe45434cf
    .word 0x5b00b697
    .word 0xef8cdc9c
    .word 0xeb1e3d63
    .word 0x9eb2c3a4
    .word 0x003ac365
    .word 0x6996ca69
    .word 0x1f86165c
    .word 0xe188724d
    .word 0x3b4f7ecf
    .word 0x821200e8
cp_mask_random:
    .word 0x0ed1024a
    .word 0x21b3b757
    .word 0xf3bbd855
    .word 0x70c93ff2
    .word 0xee154209
    .word 0x4add4308
    .word 0xd3ca1325
    .word 0xaf1c9ac2
    .word 0xdf369c99
    .word 0x7366eb7c
    .word 0x97e4d05b
    .word 0xd705c91c
    .word 0x0857e6ad
    .word 0x4e57dd0a
    .word 0xa440164c
    .word 0x0541fae2


# testgen_footer_vector2.S


RVTEST_DATA_END


RVMODEL_DATA_BEGIN
rvtest_sig_begin:
sig_begin_canary:
CANARY;

    .align 3
signature_base:
    .fill 16*(XLEN/32),4,0xdeadbeef

#ifdef rvtest_mtrap_routine

tsig_begin_canary:
CANARY;
mtrap_sigptr:
    .fill 2000*(XLEN/32),4,0xb0bacafe
tsig_end_canary:
CANARY;

#endif

#ifdef rvtest_gpr_save

gpr_save:
    .fill 32*(XLEN/32),4,0xdeadbeef

#endif

sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END

