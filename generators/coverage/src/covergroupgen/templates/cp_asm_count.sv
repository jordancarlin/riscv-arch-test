    cp_asm_count : coverpoint 1'b1  iff (ins.trap == 0 )  {
        // Number of times instruction is executed
        bins count[]  = {1};
    }
