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
//
//

class RISCV_instruction
  #(
  parameter int ILEN   = 32,  // Instruction length in bits
  parameter int XLEN   = 32,  // GPR length in bits
  parameter int FLEN   = 32,  // FPR length in bits
  parameter int VLEN   = 512, // Vector register size in bits
  parameter int NHART  = 1,   // Number of harts reported
  parameter int RETIRE = 1    // Number of instructions that can retire during valid event
);
  int hart;
  int issue;
  bit trap;
  riscvTraceData #(ILEN, XLEN, FLEN, VLEN) current;
  riscvTraceData #(ILEN, XLEN, FLEN, VLEN) prev;

  riscvTraceData #(ILEN, XLEN, FLEN, VLEN)traceDataQ[(NHART-1):0][(RETIRE-1):0][$:`NUM_RVVI_DATA];

  function new (int hart, int issue, riscvTraceData #(ILEN, XLEN, FLEN, VLEN)traceDataQ[(NHART-1):0][(RETIRE-1):0][$:`NUM_RVVI_DATA]);
    this.hart = hart;
    this.issue = issue;
    this.traceDataQ = traceDataQ;
    this.current = traceDataQ[hart][issue][`SAMPLE_CURRENT];
    this.prev = traceDataQ[hart][issue][`SAMPLE_PREV];
    this.trap = this.current.trap;
  endfunction

  function void set_instruction(instruction_id_t id);
    this.current.inst_id = id;
  endfunction

  // Lookup register values by their encoded index.
  virtual function `SIGNED_XLEN_BITS get_gpr_val(int hart, int issue, bit [4:0] index, int prev);
    return traceDataQ[hart][issue][prev].x_wdata[index];
  endfunction

  function `SIGNED_FLEN_BITS get_fpr_val(int hart, int issue, bit [4:0] index, int prev);
    return traceDataQ[hart][issue][prev].f_wdata[index];
  endfunction

  // These helpers expand UDB_VLEN, which is only defined for vector configurations.
`ifdef ZVL32B_SUPPORTED
  function `SIGNED_VLEN_BITS get_vr_val(int hart, int issue, bit [4:0] index, int prev);
    return traceDataQ[hart][issue][prev].v_wdata[index];
  endfunction

  function bit[`UDB_VLEN*4-1:0] get_vr_val_lmul4(bit [4:0] index);
    case (index)
      0 : return prev.v_wdata[3:0];
      4 : return prev.v_wdata[7:4];
      8 : return prev.v_wdata[11:8];
      12: return prev.v_wdata[15:12];
      16: return prev.v_wdata[19:16];
      20: return prev.v_wdata[23:20];
      24: return prev.v_wdata[27:24];
      28: return prev.v_wdata[31:28];
      default: begin
        $error("ERROR: SystemVerilog Functional Coverage: register %0d is not aligned for LMUL 4", index);
        $fatal(1);
      end
    endcase
  endfunction

  function bit[`UDB_VLEN*4-1:0] get_vr_val_lmul8(bit [4:0] index);
    case (index)
      0 : return prev.v_wdata[7:0];
      8 : return prev.v_wdata[15:8];
      16: return prev.v_wdata[23:16];
      24: return prev.v_wdata[31:24];
      default: begin
        $error("ERROR: SystemVerilog Functional Coverage: register %0d is not aligned for LMUL 8", index);
        $fatal(1);
      end
    endcase
  endfunction
`endif // ZVL32B_SUPPORTED

  function `SIGNED_XLEN_BITS get_pc();
    return current.pc_rdata;
  endfunction

  function gpr_name_t get_gpr_reg(bit [4:0] index);
`ifdef COVER_E
    if (index >= 16) begin
      $error("ERROR: SystemVerilog Functional Coverage: GPR index %0d is not valid for E", index);
      $fatal(1);
    end
`endif
    return gpr_name_t'(index);
  endfunction

  function gpr_reduced_name_t get_gpr_c_reg(bit [4:0] index);
    if (index < 8 || index > 15) begin
      $error("ERROR: SystemVerilog Functional Coverage: GPR index %0d is not a compressed register", index);
      $fatal(1);
    end
    return gpr_reduced_name_t'(index - 8);
  endfunction

  function fpr_name_t get_fpr_reg(bit [4:0] index);
    return fpr_name_t'(index);
  endfunction

  function fpr_reduced_name_t get_fpr_c_reg(bit [4:0] index);
    if (index < 8 || index > 15) begin
      $error("ERROR: SystemVerilog Functional Coverage: FPR index %0d is not a compressed register", index);
      $fatal(1);
    end
    return fpr_reduced_name_t'(index - 8);
  endfunction

  function vr_name_t get_vr_reg(bit [4:0] index);
    return vr_name_t'(index);
  endfunction

  // Assign encoded operands to the instruction fields used by coverpoints.
  virtual function void add_rd(bit [4:0] idx);
    current.has_rd = 1;
    current.rd = idx;
    current.rd_val = current.x_wdata[idx];
    current.rd_val_pre = prev.x_wdata[idx];
  endfunction

  virtual function void add_rd_pair(bit [4:0] idx);
    add_rd(idx);
    if ((idx % 2 == 0) && (idx < 31)) begin
      current.rd_upper_pair_val = current.x_wdata[idx+1];
      current.rd_upper_pair_val_pre = prev.x_wdata[idx+1];
    end else begin
      current.rd_upper_pair_val = '0;
      current.rd_upper_pair_val_pre = '0;
    end
  endfunction

  virtual function void add_rd_ra();
    current.has_rd = 1;
    current.rd = 5'd1;
    current.rd_val = current.x_wdata[1];
    current.rd_val_pre = prev.x_wdata[1];
  endfunction

  virtual function void add_rs1(bit [4:0] idx);
    current.has_rs1 = 1;
    current.rs1 = idx;
    current.rs1_val = prev.x_wdata[idx];
  endfunction

  virtual function void add_rs1_sp();
    current.has_rs1 = 1;
    current.rs1 = 5'd2;
    current.rs1_val = prev.x_wdata[2];
  endfunction

  virtual function void add_rs2(bit [4:0] idx);
    current.has_rs2 = 1;
    current.rs2 = idx;
    current.rs2_val = prev.x_wdata[idx];
  endfunction

  virtual function void add_rs3(bit [4:0] idx);
    current.has_rs3 = 1;
    current.rs3 = idx;
    current.rs3_val = prev.x_wdata[idx];
  endfunction

  virtual function void add_imm(logic signed [(XLEN-1):0] value);
    current.imm = value;
  endfunction

  virtual function void add_imm_addr(logic signed [(XLEN-1):0] value);
    current.imm = value;
  endfunction

  virtual function void add_mem_offset(logic signed [(XLEN-1):0] value);
    current.imm = value;
  endfunction

  virtual function void add_mem_address();
    current.mem_addr = current.rs1_val + current.imm;
  endfunction

  virtual function void add_fd(bit [4:0] idx, int finx=0);
    current.has_fd = 1;
    if (finx) begin
      current.fd = idx;
      current.fd_val = current.x_wdata[idx];
      current.fd_val_pre = prev.x_wdata[idx];
    end else begin
      current.fd = idx;
      current.fd_val = current.f_wdata[idx];
      current.fd_val_pre = prev.f_wdata[idx];
    end
  endfunction

  virtual function void add_fs1(bit [4:0] idx, int finx=0);
    current.has_fs1 = 1;
    if (finx) begin
      current.fs1 = idx;
      current.fs1_val = prev.x_wdata[idx];
    end else begin
      current.fs1 = idx;
      current.fs1_val = prev.f_wdata[idx];
    end
  endfunction

  virtual function void add_fs2(bit [4:0] idx, int finx=0);
    current.has_fs2 = 1;
    if (finx) begin
      current.fs2 = idx;
      current.fs2_val = prev.x_wdata[idx];
    end else begin
      current.fs2 = idx;
      current.fs2_val = prev.f_wdata[idx];
    end
  endfunction

  virtual function void add_fs3(bit [4:0] idx, int finx=0);
    current.has_fs3 = 1;
    if (finx) begin
      current.fs3 = idx;
      current.fs3_val = prev.x_wdata[idx];
    end else begin
      current.fs3 = idx;
      current.fs3_val = prev.f_wdata[idx];
    end
  endfunction

  // Vector
  virtual function void add_vd();
    bit [4:0] idx = current.insn[11:7];
    current.has_vd = 1;
    current.vd = idx;
    current.vd_val = current.v_wdata[idx];
    current.vd_val_pre = prev.v_wdata[idx];
  endfunction

  virtual function void add_vs1();
    bit [4:0] idx = current.insn[19:15];
    current.has_vs1 = 1;
    current.vs1 = idx;
    current.vs1_val = prev.v_wdata[idx];
  endfunction

  virtual function void add_vs2();
    bit [4:0] idx = current.insn[24:20];
    current.has_vs2 = 1;
    current.vs2 = idx;
    current.vs2_val = prev.v_wdata[idx];
  endfunction

  virtual function void add_vs3();
    bit [4:0] idx = current.insn[11:7];
    current.has_vs3 = 1;
    current.vs3 = idx;
    current.vs3_val = prev.v_wdata[idx];
  endfunction

  virtual function void add_v0();
    current.v0_val = prev.v_wdata[0];
  endfunction

  virtual function void add_vm();
    current.vm = current.insn[25];
  endfunction

endclass
