#!/usr/bin/env bash
####################################################################################
#
# RISC-V Architectural Functional Coverage Testbench (Verilator)
#
# Builds one simulator binary containing every coverage group. Each group is then
# simulated with +cover_groups=<group>.
#
# Copyright (C) 2026 Harvey Mudd College
#
# SPDX-License-Identifier: Apache-2.0
#
####################################################################################

set -euo pipefail

WKDIR="${1}"
FCOVDIR="${2}"
COVERPOINTDIR="${3}"
UDBHEADERDIR="${4}"
ENVHEADERDIR="${5}"
COVERAGELIST="${6}"

VERILATOR="${VERILATOR:-verilator}"
VERILATOR_COVERAGE_MAX_BINS="${VERILATOR_COVERAGE_MAX_BINS:-8192}"
# C++ build jobs per group. ACT already runs one group per core, so more than one job
# here oversubscribes the CPU and memory. Raise it only when running a single group.
VERILATOR_JOBS="${VERILATOR_JOBS:-1}"
# The default -Os is slower to build and to run than -O2.
VERILATOR_CFLAGS="${VERILATOR_CFLAGS:--O2}"

rm -rf "${WKDIR}"
mkdir -p "${WKDIR}"

INC_DIRS=(
  "+incdir+${UDBHEADERDIR}"
  "+incdir+${ENVHEADERDIR}"
  "+incdir+${COVERPOINTDIR}"
  "+incdir+${COVERPOINTDIR}/unpriv"
  "+incdir+${COVERPOINTDIR}/priv"
  "+incdir+${FCOVDIR}"
)
COMPILE_FILES=(
  "${FCOVDIR}/rvviTrace.sv"
  "${FCOVDIR}/riscv_arch_test.sv"
  "${FCOVDIR}/testbench.sv"
)

DEFINE_ARGS=()
for def in ${COVERAGELIST}; do
  DEFINE_ARGS+=("+define+${def}")
done

pushd "${WKDIR}" >/dev/null

if ! "${VERILATOR}" --binary -j "${VERILATOR_JOBS}" -CFLAGS "${VERILATOR_CFLAGS}" --timing -Wno-fatal --coverage-user --coverage-merge-instances \
  --coverage-max-bins "${VERILATOR_COVERAGE_MAX_BINS}" --top-module testbench \
  "${INC_DIRS[@]}" "${DEFINE_ARGS[@]}" "${COMPILE_FILES[@]}" --Mdir obj_dir >verilator.log 2>&1; then
  echo "ERROR collecting coverage. Verilator failed; see ${WKDIR}/verilator.log" >&2
  exit 1
fi

popd >/dev/null
