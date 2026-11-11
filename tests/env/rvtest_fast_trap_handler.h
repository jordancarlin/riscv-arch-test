// rvtest_fast_trap_handler.h
// RISC-V Architecture Test Framework — Fast Illegal-Instruction Trap Handler
//
// Copyright (c) 2020-2023. RISC-V International. All rights reserved.
// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
// SPDX-License-Identifier: BSD-3-Clause

//==============================================================================
//==============================================================================
//
//  SECTION 13B: RVTEST_FAST_TRAP_HANDLER
//
//  Minimal-overhead illegal-instruction trap handler for test suites that
//  generate very large numbers of illegal-instruction traps (e.g. the
//  Ssstrict CSR and instruction-encoding sweeps, 150k+ traps). The standard
//  RVTEST_TRAP_HANDLER records several words per trap into the dedicated
//  trap-signature region, which those sweeps would overflow. This handler
//  records three words (xcause, xepc, xtval) per illegal-instruction trap in
//  the regular test signature (x2), advances xEPC past the trapping
//  instruction, and returns. In self-check mode, each word is compared before
//  x2 advances.
//
//  Enabled with:    #define RVTEST_USE_FAST_TRAP_HANDLER   (in the test file)
//  Instantiated by: RVTEST_CODE_END, alongside the standard trap handlers
//  Installed by:    RVTEST_TRAP_PROLOG — when RVTEST_USE_FAST_TRAP_HANDLER is
//                   defined, the M-mode prolog installs
//                   trap_handler_fastillegalinstr in mtvec and the S-mode
//                   prolog installs strap_handler_fastillegalinstr in stvec
//                   with the selected xTVEC mode, instead of the standard
//                   trampolines. In vectored mode, synchronous exceptions
//                   still enter at the handler BASE; these tests do not enable
//                   interrupts.
//
//  M-mode handler (mtvec): handles illegal-instruction traps taken in (or not
//  delegated from) M-mode. Any other cause is forwarded to Mtrampoline, the
//  standard framework handler, so T-SBI calls, fetch faults, and the
//  RVTEST_CODE_END ecall all still work.
//
//  S-mode handler (stvec, S_SUPPORTED only): handles illegal-instruction
//  traps delegated to S-mode via medeleg[2] (set by RVTEST_BOOT_TO_SMODE).
//  With H, it also handles the virtual-instruction traps from VS and VU
//  delegated to HS-mode via medeleg[22] (hedeleg = 0), and sret returns to
//  the virtual mode. Any other S-mode trap is forwarded to Strampoline.
//
//  Assumptions:
//    - The tests do not enable interrupts when the handler uses vectored mode.
//      Synchronous exceptions enter at the handler BASE in both supported
//      modes. If xTVEC does not accept the handler address, the prolog uses
//      the standard trampoline relocation fallback instead of the fast handler.
//    - The hart has read access to the trapping instruction (PMP/physical
//      memory allows instruction reads at the faulting PC) and address
//      translation is disabled, so the handler can read the instruction word
//      directly from xEPC without manipulating mstatus.MPRV.
//
//  Instruction-width detection reads bits[1:0] of the trapping instruction:
//    bits[1:0] == 0b11 (uncompressed) -> advance xEPC by 4
//    bits[1:0] != 0b11 (compressed)   -> advance xEPC by 2
//  lhu (not lw) is used because xEPC is only guaranteed 2-byte aligned; a
//  4-byte lw at a 2 mod 4 address would misalign on cores without hardware
//  misaligned-load support. bits[1:0] fit in the loaded 16 bits.
//  Without Zca, IALIGN=32 and xEPC[1] is always zero, so the handler always
//  advances by 4; advancing by 2 would return to the same instruction.
//
//  Register usage:
//    a0, a1 (x10, x11) — the ONLY scratch registers (CSR reads, instruction
//              word, advance amount). These are the framework's designated
//              clobber registers: the priv test generator never allocates them
//              to tests, so clobbering them here without save/restore is safe.
//==============================================================================
//==============================================================================

