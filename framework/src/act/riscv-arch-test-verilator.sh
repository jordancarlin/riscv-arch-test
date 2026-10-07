#!/usr/bin/env bash
####################################################################################
#
# RISC-V Architectural Functional Coverage Testbench (Verilator)
#
# Copyright (C) 2026 Harvey Mudd College
#
# SPDX-License-Identifier: Apache-2.0
#
####################################################################################

set -euo pipefail

TRACEFILELIST="${1}"
COVERAGEDAT="${2}"
WKDIR="${3}"
FCOVDIR="${4}"
COVERPOINTDIR="${5}"
UDBHEADERDIR="${6}"
ENVHEADERDIR="${7}"
COVERAGELIST="${8}"

VERILATOR="${VERILATOR:-verilator}"
VERILATOR_COVERAGE_MAX_BINS="${VERILATOR_COVERAGE_MAX_BINS:-8192}"

rm -rf "${WKDIR}" "${COVERAGEDAT}"
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

if ! "${VERILATOR}" --binary --timing --coverage-user --coverage-merge-instances \
  --coverage-max-bins "${VERILATOR_COVERAGE_MAX_BINS}" --top-module testbench \
  "${INC_DIRS[@]}" "${DEFINE_ARGS[@]}" "${COMPILE_FILES[@]}" --Mdir obj_dir >verilator.log 2>&1; then
  echo "ERROR collecting coverage. Verilator failed; see ${WKDIR}/verilator.log" >&2
  exit 1
fi

if ! ./obj_dir/Vtestbench +traceFileList="${TRACEFILELIST}" \
  +verilator+coverage+file+"${COVERAGEDAT}" >sim.log 2>&1; then
  echo "ERROR collecting coverage. Vtestbench failed; see ${WKDIR}/sim.log" >&2
  exit 1
fi

if [[ ! -f ${COVERAGEDAT} ]]; then
  echo "ERROR collecting coverage. ${COVERAGEDAT} not found." >&2
  exit 1
fi

popd >/dev/null
