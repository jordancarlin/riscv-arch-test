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

// xcause exception codes (Interrupt = 0), named as in the privileged spec's mcause table
localparam int INSTRUCTION_ADDRESS_MISALIGNED        = 0;
localparam int INSTRUCTION_ACCESS_FAULT              = 1;
localparam int ILLEGAL_INSTRUCTION                   = 2;
localparam int BREAKPOINT                            = 3;
localparam int LOAD_ADDRESS_MISALIGNED               = 4;
localparam int LOAD_ACCESS_FAULT                     = 5;
localparam int STORE_AMO_ADDRESS_MISALIGNED          = 6;
localparam int STORE_AMO_ACCESS_FAULT                = 7;
localparam int ENVIRONMENT_CALL_FROM_U_MODE          = 8;
localparam int ENVIRONMENT_CALL_FROM_S_MODE          = 9;
localparam int ENVIRONMENT_CALL_FROM_VS_MODE         = 10;
localparam int ENVIRONMENT_CALL_FROM_M_MODE          = 11;
localparam int INSTRUCTION_PAGE_FAULT                = 12;
localparam int LOAD_PAGE_FAULT                       = 13;
localparam int STORE_AMO_PAGE_FAULT                  = 15;
localparam int DOUBLE_TRAP                           = 16;
localparam int SOFTWARE_CHECK                        = 18;
localparam int HARDWARE_ERROR                        = 19;
localparam int INSTRUCTION_GUEST_PAGE_FAULT          = 20;
localparam int LOAD_GUEST_PAGE_FAULT                 = 21;
localparam int VIRTUAL_INSTRUCTION                   = 22;
localparam int STORE_AMO_GUEST_PAGE_FAULT            = 23;

// xcause interrupt codes (Interrupt = 1)
localparam int SUPERVISOR_SOFTWARE_INTERRUPT         = 1;
localparam int VIRTUAL_SUPERVISOR_SOFTWARE_INTERRUPT = 2;
localparam int MACHINE_SOFTWARE_INTERRUPT            = 3;
localparam int SUPERVISOR_TIMER_INTERRUPT            = 5;
localparam int VIRTUAL_SUPERVISOR_TIMER_INTERRUPT    = 6;
localparam int MACHINE_TIMER_INTERRUPT               = 7;
localparam int SUPERVISOR_EXTERNAL_INTERRUPT         = 9;
localparam int VIRTUAL_SUPERVISOR_EXTERNAL_INTERRUPT = 10;
localparam int MACHINE_EXTERNAL_INTERRUPT            = 11;
localparam int SUPERVISOR_GUEST_EXTERNAL_INTERRUPT   = 12;
localparam int COUNTER_OVERFLOW_INTERRUPT            = 13;

