// c_test_start.S
// Startup code for ACT C tests
// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
// SPDX-License-Identifier: Apache-2.0

#ifdef RVTEST_NOSIG
#define SIGUPD_COUNT 0
#define TRAP_SIGUPD_COUNT 0
#endif

// The boot code clears .bss on hart 0 before it releases the other harts.
#define RVTEST_C_TEST
#include "riscv_arch_test.h"

// Set up test environment and declare main entry point.
// Every hart the test uses gets here in the test's boot mode.
RVTEST_BEGIN

  // The linker script must reserve a stack for each hart the test uses.
  LA(t1, c_num_harts)
  LREG  t1, 0(t1)
  LI(t2, RVTEST_NUM_HARTS)
  bltu  t1, t2, c_halt_fail

  // Stacks grow down from __stack_top in __stack_size chunks, one for each mhartid.
  li    a0, 0
#if RVTEST_NUM_HARTS > 1
  RVTEST_TSBI_CSR_READ(CSR_MHARTID)
#endif
  LA(sp, __stack_top)
  LA(t1, c_stack_size)
  LREG  t1, 0(t1)
1:
  beqz  a0, 2f
  sub   sp, sp, t1
  addi  a0, a0, -1
  j     1b
2:
  andi  sp, sp, -16

  // Hart 0 reports a pass. A hart whose main() returns nonzero fails the test.
  call  main
  call  c_test_exit
c_test_exit_returned:
  j     c_test_exit_returned

// C interface to T-SBI: a0 = operation code, a1 and a2 = arguments; result in a0.
// The RV64 ABI sign-extends the 32-bit operation code. T-SBI expects it zero-extended.
.global tsbi_call
tsbi_call:
#if __riscv_xlen == 64
  slli  a0, a0, 32
  srli  a0, a0, 32
#endif
  ecall
  ret

// T-SBI privilege-mode switches for C. Each returns to its caller in the new mode.
.global tsbi_goto_mmode
tsbi_goto_mmode:
  RVTEST_TSBI_GOTO_MMODE
  ret

.global tsbi_goto_smode
tsbi_goto_smode:
  RVTEST_TSBI_GOTO_SMODE
  ret

.global tsbi_goto_umode
tsbi_goto_umode:
  RVTEST_TSBI_GOTO_UMODE
  ret

#ifdef H_SUPPORTED
.global tsbi_goto_vsmode
tsbi_goto_vsmode:
  RVTEST_TSBI_GOTO_VSMODE
  ret

.global tsbi_goto_vumode
tsbi_goto_vumode:
  RVTEST_TSBI_GOTO_VUMODE
  ret
#endif

// Route pass/fail through ACT cleanup so DUT trap state is unwound normally.
.global c_halt_pass
c_halt_pass:
  j     rvtest_code_end

// rvtest_current_mode tracks hart 0 only, so switch to M-mode here on every hart.
.global c_halt_fail
c_halt_fail:
  RVTEST_TSBI_GOTO_MMODE
  j     rvtest_fail_summary_mmode

RVTEST_CODE_END

RVTEST_DATA_BEGIN

.p2align 3
// Linker-defined constants are loaded through data slots so this works for
// memory maps whose absolute addresses cannot be materialized directly.
c_stack_size:
  RVTEST_WORD_PTR __stack_size
c_num_harts:
  RVTEST_WORD_PTR __num_harts

RVTEST_DATA_END

RVTEST_SIG_SETUP
