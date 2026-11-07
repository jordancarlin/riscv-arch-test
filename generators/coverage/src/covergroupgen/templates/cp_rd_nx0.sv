    cp_rd_nx0 : coverpoint ins.current.rd iff (ins.trap == 0) {
        // RD register assignment (excluding x0)
        ignore_bins x0 = {x0};
    }