// RVTEST_FAST_TRAP_FAILURE(epc, cause, tval, status, check, description)
// Reports a fast-trap field mismatch. This path is cold, so it can use extra
// registers to snapshot the trapping CSRs for the normal trap diagnostics.
#define RVTEST_FAST_TRAP_FAILURE(_EPC, _CAUSE, _TVAL, _STATUS, _CHECK, _DESCRIPTION) \
        csrr x9, _EPC                                      ;\
        LA(x7, saved_xepc)                                 ;\
        SREG x9, 0(x7)                                     ;\
        csrr x9, _CAUSE                                    ;\
        SREG x9, 8(x7)                                     ;\
        csrr x9, _TVAL                                     ;\
        SREG x9, 16(x7)                                    ;\
        csrr x9, _STATUS                                   ;\
        SREG x9, 24(x7)                                    ;\
        mv x6, a0                                          ;\
        mv x4, a1                                          ;\
        jal x7, failedtest_trap_x7_x9                      ;\
        RVTEST_WORD_PTR _CHECK                             ;\
        RVTEST_WORD_PTR _DESCRIPTION                       ;\
        .word _EPC

.macro RVTEST_FAST_TRAP_HANDLER
.option push
.option norvc                                    // all handler code must be uncompressed

// ── Fast M-mode handler (mtvec) ─────────────────────────────────────────────
// Align to the core's WARL mtvec BASE boundary so the prolog's write of the
// handler address into mtvec survives.
.balign 64
#ifdef UDB_MTVEC_BASE_ALIGNMENT_VECTORED
.balign UDB_MTVEC_BASE_ALIGNMENT_VECTORED
#endif
#ifdef UDB_MTVEC_BASE_ALIGNMENT_DIRECT
.balign UDB_MTVEC_BASE_ALIGNMENT_DIRECT
#endif
// ENTRY PROTOCOL: the caller's a0/a1 MUST survive the forward path — the
// standard handler dispatches on the caller's a0 (a0==0 is the GOTO signal;
// T-SBI ops are a0 values). Clobbering a0 before `j Mtrampoline` breaks every
// ecall that arrives through this handler.
trap_handler_fastillegalinstr:
        csrrw a0, CSR_MSCRATCH, a0      // a0 = M save-area ptr; mscratch = caller's a0
        SREG a1, rvmodel_sv_off+2*REGWIDTH(a0)  // stash caller's a1 (rvmodel_sv slot 2 is free)
        csrr a1, mcause                 // read trap cause
        xori a1, a1, 2                  // a1 = 0 iff cause == 2 (illegal instruction)
        bnez a1, fast_Mothertrap        // not illegal — restore regs and use regular handler
        // Only traps taken in the test body may use the fast path. It signature-updates
        // through x2, which RVTEST_INIT_REGS does not load until the end of boot, so a
        // trap taken earlier — e.g. a boot-time CSR write that the reference model does
        // not implement — would write through an uninitialized register. Forward those to
        // the standard handler, which works off mscratch and records nothing in the
        // signature (so the reference model taking such a trap does not diverge from a DUT
        // that does not). Ask whether xEPC is in the test code segment rather than
        // inferring it from x2's contents. This compares unrelocated addresses, which is
        // already the fast path's assumption: RVTEST_SIGUPD_FAST_TRAP writes through x2 raw.
        SREG a2, rvmodel_sv_off+3*REGWIDTH(a0)  // stash caller's a2 (rvmodel_sv slot 3 is free)
        csrr a1, mepc
        LREG a2, code_bgn_off(a0)       // a2 = rvtest_code_begin
        sub  a1, a1, a2                 // a1 = mepc - code_begin (wraps if mepc is below it)
        LREG a2, code_seg_siz(a0)       // a2 = code segment size
        bgeu a1, a2, fast_Mboot_trap    // outside the test code — use the standard handler
#ifdef RVTEST_INVISIBLE_TRAP_HANDLER
        // Let the invisible handler try emulation before recording this trap.
        li   a1, 1
        SREG a1, rvmodel_sv_off(a0)     // Mark a declined M-mode trap for the fast path.
        j    fast_Mboot_trap            // Restore a2, which the range check clobbered.
#else
        // Match the three-instruction invisible-trap path. The code must be the same
        // length so the addresses are the same in the DUT and Sail signature builds.
        nop
        nop
        nop
