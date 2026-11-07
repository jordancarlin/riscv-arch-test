    cmp_fd_fs3 : coverpoint ins.current.fd  iff (ins.current.fd == ins.current.fs3 & ins.trap == 0 )  {
        // FD and FS1 register (assignment) WAR Hazard
    }
