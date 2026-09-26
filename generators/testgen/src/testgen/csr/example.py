# SPDX-License-Identifier: Apache-2.0

"""Generate the opt-in CSR proof of concept through the normal priv pipeline."""

import argparse
from pathlib import Path

from testgen.csr.catalog import CSRS
from testgen.csr.generate import csr_access_test, csr_bitops_test, csr_field_values_test, csr_walk_test
from testgen.csr.model import CsrTestPolicy
from testgen.csr.suites import suite_csr_test
from testgen.data.state import TestData
from testgen.data.test_chunk import TestChunk
from testgen.generate.priv import generate_priv_test
from testgen.priv.registry import add_priv_test_generator


@add_priv_test_generator("CsrPoc", required_extensions=["Sm"])
def make_csr_poc(test_data: TestData) -> list[TestChunk]:
    """Each example is independent, including guards and CSR restoration."""
    chunks: list[TestChunk] = []
    for csr in CSRS.values():
        for generator, kind in ((csr_access_test, "access"), (csr_walk_test, "walk"), (csr_bitops_test, "bitops")):
            tc = test_data.begin_test_chunk(f"{csr.name}_{kind}")
            tc.code.extend(suite_csr_test(test_data, csr, generator, "CsrPoc_cg", f"cp_{kind}"))
            chunks.append(test_data.end_test_chunk())

    tc = test_data.begin_test_chunk("menvcfg_cbie_values")
    tc.code.extend(csr_field_values_test(test_data, CSRS["menvcfg"], "CBIE", range(4), "CsrPoc_cg", "cp_values"))
    chunks.append(test_data.end_test_chunk())

    tc = test_data.begin_test_chunk("menvcfg_pmm_only")
    tc.code.extend(
        csr_walk_test(
            test_data,
            CSRS["menvcfg"],
            "CsrPoc_cg",
            "cp_pmm_only",
            policy=CsrTestPolicy(write_fields=("PMM",)),
        )
    )
    chunks.append(test_data.end_test_chunk())
    return chunks


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Output directory, e.g. /tmp/csr-poc")
    args = parser.parse_args()
    generate_priv_test("CsrPoc", args.output)


if __name__ == "__main__":
    main()