#endif
        LREG a2, rvmodel_sv_off+3*REGWIDTH(a0)  // restore caller's a2
        LREG a1, rvmodel_sv_off+2*REGWIDTH(a0)  // restore caller's a1
        csrrw a0, CSR_MSCRATCH, a0      // restore mscratch = save ptr; a0 = caller's a0
fast_Millegalinstruction:
        RVTEST_SIGUPD_FAST_TRAP(x2, a1, a0, CSR_MCAUSE, 0, fast_Mcause_mismatch)
        RVTEST_SIGUPD_FAST_TRAP(x2, a1, a0, CSR_MEPC, SIG_STRIDE, fast_Mepc_mismatch)
        RVTEST_SIGUPD_FAST_TRAP(x2, a1, a0, CSR_MTVAL, 2*SIG_STRIDE, fast_Mtval_mismatch)
        addi x2, x2, 3*SIG_STRIDE
#ifdef ZCA_SUPPORTED
        // mepc advance using only a0 — reads bits[1:0] from *mepc using lhu
        // (lhu because mepc is only guaranteed 2-byte aligned).
        csrr a0, mepc
        lhu  a0, 0(a0)                  // load lower 16 bits from *mepc
        andi a0, a0, 3                  // a0 = bits[1:0]
        xori a0, a0, 3                  // a0 = 0 iff bits[1:0]==0b11 (uncompressed)
        beqz a0, fast_Muncompressed
fast_Mcompressed:
        csrr a0, mepc
        addi a0, a0, 2                  // 16-bit instruction: advance mepc by 2
        j    fast_Mdone
#endif
fast_Muncompressed:
        csrr a0, mepc
        addi a0, a0, 4                  // 32-bit instruction: advance mepc by 4
fast_Mdone:
        csrw mepc, a0
        mret

fast_Mboot_trap:
        LREG a2, rvmodel_sv_off+3*REGWIDTH(a0)  // restore caller's a2, then fall through
fast_Mothertrap:
        LREG a1, rvmodel_sv_off+2*REGWIDTH(a0)  // restore caller's a1
        csrrw a0, CSR_MSCRATCH, a0      // restore mscratch = save ptr; a0 = caller's a0
        j    Mtrampoline                // hand off all non-illegal-instruction traps

fast_Mcause_mismatch:
        RVTEST_FAST_TRAP_FAILURE(CSR_MEPC, CSR_MCAUSE, CSR_MTVAL, CSR_MSTATUS, fast_Mcause_mismatch, sv_Mcause_str)
fast_Mepc_mismatch:
        RVTEST_FAST_TRAP_FAILURE(CSR_MEPC, CSR_MCAUSE, CSR_MTVAL, CSR_MSTATUS, fast_Mepc_mismatch, sv_Mepc_str)
fast_Mtval_mismatch:
        RVTEST_FAST_TRAP_FAILURE(CSR_MEPC, CSR_MCAUSE, CSR_MTVAL, CSR_MSTATUS, fast_Mtval_mismatch, sv_Mtval_str)

#ifdef S_SUPPORTED
// ── Fast S-mode handler (stvec) ─────────────────────────────────────────────
// Align to the core's WARL stvec BASE boundary so the prolog's write of the
// handler address into stvec survives.
.balign 64
#ifdef UDB_STVEC_BASE_ALIGNMENT_VECTORED
.balign UDB_STVEC_BASE_ALIGNMENT_VECTORED
#endif
// Same entry protocol as the M handler: preserve the caller's a0/a1 across the
// forward path (the S standard handler dispatches delegated U-ecalls on the
// caller's a0), stashing a0 in sscratch and a1 in the S save-area's free
// rvmodel_sv slot 2 during the cause check.
strap_handler_fastillegalinstr:
        csrrw a0, CSR_SSCRATCH, a0      // a0 = S save-area ptr; sscratch = caller's a0
        SREG a1, rvmodel_sv_off+2*REGWIDTH(a0)  // stash caller's a1
        csrr a1, scause
        xori a1, a1, 2                  // a1 = 0 iff scause == 2 (illegal instruction)
#ifdef H_SUPPORTED
        beqz a1, fast_Shandled_cause
        xori a1, a1, 2 ^ 22             // a1 = 0 iff scause == 22 (virtual instruction, from VS or VU)
