    // c.li with rd = 0 is a hint
    cp_c_hint_li : coverpoint signed'(ins.current.imm) iff (ins.trap == 0 && ins.current.rd == x0) {
        bins imm[] = {[-32:31]};
    }
