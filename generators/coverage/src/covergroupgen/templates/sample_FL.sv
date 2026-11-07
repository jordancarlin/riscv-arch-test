        @INSTRID@     : begin
            ins.add_fd(rd);
            ins.add_mem_offset(imm_i(insn));
            ins.add_rs1(rs1);
            ins.current.inst_category = INST_CAT_LOAD;
            ins.add_mem_address();
        end
