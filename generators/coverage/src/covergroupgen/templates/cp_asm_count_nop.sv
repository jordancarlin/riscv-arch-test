    cp_asm_count_nop : coverpoint ins.current.inst_id == @INSTRID@ iff (ins.trap == 0 && ins.current.imm == 0) {
        // Number of times the canonical @INSTR@ (imm == 0) is executed
        bins count[] = {1};
    }
