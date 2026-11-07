        @INSTRID@     : begin
            ins.add_vd(rd);
            ins.add_vs2(rs2);
            ins.add_imm(imm_zimm6(insn));
            ins.add_vm(insn[25]);
            ins.add_v0();
        end
