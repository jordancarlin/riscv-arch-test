    cmp_fd_fs2 : coverpoint ins.current.fd  iff (ins.current.fd == ins.current.fs2 & ins.trap == 0 )  {
        // FD and FS1 register (assignment) WAR Hazard
    }
