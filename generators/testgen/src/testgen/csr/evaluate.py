# SPDX-License-Identifier: Apache-2.0

"""Reproducible comparison of old/new CSR generators using controlled faults.

Only the generated bodies are interpreted. CSR signature macros are treated as
reads, so this does not stand in for framework or architectural coverage runs.
"""

import argparse
import json
from collections.abc import Callable
from dataclasses import replace
from pathlib import Path
from random import seed

from testgen.asm.csr import csr_access_test as old_access
from testgen.asm.csr import csr_walk_test as old_walk
from testgen.csr.generate import csr_access_test, csr_bitops_test, csr_walk_test
from testgen.csr.model import CsrSpec, CsrTestPolicy
from testgen.csr.test_prototype import FIELD_CSRS, execute, field_legalizer
from testgen.data.config import TestConfig
from testgen.data.state import TestData

Generator = Callable[[TestData, CsrSpec, str, str], list[str]]
Write = Callable[[int, str], int]
DEFINES = ("U_SUPPORTED", "S_SUPPORTED", "SM1P12P0_OR_LATER_SUPPORTED", "ZICBOM_SUPPORTED")


def body(csr: CsrSpec, generators: tuple[Generator, ...]) -> list[str]:
    seed(0)
    data = TestData(TestConfig(xlen=0, flen=64, testsuite="CsrPoc", required_extensions=["Sm"]))
    data.int_regs.consume_registers([0])
    data.begin_test_chunk()
    lines = [line for index, generator in enumerate(generators) for line in generator(data, csr, "cg", f"cp_{index}")]
    data.end_test_chunk()
    data.int_regs.return_register(0)
    data.destroy()
    return lines


def legacy_access(data: TestData, csr: CsrSpec, cg: str, cp: str) -> list[str]:
    mask = None if csr.name == "mscratch" else sum(f.mask(64) for f in csr.fields)
    return old_access(data, (csr.name, mask), cg, cp, maskedwrites=mask is not None)


def legacy_walk(data: TestData, csr: CsrSpec, cg: str, cp: str) -> list[str]:
    if csr.name == "mscratch":
        return old_walk(data, (csr.name, None), cg, cp)
    field = csr.fields[0]
    reserved = [("mpp", 11, 2, 2), ("mpp", 11, 2, 1, "S_SUPPORTED")] if field.name == "MPP" else [("cbie", 4, 2, 2)]
    return old_walk(data, (csr.name, field.mask(64)), cg, cp, maskedwrites=True, warl_fields=reserved)


def compare(output: Path) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    report: dict[str, object] = {}
    scratch = FIELD_CSRS["mscratch"]
    old = body(scratch, (legacy_access, legacy_walk))
    new = body(scratch, (csr_access_test, csr_bitops_test))
    for name, code in (("old", old), ("new", new)):
        (output / f"{name}_mscratch.S").write_text("\n".join(code) + "\n")
    for xlen in (32, 64):
        mask = (1 << xlen) - 1
        outcomes: dict[str, object] = {}
        for name, code in (("old", old), ("new", new)):
            expected = execute(code, xlen, 0)[0]
            misses = []
            count = 0
            for bit in range(xlen):
                for stuck in (0, 1):

                    def write(value: int, op: str, bit: int = bit, stuck: int = stuck) -> int:
                        return value | (1 << bit) if stuck else value & ~(1 << bit)

                    if execute(code, xlen, 0, write)[0] == expected:
                        misses.append(f"bit_{bit}_stuck_{stuck}")
                    count += 1
            for op in ("csrs", "csrc"):

                def rotate(value: int, instruction: str, op: str = op, xlen: int = xlen, mask: int = mask) -> int:
                    return ((value << 1) | (value >> (xlen - 1))) & mask if instruction == op else value

                if execute(code, xlen, 0, operand_transform=rotate)[0] == expected:
                    misses.append(f"{op}_rotated_operand")
                count += 1
            outcomes[name] = {"checks": len(expected), "faults": count, "misses": misses}
        report[f"rv{xlen}_rw"] = outcomes

    mpp = FIELD_CSRS["mstatus"]
    old_mpp = body(mpp, (legacy_access, legacy_walk))
    new_mpp = body(mpp, (csr_access_test, csr_walk_test, csr_bitops_test))
    for name, code in (("old", old_mpp), ("new", new_mpp)):
        (output / f"{name}_mpp.S").write_text("\n".join(code) + "\n")
        outcomes = {}
        for xlen in (32, 64):
            definitions = ("S_SUPPORTED",)
            reference = field_legalizer(11, (1, 3), 3)
            alternate = field_legalizer(11, (1, 3), 1)
            expected = execute(code, xlen, 3 << 11, reference, definitions)[0]
            other = execute(code, xlen, 3 << 11, alternate, definitions)[0]
            outcomes[f"rv{xlen}_accepts_alternate_legalization"] = expected == other

            reference = field_legalizer(11, (3,), 3)

            def reserved_to_s(value: int, op: str) -> int:
                return (value & ~(3 << 11)) | ((1 if ((value >> 11) & 3) == 2 else 3) << 11)

            expected = execute(code, xlen, 3 << 11, reference)[0]
            faulty = execute(code, xlen, 3 << 11, reserved_to_s)[0]
            outcomes[f"rv{xlen}_rejects_unsupported_s"] = expected != faulty
        report[f"{name}_mpp"] = outcomes

    cbie = replace(FIELD_CSRS["menvcfg"], fields=(FIELD_CSRS["menvcfg"].fields[0],))
    old_cbie = body(cbie, (legacy_access, legacy_walk))
    new_cbie = body(cbie, (csr_access_test, csr_walk_test, csr_bitops_test))
    for name, code in (("old", old_cbie), ("new", new_cbie)):
        required = execute(code, 64, 0, field_legalizer(4, (0, 1, 3), 0), DEFINES)[0]
        faulty = execute(code, 64, 0, field_legalizer(4, (0,), 0), DEFINES)[0]
        report[f"{name}_cbie_rejects_missing_required_values"] = required != faulty

    # A subset policy must observe collateral corruption by default.
    policy = CsrTestPolicy(write_fields=("CBIE",))
    code = body(FIELD_CSRS["menvcfg"], (lambda d, c, g, p: csr_access_test(d, c, g, p, policy=policy),))
    legal = field_legalizer(4, (0, 1, 3), 0)
    initial = 2 << 32
    reference = execute(code, 64, initial, legal, DEFINES)[0]
    faulty = execute(code, 64, initial, lambda value, op: legal(value, op) & ~(3 << 32), DEFINES)[0]
    report["new_rejects_collateral_field_corruption"] = reference != faulty
    (output / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(json.dumps(compare(args.output), indent=2))


if __name__ == "__main__":
    main()
