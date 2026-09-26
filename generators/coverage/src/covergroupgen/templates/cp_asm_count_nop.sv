    cp_asm_count_nop : coverpoint 1'b1 iff (ins.trap == 0 && ins.current.imm == 0) {
        // Number of times the canonical INSTR (imm == 0) is executed
        bins count[] = {1};
    }
