##################################
# test_bench_framework.py
#
# CodSpeed performance benchmarks for the `act` framework.
# SPDX-License-Identifier: Apache-2.0
#
# These benchmarks exercise the CPU-bound hot paths of the test framework:
# parsing YAML config headers out of the .S test files, validating that
# metadata through pydantic, selecting tests against a DUT configuration, and
# converting Sail logs into RVVI traces.
##################################

from __future__ import annotations

from pathlib import Path

import pytest

# TestMetadata is aliased so pytest does not try to collect the pydantic model as a test class.
from act.parse_test_constraints import TestMetadata as Metadata
from act.parse_test_constraints import extract_yaml_config, generate_test_dict
from act.sail_to_rvvi import sailLog2Trace
from act.select_tests import ConfigParamValue, check_test_params, select_tests

REPO_ROOT = Path(__file__).resolve().parent.parent
TESTS_DIR = REPO_ROOT / "tests"

# A bounded, deterministic sample of real test files so the benchmarks stay
# stable and fast while remaining representative of production workloads.
SAMPLE_SIZE = 200


def _sample_test_files() -> list[Path]:
    files = sorted(TESTS_DIR.rglob("*.S"))
    if not files:
        pytest.skip("No .S test files available to benchmark")
    return files[:SAMPLE_SIZE]


def test_extract_yaml_config(benchmark: object) -> None:
    """Parse the YAML config header out of a single representative test file."""
    test_file = _sample_test_files()[0]

    result = benchmark(extract_yaml_config, test_file)  # type: ignore[operator]

    assert isinstance(result, Metadata)


def test_extract_yaml_config_batch(benchmark: object) -> None:
    """Parse YAML config headers across a batch of real test files."""
    files = _sample_test_files()

    def parse_all() -> int:
        return sum(1 for f in files if extract_yaml_config(f))

    count = benchmark(parse_all)  # type: ignore[operator]

    assert count == len(files)


def test_generate_test_dict_rv32i(benchmark: object) -> None:
    """Discover and parse the metadata for every rv32i test on disk."""
    rv32i_dir = TESTS_DIR / "rv32i"
    if not rv32i_dir.is_dir():
        pytest.skip("rv32i tests not available")

    result = benchmark(generate_test_dict, rv32i_dir, "all")  # type: ignore[operator]

    assert len(result) > 0


def test_select_tests(benchmark: object) -> None:
    """Select the matching tests for a DUT configuration from a full test dict."""
    test_dict = generate_test_dict(TESTS_DIR / "rv32i", "all")
    if not test_dict:
        pytest.skip("rv32i tests not available")

    implemented_extensions = {"I", "M", "A", "F", "D", "C", "Zicsr", "Zifencei"}
    config_params: dict[str, ConfigParamValue] = {"MXLEN": 32, "FLEN": 64}

    result = benchmark(  # type: ignore[operator]
        select_tests,
        test_dict,
        implemented_extensions,
        config_params,
    )

    assert isinstance(result, dict)


def test_check_test_params(benchmark: object) -> None:
    """Evaluate parameter constraint comparisons (hot inner loop of selection)."""
    test_params: dict[str, int | bool | str] = {
        "MXLEN": ">=32",
        "FLEN": "<=64",
        "VLEN": "!=0",
        "XLEN": "==32",
    }
    config_params: dict[str, ConfigParamValue] = {"MXLEN": 64, "FLEN": 64, "VLEN": 128, "XLEN": 32}

    def run() -> bool:
        matched = True
        for _ in range(1000):
            matched = check_test_params(test_params, config_params)
        return matched

    assert benchmark(run) is True  # type: ignore[operator]


def test_flen_property(benchmark: object) -> None:
    """Derive FLEN from a variety of march strings (regex-backed property)."""
    marches = [
        "rv32i_zicsr_zifencei",
        "rv32if_zicsr",
        "rv32ifd_zicsr_zifencei",
        "rv64gc",
        "rv32i_f_d_zfhmin",
        "rv64i_q_zicsr",
    ]
    metadatas = [
        Metadata.model_validate(
            {
                "test_path": str(_sample_test_files()[0]),
                "REQUIRED_EXTENSIONS": ["I"],
                "MARCH": march,
            }
        )
        for march in marches
    ]

    def run() -> list[str]:
        return [m.flen for m in metadatas]

    result = benchmark(run)  # type: ignore[operator]
    assert result == ["32", "32", "64", "64", "64", "128"]


def test_sail_log_to_trace(benchmark: object, tmp_path: Path) -> None:
    """Convert a synthetic Sail log into an RVVI trace (regex-heavy parsing)."""
    lines: list[str] = []
    for step in range(2000):
        mode = "MSU"[step % 3]
        pc = 0x80000000 + step * 4
        lines.append(f"[{step}] [{mode}]: 0x{pc:08x} (0x00000013) addi x0, x0, 0")
        lines.append(f"x{step % 31 + 1} <- 0x{step:016x}")
        if step % 5 == 0:
            lines.append(f"CSR mstatus (0x{step:016x}) <- 0x{step + 1:016x}")
        if step % 7 == 0:
            lines.append(f"f{step % 31} <- 0x{step:016x}")

    input_log = tmp_path / "sail.log"
    input_log.write_text("\n".join(lines) + "\n")
    output_trace = tmp_path / "trace.rvvi"

    benchmark(sailLog2Trace, input_log, output_trace)  # type: ignore[operator]

    assert output_trace.exists()
