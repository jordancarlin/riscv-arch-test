//
// Copyright (c) 2023 Imperas Software Ltd., www.imperas.com
// Modified February 2024, jcarlin@hmc.edu
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied.
//
// See the License for the specific language governing permissions and
// limitations under the License.

// Print coverage information if not in quiet mode
`ifndef COVER_QUIET
  `define cover_info(s)     $display(s);
`else
  `define cover_info(s)
`endif

// Constants
`define SAMPLE_AFTER 0
`define SAMPLE_BEFORE 1
`define SAMPLE_CURRENT 0
`define SAMPLE_PREV 1
`define NUM_RVVI_DATA 5

// -----------------------------------------------------------------------------
// Physical Memory Protection (PMP) Specific Macros
// -----------------------------------------------------------------------------

/*          To align with the starting address of a PMP region used in testing, the address is hardcoded here.
            Since the Sail data region begins at 0x80004000, we simply add the size of the test strings,
            which has been fixed at 4 KB. The executable blob each test places there begins at 80005000
            with a pad of return instructions, which is there to make sure we fetch a proper instruction
            from the background region; the region under test follows that pad.
 */
`ifdef UDB_MXLEN_64
  `define PMP_PAD_START      64'h80005000 // pad ahead of the region under test
  `define PMP_SPECIAL_REGION_START 64'h80005000 // Zicbo + Zaamo tests
  `define PMP_MASK_BASE      64'h4000
`else
  `define PMP_PAD_START      32'h80005000 // pad ahead of the region under test
  `define PMP_SPECIAL_REGION_START 32'h80005000 // Zicbo + Zaamo tests
  `define PMP_MASK_BASE      32'h4000
`endif

// Calculate region size g in bytes.
`define g_tor       (2 ** (`UDB_PMP_GRANULARITY))
`define g_napot     ((`UDB_PMP_GRANULARITY > 2) ? (2 ** (`UDB_PMP_GRANULARITY)) : (2 ** (`UDB_PMP_GRANULARITY + 1)))

// Region bases. Each test pads its blob by one grain so that the region under test starts on a
// grain-aligned boundary and the pad stays in the background region (the pad is emitted by
// PMP_TOR_REGION_BYTES and PMP_NAPOT_REGION_PAD_WORDS in tests/env/rvtest_pmp_macros.h). A TOR or
// NA4 region is padded by one g_tor and a NAPOT region by one g_napot, so both bases track the
// grain: at grain 2 they are 0x80005004 and 0x80005008, at grain 6 both are 0x80005040. A NAPOT
// base must be g_napot-aligned in particular, because `(base>>2)|trailing1s` would otherwise decode
// to a region that swallows the pad -> NAPOT tests hang / mis-cover.
`define PMP_REGION_START       (`PMP_PAD_START + `g_tor)   // generic (TOR/NA4) tests
`define PMP_NAPOT_REGION_START (`PMP_PAD_START + `g_napot)

// Calculate k = G - 1 trailing ones in NAPOT encoding.
`define k  ((`UDB_PMP_GRANULARITY > 3) ? (`UDB_PMP_GRANULARITY - 3) : 0)

// Address encodings

// TOR or NA4 region: directly right-shifted
`define NON_STANDARD_REGION  (`PMP_REGION_START >> 2)              // TOR/NA4 format: yyyyy...
`define SPECIAL_NON_STANDARD_REGION  (`PMP_SPECIAL_REGION_START >> 2)              // TOR/NA4 format: yyyyy...

// NAPOT region: add trailing 1s per `k` to form mask
`define STANDARD_REGION      ((`PMP_NAPOT_REGION_START >> 2) | ((2 ** `k) - 1)) // NAPOT format: yyyyy...0111
`define SPECIAL_STANDARD_REGION      ((`PMP_SPECIAL_REGION_START >> 2) | ((2 ** `k) - 1)) // NAPOT format: yyyyy...0111

// Code-size-invariant region matching. The region-under-test is placed by each test at a `.p2align 12`
// boundary inside .data, which the linker puts at ALIGN(0x4000) AFTER the variable-size .text.rvtest.
// So its ABSOLUTE address drifts with test code size (small tests -> 0x80005xxx, large tests such as
// cfg_XWR's 400-entry signature -> 0x80009xxx), but it always sits at the same offset within a
// 0x4000-aligned block -> its LOW address bits are invariant. Match pmp_hit and the region-address
// coverpoints on those low bits (byte address & 0x3FFF, or pmpaddr & 0xFFF) so coverage fires no matter
// where .data landed. pmpaddr values in these tests are sparse (region / 0 / all-ones), so the low-bit
// match has no false positives. Assumes the linker's .data ALIGN of 0x4000 (which the DUT/ref share).
`define PMP_ADDR_LOWMASK      (`PMP_MASK_BASE - 1)        // low 14 bits of a byte address
`define PMP_PMPADDR_LOWMASK   ((`PMP_MASK_BASE - 1) >> 2) // low 12 bits of a pmpaddr

