    cmp_rd_rs1_nx0 : coverpoint ins.current.rd  iff (ins.current.rd == ins.current.rs1 & ins.trap == 0 )  {
        // Compare assignments of all 31 registers excluding x0
        ignore_bins x0 = {x0};
    }
