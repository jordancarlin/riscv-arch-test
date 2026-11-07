        @INSTRID@     : begin
            ins.add_fs2(crs2);
            ins.add_mem_offset(imm_csdsp(insn));
            ins.add_rs1_sp();
            ins.current.inst_category = INST_CAT_STORE;
            ins.add_mem_address();
        end