#endif
        bnez a1, fast_Sothertrap        // not illegal (or virtual) instruction — restore regs and use the S
                                        // framework handler (NOT fast_Mothertrap: the M trampoline's mscratch
                                        // access is itself illegal from S-mode and creates a trap loop)
fast_Shandled_cause:
        // Same test-body check as the M handler: only traps taken in the test code segment
        // may use the fast path, because it signature-updates through x2, which is not
        // loaded until the end of boot. See the M handler for the full rationale.
        SREG a2, rvmodel_sv_off+3*REGWIDTH(a0)  // stash caller's a2 (rvmodel_sv slot 3 is free)
        csrr a1, sepc
        LREG a2, code_bgn_off(a0)       // a2 = rvtest_code_begin
        sub  a1, a1, a2                 // a1 = sepc - code_begin (wraps if sepc is below it)
        LREG a2, code_seg_siz(a0)       // a2 = code segment size
        bgeu a1, a2, fast_Sboot_trap    // outside the test code — use the S framework handler
        LREG a2, rvmodel_sv_off+3*REGWIDTH(a0)  // restore caller's a2
        LREG a1, rvmodel_sv_off+2*REGWIDTH(a0)  // restore caller's a1
        csrrw a0, CSR_SSCRATCH, a0      // restore sscratch = save ptr; a0 = caller's a0
fast_Sillegalinstruction:
        RVTEST_SIGUPD_FAST_TRAP(x2, a1, a0, CSR_SCAUSE, 0, fast_Scause_mismatch)
        RVTEST_SIGUPD_FAST_TRAP(x2, a1, a0, CSR_SEPC, SIG_STRIDE, fast_Sepc_mismatch)
        RVTEST_SIGUPD_FAST_TRAP(x2, a1, a0, CSR_STVAL, 2*SIG_STRIDE, fast_Stval_mismatch)
        addi x2, x2, 3*SIG_STRIDE
#ifdef ZCA_SUPPORTED
        // Width detection: lhu at sepc (2-byte aligned -> no misalign trap).
        csrr a0, sepc
        lhu  a0, 0(a0)                  // load lower 16 bits of faulting instruction
        andi a0, a0, 3
        xori a0, a0, 3                  // a0 = 0 iff bits[1:0]==0b11 (uncompressed)
        beqz a0, fast_Suncompressed
fast_Scompressed:
        csrr a0, sepc
        addi a0, a0, 2                  // 16-bit instruction: advance sepc by 2
        j    fast_Sdone
#endif
fast_Suncompressed:
        csrr a0, sepc
        addi a0, a0, 4                  // 32-bit instruction: advance sepc by 4
fast_Sdone:
        csrw sepc, a0
        sret                            // MUST be sret: this handler runs in S-mode — an mret here
                                        // is itself an illegal instruction and re-enters this
                                        // handler forever

fast_Sboot_trap:
        LREG a2, rvmodel_sv_off+3*REGWIDTH(a0)  // restore caller's a2, then fall through
fast_Sothertrap:
        LREG a1, rvmodel_sv_off+2*REGWIDTH(a0)  // restore caller's a1
        csrrw a0, CSR_SSCRATCH, a0      // restore sscratch = save ptr; a0 = caller's a0
        j    Strampoline                // hand off all non-illegal-instruction traps

fast_Scause_mismatch:
        RVTEST_FAST_TRAP_FAILURE(CSR_SEPC, CSR_SCAUSE, CSR_STVAL, CSR_SSTATUS, fast_Scause_mismatch, sv_Scause_str)
fast_Sepc_mismatch:
        RVTEST_FAST_TRAP_FAILURE(CSR_SEPC, CSR_SCAUSE, CSR_STVAL, CSR_SSTATUS, fast_Sepc_mismatch, sv_Sepc_str)
fast_Stval_mismatch:
        RVTEST_FAST_TRAP_FAILURE(CSR_SEPC, CSR_SCAUSE, CSR_STVAL, CSR_SSTATUS, fast_Stval_mismatch, sv_Stval_str)
#endif // S_SUPPORTED

.option pop
.endm                                            // end of RVTEST_FAST_TRAP_HANDLER
