// tsbi.h
// T-SBI (Test Supervisor Binary Interface) operation codes for assembly and C tests,
// and RVTEST_TSBI_* assembly macros.
//
// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
// SPDX-License-Identifier: BSD-3-Clause

#ifndef TSBI_H
#define TSBI_H

// A T-SBI call is an ecall with the operation code in a0. Arguments go in a1 and a2.
// The result is returned in a0. Operation codes are 32-bit values. On RV64, a0 must
// hold the code zero-extended.
//
// The handler dispatches in this order:
//   1. a0 in [1, 5]: switch the caller to the privilege mode given by TSBI_GOTO_*.
//   2. a0 == 0x73 (the ecall encoding): TSBI_ECALL_TEST.
//   3. Otherwise, a0 is the encoding of an instruction for the handler to execute.
//      The handler finds the encoding in a table of supported instructions and runs
//      that copy, so it does not need self-modifying code.
// An unsupported operation fails the test or returns TSBI_RESERVED_RET in a0.

// Privilege-mode switches.
#define TSBI_GOTO_MMODE     0x00000001
#define TSBI_GOTO_SMODE     0x00000002
#define TSBI_GOTO_UMODE     0x00000003
#define TSBI_GOTO_VSMODE    0x00000004
#define TSBI_GOTO_VUMODE    0x00000005

// Record the ecall in the trap signature and return with xEPC in a0.
#define TSBI_ECALL_TEST     0x00000073

#define TSBI_SFENCE_VMA     0x12000073           // sfence.vma x0, x0: flush address-translation caches (requires S)

// Physical-memory accesses. The address is in a1. Stores write a2. Loads return the value in a0.
#define TSBI_LW             0x0005a503           // lw a0, 0(a1)
#define TSBI_LWP4           0x0045a503           // lw a0, 4(a1)
#define TSBI_LD             0x0005b503           // ld a0, 0(a1) (RV64 only)
#define TSBI_SW             0x00c5a023           // sw a2, 0(a1)
#define TSBI_SWP4           0x00c5a223           // sw a2, 4(a1)
#define TSBI_SD             0x00c5b023           // sd a2, 0(a1) (RV64 only)

// CSR accesses. csr is a 12-bit CSR number such as CSR_MIP from encoding.h.
// The CSR must be in the T-SBI CSR table in rvtest_trap_handler.h.
// Writes take the value in a1. Reads return the value in a0.
// In C, the CSR number is unsigned so that the shift into bit 31 is defined.
#ifdef __ASSEMBLER__
  #define TSBI_CSR_NUM(csr)  ((csr) & 0xFFF)
#else
  #define TSBI_CSR_NUM(csr)  ((unsigned int)(csr) & 0xFFFu)
#endif
#define TSBI_CSR_SET(csr)    ((TSBI_CSR_NUM(csr) << 20) | 0x0005a073)  // csrrs x0, csr, a1
#define TSBI_CSR_CLEAR(csr)  ((TSBI_CSR_NUM(csr) << 20) | 0x0005b073)  // csrrc x0, csr, a1
#define TSBI_CSR_WRITE(csr)  ((TSBI_CSR_NUM(csr) << 20) | 0x00059073)  // csrrw x0, csr, a1
#define TSBI_CSR_READ(csr)   ((TSBI_CSR_NUM(csr) << 20) | 0x00002573)  // csrrs a0, csr, x0

// Value returned in a0 for some unsupported operations.
#define TSBI_RESERVED_RET   (-1)

#ifdef __ASSEMBLER__

