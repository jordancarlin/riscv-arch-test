    cmp_rd_rs2 : coverpoint ins.current.rd  iff (ins.current.rd == ins.current.rs2 & ins.trap == 0 )  {
        // Compare assignments of all registers
    }
