    cmp_rd_rs2_pair : coverpoint ins.current.rd  iff (ins.current.rd == ins.current.rs2 & ins.trap == 0 )  {
        // Compare assignments of all even registers
        bins reg_pair[] = {[$:$]} with (item % 2 == 0);
    }
