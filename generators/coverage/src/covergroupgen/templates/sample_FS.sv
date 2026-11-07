        @INSTRID@     : begin
            ins.add_fs2(rs2);
            ins.add_mem_offset(imm_s(insn));
            ins.add_rs1(rs1);
            ins.current.inst_category = INST_CAT_STORE;
            ins.add_mem_address();
        end
