#!/usr/bin/env bash
####################################################################################
#
# RISC-V Architectural Functional Coverage Testbench (VCS)
#
# Builds one simulator binary containing every coverage group. Each group is then
# simulated with +cover_groups=<group>.
#
# Copyright (C) 2026 Harvey Mudd College
# Written: Jordan Carlin jcarlin@hmc.edu March 2026
#
# SPDX-License-Identifier: Apache-2.0
#
####################################################################################

set -euo pipefail

# Input arguments
WKDIR="${1}"
FCOVDIR="${2}"
COVERPOINTDIR="${3}"
UDBHEADERDIR="${4}"
ENVHEADERDIR="${5}"
COVERAGELIST="${6}"

# Clean old build
rm -rf "${WKDIR}"
mkdir -p "${WKDIR}"

# Setup VCS arguments
COVERPOINTS=(
  "+incdir+${COVERPOINTDIR}"
  "+incdir+${COVERPOINTDIR}/unpriv"
  "+incdir+${COVERPOINTDIR}/priv"
)
INC_DIRS=(
  "+incdir+${UDBHEADERDIR}"
  "+incdir+${ENVHEADERDIR}"
  "${COVERPOINTS[@]}"
  "+incdir+${FCOVDIR}"
)
COMPILE_FILES=(
  "${FCOVDIR}/rvviTrace.sv"
  "${FCOVDIR}/riscv_arch_test.sv"
  "${FCOVDIR}/testbench.sv"
)

DEFINE_ARGS=()
for def in ${COVERAGELIST}; do
  if [[ -n ${def} ]]; then
    DEFINE_ARGS+=("+define+${def}")
  fi
done

pushd "${WKDIR}" >/dev/null

# Compile
if ! vlogan -q -full64 -sverilog "${INC_DIRS[@]}" "${DEFINE_ARGS[@]}" "${COMPILE_FILES[@]}" >vlogan.log 2>&1; then
  echo "ERROR collecting coverage. vlogan failed; see ${WKDIR}/vlogan.log" >&2
  exit 1
fi

# Elaborate
if ! vcs -q -full64 -sverilog testbench -o simv >vcs.log 2>&1; then
  echo "ERROR collecting coverage. vcs elaboration failed; see ${WKDIR}/vcs.log" >&2
  exit 1
fi

popd >/dev/null
