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
  `include "rvtest_config.svh"

  // Set up variable lengths
  localparam XLEN = `UDB_MXLEN;

  `ifdef Q_SUPPORTED
    localparam FLEN = 128;
  `elsif D_SUPPORTED
    localparam FLEN = 64;
  `else
    localparam FLEN = 32;
  `endif

  localparam VLEN = `UDB_VLEN;

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
  logic              mode_virt; // hypervisor bit
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

  // Sample an instruction from the trace file on each clock edge
  // Moves through full list of trace files
  always_ff @(posedge clk) begin
    // Open trace file if needed
    if(traceFileHandler === 'x) begin
      fileNum = 0;
      traceFile = traceFiles[fileNum];
      $display("Opening trace file: %s", traceFile);
      traceFileHandler = $fopen(traceFile, "r");
      if (traceFileHandler == 0) begin
        $display("Error: Could not open trace file");
        $finish;
      end
    end else if($feof(traceFileHandler)) begin
      $display("Completed trace file: %s", traceFile);
      $fclose(traceFileHandler);
      if(fileNum < traceFiles.size - 1) begin
        fileNum++;
        traceFile = traceFiles[fileNum];
        $display("Opening trace file: %s", traceFile);
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
    {valid, insn, trap, debug_mode, pc_rdata, mode, mode_virt,
    x_wb, f_wb, v_wb, csr_wb, x_wdata, f_wdata, v_wdata} = 0;

    // Get next line from trace file
    num = $fgets(line, traceFileHandler);

    // Parse line and set signals
    if (line != "" & line != "\n") begin // Skip empty lines
      splitLine(line, words); // Split line into queue of individual words
      while (words.size > 0) begin
        key = words.pop_front();
        val = words.pop_front();
        // Need to parse values using $sscanf because standard ascii to int conversion
        // doesn't work for number larger than 32 bits
        case(key)
          // Standard signals
          "ORDER":          num = $sscanf(val, "%d", order);
          "INSN":           num = $sscanf(val, "%h", insn);
          "TRAP":           num = $sscanf(val, "%b", trap);
          "DEBUG_MODE":     num = $sscanf(val, "%b", debug_mode);
          "PC":             num = $sscanf(val, "%h", pc_rdata);
          "MODE":           num = $sscanf(val, "%d", mode);
          "MODE_VIRT":      num = $sscanf(val, "%d", mode_virt);
          // Registers
          "X": begin
            num = $sscanf(val, "%d", regNum);
            val = words.pop_front();
            num = $sscanf(val, "%h", xRegVal);
            x_wdata[regNum] = xRegVal;
            x_wb |= (1 << regNum);
          end
          "F": begin
            num = $sscanf(val, "%d", regNum);
            val = words.pop_front();
            num = $sscanf(val, "%h", fRegVal);
            f_wdata[regNum] = fRegVal;
            f_wb |= (1 << regNum);
          end
          "V": begin
            num = $sscanf(val, "%d", regNum);
            val = words.pop_front();
            num = $sscanf(val, "%h", vRegVal);
            v_wdata[regNum] = vRegVal;
            v_wb |= (1 << regNum);
          end
          "CSR": begin
            num = $sscanf(val, "%h", regNum);
            val = words.pop_front();
            num = $sscanf(val, "%h", xRegVal);
            csr[regNum] = xRegVal;
            csr_wb[regNum] =1'b1;
          end
          default: begin
            $display("Unknown key: %s", key);
            $finish();
          end
        endcase
      end
      valid = 1;
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
  assign rvvi.mode_virt[0][0] = mode_virt;

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
