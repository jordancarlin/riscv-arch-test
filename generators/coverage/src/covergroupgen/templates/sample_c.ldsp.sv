        @INSTRID@     : begin
            ins.add_rd(rd);
            ins.add_mem_offset(imm_cldsp(insn));
            ins.add_rs1_sp();
            ins.current.inst_category = INST_CAT_LOAD;
            ins.add_mem_address();
        end
