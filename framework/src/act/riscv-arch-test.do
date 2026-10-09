####################################################################################
#
# RISC-V Architectural Functional Coverage Testbench (run)
#
# Simulates one coverage group on the design built by riscv-arch-test-compile.do.
#
# Copyright (C) 2025 Harvey Mudd College, 10x Engineers, UET Lahore
# Written: Jordan Carlin jcarlin@hmc.edu March 2025
#
# SPDX-License-Identifier: Apache-2.0
#
####################################################################################

onbreak {resume}

# Initialize variables
set WKDIR ${1}
set UCDB ${2}
set TRACEFILELIST ${3}
set GROUP ${4}

onerror {puts stderr "\033\[1;31mERROR collecting coverage. Check ${UCDB}.log for details.\033\[0m"; quit -f -code 1}

vsim -lib ${WKDIR} testbenchopt +traceFileList=${TRACEFILELIST} +cover_groups=${GROUP} -fatal 7

coverage save -onexit ${UCDB}

run -all
quit