// UDB_MXLEN_64 -> [53:0] & UDB_MXLEN_32 -> [31:0]
`define EFFECTIVE_PMPADDR (`ifdef UDB_MXLEN_64 53 `else 31 `endif)
`define READ_ZERO_MASK   ~((1<<(`UDB_PMP_GRANULARITY - 2))-1)


// -----------------------------------------------------------------------------
//                                 FLEN Macros
// -----------------------------------------------------------------------------

// XLEN/FLEN as usable numbers
`ifdef Q_COVERAGE
  `define FLEN 128
`elsif D_COVERAGE
  `define FLEN 64
`else
  `define FLEN 32
`endif

///////////////////////////////////////////////////
// VECTOR-RELATED MACROS
///////////////////////////////////////////////////

// MAXINDEXEEW — maximum supported index element width for indexed load/store
// Config should define one of: MAXINDEXEEW64, MAXINDEXEEW32, MAXINDEXEEW16, MAXINDEXEEW8
`ifdef MAXINDEXEEW64
  `define MAXINDEXEEW 64
  `define MAXINDEXEEW_GE8
  `define MAXINDEXEEW_GE16
  `define MAXINDEXEEW_GE32
  `define MAXINDEXEEW_GE64
`elsif MAXINDEXEEW32
  `define MAXINDEXEEW 32
  `define MAXINDEXEEW_GE8
  `define MAXINDEXEEW_GE16
  `define MAXINDEXEEW_GE32
`elsif MAXINDEXEEW16
  `define MAXINDEXEEW 16
  `define MAXINDEXEEW_GE8
  `define MAXINDEXEEW_GE16
`elsif MAXINDEXEEW8
  `define MAXINDEXEEW 8
  `define MAXINDEXEEW_GE8
`endif

// Set register type length
`define XLEN_BITS         bit        [`UDB_MXLEN-1:0]
`define SIGNED_XLEN_BITS  bit signed [`UDB_MXLEN-1:0]
`define FLEN_BITS         bit        [`FLEN-1:0]
`define SIGNED_FLEN_BITS  bit signed [`FLEN-1:0]
`define VLEN_BITS         bit        [`UDB_VLEN-1:0]
`define SIGNED_VLEN_BITS  bit signed [`UDB_VLEN-1:0]

// Register data structures for GPRs and FPRs
typedef enum {
  x0,
  x1,
  x2,
  x3,
  x4,
  x5,
  x6,
  x7,
  x8,
  x9,
  x10,
  x11,
  x12,
  x13,
  x14,
  x15
`ifndef E_SUPPORTED
  ,
  x16,
  x17,
  x18,
  x19,
  x20,
  x21,
  x22,
  x23,
  x24,
  x25,
  x26,
  x27,
  x28,
  x29,
  x30,
  x31
`endif
} gpr_name_t;

typedef enum {
  c_x8,
  c_x9,
  c_x10,
  c_x11,
  c_x12,
  c_x13,
  c_x14,
  c_x15
} gpr_reduced_name_t;

typedef enum {
  f0,
  f1,
  f2,
  f3,
  f4,
  f5,
  f6,
  f7,
  f8,
  f9,
  f10,
  f11,
  f12,
  f13,
  f14,
  f15,
  f16,
  f17,
  f18,
  f19,
  f20,
  f21,
  f22,
  f23,
  f24,
  f25,
  f26,
  f27,
  f28,
  f29,
  f30,
  f31
} fpr_name_t;

