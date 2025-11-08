///////////////////////////////////////////
//
// RISC-V Architectural Functional Coverage Testbench
//
// Copyright (C) 2025 Harvey Mudd College, 10x Engineers, UET Lahore
// Written: Jordan Carlin jcarlin@hmc.edu March 2025
//
// SPDX-License-Identifier: Apache-2.0
//
////////////////////////////////////////////////////////////////////////////////////////////////

module testbench;

  // Load configuration
  `include "riscv-arch-test_coverage.svh"

  // Set up variable lengths
  `ifdef XLEN32
    localparam XLEN = 32;
  `else
    localparam XLEN = 64;
  `endif

  `ifdef FLEN128
    localparam FLEN = 128;
  `elsif FLEN64
    localparam FLEN = 64;
  `else
    localparam FLEN = 32;
  `endif

  localparam VLEN = 512; // TODO: Make configurable (maybe just use the macro directly)

  localparam PA_BITS = (XLEN==32 ? 32'd34 : 32'd56);
  localparam PPN_BITS = (XLEN==32 ? 32'd22 : 32'd44);

  // Temporary signals for filling RVVI trace interface (file handling, string parsing, etc)
  string  traceFileList, traceFile;
  integer traceFileListHandler, traceFileHandler, num;
  string  line;
  string  key, val;
  string  words[$];
  string  traceFiles[$];
  int     fileNum;
  int     order;
  int     regNum;
  int     hartId;
  int     issueSlot;
  logic [(XLEN-1):0] xRegVal;
  logic [(FLEN-1):0] fRegVal;
  logic [(VLEN-1):0] vRegVal;

  // RVVI Trace interface signals
  // Basic signals
  logic              clk;
  logic [31:0]       insn;
  logic              trap;
  logic              valid;
  logic              debug_mode;
  logic [(XLEN-1):0] pc_rdata;
  logic [1:0]        mode;
  // Interrupts
  logic m_ext_intr, s_ext_intr, m_timer_intr, m_soft_intr;
  // Virtual Memory
  logic [(XLEN-1):0]     virt_adr_i, virt_adr_d;
  logic [(PA_BITS-1):0]  phys_adr_i, phys_adr_d;
  logic [(XLEN-1):0]     pte_i, pte_d;
  logic [(PPN_BITS-1):0] ppn_i, ppn_d;
  logic [1:0]            page_type_i, page_type_d;
  logic read_access, write_access, execute_access;
  // Registers
  logic [31:0][(XLEN-1):0]   x_wdata;
  logic [31:0]               x_wb;
  logic [31:0][(FLEN-1):0]   f_wdata;
  logic [31:0]               f_wb;
  logic [31:0][(VLEN-1):0]   v_wdata;
  logic [31:0]               v_wb;
  logic [4095:0][(XLEN-1):0] csr;
  logic [4095:0]             csr_wb;

  // Generate clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Load list of trace files from traceFileList plusarg
  initial begin
    if (!$value$plusargs("traceFileList=%s", traceFileList)) begin
      $display("Error: traceFileList not provided");
      $finish;
    end
    traceFileListHandler = $fopen(traceFileList, "r");
    if (traceFileListHandler == 0) begin
      $display("Error: Could not open trace file list");
      $finish;
    end
    while($fgets(line, traceFileListHandler)) begin
      if (line != "" && line != "\n" && line[0] != "#") begin
        // Strip newline character from the end of the line
        if (line[line.len()-1] == "\n") begin
          line = line.substr(0, line.len()-2);
        end
        traceFiles.push_back(line);
      end
    end
    if(traceFiles.size == 0) begin
      $display("Error: No trace files found in trace file list");
      $finish;
    end
    $fclose(traceFileListHandler);
  end

  // Load coverage model and connect to RVVI trace interface
  rvviTrace #(.XLEN(XLEN), .FLEN(FLEN), .VLEN(VLEN)) rvvi();
  riscv_arch_test riscv_arch_test(rvvi);

  // Initialize RVVI-Text state tracking variables
  initial begin
    order = 0;
    hartId = 0;
    issueSlot = 0;
  end

  // Sample an instruction from the trace file on each clock edge
  // Moves through full list of trace files
  always_ff @(posedge clk) begin
    // Open trace file if needed
    if(traceFileHandler === 'x) begin
      fileNum = 0;
      traceFile = traceFiles[fileNum];
      traceFileHandler = $fopen(traceFile, "r");
      if (traceFileHandler == 0) begin
        $display("Error: Could not open trace file");
        $finish;
      end
    end else if($feof(traceFileHandler)) begin
      $fclose(traceFileHandler);
      if(fileNum < traceFiles.size - 1) begin
        fileNum++;
        traceFile = traceFiles[fileNum];
        traceFileHandler = $fopen(traceFile, "r");
        if (traceFileHandler == 0) begin
          $display("Error: Could not open trace file");
          $finish;
        end
      end else begin
        $display("All trace files completed");
        $finish;
      end
    end

    // Reset all signals at the beginning of each iteration
    {valid, insn, trap, debug_mode, pc_rdata, mode,
    m_ext_intr, s_ext_intr, m_timer_intr, m_soft_intr,
    virt_adr_i, virt_adr_d, phys_adr_i, phys_adr_d,
    pte_i, pte_d, ppn_i, ppn_d, page_type_i, page_type_d,
    read_access, write_access, execute_access,
    x_wb, f_wb, v_wb, csr_wb, x_wdata, f_wdata, v_wdata} = 0;

    // Get next line from trace file
    num = $fgets(line, traceFileHandler);

    // Parse line and set signals
    if (line != "" & line != "\n") begin // Skip empty lines
      splitLine(line, words); // Split line into queue of individual words
      while (words.size > 0) begin
        key = words.pop_front();
        // Need to parse values using $sscanf because standard ascii to int conversion
        // doesn't work for number larger than 32 bits
        case(key)
          // RVVI-Text header elements (skip/validate)
          "VERSION": begin
            // Skip version numbers
            val = words.pop_front(); // major
            val = words.pop_front(); // minor
          end
          "VENDOR": begin
            // Skip vendor name and version
            val = words.pop_front(); // name
            val = words.pop_front(); // version
          end
          "PARAMS": begin
            // Parse PARAMS count and skip parameters
            val = words.pop_front();
            num = $sscanf(val, "%d", regNum); // count
            // Skip all parameters (count * 2 words)
            for (int i = 0; i < regNum * 2; i++) begin
              val = words.pop_front();
            end
          end
          // RVVI-Text control elements
          "HART": begin
            val = words.pop_front();
            num = $sscanf(val, "%d", hartId);
            issueSlot = 0; // Reset issue slot when hart changes
          end
          "ISSUE": begin
            val = words.pop_front();
            num = $sscanf(val, "%d", issueSlot);
          end
          "ORDER": begin
            val = words.pop_front();
            num = $sscanf(val, "%d", order);
          end
          // Retirement/Trap events
          "RET": begin
            val = words.pop_front();
            num = $sscanf(val, "%h", pc_rdata);
            val = words.pop_front();
            num = $sscanf(val, "%h", insn);
            valid = 1;
            // Auto-increment order for next instruction
            order++;
          end
          "TRAP": begin
            val = words.pop_front();
            num = $sscanf(val, "%h", pc_rdata);
            val = words.pop_front();
            num = $sscanf(val, "%h", insn);
            trap = 1;
            valid = 1;
            // Auto-increment order for next instruction
            order++;
          end
          // Standard signals
          "DM":             begin
            val = words.pop_front();
            num = $sscanf(val, "%h", debug_mode);
          end
          "MODE":           begin
            val = words.pop_front();
            num = $sscanf(val, "%h", mode);
          end
          "VIRT":           begin
            val = words.pop_front();
            // VIRT not currently used, skip
          end
          // Interrupts
          "M_EXT_INTR":     begin
            val = words.pop_front();
            num = $sscanf(val, "%b", m_ext_intr);
          end
          "S_EXT_INTR":     begin
            val = words.pop_front();
            num = $sscanf(val, "%b", s_ext_intr);
          end
          "M_TIMER_INTR":   begin
            val = words.pop_front();
            num = $sscanf(val, "%b", m_timer_intr);
          end
          "M_SOFT_INTR":    begin
            val = words.pop_front();
            num = $sscanf(val, "%b", m_soft_intr);
          end
          // Virtual Memory
          "VIRT_ADR_I":     begin
            val = words.pop_front();
            num = $sscanf(val, "%h", virt_adr_i);
          end
          "VIRT_ADR_D":     begin
            val = words.pop_front();
            num = $sscanf(val, "%h", virt_adr_d);
          end
          "PHYS_ADR_I":     begin
            val = words.pop_front();
            num = $sscanf(val, "%h", phys_adr_i);
          end
          "PHYS_ADR_D":     begin
            val = words.pop_front();
            num = $sscanf(val, "%h", phys_adr_d);
          end
          "PTE_I":          begin
            val = words.pop_front();
            num = $sscanf(val, "%h", pte_i);
          end
          "PTE_D":          begin
            val = words.pop_front();
            num = $sscanf(val, "%h", pte_d);
          end
          "PPN_I":          begin
            val = words.pop_front();
            num = $sscanf(val, "%h", ppn_i);
          end
          "PPN_D":          begin
            val = words.pop_front();
            num = $sscanf(val, "%h", ppn_d);
          end
          "PAGE_TYPE_I":    begin
            val = words.pop_front();
            num = $sscanf(val, "%b", page_type_i);
          end
          "PAGE_TYPE_D":    begin
            val = words.pop_front();
            num = $sscanf(val, "%b", page_type_d);
          end
          "READ_ACCESS":    begin
            val = words.pop_front();
            num = $sscanf(val, "%b", read_access);
          end
          "WRITE_ACCESS":   begin
            val = words.pop_front();
            num = $sscanf(val, "%b", write_access);
          end
          "EXECUTE_ACCESS": begin
            val = words.pop_front();
            num = $sscanf(val, "%b", execute_access);
          end
          // Registers
          "X": begin
            val = words.pop_front();
            num = $sscanf(val, "%d", regNum);
            val = words.pop_front();
            num = $sscanf(val, "%h", xRegVal);
            x_wdata[regNum] = xRegVal;
            x_wb |= (1 << regNum);
          end
          "F": begin
            val = words.pop_front();
            num = $sscanf(val, "%d", regNum);
            val = words.pop_front();
            num = $sscanf(val, "%h", fRegVal);
            f_wdata[regNum] = fRegVal;
            f_wb |= (1 << regNum);
          end
          "V": begin
            val = words.pop_front();
            num = $sscanf(val, "%d", regNum);
            val = words.pop_front();
            num = $sscanf(val, "%h", vRegVal);
            v_wdata[regNum] = vRegVal;
            v_wb |= (1 << regNum);
          end
          "C": begin // CSR using RVVI-Text format
            val = words.pop_front();
            num = $sscanf(val, "%h", regNum);
            val = words.pop_front();
            num = $sscanf(val, "%h", xRegVal);
            csr[regNum] = xRegVal;
            csr_wb[regNum] =1'b1;
          end
          // Legacy support for old format
          "INSN":           begin
            val = words.pop_front();
            num = $sscanf(val, "%h", insn);
          end
          "PC":             begin
            val = words.pop_front();
            num = $sscanf(val, "%h", pc_rdata);
          end
          "CSR": begin
            val = words.pop_front();
            num = $sscanf(val, "%h", regNum);
            val = words.pop_front();
            num = $sscanf(val, "%h", xRegVal);
            csr[regNum] = xRegVal;
            csr_wb[regNum] =1'b1;
          end
          // NET and META elements
          "NET": begin
            // Skip NET elements
            val = words.pop_front(); // name
            val = words.pop_front(); // value
          end
          "META": begin
            // Parse META count and skip tokens
            val = words.pop_front();
            num = $sscanf(val, "%d", regNum); // count
            for (int i = 0; i < regNum; i++) begin
              val = words.pop_front();
            end
          end
          default: begin
            // Skip unknown keys (could be comments or extensions)
            if (words.size > 0) begin
              val = words.pop_front();
            end
          end
        endcase
      end
    end
  end

  // Connect testbench signals to RVVI trace interface
  // Basic signals
  assign rvvi.clk = clk;
  assign rvvi.valid[0][0] = valid;
  assign rvvi.order[0][0] = order;
  assign rvvi.insn[0][0] = insn;
  assign rvvi.trap[0][0] = trap;
  assign rvvi.debug_mode[0][0] = debug_mode;
  assign rvvi.pc_rdata[0][0] = pc_rdata;
  assign rvvi.mode[0][0] = mode;

  // Interrupts
  assign rvvi.m_ext_intr[0][0] = m_ext_intr;
  assign rvvi.s_ext_intr[0][0] = s_ext_intr;
  assign rvvi.m_timer_intr[0][0] = m_timer_intr;
  assign rvvi.m_soft_intr[0][0] = m_soft_intr;

  // Virtual Memory
  assign rvvi.virt_adr_i[0][0] = virt_adr_i;
  assign rvvi.virt_adr_d[0][0] = virt_adr_d;
  assign rvvi.phys_adr_i[0][0] = phys_adr_i;
  assign rvvi.phys_adr_d[0][0] = phys_adr_d;
  assign rvvi.pte_i[0][0] = pte_i;
  assign rvvi.pte_d[0][0] = pte_d;
  assign rvvi.ppn_i[0][0] = ppn_i;
  assign rvvi.ppn_d[0][0] = ppn_d;
  assign rvvi.page_type_i[0][0] = page_type_i;
  assign rvvi.page_type_d[0][0] = page_type_d;
  assign rvvi.read_access[0][0] = read_access;
  assign rvvi.write_access[0][0] = write_access;
  assign rvvi.execute_access[0][0] = execute_access;

  // Registers
  assign rvvi.x_wb[0][0] = x_wb;
  assign rvvi.x_wdata[0][0] = x_wdata;
  assign rvvi.f_wb[0][0] = f_wb;
  assign rvvi.f_wdata[0][0] = f_wdata;
  assign rvvi.v_wb[0][0] = v_wb;
  assign rvvi.v_wdata[0][0] = v_wdata;
  assign rvvi.csr_wb[0][0] = csr_wb;
  assign rvvi.csr[0][0] = csr;

  // Takes a string and splits it into individual words that are returned in the provided string queue
  function automatic void splitLine(string line, ref string words[$]);
    string word;
    while (line.len() > 0) begin
      num = $sscanf(line, "%s", word);
      words.push_back(word);
      line = line.substr(word.len() + 1, line.len() - 1);
    end
  endfunction

endmodule
