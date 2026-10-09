//
// Copyright (c) 2023 Imperas Software Ltd., www.imperas.com
// Modified 3 Sept 2024 David_Harris@hmc.edu
//   support more EXTENSIONS
//   change capitalization of sample function
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
//
//

class RISCV_coverage
#(
  parameter int ILEN   = 32,  // Instruction length in bits
  parameter int XLEN   = 32,  // GPR length in bits
  parameter int FLEN   = 32,  // FPR length in bits
  parameter int VLEN   = 512, // Vector register size in bits
  parameter int NHART  = 1,   // Number of harts reported
  parameter int RETIRE = 1    // Number of instructions that can retire during valid event
);

  typedef RISCV_instruction #(ILEN, XLEN, FLEN, VLEN, NHART, RETIRE) ins_t;

  // Additional functions for coverage collection
  `include "coverage/RISCV_coverage_rvvi.svh"
  `include "coverage/RISCV_coverage_csr.svh"
  `ifdef ZVL32B_SUPPORTED
    `include "coverage/RISCV_coverage_vector.svh"
  `endif
  `include "coverage/RISCV_coverage_exceptions.svh"
  `include "coverage/RISCV_coverage_hazards.svh"
  `include "coverage/RISCV_coverage_config.svh"

  virtual rvviTrace #(ILEN, XLEN, FLEN, VLEN, NHART, RETIRE) rvvi;

  // Enables the coverage groups listed in +cover_groups=<group>[,<group>...]
  function void select_coverage_groups();
    string groups, name;
    int start = 0;
    if (!$value$plusargs("cover_groups=%s", groups)) $fatal(1, "+cover_groups=<group>[,<group>...] is required");
    for (int i = 0; i <= groups.len(); i++) begin
      if (i == groups.len() || groups[i] == ",") begin
        name = groups.substr(start, i - 1);
        if (!fcov_select_group(name)) $fatal(1, "Unknown coverage group '%s'", name);
        start = i + 1;
      end
    end
  endfunction

  function new(virtual rvviTrace #(ILEN, XLEN, FLEN, VLEN, NHART, RETIRE) rvvi);
    this.rvvi = rvvi;
    select_coverage_groups();

    // Print header information
    `cover_info("\n//  riscv_arch_test    ");
    `cover_info("//  adapted from riscvISACOV Version 20231026.0");
    `cover_info("//  SPDX-License-Identifier: Apache-2.0\n//");
    `cover_info("//  Configuration:");
    `ifdef UDB_MXLEN_32
        `cover_info("//    XLEN: 32");
    `endif
    `ifdef UDB_MXLEN_64
        `cover_info("//    XLEN: 64");
    `endif
    `cover_info("//    EXTENSIONS:");
    `include "coverage/RISCV_coverage_base_init.svh"
  endfunction

  // Returns just the instruction name from the disassembly
  function string get_inst_name(bit trap, int hart, int issue, string disass);
    string insbin, ins_str, ops;
    int num = $sscanf (disass, "%s %s %s", insbin, ins_str, ops);
    return ins_str;
  endfunction

  // Runs all of the sample functions created per extension from templates
  function void sample_extensions(int hart, int issue);
    `include "coverage/RISCV_instruction_sample.svh"
    `include "coverage/RISCV_coverage_base_sample.svh"
  endfunction
endclass
