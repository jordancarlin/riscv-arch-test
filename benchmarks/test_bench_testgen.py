##################################
# test_bench_testgen.py
#
# CodSpeed performance benchmarks for the `testgen` package.
# SPDX-License-Identifier: Apache-2.0
#
# These benchmarks exercise the CPU-bound hot paths of the RISC-V test
# generator: reading CSV testplans, discovering the available unprivileged and
# privileged extensions, and the end-to-end generation of the assembly test
# files for a testsuite (coverpoint expansion + assembly emission + writing).
##################################

from __future__ import annotations

from pathlib import Path

import pytest
from testgen.generate import generate_priv_test, generate_unpriv_extension_tests
from testgen.io.testplans import get_extensions, read_testplan
from testgen.priv import get_priv_test_extensions

REPO_ROOT = Path(__file__).resolve().parent.parent
TESTPLAN_DIR = REPO_ROOT / "testplans"


def _require_testplan(name: str) -> Path:
    testplan = TESTPLAN_DIR / f"{name}.csv"
    if not testplan.is_file():
        pytest.skip(f"Testplan {name}.csv not available")
    return testplan


def test_read_testplan(benchmark: object) -> None:
    """Parse a single CSV testplan into structured instruction metadata."""
    testplan = _require_testplan("I")

    result = benchmark(read_testplan, testplan)  # type: ignore[operator]

    assert len(result) > 0


def test_get_extensions(benchmark: object) -> None:
    """Discover every unprivileged extension from the testplan directory."""
    if not TESTPLAN_DIR.is_dir():
        pytest.skip("Testplan directory not available")

    result = benchmark(get_extensions, TESTPLAN_DIR)  # type: ignore[operator]

    assert len(result) > 0


def test_get_priv_test_extensions(benchmark: object) -> None:
    """Discover every registered privileged test extension (registry scan)."""
    result = benchmark(get_priv_test_extensions)  # type: ignore[operator]

    assert len(result) > 0


def test_generate_unpriv_i_rv32(benchmark: object, tmp_path: Path) -> None:
    """Generate the full rv32i base integer testsuite end to end."""
    _require_testplan("I")

    benchmark(  # type: ignore[operator]
        generate_unpriv_extension_tests,
        xlen=32,
        E_ext=False,
        testsuite="I",
        testplan_dir=TESTPLAN_DIR,
        output_test_dir=tmp_path,
    )

    assert any(tmp_path.rglob("*.S"))


def test_generate_unpriv_i_rv64(benchmark: object, tmp_path: Path) -> None:
    """Generate the full rv64i base integer testsuite end to end."""
    _require_testplan("I")

    benchmark(  # type: ignore[operator]
        generate_unpriv_extension_tests,
        xlen=64,
        E_ext=False,
        testsuite="I",
        testplan_dir=TESTPLAN_DIR,
        output_test_dir=tmp_path,
    )

    assert any(tmp_path.rglob("*.S"))


def test_generate_unpriv_m_rv64(benchmark: object, tmp_path: Path) -> None:
    """Generate the rv64 M (multiply/divide) testsuite end to end."""
    _require_testplan("M")

    benchmark(  # type: ignore[operator]
        generate_unpriv_extension_tests,
        xlen=64,
        E_ext=False,
        testsuite="M",
        testplan_dir=TESTPLAN_DIR,
        output_test_dir=tmp_path,
    )

    assert any(tmp_path.rglob("*.S"))


def test_generate_priv(benchmark: object, tmp_path: Path) -> None:
    """Generate a privileged testsuite end to end (register setup + emission)."""
    extensions = sorted(get_priv_test_extensions())
    if not extensions:
        pytest.skip("No privileged test extensions registered")
    testsuite = extensions[0]

    benchmark(  # type: ignore[operator]
        generate_priv_test,
        testsuite=testsuite,
        output_test_dir=tmp_path,
    )

    assert any(tmp_path.rglob("*.S"))
