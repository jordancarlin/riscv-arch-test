    cmp_rd_rs2_nx0 : coverpoint ins.current.rd  iff (ins.current.rd == ins.current.rs2 & ins.trap == 0 )  {
        // Compare assignments of all 31 registers excluding x0
        ignore_bins x0 = {x0};
    }
