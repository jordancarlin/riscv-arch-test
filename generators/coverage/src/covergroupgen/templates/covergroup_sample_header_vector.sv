function void @ARCH@_sample(int hart, int issue, ins_t ins);
    inst_id_t inst_id = ins.current.inst_id;

    // Want to sample only if the SEW matches the target SEW of the file, some tests require
    // testing when vill is set, if vill=1 all other vtype bits are set to 0 so there is no
    // associated sew with these tests
    if (get_csr_field(hart, issue, `SAMPLE_BEFORE, VTYPE_VSEW) == @EFFVSEW@ ||
        get_csr_field(hart, issue, `SAMPLE_BEFORE, VTYPE_VILL) == 1) begin
        case (inst_id)
