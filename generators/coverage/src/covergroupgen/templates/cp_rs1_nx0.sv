    cp_rs1_nx0 : coverpoint ins.current.rs1 iff (ins.trap == 0) {
        // RS1 register assignment (excluding x0)
        ignore_bins x0 = {x0};
    }
