    cp_rd_pair : coverpoint ins.current.rd  iff (ins.trap == 0 )  {
        // RD register assignment, even registers only
        bins reg_pair[] = {[$:$]} with (item % 2 == 0);
    }