//==============================================================================
// T-SBI TEST MACROS (assembly only)
//
// Each macro loads a T-SBI operation code into a0 and executes ecall.
//
// Usage in tests:
//   RVTEST_TSBI_GOTO_MMODE              // switch to M-mode, clobbers a0
//   RVTEST_TSBI_GOTO_UMODE              // switch to U-mode, clobbers a0
//   RVTEST_TSBI_ECALL_TEST              // ecall recorded in the trap signature, xEPC in a0
//   RVTEST_TSBI_CSR_ACCESS 0x30002573   // read mstatus into a0
//
// CLOBBERS: a0 (operation code / return value). RVTEST_TSBI_CSR_SET, _CLEAR,
//           and _WRITE also load their argument into a1.
// PRESERVES: all other registers
//==============================================================================

// Switch to M-mode via T-SBI.
// After this macro, the processor is in M-mode and a0 is undefined.
// The S-mode handler forwards a GOTO_MMODE from U, VS or VU to M-mode and then
// resumes here in M-mode with jr a0, which sets ELP when mseccfg.MLPE=1 (Zicfilp).
// So the instruction after the ecall is a 4-byte-aligned lpad 0, which is a no-op
// when the handler returns here with mret instead.
.macro RVTEST_TSBI_GOTO_MMODE
  .option push
  .p2align 2                                     // align the lpad below (c.nop padding if needed)
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_GOTO_MMODE                      // a0 = 1 (GOTO_MMODE operation code)
  ecall                                          // trap to handler; handler sets MPP=M, mrets
  auipc x0, 0                                    // lpad 0: landing pad for the forwarded jr a0
  .option pop
.endm

// Switch to S-mode via T-SBI.
// After this macro, the processor is in S-mode and a0 is undefined.
.macro RVTEST_TSBI_GOTO_SMODE
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_GOTO_SMODE                      // a0 = 2 (GOTO_SMODE operation code)
  ecall                                          // trap to handler; handler sets MPP=S, mrets
  .option pop
.endm

// Switch to U-mode via T-SBI.
// After this macro, the processor is in U-mode and a0 is undefined.
.macro RVTEST_TSBI_GOTO_UMODE
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_GOTO_UMODE                      // a0 = 3 (GOTO_UMODE operation code)
  ecall                                          // trap to handler; handler sets MPP=U, mrets
  .option pop
.endm

// Test the ecall trap path via T-SBI. The handler records the ecall in the trap
// signature and returns past it. After this macro, a0 contains the address of the
// ecall instruction itself.
.macro RVTEST_TSBI_ECALL_TEST
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_ECALL_TEST                      // a0 = 0x73 (ECALL_TEST operation code)
  ecall                                          // trap to handler; handler records it and reads xEPC into a0
  // a0 now contains the address of the ecall instruction above
  .option pop
.endm

// Execute sfence.vma x0, x0 via T-SBI, for a U-mode test that has set satp through
// TSBI_CSR_WRITE and cannot execute sfence.vma itself. Runs in the S-mode handler when
// one exists, otherwise in the M-mode handler. Clobbers a0.
.macro RVTEST_TSBI_SFENCE_VMA
  .option push
  .option norvc
  li   a0, TSBI_SFENCE_VMA
  ecall                                          // trap to handler; handler executes sfence.vma
  .option pop
.endm

.macro RVTEST_TSBI_LW
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_LW                               // code for lw a0, 0(a1)
  ecall                                          // T-SBI call
  .option pop
.endm

.macro RVTEST_TSBI_LWP4
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_LWP4                             // code for lw a0, 4(a1)
  ecall                                          // T-SBI call
  .option pop
.endm

.macro RVTEST_TSBI_LD
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_LD                               // code for ld a0, 0(a1)
  ecall                                          // T-SBI call
  .option pop
.endm

.macro RVTEST_TSBI_SW
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_SW                               // code for sw a2, 0(a1)
  ecall                                          // T-SBI call
  .option pop
.endm

.macro RVTEST_TSBI_SWP4
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_SWP4                             // code for sw a2, 4(a1)
  ecall                                          // T-SBI call
  .option pop
.endm

.macro RVTEST_TSBI_SD
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_SD                               // code for sd a2, 0(a1)
  ecall                                          // T-SBI call
  .option pop
