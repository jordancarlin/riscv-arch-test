    cmp_fd_fs1 : coverpoint ins.current.fd  iff (ins.current.fd == ins.current.fs1 & ins.trap == 0 )  {
        // FD and FS1 register (assignment) WAR Hazard
    }
