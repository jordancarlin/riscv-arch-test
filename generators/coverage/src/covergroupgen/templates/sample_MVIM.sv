        @INSTRID@     : begin
            ins.add_vd(rd);
            ins.add_vs2(rs2);
            ins.add_imm(imm_v(insn));
            ins.add_vm(1'b0);
            ins.add_v0();
        end
