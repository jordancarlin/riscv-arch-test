# SPDX-License-Identifier: Apache-2.0

"""Run old/new generated CSR bodies on Spike and Sail in an isolated harness.

The harness compares every signature value and exits through HTIF. It does not
use ACT headers, UDB configuration, or the production trap handler. Its purpose
is to validate the emitted instructions independently of the Python interpreter.
"""

import argparse
import json
import re
import subprocess
from dataclasses import replace
from pathlib import Path

from testgen.csr.evaluate import DEFINES, Write, body, legacy_access, legacy_walk
from testgen.csr.generate import csr_access_test, csr_bitops_test, csr_walk_test
from testgen.csr.model import CsrSpec
from testgen.csr.test_prototype import FIELD_CSRS, execute, field_legalizer
from testgen.data.registers import IntegerRegisterFile


def harness(code: list[str], csr: CsrSpec, xlen: int, initial: int, expected: list[int]) -> str:
    regs = IntegerRegisterFile()
    sig, temp, link = regs.sig_reg, regs.temp_reg, regs.link_reg
    regs.destroy()
    load, store, directive = ("lw", "sw", ".word") if xlen == 32 else ("ld", "sd", ".dword")
    header = f"""#define LI(rd, value) li rd, value
#define LA(rd, symbol) la rd, symbol
#define RVTEST_SIGUPD(sig, link, tmp, value, label, str) {load} tmp, 0(sig); bne tmp, value, failed; addi sig, sig, {xlen // 8}
#define RVTEST_SIGUPD_CSR_READ(csr, rd, label, str) csrr rd, csr; RVTEST_SIGUPD(x{sig}, x{link}, x{temp}, rd, label, str)
.section .text
.global _start
_start:
  LA(x{temp}, unexpected_trap)
  csrw mtvec, x{temp}
  csrw mie, zero
  csrw mstatus, zero
  LI(x{temp}, {initial})
  csrw {csr.name}, x{temp}
  LA(x{sig}, expected_signature)
test_body:
"""
    footer = f"""
test_body_end:
  LA(x{temp}, expected_end)
  bne x{sig}, x{temp}, failed
  LI(x{temp}, 1)
  j finish
failed:
  LI(x{temp}, 3)
  j finish
.balign 4
unexpected_trap:
  LI(x{temp}, 5)
finish:
  LA(x{link}, tohost)
  {store} x{temp}, 0(x{link})
  j finish
.section .data
.balign 8
.global tohost, fromhost
tohost: .dword 0
fromhost: .dword 0
expected_signature:
"""
    data = "\n".join(f"{directive} {value:#x}" for value in expected)
    return header + "\n".join(code) + footer + data + "\nexpected_end:\n"


