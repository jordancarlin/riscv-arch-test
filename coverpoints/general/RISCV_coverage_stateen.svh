///////////////////////////////////////////
//
// RISC-V Architectural Functional Coverage Covergroups
//
// Functions shared by the Smstateen and Ssstateen covergroups. They sample the bit that mstateen0,
// hstateen0 and sstateen0 each hold for one piece of state.
// A bit in a CSR that does not exist reads as 1, so it does not restrict the state of the others.
//
// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
// SPDX-License-Identifier: Apache-2.0
//
////////////////////////////////////////////////////////////////////////////////////////////////

`ifndef RISCV_COVERAGE_STATEEN_SVH
`define RISCV_COVERAGE_STATEEN_SVH

// Bit f of mstateen0, hstateen0, or sstateen0. hstateen0_bit and sstateen0_bit return 1 when the CSR is not implemented.
function bit mstateen0_bit(int hart, int issue, int prev, csr_field_t f);
    return get_csr_field(hart, issue, prev, f)[0];
endfunction

function bit hstateen0_bit(int hart, int issue, int prev, csr_field_t f);
    `ifdef H_SUPPORTED
        return get_csr_field(hart, issue, prev, f)[0];
    `else
        return 1'b1;
    `endif
endfunction

function bit sstateen0_bit(int hart, int issue, int prev, csr_field_t f);
    `ifdef S_SUPPORTED
        return get_csr_field(hart, issue, prev, f)[0];
    `else
        return 1'b1;
    `endif
endfunction

// Bit 63 (SE<n>) of mstateen<n> and of hstateen<n>, where n is the low two bits of the address of the
// CSR being accessed. On RV32 the bit is bit 31 of mstateen<n>h and hstateen<n>h.
function bit mstateen_se_n(ins_t ins);
    `ifdef UDB_MXLEN_64
        return get_csr_val(ins.hart, ins.issue, `SAMPLE_BEFORE, CSR_MSTATEEN0 + 12'(ins.current.insn[21:20]))[63];
    `else
        return get_csr_val(ins.hart, ins.issue, `SAMPLE_BEFORE, CSR_MSTATEEN0H + 12'(ins.current.insn[21:20]))[31];
    `endif
endfunction

function bit hstateen_se_n(ins_t ins);
    `ifdef H_SUPPORTED
        `ifdef UDB_MXLEN_64
            return get_csr_val(ins.hart, ins.issue, `SAMPLE_BEFORE, CSR_HSTATEEN0 + 12'(ins.current.insn[21:20]))[63];
        `else
            return get_csr_val(ins.hart, ins.issue, `SAMPLE_BEFORE, CSR_HSTATEEN0H + 12'(ins.current.insn[21:20]))[31];
        `endif
    `else
        return 1'b1;
    `endif
endfunction

`endif
