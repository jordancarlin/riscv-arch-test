# SPDX-License-Identifier: Apache-2.0

"""Sm/S write policies and execution context for complete CSR descriptions."""

from collections.abc import Callable
from dataclasses import replace

from testgen.csr.catalog import CSRS
from testgen.csr.generate import csr_walk_test
from testgen.csr.model import CsrSpec, CsrTestPolicy
from testgen.data.state import TestData

# Preserve the suites' existing division of work and reference-model exclusions.
# Excluded write fields are still described and their readbacks are checked.
MSTATUS_WRITE_EXCLUSIONS = {
    "UBE": "Exercised by endian tests; changing byte order affects signatures.",
    "SBE": "Exercised by endian tests.",
    "MBE": "Exercised by endian tests; changing byte order affects signatures.",
    "UXL": "Exercised by XLEN tests with a compatible execution environment.",
    "SXL": "Exercised by XLEN tests with a compatible execution environment.",
    "SDT": "Double-trap control writes are excluded by Sm's reference-model policy.",
    "MDT": "Double-trap control writes are excluded by Sm's reference-model policy.",
}
MENVCFG_WRITE_EXCLUSIONS = {
    "DTE": "Double-trap control writes are excluded by Sm's reference-model policy.",
    "CDE": "Counter-delegation control writes are excluded by Sm's reference-model policy.",
}
POLICIES = {
    name: CsrTestPolicy(write_fields=tuple(f.name for f in CSRS[name].fields if f.name not in exclusions))
    for names, exclusions in (
        (("mstatus", "mstatush"), MSTATUS_WRITE_EXCLUSIONS),
        (("menvcfg", "menvcfgh"), MENVCFG_WRITE_EXCLUSIONS),
        (("senvcfg",), {}),
    )
    for name in names
}


def suite_csr_test(
    test_data: TestData,
    csr: CsrSpec,
    generator: Callable[..., list[str]],
    covergroup: str,
    coverpoint: str,
) -> list[str]:
    """Apply the suite's field policy and establish safe mstatus write context."""
    policy = POLICIES.get(csr.name, CsrTestPolicy())
    if csr.name != "mstatus":
        return generator(test_data, csr, covergroup, coverpoint, policy=policy)

    # MPRV tests need MPP=M so signature memory accesses retain M-mode access.
    # MPP tests need MPRV=0 so writing U/S does not change those accesses.
    original, temp = test_data.int_regs.get_registers(2)
    lines = [
        "",
        "# Establish MPP=M and MPRV=0 for mstatus tests.",
        f"csrr x{original}, mstatus",
        f"LI(x{temp}, 0x20000)",
        f"csrc mstatus, x{temp}",
        f"LI(x{temp}, 0x1800)",
        f"csrs mstatus, x{temp}",
    ]
    test_data.int_regs.return_register(temp)
    try:
        if generator is csr_walk_test:
            # Walking the entire mstatus value would set MPRV while clearing MPP.
            for field in csr.fields:
                if field.name in (policy.write_fields or ()):
                    lines.extend(
                        generator(
                            test_data, csr, covergroup, coverpoint, policy=replace(policy, write_fields=(field.name,))
                        )
                    )
        else:
            lines.extend(generator(test_data, csr, covergroup, coverpoint, policy=policy))
        lines.extend(["# Restore the caller's mstatus.", f"csrw mstatus, x{original}"])
        return lines
    finally:
        test_data.int_regs.return_register(original)
