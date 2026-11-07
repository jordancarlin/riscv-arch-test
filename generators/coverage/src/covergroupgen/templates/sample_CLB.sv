        @INSTRID@     : begin
            ins.add_rd(rs2p);
            ins.add_mem_offset(imm_clb(insn));
            ins.add_rs1(rs1p);
            ins.current.inst_category = INST_CAT_LOAD;
            ins.add_mem_address();
        end
