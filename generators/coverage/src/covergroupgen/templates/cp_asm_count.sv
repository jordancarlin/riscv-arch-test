    cp_asm_count : coverpoint ins.current.inst_id == @INSTRID@  iff (ins.trap == 0 )  {
        // Number of times instruction is executed
        bins count[]  = {1};
    }