def simulate(output: Path) -> list[dict[str, object]]:
    output.mkdir(parents=True, exist_ok=True)
    linker = output / "harness.ld"
    linker.write_text(
        "ENTRY(_start)\nSECTIONS {\n"
        "  . = 0x80000000;\n"
        "  .text : { *(.text*) }\n"
        "  .data : { *(.data*) }\n"
        "  .bss : { *(.bss*) }\n"
        "}\n"
    )
    cbie = field_legalizer(4, (0, 1, 3), 0)
    pmm = field_legalizer(32, (0, 2, 3), 0)
    scenarios: list[tuple[str, CsrSpec, int, Write]] = [
        ("mscratch", FIELD_CSRS["mscratch"], 0, lambda value, op: value),
        ("sscratch", FIELD_CSRS["sscratch"], 0, lambda value, op: value),
        ("mstatus", FIELD_CSRS["mstatus"], 3 << 11, field_legalizer(11, (0, 1, 3), 0)),
        ("menvcfg", replace(FIELD_CSRS["menvcfg"], fields=(FIELD_CSRS["menvcfg"].fields[0],)), 0, cbie),
        ("menvcfg_fields", FIELD_CSRS["menvcfg"], 0, lambda value, op: pmm(cbie(value, op), op)),
    ]
    results: list[dict[str, object]] = []
    for scenario, csr, initial, legalize in scenarios:
        for implementation in ("old", "new"):
            if implementation == "old" and scenario in ("sscratch", "menvcfg_fields"):
                continue  # The legacy comparison adapter handles only the three like-for-like cases.
            generators = (legacy_access, legacy_walk) if implementation == "old" else (csr_access_test, csr_bitops_test)
            if scenario == "menvcfg_fields":
                generators = (csr_access_test, csr_walk_test, csr_bitops_test)
            code = body(csr, generators)
            for xlen in (32, 64):
                expected = execute(code, xlen, initial, legalize, DEFINES)[0]
                variants = ("normal", "ignored_set") if csr.name == "mscratch" else ("normal",)
                for variant in variants:
                    tested = (
                        ["# omitted csrs" if line.startswith("csrs ") else line for line in code]
                        if variant == "ignored_set"
                        else code
                    )
                    name = f"{implementation}_{scenario}_rv{xlen}_{variant}"
                    source, elf = output / f"{name}.S", output / f"{name}.elf"
                    source.write_text(harness(tested, csr, xlen, initial, expected))
                    command = [
                        "riscv64-unknown-elf-gcc",
                        "-nostdlib",
                        "-static",
                        "-mno-relax",
                        f"-march=rv{xlen}im_zicsr_zicbom",
                        "-mabi=" + ("ilp32" if xlen == 32 else "lp64"),
                        f"-Wl,-T,{linker},--no-relax",
                        *[f"-D{d}" for d in DEFINES],
                        str(source),
                        "-o",
                        str(elf),
                    ]
                    compiled = subprocess.run(command, check=False, capture_output=True, text=True)
                    if compiled.returncode:
                        raise RuntimeError(f"Failed to compile {source}:\n{compiled.stderr}")
                    symbols = subprocess.run(
                        ["riscv64-unknown-elf-nm", str(elf)], check=True, capture_output=True, text=True
                    ).stdout
                    addresses = {
                        m[2]: int(m[1], 16)
                        for m in re.finditer(r"^([0-9a-f]+) \w (test_body(?:_end)?)$", symbols, re.MULTILINE)
                    }
                    for simulator in ("spike", "sail_riscv_sim"):
                        command = (
                            [simulator, f"--isa=rv{xlen}im_zicsr_zicbom", "-m64", str(elf)]
                            if simulator == "spike"
                            else [simulator, *(["--rv32"] if xlen == 32 else []), "--inst-limit", "1000000", str(elf)]
                        )
                        result = subprocess.run(command, check=False, capture_output=True, text=True, timeout=20)
                        log = output / f"{name}_{simulator}.log"
                        log.write_text(result.stdout + result.stderr)
                        expected_exit = 1 if variant == "ignored_set" else 0
                        passed = result.returncode == expected_exit
                        if simulator == "sail_riscv_sim":
                            marker = "FAILURE: 1 (0x00000001)" if variant == "ignored_set" else "SUCCESS"
                            passed = passed and marker in result.stdout + result.stderr
                        elif variant == "ignored_set":
                            passed = passed and "*** FAILED *** (tohost = 1)" in result.stderr
                        results.append(
                            {
                                "case": name,
                                "simulator": simulator,
                                "checks": len(expected),
                                "body_bytes": addresses["test_body_end"] - addresses["test_body"],
                                "exit": result.returncode,
                                "expected_exit": expected_exit,
                                "passed": passed,
                            }
                        )
                        print(f"{'PASS' if passed else 'FAIL'} {name} {simulator}", flush=True)
                        if not passed:
                            print((result.stdout + result.stderr)[-1500:], flush=True)
    (output / "simulation.json").write_text(json.dumps(results, indent=2) + "\n")
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    results = simulate(args.output)
    if not all(row["passed"] for row in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