.endm

// Access a CSR via T-SBI (read, write, or read-modify-write).
//
// Parameters:
//   encoding: the 32-bit RISC-V CSR instruction encoding to execute.
//             The rd field MUST be a0 (x10, register 10) for reads.
//             The rs1 field SHOULD be a1 (x11, register 11) for writes.
//   a1 holds the rs1 value for csrrs/csrrc/csrrw; the caller loads it before the macro.
//
// After this macro, a0 contains the CSR read result (if rd==a0 in encoding).
//
// Example: Read mstatus (CSR 0x300) via csrrs a0, mstatus, x0
//   Encoding: imm[31:20]=0x300, rs1[19:15]=0, funct3[14:12]=010, rd[11:7]=01010, opcode=1110011
//   Binary:   0011_0000_0000_00000_010_01010_1110011 = 0x30002573
//   Usage:    RVTEST_TSBI_CSR_ACCESS 0x30002573
//
// Example: Set mstatus.TVM via csrrs x0, mstatus, a1 (a1 has bit 20 set)
//   Encoding: imm=0x300, rs1=01011(a1), funct3=010, rd=00000(x0), opcode=1110011
//   Binary:   0011_0000_0000_01011_010_00000_1110011 = 0x3005A073
//   Usage:    li a1, (1 << 20)
//             RVTEST_TSBI_CSR_ACCESS 0x3005A073
.macro RVTEST_TSBI_CSR_ACCESS encoding
  .option push
  .option norvc                                  // ensure consistent code size
  li a0, \encoding                               // a0 = CSR instruction encoding (32-bit value)
  ecall                                          // trap to handler; handler executes the matching CSR instr from its table
  // a0 now contains the CSR read result (if rd==a0 in the encoding)
  .option pop
.endm

// CSR access by CSR number: csr is a 12-bit CSR number such as CSR_MIP from encoding.h,
// imm is a constant loaded into a1 with li before the call.
#define RVTEST_TSBI_CSR_SET(csr, imm)    li a1, imm; RVTEST_TSBI_CSR_ACCESS TSBI_CSR_SET(csr)
#define RVTEST_TSBI_CSR_CLEAR(csr, imm)  li a1, imm; RVTEST_TSBI_CSR_ACCESS TSBI_CSR_CLEAR(csr)
#define RVTEST_TSBI_CSR_WRITE(csr, imm)  li a1, imm; RVTEST_TSBI_CSR_ACCESS TSBI_CSR_WRITE(csr)
// write value in a1 to CSR
#define RVTEST_TSBI_CSR_WRITE_A1(csr)       RVTEST_TSBI_CSR_ACCESS TSBI_CSR_WRITE(csr)
// read value from CSR into a0
#define RVTEST_TSBI_CSR_READ(csr)        RVTEST_TSBI_CSR_ACCESS TSBI_CSR_READ(csr)

#ifdef H_SUPPORTED
// Switch to VS-mode via T-SBI. Requires hypervisor extension.
// After this macro, the processor is in VS-mode and a0 is undefined.
.macro RVTEST_TSBI_GOTO_VSMODE
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_GOTO_VSMODE                     // a0 = 4 (GOTO_VSMODE operation code)
  ecall                                          // trap to handler; handler sets MPP=S, MPV=1, mrets
  .option pop
.endm

// Switch to VU-mode via T-SBI. Requires hypervisor extension.
// After this macro, the processor is in VU-mode and a0 is undefined.
.macro RVTEST_TSBI_GOTO_VUMODE
  .option push
  .option norvc                                  // ensure consistent code size
  li   a0, TSBI_GOTO_VUMODE                     // a0 = 5 (GOTO_VUMODE operation code)
  ecall                                          // trap to handler; handler sets MPP=U, MPV=1, mrets
  .option pop
.endm
#endif // H_SUPPORTED

#endif // __ASSEMBLER__

#endif // TSBI_H