// Whole value of the CSR at addr
function `XLEN_BITS get_csr_val(int hart, int issue, int prev, bit [11:0] addr);
  return traceDataQ[hart][issue][prev].csr[addr];
endfunction

// CSR field: CSR address, LSB position, and width in bits.
// On RV32, a field in bits 63:32 of a CSR is in the high-half CSR (for example, MENVCFG_STCE is in menvcfgh).
typedef struct packed {
  bit [11:0] addr;
  bit [5:0]  lsb;
  bit [6:0]  width;
} csr_field_t;

localparam csr_field_t DCSR_CAUSE = '{CSR_DCSR, 6, 3};
localparam csr_field_t DCSR_EBREAKM = '{CSR_DCSR, 15, 1};
localparam csr_field_t DCSR_EBREAKS = '{CSR_DCSR, 13, 1};
localparam csr_field_t DCSR_EBREAKU = '{CSR_DCSR, 12, 1};
localparam csr_field_t DCSR_MPRVEN = '{CSR_DCSR, 4, 1};
localparam csr_field_t DCSR_NMIP = '{CSR_DCSR, 3, 1};
localparam csr_field_t DCSR_PRV = '{CSR_DCSR, 0, 2};
localparam csr_field_t DCSR_STEP = '{CSR_DCSR, 2, 1};
localparam csr_field_t DCSR_STEPIE = '{CSR_DCSR, 11, 1};
localparam csr_field_t DCSR_STOPCOUNT = '{CSR_DCSR, 10, 1};
localparam csr_field_t DCSR_STOPTIME = '{CSR_DCSR, 9, 1};
localparam csr_field_t DCSR_XDEBUGVER = '{CSR_DCSR, 28, 4};
localparam csr_field_t FCSR_FFLAGS = '{CSR_FCSR, 0, 5};
localparam csr_field_t FCSR_FRM = '{CSR_FCSR, 5, 3};
localparam csr_field_t FFLAGS_FFLAGS = '{CSR_FFLAGS, 0, 5};
localparam csr_field_t FRM_FRM = '{CSR_FRM, 0, 3};
localparam csr_field_t HCOUNTEREN_CY = '{CSR_HCOUNTEREN, 0, 1};
localparam csr_field_t HCOUNTEREN_ENABLE = '{CSR_HCOUNTEREN, 3, 29};
localparam csr_field_t HCOUNTEREN_IR = '{CSR_HCOUNTEREN, 2, 1};
localparam csr_field_t HCOUNTEREN_TM = '{CSR_HCOUNTEREN, 1, 1};
localparam csr_field_t HEDELEG_DELEG = '{CSR_HEDELEG, 0, 32};
localparam csr_field_t HENVCFG_FIOM = '{CSR_HENVCFG, 0, 1};
localparam csr_field_t HENVCFG_LPE = '{CSR_HENVCFG, 2, 1};
localparam csr_field_t HENVCFG_SSE = '{CSR_HENVCFG, 3, 1};
localparam csr_field_t HENVCFG_CBIE = '{CSR_HENVCFG, 4, 2};
localparam csr_field_t HENVCFG_CBCFE = '{CSR_HENVCFG, 6, 1};
localparam csr_field_t HENVCFG_CBZE = '{CSR_HENVCFG, 7, 1};
`ifdef UDB_MXLEN_64
localparam csr_field_t HENVCFG_PMM = '{CSR_HENVCFG, 32, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HENVCFG_DTE = '{CSR_HENVCFGH, 27, 1};
`else
localparam csr_field_t HENVCFG_DTE = '{CSR_HENVCFG, 59, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HENVCFG_ADUE = '{CSR_HENVCFGH, 29, 1};
`else
localparam csr_field_t HENVCFG_ADUE = '{CSR_HENVCFG, 61, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HENVCFG_PBMTE = '{CSR_HENVCFGH, 30, 1};
`else
localparam csr_field_t HENVCFG_PBMTE = '{CSR_HENVCFG, 62, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HENVCFG_STCE = '{CSR_HENVCFGH, 31, 1};
`else
localparam csr_field_t HENVCFG_STCE = '{CSR_HENVCFG, 63, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HGATP_VMID = '{CSR_HGATP, 22, 7};
`else
localparam csr_field_t HGATP_VMID = '{CSR_HGATP, 44, 14};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HGATP_MODE = '{CSR_HGATP, 31, 1};
`else
localparam csr_field_t HGATP_MODE = '{CSR_HGATP, 60, 4};
`endif
localparam csr_field_t HGEIE_ENABLE = '{CSR_HGEIE, 1, 31};
localparam csr_field_t HGEIP_PENDING = '{CSR_HGEIP, 1, 31};
localparam csr_field_t HIDELEG_MEIP = '{CSR_HIDELEG, 11, 1};
localparam csr_field_t HIDELEG_MSIP = '{CSR_HIDELEG, 3, 1};
localparam csr_field_t HIDELEG_MTIP = '{CSR_HIDELEG, 7, 1};
localparam csr_field_t HIDELEG_SEIP = '{CSR_HIDELEG, 9, 1};
localparam csr_field_t HIDELEG_SGEIP = '{CSR_HIDELEG, 12, 1};
localparam csr_field_t HIDELEG_SSIP = '{CSR_HIDELEG, 1, 1};
localparam csr_field_t HIDELEG_STIP = '{CSR_HIDELEG, 5, 1};
localparam csr_field_t HIDELEG_VGEIP = '{CSR_HIDELEG, 10, 1};
localparam csr_field_t HIDELEG_VSSIP = '{CSR_HIDELEG, 2, 1};
localparam csr_field_t HIDELEG_VSTIP = '{CSR_HIDELEG, 6, 1};
localparam csr_field_t HIE_SGEIE = '{CSR_HIE, 12, 1};
localparam csr_field_t HIE_VSEIE = '{CSR_HIE, 10, 1};
localparam csr_field_t HIE_VSSIE = '{CSR_HIE, 2, 1};
localparam csr_field_t HIE_VSTIE = '{CSR_HIE, 6, 1};
localparam csr_field_t HIP_SGEIP = '{CSR_HIP, 12, 1};
localparam csr_field_t HIP_VSEIP = '{CSR_HIP, 10, 1};
localparam csr_field_t HIP_VSSIP = '{CSR_HIP, 2, 1};
localparam csr_field_t HIP_VSTIP = '{CSR_HIP, 6, 1};
localparam csr_field_t HSTATEEN0_C = '{CSR_HSTATEEN0, 0, 1};
localparam csr_field_t HSTATEEN0_FCSR = '{CSR_HSTATEEN0, 1, 1};
localparam csr_field_t HSTATEEN0_JVT = '{CSR_HSTATEEN0, 2, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t HSTATEEN0_CTR = '{CSR_HSTATEEN0H, 22, 1};
`else
localparam csr_field_t HSTATEEN0_CTR = '{CSR_HSTATEEN0, 54, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HSTATEEN0_CONTEXT = '{CSR_HSTATEEN0H, 25, 1};
`else
localparam csr_field_t HSTATEEN0_CONTEXT = '{CSR_HSTATEEN0, 57, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HSTATEEN0_IMSIC = '{CSR_HSTATEEN0H, 26, 1};
`else
localparam csr_field_t HSTATEEN0_IMSIC = '{CSR_HSTATEEN0, 58, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HSTATEEN0_AIA = '{CSR_HSTATEEN0H, 27, 1};
`else
localparam csr_field_t HSTATEEN0_AIA = '{CSR_HSTATEEN0, 59, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HSTATEEN0_CSRIND = '{CSR_HSTATEEN0H, 28, 1};
`else
localparam csr_field_t HSTATEEN0_CSRIND = '{CSR_HSTATEEN0, 60, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HSTATEEN0_ENVCFG = '{CSR_HSTATEEN0H, 30, 1};
`else
localparam csr_field_t HSTATEEN0_ENVCFG = '{CSR_HSTATEEN0, 62, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t HSTATEEN0_SE0 = '{CSR_HSTATEEN0H, 31, 1};
`else
localparam csr_field_t HSTATEEN0_SE0 = '{CSR_HSTATEEN0, 63, 1};
`endif
localparam csr_field_t HSTATUS_GVA = '{CSR_HSTATUS, 6, 1};
localparam csr_field_t HSTATUS_HU = '{CSR_HSTATUS, 9, 1};
`ifdef UDB_MXLEN_64
localparam csr_field_t HSTATUS_HUPMM = '{CSR_HSTATUS, 48, 2};
`endif
localparam csr_field_t HSTATUS_SPV = '{CSR_HSTATUS, 7, 1};
localparam csr_field_t HSTATUS_SPVP = '{CSR_HSTATUS, 8, 1};
localparam csr_field_t HSTATUS_VSBE = '{CSR_HSTATUS, 5, 1};
`ifdef UDB_MXLEN_64
localparam csr_field_t HSTATUS_VSXL = '{CSR_HSTATUS, 32, 2};
`endif
localparam csr_field_t HSTATUS_VTSR = '{CSR_HSTATUS, 22, 1};
localparam csr_field_t HSTATUS_VTVM = '{CSR_HSTATUS, 20, 1};
localparam csr_field_t HSTATUS_VTW = '{CSR_HSTATUS, 21, 1};
localparam csr_field_t HVIP_VSEIP = '{CSR_HVIP, 10, 1};
localparam csr_field_t HVIP_VSSIP = '{CSR_HVIP, 2, 1};
localparam csr_field_t HVIP_VSTIP = '{CSR_HVIP, 6, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t JVT_BASE = '{CSR_JVT, 6, 26};
`else
localparam csr_field_t JVT_BASE = '{CSR_JVT, 6, 58};
`endif
localparam csr_field_t JVT_MODE = '{CSR_JVT, 0, 6};
`ifdef UDB_MXLEN_32
localparam csr_field_t MCAUSE_CODE = '{CSR_MCAUSE, 0, 31};
`else
localparam csr_field_t MCAUSE_CODE = '{CSR_MCAUSE, 0, 63};
`endif
localparam csr_field_t MCOUNTEREN_CY = '{CSR_MCOUNTEREN, 0, 1};
localparam csr_field_t MCOUNTEREN_ENABLE = '{CSR_MCOUNTEREN, 3, 29};
localparam csr_field_t MCOUNTEREN_IR = '{CSR_MCOUNTEREN, 2, 1};
localparam csr_field_t MCOUNTEREN_TM = '{CSR_MCOUNTEREN, 1, 1};
localparam csr_field_t MCOUNTINHIBIT_CY = '{CSR_MCOUNTINHIBIT, 0, 1};
localparam csr_field_t MCOUNTINHIBIT_INHIBIT = '{CSR_MCOUNTINHIBIT, 3, 29};
localparam csr_field_t MCOUNTINHIBIT_IR = '{CSR_MCOUNTINHIBIT, 2, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t MCYCLECFG_MINH = '{CSR_MCYCLECFGH, 30, 1};
`else
localparam csr_field_t MCYCLECFG_MINH = '{CSR_MCYCLECFG, 62, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MCYCLECFG_SINH = '{CSR_MCYCLECFGH, 29, 1};
`else
localparam csr_field_t MCYCLECFG_SINH = '{CSR_MCYCLECFG, 61, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MCYCLECFG_UINH = '{CSR_MCYCLECFGH, 28, 1};
`else
localparam csr_field_t MCYCLECFG_UINH = '{CSR_MCYCLECFG, 60, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MCYCLECFG_VSINH = '{CSR_MCYCLECFGH, 27, 1};
`else
localparam csr_field_t MCYCLECFG_VSINH = '{CSR_MCYCLECFG, 59, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MCYCLECFG_VUINH = '{CSR_MCYCLECFGH, 26, 1};
`else
localparam csr_field_t MCYCLECFG_VUINH = '{CSR_MCYCLECFG, 58, 1};
`endif
localparam csr_field_t MEDELEG_DELEG = '{CSR_MEDELEG, 0, 32};
localparam csr_field_t MENVCFG_FIOM = '{CSR_MENVCFG, 0, 1};
localparam csr_field_t MENVCFG_LPE = '{CSR_MENVCFG, 2, 1};
localparam csr_field_t MENVCFG_SSE = '{CSR_MENVCFG, 3, 1};
localparam csr_field_t MENVCFG_CBIE = '{CSR_MENVCFG, 4, 2};
localparam csr_field_t MENVCFG_CBCFE = '{CSR_MENVCFG, 6, 1};
localparam csr_field_t MENVCFG_CBZE = '{CSR_MENVCFG, 7, 1};
`ifdef UDB_MXLEN_64
localparam csr_field_t MENVCFG_PMM = '{CSR_MENVCFG, 32, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MENVCFG_DTE = '{CSR_MENVCFGH, 27, 1};
`else
localparam csr_field_t MENVCFG_DTE = '{CSR_MENVCFG, 59, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MENVCFG_CDE = '{CSR_MENVCFGH, 28, 1};
`else
localparam csr_field_t MENVCFG_CDE = '{CSR_MENVCFG, 60, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MENVCFG_ADUE = '{CSR_MENVCFGH, 29, 1};
`else
localparam csr_field_t MENVCFG_ADUE = '{CSR_MENVCFG, 61, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t MENVCFG_PBMTE = '{CSR_MENVCFG, 62, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MENVCFG_STCE = '{CSR_MENVCFGH, 31, 1};
`else
localparam csr_field_t MENVCFG_STCE = '{CSR_MENVCFG, 63, 1};
`endif
localparam csr_field_t MIDELEG_LCOFIP = '{CSR_MIDELEG, 13, 1};
localparam csr_field_t MIDELEG_MEIP = '{CSR_MIDELEG, 11, 1};
localparam csr_field_t MIDELEG_MSIP = '{CSR_MIDELEG, 3, 1};
localparam csr_field_t MIDELEG_MTIP = '{CSR_MIDELEG, 7, 1};
localparam csr_field_t MIDELEG_SEIP = '{CSR_MIDELEG, 9, 1};
localparam csr_field_t MIDELEG_SGEIP = '{CSR_MIDELEG, 12, 1};
localparam csr_field_t MIDELEG_SSIP = '{CSR_MIDELEG, 1, 1};
localparam csr_field_t MIDELEG_STIP = '{CSR_MIDELEG, 5, 1};
localparam csr_field_t MIDELEG_VGEIP = '{CSR_MIDELEG, 10, 1};
localparam csr_field_t MIDELEG_VSSIP = '{CSR_MIDELEG, 2, 1};
localparam csr_field_t MIDELEG_VSTIP = '{CSR_MIDELEG, 6, 1};
localparam csr_field_t MIE_LCOFIE = '{CSR_MIE, 13, 1};
localparam csr_field_t MIE_MEIE = '{CSR_MIE, 11, 1};
localparam csr_field_t MIE_MSIE = '{CSR_MIE, 3, 1};
localparam csr_field_t MIE_MTIE = '{CSR_MIE, 7, 1};
localparam csr_field_t MIE_SEIE = '{CSR_MIE, 9, 1};
localparam csr_field_t MIE_SGEIE = '{CSR_MIE, 12, 1};
localparam csr_field_t MIE_SSIE = '{CSR_MIE, 1, 1};
localparam csr_field_t MIE_STIE = '{CSR_MIE, 5, 1};
localparam csr_field_t MIE_VGEIE = '{CSR_MIE, 10, 1};
localparam csr_field_t MIE_VSSIE = '{CSR_MIE, 2, 1};
localparam csr_field_t MIE_VSTIE = '{CSR_MIE, 6, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t MINSTRETCFG_MINH = '{CSR_MINSTRETCFGH, 30, 1};
`else
localparam csr_field_t MINSTRETCFG_MINH = '{CSR_MINSTRETCFG, 62, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MINSTRETCFG_SINH = '{CSR_MINSTRETCFGH, 29, 1};
`else
localparam csr_field_t MINSTRETCFG_SINH = '{CSR_MINSTRETCFG, 61, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MINSTRETCFG_UINH = '{CSR_MINSTRETCFGH, 28, 1};
`else
localparam csr_field_t MINSTRETCFG_UINH = '{CSR_MINSTRETCFG, 60, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MINSTRETCFG_VSINH = '{CSR_MINSTRETCFGH, 27, 1};
`else
localparam csr_field_t MINSTRETCFG_VSINH = '{CSR_MINSTRETCFG, 59, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MINSTRETCFG_VUINH = '{CSR_MINSTRETCFGH, 26, 1};
`else
localparam csr_field_t MINSTRETCFG_VUINH = '{CSR_MINSTRETCFG, 58, 1};
`endif
localparam csr_field_t MIP_LCOFIP = '{CSR_MIP, 13, 1};
localparam csr_field_t MIP_MEIP = '{CSR_MIP, 11, 1};
localparam csr_field_t MIP_MSIP = '{CSR_MIP, 3, 1};
localparam csr_field_t MIP_MTIP = '{CSR_MIP, 7, 1};
localparam csr_field_t MIP_SEIP = '{CSR_MIP, 9, 1};
localparam csr_field_t MIP_SGEIP = '{CSR_MIP, 12, 1};
localparam csr_field_t MIP_SSIP = '{CSR_MIP, 1, 1};
localparam csr_field_t MIP_STIP = '{CSR_MIP, 5, 1};
localparam csr_field_t MIP_VGEIP = '{CSR_MIP, 10, 1};
localparam csr_field_t MIP_VSSIP = '{CSR_MIP, 2, 1};
localparam csr_field_t MIP_VSTIP = '{CSR_MIP, 6, 1};
localparam csr_field_t MISA_EXTS = '{CSR_MISA, 0, 26};
`ifdef UDB_MXLEN_32
localparam csr_field_t MISA_MXL = '{CSR_MISA, 30, 2};
`else
localparam csr_field_t MISA_MXL = '{CSR_MISA, 62, 2};
`endif
localparam csr_field_t MSECCFG_MML = '{CSR_MSECCFG, 0, 1};
localparam csr_field_t MSECCFG_MMWP = '{CSR_MSECCFG, 1, 1};
localparam csr_field_t MSECCFG_RLB = '{CSR_MSECCFG, 2, 1};
localparam csr_field_t MSECCFG_USEED = '{CSR_MSECCFG, 8, 1};
localparam csr_field_t MSECCFG_SSEED = '{CSR_MSECCFG, 9, 1};
localparam csr_field_t MSECCFG_MLPE = '{CSR_MSECCFG, 10, 1};
`ifdef UDB_MXLEN_64
localparam csr_field_t MSECCFG_PMM = '{CSR_MSECCFG, 32, 2};
`endif
localparam csr_field_t MSTATUS_FS = '{CSR_MSTATUS, 13, 2};
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATUS_GVA = '{CSR_MSTATUSH, 6, 1};
`else
localparam csr_field_t MSTATUS_GVA = '{CSR_MSTATUS, 38, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATUS_MBE = '{CSR_MSTATUSH, 5, 1};
`else
localparam csr_field_t MSTATUS_MBE = '{CSR_MSTATUS, 37, 1};
`endif
localparam csr_field_t MSTATUS_MIE = '{CSR_MSTATUS, 3, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATUS_MPELP = '{CSR_MSTATUSH, 9, 1};
`else
localparam csr_field_t MSTATUS_MPELP = '{CSR_MSTATUS, 41, 1};
`endif
localparam csr_field_t MSTATUS_MPIE = '{CSR_MSTATUS, 7, 1};
localparam csr_field_t MSTATUS_MPP = '{CSR_MSTATUS, 11, 2};
localparam csr_field_t MSTATUS_MPRV = '{CSR_MSTATUS, 17, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATUS_MPV = '{CSR_MSTATUSH, 7, 1};
`else
localparam csr_field_t MSTATUS_MPV = '{CSR_MSTATUS, 39, 1};
`endif
localparam csr_field_t MSTATUS_MXR = '{CSR_MSTATUS, 19, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATUS_SBE = '{CSR_MSTATUSH, 4, 1};
`else
localparam csr_field_t MSTATUS_SBE = '{CSR_MSTATUS, 36, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATUS_SD = '{CSR_MSTATUS, 31, 1};
`else
localparam csr_field_t MSTATUS_SD = '{CSR_MSTATUS, 63, 1};
`endif
localparam csr_field_t MSTATUS_SIE = '{CSR_MSTATUS, 1, 1};
localparam csr_field_t MSTATUS_SPELP = '{CSR_MSTATUS, 23, 1};
localparam csr_field_t MSTATUS_SPIE = '{CSR_MSTATUS, 5, 1};
localparam csr_field_t MSTATUS_SPP = '{CSR_MSTATUS, 8, 1};
localparam csr_field_t MSTATUS_SUM = '{CSR_MSTATUS, 18, 1};
`ifdef UDB_MXLEN_64
localparam csr_field_t MSTATUS_SXL = '{CSR_MSTATUS, 34, 2};
`endif
localparam csr_field_t MSTATUS_TSR = '{CSR_MSTATUS, 22, 1};
localparam csr_field_t MSTATUS_TVM = '{CSR_MSTATUS, 20, 1};
localparam csr_field_t MSTATUS_TW = '{CSR_MSTATUS, 21, 1};
localparam csr_field_t MSTATUS_UBE = '{CSR_MSTATUS, 6, 1};
`ifdef UDB_MXLEN_64
localparam csr_field_t MSTATUS_UXL = '{CSR_MSTATUS, 32, 2};
`endif
localparam csr_field_t MSTATUS_VS = '{CSR_MSTATUS, 9, 2};
localparam csr_field_t MSTATUS_XS = '{CSR_MSTATUS, 15, 2};
localparam csr_field_t MTVEC_MODE = '{CSR_MTVEC, 0, 2};
localparam csr_field_t PMPCFG0_PMP0CFG_A = '{CSR_PMPCFG0, 3, 2};
localparam csr_field_t PMPCFG0_PMP0CFG_L = '{CSR_PMPCFG0, 7, 1};
localparam csr_field_t PMPCFG0_PMP0CFG_XWR = '{CSR_PMPCFG0, 0, 3};
localparam csr_field_t PMPCFG0_PMP1CFG_A = '{CSR_PMPCFG0, 11, 2};
localparam csr_field_t PMPCFG0_PMP1CFG_L = '{CSR_PMPCFG0, 15, 1};
localparam csr_field_t PMPCFG0_PMP1CFG_XWR = '{CSR_PMPCFG0, 8, 3};
localparam csr_field_t PMPCFG0_PMP2CFG_A = '{CSR_PMPCFG0, 19, 2};
localparam csr_field_t PMPCFG0_PMP2CFG_L = '{CSR_PMPCFG0, 23, 1};
localparam csr_field_t PMPCFG0_PMP2CFG_XWR = '{CSR_PMPCFG0, 16, 3};
localparam csr_field_t PMPCFG0_PMP3CFG_A = '{CSR_PMPCFG0, 27, 2};
localparam csr_field_t PMPCFG0_PMP3CFG_L = '{CSR_PMPCFG0, 31, 1};
localparam csr_field_t PMPCFG0_PMP3CFG_XWR = '{CSR_PMPCFG0, 24, 3};
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP4CFG_A = '{CSR_PMPCFG0, 35, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP4CFG_L = '{CSR_PMPCFG0, 39, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP4CFG_XWR = '{CSR_PMPCFG0, 32, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP5CFG_A = '{CSR_PMPCFG0, 43, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP5CFG_L = '{CSR_PMPCFG0, 47, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP5CFG_XWR = '{CSR_PMPCFG0, 40, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP6CFG_A = '{CSR_PMPCFG0, 51, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP6CFG_L = '{CSR_PMPCFG0, 55, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP6CFG_XWR = '{CSR_PMPCFG0, 48, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP7CFG_A = '{CSR_PMPCFG0, 59, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP7CFG_L = '{CSR_PMPCFG0, 63, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG0_PMP7CFG_XWR = '{CSR_PMPCFG0, 56, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP4CFG_A = '{CSR_PMPCFG1, 3, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP4CFG_L = '{CSR_PMPCFG1, 7, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP4CFG_XWR = '{CSR_PMPCFG1, 0, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP5CFG_A = '{CSR_PMPCFG1, 11, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP5CFG_L = '{CSR_PMPCFG1, 15, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP5CFG_XWR = '{CSR_PMPCFG1, 8, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP6CFG_A = '{CSR_PMPCFG1, 19, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP6CFG_L = '{CSR_PMPCFG1, 23, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP6CFG_XWR = '{CSR_PMPCFG1, 16, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP7CFG_A = '{CSR_PMPCFG1, 27, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP7CFG_L = '{CSR_PMPCFG1, 31, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG1_PMP7CFG_XWR = '{CSR_PMPCFG1, 24, 3};
`endif
localparam csr_field_t PMPCFG2_PMP10CFG_A = '{CSR_PMPCFG2, 19, 2};
localparam csr_field_t PMPCFG2_PMP10CFG_L = '{CSR_PMPCFG2, 23, 1};
localparam csr_field_t PMPCFG2_PMP10CFG_XWR = '{CSR_PMPCFG2, 16, 3};
localparam csr_field_t PMPCFG2_PMP11CFG_A = '{CSR_PMPCFG2, 27, 2};
localparam csr_field_t PMPCFG2_PMP11CFG_L = '{CSR_PMPCFG2, 31, 1};
localparam csr_field_t PMPCFG2_PMP11CFG_XWR = '{CSR_PMPCFG2, 24, 3};
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP12CFG_A = '{CSR_PMPCFG2, 35, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP12CFG_L = '{CSR_PMPCFG2, 39, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP12CFG_XWR = '{CSR_PMPCFG2, 32, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP13CFG_A = '{CSR_PMPCFG2, 43, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP13CFG_L = '{CSR_PMPCFG2, 47, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP13CFG_XWR = '{CSR_PMPCFG2, 40, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP14CFG_A = '{CSR_PMPCFG2, 51, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP14CFG_L = '{CSR_PMPCFG2, 55, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP14CFG_XWR = '{CSR_PMPCFG2, 48, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP15CFG_A = '{CSR_PMPCFG2, 59, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP15CFG_L = '{CSR_PMPCFG2, 63, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG2_PMP15CFG_XWR = '{CSR_PMPCFG2, 56, 3};
`endif
localparam csr_field_t PMPCFG2_PMP8CFG_A = '{CSR_PMPCFG2, 3, 2};
localparam csr_field_t PMPCFG2_PMP8CFG_L = '{CSR_PMPCFG2, 7, 1};
localparam csr_field_t PMPCFG2_PMP8CFG_XWR = '{CSR_PMPCFG2, 0, 3};
localparam csr_field_t PMPCFG2_PMP9CFG_A = '{CSR_PMPCFG2, 11, 2};
localparam csr_field_t PMPCFG2_PMP9CFG_L = '{CSR_PMPCFG2, 15, 1};
localparam csr_field_t PMPCFG2_PMP9CFG_XWR = '{CSR_PMPCFG2, 8, 3};
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP12CFG_A = '{CSR_PMPCFG3, 3, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP12CFG_L = '{CSR_PMPCFG3, 7, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP12CFG_XWR = '{CSR_PMPCFG3, 0, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP13CFG_A = '{CSR_PMPCFG3, 11, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP13CFG_L = '{CSR_PMPCFG3, 15, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP13CFG_XWR = '{CSR_PMPCFG3, 8, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP14CFG_A = '{CSR_PMPCFG3, 19, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP14CFG_L = '{CSR_PMPCFG3, 23, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP14CFG_XWR = '{CSR_PMPCFG3, 16, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP15CFG_A = '{CSR_PMPCFG3, 27, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP15CFG_L = '{CSR_PMPCFG3, 31, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG3_PMP15CFG_XWR = '{CSR_PMPCFG3, 24, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t SATP_ASID = '{CSR_SATP, 22, 9};
`else
localparam csr_field_t SATP_ASID = '{CSR_SATP, 44, 16};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t SATP_MODE = '{CSR_SATP, 31, 1};
`else
localparam csr_field_t SATP_MODE = '{CSR_SATP, 60, 4};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t SATP_PPN = '{CSR_SATP, 0, 22};
`else
localparam csr_field_t SATP_PPN = '{CSR_SATP, 0, 44};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t SCAUSE_CODE = '{CSR_SCAUSE, 0, 31};
`else
localparam csr_field_t SCAUSE_CODE = '{CSR_SCAUSE, 0, 63};
`endif
localparam csr_field_t SCOUNTEREN_CY = '{CSR_SCOUNTEREN, 0, 1};
localparam csr_field_t SCOUNTEREN_ENABLE = '{CSR_SCOUNTEREN, 3, 29};
localparam csr_field_t SCOUNTEREN_IR = '{CSR_SCOUNTEREN, 2, 1};
localparam csr_field_t SCOUNTEREN_TM = '{CSR_SCOUNTEREN, 1, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t SEED_OPST = '{CSR_SEED, 30, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t SEED_ENTROPY = '{CSR_SEED, 0, 16};
`endif
localparam csr_field_t SENVCFG_FIOM = '{CSR_SENVCFG, 0, 1};
localparam csr_field_t SENVCFG_LPE = '{CSR_SENVCFG, 2, 1};
localparam csr_field_t SENVCFG_SSE = '{CSR_SENVCFG, 3, 1};
localparam csr_field_t SENVCFG_CBIE = '{CSR_SENVCFG, 4, 2};
localparam csr_field_t SENVCFG_CBCFE = '{CSR_SENVCFG, 6, 1};
localparam csr_field_t SENVCFG_CBZE = '{CSR_SENVCFG, 7, 1};
`ifdef UDB_MXLEN_64
localparam csr_field_t SENVCFG_PMM = '{CSR_SENVCFG, 32, 2};
`endif
localparam csr_field_t SIE_LCOFIE = '{CSR_SIE, 13, 1};
localparam csr_field_t SIE_SEIE = '{CSR_SIE, 9, 1};
localparam csr_field_t SIE_SSIE = '{CSR_SIE, 1, 1};
localparam csr_field_t SIE_STIE = '{CSR_SIE, 5, 1};
localparam csr_field_t SIP_LCOFIP = '{CSR_SIP, 13, 1};
localparam csr_field_t SIP_SEIP = '{CSR_SIP, 9, 1};
localparam csr_field_t SIP_SSIP = '{CSR_SIP, 1, 1};
localparam csr_field_t SIP_STIP = '{CSR_SIP, 5, 1};
localparam csr_field_t SSTATUS_FS = '{CSR_SSTATUS, 13, 2};
localparam csr_field_t SSTATUS_MXR = '{CSR_SSTATUS, 19, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t SSTATUS_SD = '{CSR_SSTATUS, 31, 1};
`else
localparam csr_field_t SSTATUS_SD = '{CSR_SSTATUS, 63, 1};
`endif
localparam csr_field_t SSTATUS_SIE = '{CSR_SSTATUS, 1, 1};
localparam csr_field_t SSTATUS_SPELP = '{CSR_SSTATUS, 23, 1};
localparam csr_field_t SSTATUS_SPIE = '{CSR_SSTATUS, 5, 1};
localparam csr_field_t SSTATUS_SPP = '{CSR_SSTATUS, 8, 1};
localparam csr_field_t SSTATUS_SUM = '{CSR_SSTATUS, 18, 1};
localparam csr_field_t SSTATUS_UBE = '{CSR_SSTATUS, 6, 1};
`ifdef UDB_MXLEN_64
localparam csr_field_t SSTATUS_UXL = '{CSR_SSTATUS, 32, 2};
`endif
localparam csr_field_t SSTATUS_VS = '{CSR_SSTATUS, 9, 2};
localparam csr_field_t SSTATUS_XS = '{CSR_SSTATUS, 15, 2};
localparam csr_field_t STVEC_MODE = '{CSR_STVEC, 0, 2};
localparam csr_field_t TCONTROL_MPTE = '{CSR_TCONTROL, 7, 1};
localparam csr_field_t TCONTROL_MTE = '{CSR_TCONTROL, 3, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t TDATA1_TYPE = '{CSR_TDATA1, 28, 4};
`else
localparam csr_field_t TDATA1_TYPE = '{CSR_TDATA1, 60, 4};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t TDATA1_DMODE = '{CSR_TDATA1, 27, 1};
`else
localparam csr_field_t TDATA1_DMODE = '{CSR_TDATA1, 59, 1};
`endif
localparam csr_field_t TDATA1_UNCERTAIN = '{CSR_TDATA1, 26, 1};
localparam csr_field_t TDATA1_HIT1 = '{CSR_TDATA1, 25, 1};
localparam csr_field_t TDATA1_VS = '{CSR_TDATA1, 24, 1};
localparam csr_field_t TDATA1_VU = '{CSR_TDATA1, 23, 1};
localparam csr_field_t TDATA1_HIT0 = '{CSR_TDATA1, 22, 1};
localparam csr_field_t TDATA1_SELECT = '{CSR_TDATA1, 21, 1};
localparam csr_field_t TDATA1_SIZE = '{CSR_TDATA1, 16, 3};
localparam csr_field_t TDATA1_ACTION = '{CSR_TDATA1, 12, 4};
localparam csr_field_t TDATA1_CHAIN = '{CSR_TDATA1, 11, 1};
localparam csr_field_t TDATA1_MATCH = '{CSR_TDATA1, 7, 4};
localparam csr_field_t TDATA1_M = '{CSR_TDATA1, 6, 1};
localparam csr_field_t TDATA1_UNCERTAINEN = '{CSR_TDATA1, 5, 1};
localparam csr_field_t TDATA1_S = '{CSR_TDATA1, 4, 1};
localparam csr_field_t TDATA1_U = '{CSR_TDATA1, 3, 1};
localparam csr_field_t TDATA1_EXECUTE = '{CSR_TDATA1, 2, 1};
localparam csr_field_t TDATA1_STORE = '{CSR_TDATA1, 1, 1};
localparam csr_field_t TDATA1_LOAD = '{CSR_TDATA1, 0, 1};
localparam csr_field_t TINFO_INFO = '{CSR_TINFO, 0, 16};
localparam csr_field_t VCSR_VXSAT = '{CSR_VCSR, 0, 1};
localparam csr_field_t VCSR_VXRM = '{CSR_VCSR, 1, 2};
localparam csr_field_t VL_VL = '{CSR_VL, 0, 16};
localparam csr_field_t VLENB_VLENB = '{CSR_VLENB, 0, 13};
`ifdef UDB_MXLEN_32
localparam csr_field_t VSATP_ASID = '{CSR_VSATP, 22, 9};
`else
localparam csr_field_t VSATP_ASID = '{CSR_VSATP, 44, 16};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t VSATP_MODE = '{CSR_VSATP, 31, 1};
`else
localparam csr_field_t VSATP_MODE = '{CSR_VSATP, 60, 4};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t VSCAUSE_CODE = '{CSR_VSCAUSE, 0, 31};
`else
localparam csr_field_t VSCAUSE_CODE = '{CSR_VSCAUSE, 0, 63};
`endif
localparam csr_field_t VSIE_SEIE = '{CSR_VSIE, 9, 1};
localparam csr_field_t VSIE_SSIE = '{CSR_VSIE, 1, 1};
localparam csr_field_t VSIE_STIE = '{CSR_VSIE, 5, 1};
localparam csr_field_t VSIP_SEIP = '{CSR_VSIP, 9, 1};
localparam csr_field_t VSIP_SSIP = '{CSR_VSIP, 1, 1};
localparam csr_field_t VSIP_STIP = '{CSR_VSIP, 5, 1};
localparam csr_field_t VSSTATUS_FS = '{CSR_VSSTATUS, 13, 2};
localparam csr_field_t VSSTATUS_MXR = '{CSR_VSSTATUS, 19, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t VSSTATUS_SD = '{CSR_VSSTATUS, 31, 1};
`else
localparam csr_field_t VSSTATUS_SD = '{CSR_VSSTATUS, 63, 1};
`endif
localparam csr_field_t VSSTATUS_SIE = '{CSR_VSSTATUS, 1, 1};
localparam csr_field_t VSSTATUS_SPELP = '{CSR_VSSTATUS, 23, 1};
localparam csr_field_t VSSTATUS_SPIE = '{CSR_VSSTATUS, 5, 1};
localparam csr_field_t VSSTATUS_SPP = '{CSR_VSSTATUS, 8, 1};
localparam csr_field_t VSSTATUS_SUM = '{CSR_VSSTATUS, 18, 1};
localparam csr_field_t VSSTATUS_UBE = '{CSR_VSSTATUS, 6, 1};
`ifdef UDB_MXLEN_64
localparam csr_field_t VSSTATUS_UXL = '{CSR_VSSTATUS, 32, 2};
`endif
localparam csr_field_t VSSTATUS_VS = '{CSR_VSSTATUS, 9, 2};
localparam csr_field_t VSSTATUS_XS = '{CSR_VSSTATUS, 15, 2};
localparam csr_field_t VSTART_VSTART = '{CSR_VSTART, 0, 16};
localparam csr_field_t VSTVEC_MODE = '{CSR_VSTVEC, 0, 2};
`ifdef UDB_MXLEN_32
localparam csr_field_t VTYPE_VILL = '{CSR_VTYPE, 31, 1};
`else
localparam csr_field_t VTYPE_VILL = '{CSR_VTYPE, 63, 1};
`endif
localparam csr_field_t VTYPE_VLMUL = '{CSR_VTYPE, 0, 3};
localparam csr_field_t VTYPE_VMA = '{CSR_VTYPE, 7, 1};
localparam csr_field_t VTYPE_VSEW = '{CSR_VTYPE, 3, 3};
localparam csr_field_t VTYPE_VTA = '{CSR_VTYPE, 6, 1};
localparam csr_field_t VXRM_VXRM = '{CSR_VXRM, 0, 2};
localparam csr_field_t VXSAT_VXSAT = '{CSR_VXSAT, 0, 1};
localparam csr_field_t SSTATEEN0_FCSR = '{CSR_SSTATEEN0, 1, 1};
localparam csr_field_t SSTATEEN0_JVT = '{CSR_SSTATEEN0, 2, 1};
localparam csr_field_t MSTATEEN0_C = '{CSR_MSTATEEN0, 0, 1};
localparam csr_field_t MSTATEEN0_FCSR = '{CSR_MSTATEEN0, 1, 1};
localparam csr_field_t MSTATEEN0_JVT = '{CSR_MSTATEEN0, 2, 1};
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATEEN0_CTR = '{CSR_MSTATEEN0H, 22, 1};
`else
localparam csr_field_t MSTATEEN0_CTR = '{CSR_MSTATEEN0, 54, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATEEN0_SRMCFG = '{CSR_MSTATEEN0H, 23, 1};
`else
localparam csr_field_t MSTATEEN0_SRMCFG = '{CSR_MSTATEEN0, 55, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATEEN0_P1P13 = '{CSR_MSTATEEN0H, 24, 1};
`else
localparam csr_field_t MSTATEEN0_P1P13 = '{CSR_MSTATEEN0, 56, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATEEN0_CONTEXT = '{CSR_MSTATEEN0H, 25, 1};
`else
localparam csr_field_t MSTATEEN0_CONTEXT = '{CSR_MSTATEEN0, 57, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATEEN0_IMSIC = '{CSR_MSTATEEN0H, 26, 1};
`else
localparam csr_field_t MSTATEEN0_IMSIC = '{CSR_MSTATEEN0, 58, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATEEN0_AIA = '{CSR_MSTATEEN0H, 27, 1};
`else
localparam csr_field_t MSTATEEN0_AIA = '{CSR_MSTATEEN0, 59, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATEEN0_CSRIND = '{CSR_MSTATEEN0H, 28, 1};
`else
localparam csr_field_t MSTATEEN0_CSRIND = '{CSR_MSTATEEN0, 60, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATEEN0_ENVCFG = '{CSR_MSTATEEN0H, 30, 1};
`else
localparam csr_field_t MSTATEEN0_ENVCFG = '{CSR_MSTATEEN0, 62, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t MSTATEEN0_SE0 = '{CSR_MSTATEEN0H, 31, 1};
`else
localparam csr_field_t MSTATEEN0_SE0 = '{CSR_MSTATEEN0, 63, 1};
`endif
localparam csr_field_t PMPCFG4_PMP16CFG_A = '{CSR_PMPCFG4, 3, 2};
localparam csr_field_t PMPCFG4_PMP16CFG_L = '{CSR_PMPCFG4, 7, 1};
localparam csr_field_t PMPCFG4_PMP16CFG_XWR = '{CSR_PMPCFG4, 0, 3};
localparam csr_field_t PMPCFG4_PMP17CFG_A = '{CSR_PMPCFG4, 11, 2};
localparam csr_field_t PMPCFG4_PMP17CFG_L = '{CSR_PMPCFG4, 15, 1};
localparam csr_field_t PMPCFG4_PMP17CFG_XWR = '{CSR_PMPCFG4, 8, 3};
localparam csr_field_t PMPCFG4_PMP18CFG_A = '{CSR_PMPCFG4, 19, 2};
localparam csr_field_t PMPCFG4_PMP18CFG_L = '{CSR_PMPCFG4, 23, 1};
localparam csr_field_t PMPCFG4_PMP18CFG_XWR = '{CSR_PMPCFG4, 16, 3};
localparam csr_field_t PMPCFG4_PMP19CFG_A = '{CSR_PMPCFG4, 27, 2};
localparam csr_field_t PMPCFG4_PMP19CFG_L = '{CSR_PMPCFG4, 31, 1};
localparam csr_field_t PMPCFG4_PMP19CFG_XWR = '{CSR_PMPCFG4, 24, 3};
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP20CFG_A = '{CSR_PMPCFG4, 35, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP20CFG_L = '{CSR_PMPCFG4, 39, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP20CFG_XWR = '{CSR_PMPCFG4, 32, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP21CFG_A = '{CSR_PMPCFG4, 43, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP21CFG_L = '{CSR_PMPCFG4, 47, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP21CFG_XWR = '{CSR_PMPCFG4, 40, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP22CFG_A = '{CSR_PMPCFG4, 51, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP22CFG_L = '{CSR_PMPCFG4, 55, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP22CFG_XWR = '{CSR_PMPCFG4, 48, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP23CFG_A = '{CSR_PMPCFG4, 59, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP23CFG_L = '{CSR_PMPCFG4, 63, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG4_PMP23CFG_XWR = '{CSR_PMPCFG4, 56, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP20CFG_A = '{CSR_PMPCFG5, 3, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP20CFG_L = '{CSR_PMPCFG5, 7, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP20CFG_XWR = '{CSR_PMPCFG5, 0, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP21CFG_A = '{CSR_PMPCFG5, 11, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP21CFG_L = '{CSR_PMPCFG5, 15, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP21CFG_XWR = '{CSR_PMPCFG5, 8, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP22CFG_A = '{CSR_PMPCFG5, 19, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP22CFG_L = '{CSR_PMPCFG5, 23, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP22CFG_XWR = '{CSR_PMPCFG5, 16, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP23CFG_A = '{CSR_PMPCFG5, 27, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP23CFG_L = '{CSR_PMPCFG5, 31, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG5_PMP23CFG_XWR = '{CSR_PMPCFG5, 24, 3};
`endif
localparam csr_field_t PMPCFG6_PMP24CFG_A = '{CSR_PMPCFG6, 3, 2};
localparam csr_field_t PMPCFG6_PMP24CFG_L = '{CSR_PMPCFG6, 7, 1};
localparam csr_field_t PMPCFG6_PMP24CFG_XWR = '{CSR_PMPCFG6, 0, 3};
localparam csr_field_t PMPCFG6_PMP25CFG_A = '{CSR_PMPCFG6, 11, 2};
localparam csr_field_t PMPCFG6_PMP25CFG_L = '{CSR_PMPCFG6, 15, 1};
localparam csr_field_t PMPCFG6_PMP25CFG_XWR = '{CSR_PMPCFG6, 8, 3};
localparam csr_field_t PMPCFG6_PMP26CFG_A = '{CSR_PMPCFG6, 19, 2};
localparam csr_field_t PMPCFG6_PMP26CFG_L = '{CSR_PMPCFG6, 23, 1};
localparam csr_field_t PMPCFG6_PMP26CFG_XWR = '{CSR_PMPCFG6, 16, 3};
localparam csr_field_t PMPCFG6_PMP27CFG_A = '{CSR_PMPCFG6, 27, 2};
localparam csr_field_t PMPCFG6_PMP27CFG_L = '{CSR_PMPCFG6, 31, 1};
localparam csr_field_t PMPCFG6_PMP27CFG_XWR = '{CSR_PMPCFG6, 24, 3};
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP28CFG_A = '{CSR_PMPCFG6, 35, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP28CFG_L = '{CSR_PMPCFG6, 39, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP28CFG_XWR = '{CSR_PMPCFG6, 32, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP29CFG_A = '{CSR_PMPCFG6, 43, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP29CFG_L = '{CSR_PMPCFG6, 47, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP29CFG_XWR = '{CSR_PMPCFG6, 40, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP30CFG_A = '{CSR_PMPCFG6, 51, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP30CFG_L = '{CSR_PMPCFG6, 55, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP30CFG_XWR = '{CSR_PMPCFG6, 48, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP31CFG_A = '{CSR_PMPCFG6, 59, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP31CFG_L = '{CSR_PMPCFG6, 63, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG6_PMP31CFG_XWR = '{CSR_PMPCFG6, 56, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP28CFG_A = '{CSR_PMPCFG7, 3, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP28CFG_L = '{CSR_PMPCFG7, 7, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP28CFG_XWR = '{CSR_PMPCFG7, 0, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP29CFG_A = '{CSR_PMPCFG7, 11, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP29CFG_L = '{CSR_PMPCFG7, 15, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP29CFG_XWR = '{CSR_PMPCFG7, 8, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP30CFG_A = '{CSR_PMPCFG7, 19, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP30CFG_L = '{CSR_PMPCFG7, 23, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP30CFG_XWR = '{CSR_PMPCFG7, 16, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP31CFG_A = '{CSR_PMPCFG7, 27, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP31CFG_L = '{CSR_PMPCFG7, 31, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG7_PMP31CFG_XWR = '{CSR_PMPCFG7, 24, 3};
`endif
localparam csr_field_t PMPCFG8_PMP32CFG_A = '{CSR_PMPCFG8, 3, 2};
localparam csr_field_t PMPCFG8_PMP32CFG_L = '{CSR_PMPCFG8, 7, 1};
localparam csr_field_t PMPCFG8_PMP32CFG_XWR = '{CSR_PMPCFG8, 0, 3};
localparam csr_field_t PMPCFG8_PMP33CFG_A = '{CSR_PMPCFG8, 11, 2};
localparam csr_field_t PMPCFG8_PMP33CFG_L = '{CSR_PMPCFG8, 15, 1};
localparam csr_field_t PMPCFG8_PMP33CFG_XWR = '{CSR_PMPCFG8, 8, 3};
localparam csr_field_t PMPCFG8_PMP34CFG_A = '{CSR_PMPCFG8, 19, 2};
localparam csr_field_t PMPCFG8_PMP34CFG_L = '{CSR_PMPCFG8, 23, 1};
localparam csr_field_t PMPCFG8_PMP34CFG_XWR = '{CSR_PMPCFG8, 16, 3};
localparam csr_field_t PMPCFG8_PMP35CFG_A = '{CSR_PMPCFG8, 27, 2};
localparam csr_field_t PMPCFG8_PMP35CFG_L = '{CSR_PMPCFG8, 31, 1};
localparam csr_field_t PMPCFG8_PMP35CFG_XWR = '{CSR_PMPCFG8, 24, 3};
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP36CFG_A = '{CSR_PMPCFG8, 35, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP36CFG_L = '{CSR_PMPCFG8, 39, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP36CFG_XWR = '{CSR_PMPCFG8, 32, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP37CFG_A = '{CSR_PMPCFG8, 43, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP37CFG_L = '{CSR_PMPCFG8, 47, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP37CFG_XWR = '{CSR_PMPCFG8, 40, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP38CFG_A = '{CSR_PMPCFG8, 51, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP38CFG_L = '{CSR_PMPCFG8, 55, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP38CFG_XWR = '{CSR_PMPCFG8, 48, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP39CFG_A = '{CSR_PMPCFG8, 59, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP39CFG_L = '{CSR_PMPCFG8, 63, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG8_PMP39CFG_XWR = '{CSR_PMPCFG8, 56, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP36CFG_A = '{CSR_PMPCFG9, 3, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP36CFG_L = '{CSR_PMPCFG9, 7, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP36CFG_XWR = '{CSR_PMPCFG9, 0, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP37CFG_A = '{CSR_PMPCFG9, 11, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP37CFG_L = '{CSR_PMPCFG9, 15, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP37CFG_XWR = '{CSR_PMPCFG9, 8, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP38CFG_A = '{CSR_PMPCFG9, 19, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP38CFG_L = '{CSR_PMPCFG9, 23, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP38CFG_XWR = '{CSR_PMPCFG9, 16, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP39CFG_A = '{CSR_PMPCFG9, 27, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP39CFG_L = '{CSR_PMPCFG9, 31, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG9_PMP39CFG_XWR = '{CSR_PMPCFG9, 24, 3};
`endif
localparam csr_field_t PMPCFG10_PMP40CFG_A = '{CSR_PMPCFG10, 3, 2};
localparam csr_field_t PMPCFG10_PMP40CFG_L = '{CSR_PMPCFG10, 7, 1};
localparam csr_field_t PMPCFG10_PMP40CFG_XWR = '{CSR_PMPCFG10, 0, 3};
localparam csr_field_t PMPCFG10_PMP41CFG_A = '{CSR_PMPCFG10, 11, 2};
localparam csr_field_t PMPCFG10_PMP41CFG_L = '{CSR_PMPCFG10, 15, 1};
localparam csr_field_t PMPCFG10_PMP41CFG_XWR = '{CSR_PMPCFG10, 8, 3};
localparam csr_field_t PMPCFG10_PMP42CFG_A = '{CSR_PMPCFG10, 19, 2};
localparam csr_field_t PMPCFG10_PMP42CFG_L = '{CSR_PMPCFG10, 23, 1};
localparam csr_field_t PMPCFG10_PMP42CFG_XWR = '{CSR_PMPCFG10, 16, 3};
localparam csr_field_t PMPCFG10_PMP43CFG_A = '{CSR_PMPCFG10, 27, 2};
localparam csr_field_t PMPCFG10_PMP43CFG_L = '{CSR_PMPCFG10, 31, 1};
localparam csr_field_t PMPCFG10_PMP43CFG_XWR = '{CSR_PMPCFG10, 24, 3};
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP44CFG_A = '{CSR_PMPCFG10, 35, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP44CFG_L = '{CSR_PMPCFG10, 39, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP44CFG_XWR = '{CSR_PMPCFG10, 32, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP45CFG_A = '{CSR_PMPCFG10, 43, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP45CFG_L = '{CSR_PMPCFG10, 47, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP45CFG_XWR = '{CSR_PMPCFG10, 40, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP46CFG_A = '{CSR_PMPCFG10, 51, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP46CFG_L = '{CSR_PMPCFG10, 55, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP46CFG_XWR = '{CSR_PMPCFG10, 48, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP47CFG_A = '{CSR_PMPCFG10, 59, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP47CFG_L = '{CSR_PMPCFG10, 63, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG10_PMP47CFG_XWR = '{CSR_PMPCFG10, 56, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP44CFG_A = '{CSR_PMPCFG11, 3, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP44CFG_L = '{CSR_PMPCFG11, 7, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP44CFG_XWR = '{CSR_PMPCFG11, 0, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP45CFG_A = '{CSR_PMPCFG11, 11, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP45CFG_L = '{CSR_PMPCFG11, 15, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP45CFG_XWR = '{CSR_PMPCFG11, 8, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP46CFG_A = '{CSR_PMPCFG11, 19, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP46CFG_L = '{CSR_PMPCFG11, 23, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP46CFG_XWR = '{CSR_PMPCFG11, 16, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP47CFG_A = '{CSR_PMPCFG11, 27, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP47CFG_L = '{CSR_PMPCFG11, 31, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG11_PMP47CFG_XWR = '{CSR_PMPCFG11, 24, 3};
`endif
localparam csr_field_t PMPCFG12_PMP48CFG_A = '{CSR_PMPCFG12, 3, 2};
localparam csr_field_t PMPCFG12_PMP48CFG_L = '{CSR_PMPCFG12, 7, 1};
localparam csr_field_t PMPCFG12_PMP48CFG_XWR = '{CSR_PMPCFG12, 0, 3};
localparam csr_field_t PMPCFG12_PMP49CFG_A = '{CSR_PMPCFG12, 11, 2};
localparam csr_field_t PMPCFG12_PMP49CFG_L = '{CSR_PMPCFG12, 15, 1};
localparam csr_field_t PMPCFG12_PMP49CFG_XWR = '{CSR_PMPCFG12, 8, 3};
localparam csr_field_t PMPCFG12_PMP50CFG_A = '{CSR_PMPCFG12, 19, 2};
localparam csr_field_t PMPCFG12_PMP50CFG_L = '{CSR_PMPCFG12, 23, 1};
localparam csr_field_t PMPCFG12_PMP50CFG_XWR = '{CSR_PMPCFG12, 16, 3};
localparam csr_field_t PMPCFG12_PMP51CFG_A = '{CSR_PMPCFG12, 27, 2};
localparam csr_field_t PMPCFG12_PMP51CFG_L = '{CSR_PMPCFG12, 31, 1};
localparam csr_field_t PMPCFG12_PMP51CFG_XWR = '{CSR_PMPCFG12, 24, 3};
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP52CFG_A = '{CSR_PMPCFG12, 35, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP52CFG_L = '{CSR_PMPCFG12, 39, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP52CFG_XWR = '{CSR_PMPCFG12, 32, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP53CFG_A = '{CSR_PMPCFG12, 43, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP53CFG_L = '{CSR_PMPCFG12, 47, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP53CFG_XWR = '{CSR_PMPCFG12, 40, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP54CFG_A = '{CSR_PMPCFG12, 51, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP54CFG_L = '{CSR_PMPCFG12, 55, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP54CFG_XWR = '{CSR_PMPCFG12, 48, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP55CFG_A = '{CSR_PMPCFG12, 59, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP55CFG_L = '{CSR_PMPCFG12, 63, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG12_PMP55CFG_XWR = '{CSR_PMPCFG12, 56, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP52CFG_A = '{CSR_PMPCFG13, 3, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP52CFG_L = '{CSR_PMPCFG13, 7, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP52CFG_XWR = '{CSR_PMPCFG13, 0, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP53CFG_A = '{CSR_PMPCFG13, 11, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP53CFG_L = '{CSR_PMPCFG13, 15, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP53CFG_XWR = '{CSR_PMPCFG13, 8, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP54CFG_A = '{CSR_PMPCFG13, 19, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP54CFG_L = '{CSR_PMPCFG13, 23, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP54CFG_XWR = '{CSR_PMPCFG13, 16, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP55CFG_A = '{CSR_PMPCFG13, 27, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP55CFG_L = '{CSR_PMPCFG13, 31, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG13_PMP55CFG_XWR = '{CSR_PMPCFG13, 24, 3};
`endif
localparam csr_field_t PMPCFG14_PMP56CFG_A = '{CSR_PMPCFG14, 3, 2};
localparam csr_field_t PMPCFG14_PMP56CFG_L = '{CSR_PMPCFG14, 7, 1};
localparam csr_field_t PMPCFG14_PMP56CFG_XWR = '{CSR_PMPCFG14, 0, 3};
localparam csr_field_t PMPCFG14_PMP57CFG_A = '{CSR_PMPCFG14, 11, 2};
localparam csr_field_t PMPCFG14_PMP57CFG_L = '{CSR_PMPCFG14, 15, 1};
localparam csr_field_t PMPCFG14_PMP57CFG_XWR = '{CSR_PMPCFG14, 8, 3};
localparam csr_field_t PMPCFG14_PMP58CFG_A = '{CSR_PMPCFG14, 19, 2};
localparam csr_field_t PMPCFG14_PMP58CFG_L = '{CSR_PMPCFG14, 23, 1};
localparam csr_field_t PMPCFG14_PMP58CFG_XWR = '{CSR_PMPCFG14, 16, 3};
localparam csr_field_t PMPCFG14_PMP59CFG_A = '{CSR_PMPCFG14, 27, 2};
localparam csr_field_t PMPCFG14_PMP59CFG_L = '{CSR_PMPCFG14, 31, 1};
localparam csr_field_t PMPCFG14_PMP59CFG_XWR = '{CSR_PMPCFG14, 24, 3};
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP60CFG_A = '{CSR_PMPCFG14, 35, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP60CFG_L = '{CSR_PMPCFG14, 39, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP60CFG_XWR = '{CSR_PMPCFG14, 32, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP61CFG_A = '{CSR_PMPCFG14, 43, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP61CFG_L = '{CSR_PMPCFG14, 47, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP61CFG_XWR = '{CSR_PMPCFG14, 40, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP62CFG_A = '{CSR_PMPCFG14, 51, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP62CFG_L = '{CSR_PMPCFG14, 55, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP62CFG_XWR = '{CSR_PMPCFG14, 48, 3};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP63CFG_A = '{CSR_PMPCFG14, 59, 2};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP63CFG_L = '{CSR_PMPCFG14, 63, 1};
`endif
`ifdef UDB_MXLEN_64
localparam csr_field_t PMPCFG14_PMP63CFG_XWR = '{CSR_PMPCFG14, 56, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP60CFG_A = '{CSR_PMPCFG15, 3, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP60CFG_L = '{CSR_PMPCFG15, 7, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP60CFG_XWR = '{CSR_PMPCFG15, 0, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP61CFG_A = '{CSR_PMPCFG15, 11, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP61CFG_L = '{CSR_PMPCFG15, 15, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP61CFG_XWR = '{CSR_PMPCFG15, 8, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP62CFG_A = '{CSR_PMPCFG15, 19, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP62CFG_L = '{CSR_PMPCFG15, 23, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP62CFG_XWR = '{CSR_PMPCFG15, 16, 3};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP63CFG_A = '{CSR_PMPCFG15, 27, 2};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP63CFG_L = '{CSR_PMPCFG15, 31, 1};
`endif
`ifdef UDB_MXLEN_32
localparam csr_field_t PMPCFG15_PMP63CFG_XWR = '{CSR_PMPCFG15, 24, 3};
`endif

// tdata1/tdata3 type views. They have no CSR address, so these descriptors are disabled.
// localparam csr_field_t ETRIGGER_DMODE = '{CSR_TDATA1, 27, 1};  // RV32 only
// localparam csr_field_t ETRIGGER_DMODE = '{CSR_TDATA1, 59, 1};  // RV64 only
// localparam csr_field_t ETRIGGER_HIT = '{CSR_TDATA1, 26, 1};  // RV32 only
// localparam csr_field_t ETRIGGER_HIT = '{CSR_TDATA1, 58, 1};  // RV64 only
// localparam csr_field_t ETRIGGER_M = '{CSR_TDATA1, 9, 1};
// localparam csr_field_t ETRIGGER_NMI = '{CSR_TDATA1, 10, 1};
// localparam csr_field_t ETRIGGER_S = '{CSR_TDATA1, 7, 1};
// localparam csr_field_t ETRIGGER_TYPE = '{CSR_TDATA1, 28, 4};  // RV32 only
// localparam csr_field_t ETRIGGER_TYPE = '{CSR_TDATA1, 60, 4};  // RV64 only
// localparam csr_field_t ETRIGGER_U = '{CSR_TDATA1, 6, 1};
// localparam csr_field_t ICOUNT_DMODE = '{CSR_TDATA1, 27, 1};  // RV32 only
// localparam csr_field_t ICOUNT_DMODE = '{CSR_TDATA1, 59, 1};  // RV64 only
// localparam csr_field_t ICOUNT_HIT = '{CSR_TDATA1, 24, 1};
// localparam csr_field_t ICOUNT_M = '{CSR_TDATA1, 9, 1};
// localparam csr_field_t ICOUNT_S = '{CSR_TDATA1, 7, 1};
// localparam csr_field_t ICOUNT_TYPE = '{CSR_TDATA1, 28, 4};  // RV32 only
// localparam csr_field_t ICOUNT_TYPE = '{CSR_TDATA1, 60, 4};  // RV64 only
// localparam csr_field_t ICOUNT_U = '{CSR_TDATA1, 6, 1};
// localparam csr_field_t ITRIGGER_DMODE = '{CSR_TDATA1, 27, 1};  // RV32 only
// localparam csr_field_t ITRIGGER_DMODE = '{CSR_TDATA1, 59, 1};  // RV64 only
// localparam csr_field_t ITRIGGER_HIT = '{CSR_TDATA1, 26, 1};  // RV32 only
// localparam csr_field_t ITRIGGER_HIT = '{CSR_TDATA1, 58, 1};  // RV64 only
// localparam csr_field_t ITRIGGER_M = '{CSR_TDATA1, 9, 1};
// localparam csr_field_t ITRIGGER_S = '{CSR_TDATA1, 7, 1};
// localparam csr_field_t ITRIGGER_TYPE = '{CSR_TDATA1, 28, 4};  // RV32 only
// localparam csr_field_t ITRIGGER_TYPE = '{CSR_TDATA1, 60, 4};  // RV64 only
// localparam csr_field_t ITRIGGER_U = '{CSR_TDATA1, 6, 1};
// localparam csr_field_t MCONTROL_ACTION = '{CSR_TDATA1, 12, 4};
// localparam csr_field_t MCONTROL_CHAIN = '{CSR_TDATA1, 11, 1};
// localparam csr_field_t MCONTROL_DMODE = '{CSR_TDATA1, 27, 1};  // RV32 only
// localparam csr_field_t MCONTROL_DMODE = '{CSR_TDATA1, 59, 1};  // RV64 only
// localparam csr_field_t MCONTROL_EXECUTE = '{CSR_TDATA1, 2, 1};
// localparam csr_field_t MCONTROL_HIT = '{CSR_TDATA1, 20, 1};
// localparam csr_field_t MCONTROL_LOAD = '{CSR_TDATA1, 0, 1};
// localparam csr_field_t MCONTROL_M = '{CSR_TDATA1, 6, 1};
// localparam csr_field_t MCONTROL_MASKMAX = '{CSR_TDATA1, 21, 6};  // RV32 only
// localparam csr_field_t MCONTROL_MASKMAX = '{CSR_TDATA1, 53, 6};  // RV64 only
// localparam csr_field_t MCONTROL_MATCH = '{CSR_TDATA1, 7, 4};
// localparam csr_field_t MCONTROL_S = '{CSR_TDATA1, 4, 1};
// localparam csr_field_t MCONTROL_SELECT = '{CSR_TDATA1, 19, 1};
// localparam csr_field_t MCONTROL_SIZEHI = '{CSR_TDATA1, 21, 2};  // RV64 only
// localparam csr_field_t MCONTROL_SIZELO = '{CSR_TDATA1, 16, 2};
// localparam csr_field_t MCONTROL_STORE = '{CSR_TDATA1, 1, 1};
// localparam csr_field_t MCONTROL_TIMING = '{CSR_TDATA1, 18, 1};
// localparam csr_field_t MCONTROL_TYPE = '{CSR_TDATA1, 28, 4};  // RV32 only
// localparam csr_field_t MCONTROL_TYPE = '{CSR_TDATA1, 60, 4};  // RV64 only
// localparam csr_field_t MCONTROL_U = '{CSR_TDATA1, 3, 1};
// localparam csr_field_t TEXTRA32_MSELECT = '{CSR_TDATA1, 25, 1};  // RV32 only
// localparam csr_field_t TEXTRA32_SSELECT = '{CSR_TDATA1, 0, 2};  // RV32 only
// localparam csr_field_t TEXTRA64_MSELECT = '{CSR_TDATA1, 50, 1};  // RV64 only
// localparam csr_field_t TEXTRA64_SSELECT = '{CSR_TDATA1, 0, 2};  // RV64 only

// Field f of its CSR, shifted to bit 0
function `XLEN_BITS get_csr_field(int hart, int issue, int prev, csr_field_t f);
  `XLEN_BITS val = traceDataQ[hart][issue][prev].csr[f.addr];
  return (val >> f.lsb) & ~({`UDB_MXLEN{1'b1}} << f.width);
endfunction
