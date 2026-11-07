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

  function new (int hart, int issue, riscvTraceData #(ILEN, XLEN, FLEN, VLEN)traceDataQ[(NHART-1):0][(RETIRE-1):0][$:`NUM_RVVI_DATA]);
    this.hart = hart;
    this.issue = issue;
    this.current = traceDataQ[hart][issue][`SAMPLE_CURRENT];
    this.prev = traceDataQ[hart][issue][`SAMPLE_PREV];
    this.trap = this.current.trap;
  endfunction

  function bit[`UDB_VLEN*4-1:0] get_vr_val_lmul4(vr_name_t r);
    case (r)
      v0 : return prev.v_wdata[3:0];   // { v3,  v2,  v1,  v0  };
      v4 : return prev.v_wdata[7:4];   // { v7,  v6,  v5,  v4  };
      v8 : return prev.v_wdata[11:8];  // { v11, v10, v9,  v8  };
      v12: return prev.v_wdata[15:12]; // { v15, v14, v13, v12 };
      v16: return prev.v_wdata[19:16]; // { v19, v18, v17, v16 };
      v20: return prev.v_wdata[23:20]; // { v23, v22, v21, v20 };
      v24: return prev.v_wdata[27:24]; // { v27, v26, v25, v24 };
      v28: return prev.v_wdata[31:28]; // { v31, v30, v29, v28 };
      default: begin
        $error("ERROR: SystemVerilog Functional Coverage: given (%s) as a register with LMUL 4", r.name());
        $fatal(1);
      end
    endcase
  endfunction

  function bit[`UDB_VLEN*8-1:0] get_vr_val_lmul8(vr_name_t r);
    case (r)
      v0 : return prev.v_wdata[7:0];   // { v7,  v6,  v5,  v4,  v3,  v2,  v1,  v0  };
      v8 : return prev.v_wdata[15:8];  // { v15, v14, v13, v12, v11, v10, v9,  v8  };
      v16: return prev.v_wdata[23:16]; // { v23, v22, v21, v20, v19, v18, v17, v16 };
      v24: return prev.v_wdata[31:24]; // { v31, v30, v29, v28, v27, v26, v25, v24 };
      default: begin
        $error("ERROR: SystemVerilog Functional Coverage: given (%s) as a register with LMUL 8", r.name());
        $fatal(1);
      end
    endcase
  endfunction

  function `SIGNED_XLEN_BITS get_pc();
    return current.pc_rdata;
  endfunction

  // compressed register
  function gpr_reduced_name_t get_gpr_c_reg (gpr_name_t r);
    if (r < x8 || r > x15) begin
      $error("ERROR: SystemVerilog Functional Coverage: get_gpr_c_reg(%0s) not found gpr", r.name());
      $fatal(1);
    end
    return gpr_reduced_name_t'(r - x8);
  endfunction

  function fpr_reduced_name_t get_fpr_c_reg (fpr_name_t r);
    if (r < f8 || r > f15) begin
      $error("ERROR: SystemVerilog Functional Coverage: get_fpr_c_reg(%0s) not found fpr", r.name());
      $fatal(1);
    end
    return fpr_reduced_name_t'(r - f8);
  endfunction

  // Assign operands to appropriate instruction fields in riscvTraceData (registers, immediates, CSRs, etc.)
  // Register arguments are register numbers from the instruction encoding.
  virtual function void add_rd(bit [4:0] r);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_rd = 1;
    c.rd = gpr_name_t'(r);
    c.rd_val = c.x_wdata[r];
    c.rd_val_pre = prev.x_wdata[r];
  endfunction

  virtual function void add_rd_pair(bit [4:0] r);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    add_rd(r);
    if ((r % 2 == 0) && (r < 31)) begin
      c.rd_upper_pair_val = c.x_wdata[r+1];
      c.rd_upper_pair_val_pre = prev.x_wdata[r+1];
    end else begin
      c.rd_upper_pair_val = '0;
      c.rd_upper_pair_val_pre = '0;
    end
  endfunction

  virtual function void add_rd_ra();
    add_rd(1);
  endfunction

  virtual function void add_rs1(bit [4:0] r);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_rs1 = 1;
    c.rs1 = gpr_name_t'(r);
    c.rs1_val = prev.x_wdata[r];
  endfunction

  virtual function void add_rs1_sp();
    add_rs1(2);
  endfunction

  virtual function void add_rs2(bit [4:0] r);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_rs2 = 1;
    c.rs2 = gpr_name_t'(r);
    c.rs2_val = prev.x_wdata[r];
  endfunction

  virtual function void add_rs3(bit [4:0] r);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_rs3 = 1;
    c.rs3 = gpr_name_t'(r);
    c.rs3_val = prev.x_wdata[r];
  endfunction

  virtual function void add_imm(int imm);
    current.imm = XLEN'(imm);
  endfunction

  virtual function void add_imm2(int imm);
    current.imm2 = XLEN'(imm);
  endfunction

  virtual function void add_imm3(int imm);
    current.imm3 = XLEN'(imm);
  endfunction

  virtual function void add_imm_addr(int imm);
    current.imm = XLEN'(imm);
  endfunction

  virtual function void add_csr();
    current.imm2 = XLEN'(current.insn[31:20]);
  endfunction

  virtual function void add_mem_offset(int imm);
    current.imm = XLEN'(imm);
  endfunction

  virtual function void add_mem_address();
    current.mem_addr = current.rs1_val + current.imm;
  endfunction

  virtual function void add_fd(bit [4:0] r, bit finx=0);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_fd = 1;
    c.fd = fpr_name_t'(r);
    if (finx) begin
      c.fd_val = FLEN'(c.x_wdata[r]);
      c.fd_val_pre = FLEN'(prev.x_wdata[r]);
    end else begin
      c.fd_val = c.f_wdata[r];
      c.fd_val_pre = prev.f_wdata[r];
    end
  endfunction

  virtual function void add_fs1(bit [4:0] r, bit finx=0);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_fs1 = 1;
    c.fs1 = fpr_name_t'(r);
    c.fs1_val = finx ? FLEN'(prev.x_wdata[r]) : prev.f_wdata[r];
  endfunction

  virtual function void add_fs2(bit [4:0] r, bit finx=0);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_fs2 = 1;
    c.fs2 = fpr_name_t'(r);
    c.fs2_val = finx ? FLEN'(prev.x_wdata[r]) : prev.f_wdata[r];
  endfunction

  virtual function void add_fs3(bit [4:0] r, bit finx=0);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_fs3 = 1;
    c.fs3 = fpr_name_t'(r);
    c.fs3_val = finx ? FLEN'(prev.x_wdata[r]) : prev.f_wdata[r];
  endfunction

  // Vector
  virtual function void add_vd(bit [4:0] r);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_vd = 1;
    c.vd = vr_name_t'(r);
    c.vd_val = c.v_wdata[r];
    c.vd_val_pre = prev.v_wdata[r];
  endfunction

  virtual function void add_vs1(bit [4:0] r);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_vs1 = 1;
    c.vs1 = vr_name_t'(r);
    c.vs1_val = prev.v_wdata[r];
  endfunction

  virtual function void add_vs2(bit [4:0] r);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_vs2 = 1;
    c.vs2 = vr_name_t'(r);
    c.vs2_val = prev.v_wdata[r];
  endfunction

  virtual function void add_vs3(bit [4:0] r);
    riscvTraceData #(ILEN, XLEN, FLEN, VLEN) c = current;
    c.has_vs3 = 1;
    c.vs3 = vr_name_t'(r);
    c.vs3_val = prev.v_wdata[r];
  endfunction

  virtual function void add_v0();
    current.has_v0 = 1;
    current.v0_val = prev.v_wdata[0];
  endfunction

  virtual function void add_vm(bit vm);
    current.vm = vm;
  endfunction

endclass
