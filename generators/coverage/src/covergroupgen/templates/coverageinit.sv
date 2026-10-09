    if (fcov_en_@ARCHCASE@) begin
        `cover_info("//      @ARCHCASE@ - Enabled");
        `include "@ARCHCASE@_coverage_init.svh"
    end