typedef enum {
  v0,
  v1,
  v2,
  v3,
  v4,
  v5,
  v6,
  v7,
  v8,
  v9,
  v10,
  v11,
  v12,
  v13,
  v14,
  v15,
  v16,
  v17,
  v18,
  v19,
  v20,
  v21,
  v22,
  v23,
  v24,
  v25,
  v26,
  v27,
  v28,
  v29,
  v30,
  v31
} vr_name_t;

typedef enum {
  c_f8,
  c_f9,
  c_f10,
  c_f11,
  c_f12,
  c_f13,
  c_f14,
  c_f15
} fpr_reduced_name_t;




// Floating point rounding modes
typedef enum {
  dyn,
  rdn,
  rmm,
  rne,
  rtz,
  rup
} frm_name_t;

// Map the rm field encoding to its rounding mode. Reserved encodings map to dyn.
function frm_name_t get_frm(bit [2:0] rm);
  case (rm)
    3'b000: return rne;
    3'b001: return rtz;
    3'b010: return rdn;
    3'b011: return rup;
    3'b100: return rmm;
    default: return dyn;
  endcase
endfunction

// Immediate fields of the instruction encoding
function int imm_i(bit [31:0] i);      return int'($signed(i[31:20])); endfunction
function int imm_s(bit [31:0] i);      return int'($signed({i[31:25], i[11:7]})); endfunction
function int imm_b(bit [31:0] i);      return int'($signed({i[31], i[7], i[30:25], i[11:8], 1'b0})); endfunction
function int imm_u(bit [31:0] i);      return int'($signed(i[31:12])); endfunction
function int imm_j(bit [31:0] i);      return int'($signed({i[31], i[19:12], i[20], i[30:21], 1'b0})); endfunction
function int imm_v(bit [31:0] i);      return int'($signed(i[19:15])); endfunction
function int imm_bi(bit [31:0] i);     return (i[24:20] == 0) ? -1 : int'(i[24:20]); endfunction
function int imm_shamt(bit [31:0] i);  return int'(i[25:20]); endfunction
function int imm_shamtw(bit [31:0] i); return int'(i[24:20]); endfunction
function int imm_zimm5(bit [31:0] i);  return int'(i[19:15]); endfunction
function int imm_zimm6(bit [31:0] i);  return int'({i[26], i[19:15]}); endfunction
function int imm_ci(bit [31:0] i);     return int'($signed({i[12], i[6:2]})); endfunction
function int imm_ci_u(bit [31:0] i);   return int'({i[12], i[6:2]}); endfunction
function int imm_ci16sp(bit [31:0] i); return int'($signed({i[12], i[4:3], i[5], i[2], i[6], 4'b0})); endfunction
function int imm_ciw(bit [31:0] i);    return int'({i[10:7], i[12:11], i[5], i[6], 2'b0}); endfunction
function int imm_clw(bit [31:0] i);    return int'({i[5], i[12:10], i[6], 2'b0}); endfunction
function int imm_cld(bit [31:0] i);    return int'({i[6:5], i[12:10], 3'b0}); endfunction
function int imm_clh(bit [31:0] i);    return int'({i[5], 1'b0}); endfunction
function int imm_clb(bit [31:0] i);    return int'({i[5], i[6]}); endfunction
function int imm_clwsp(bit [31:0] i);  return int'({i[3:2], i[12], i[6:4], 2'b0}); endfunction
function int imm_cldsp(bit [31:0] i);  return int'({i[4:2], i[12], i[6:5], 3'b0}); endfunction
function int imm_cswsp(bit [31:0] i);  return int'({i[8:7], i[12:9], 2'b0}); endfunction
function int imm_csdsp(bit [31:0] i);  return int'({i[9:7], i[12:10], 3'b0}); endfunction
function int imm_cb(bit [31:0] i);     return int'($signed({i[12], i[6:5], i[2], i[11:10], i[4:3], 1'b0})); endfunction
function int imm_cj(bit [31:0] i);     return int'($signed({i[12], i[8], i[10:9], i[6], i[7], i[2], i[11], i[5:3], 1'b0})); endfunction
