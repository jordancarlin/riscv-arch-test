####################################################################################
#
# RISC-V Architectural Functional Coverage Testbench (compile)
#
# Compiles one design containing every coverage group. riscv-arch-test.do runs it.
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
set FCOVDIR ${2}
set COVERPOINTDIR ${3}
set UDBHEADERDIR ${4}
set ENVHEADERDIR ${5}
set COVERAGELIST ${6}

onerror {puts stderr "\033\[1;31mERROR collecting coverage. Compilation failed.\033\[0m"; quit -f -code 1}

# Create library
if [file exists ${WKDIR}] {
    vdel -lib ${WKDIR} -all
}
vlib ${WKDIR}

# Include directories and files to compile
set COVERPOINTS "+incdir+${COVERPOINTDIR} +incdir+${COVERPOINTDIR}/unpriv +incdir+${COVERPOINTDIR}/priv"
set INC_DIRS "+incdir+${UDBHEADERDIR} +incdir+${ENVHEADERDIR} ${COVERPOINTS} +incdir+${FCOVDIR}"
set COMPILE_FILES "${FCOVDIR}/rvviTrace.sv ${FCOVDIR}/riscv_arch_test.sv ${FCOVDIR}/testbench.sv"

# Build +define+ list from COVERAGELIST (space-separated)
set DEFINE_ARGS {}
foreach def [split ${COVERAGELIST}] {
    if {$def eq ""} { continue }
    lappend DEFINE_ARGS "+define+$def"
}

# Compile and optimize
vlog -permissive -lint -work ${WKDIR} {*}${INC_DIRS} {*}${DEFINE_ARGS} {*}${COMPILE_FILES}
vopt ${WKDIR}.testbench -work ${WKDIR} -o testbenchopt
quit
