function void @ARCH@_sample(int hart, int issue, ins_t ins);
    inst_id_t inst_id = ins.current.inst_id;

    case (inst_id)
