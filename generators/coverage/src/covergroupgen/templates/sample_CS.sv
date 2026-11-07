        @INSTRID@     : begin
            ins.add_rs2(rs2p);
            ins.add_mem_offset(imm_clw(insn));
            ins.add_rs1(rs1p);
            ins.current.inst_category = INST_CAT_STORE;
            ins.add_mem_address();
        end
