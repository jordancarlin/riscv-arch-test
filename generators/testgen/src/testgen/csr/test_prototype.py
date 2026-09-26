# SPDX-License-Identifier: Apache-2.0

"""Execute the prototype's emitted integer operations against small CSR models.

This deliberately limited interpreter checks the emitted predicates, not an
independent Python version of those predicates. It is not an ISA simulator.
"""

import re
import unittest
from collections.abc import Callable
from dataclasses import replace

from testgen.csr.catalog import CBIE, CSRS, MPP, PMM
from testgen.csr.generate import csr_access_test, csr_bitops_test, csr_field_values_test, csr_walk_test
from testgen.csr.model import CsrField, CsrSpec, CsrTestPolicy
from testgen.csr.suites import POLICIES, suite_csr_test
from testgen.data.config import TestConfig
from testgen.data.state import TestData

# Small independent field models used by the instruction interpreter.
FIELD_CSRS = {
    **CSRS,
    "mstatus": replace(CSRS["mstatus"], fields=(MPP,)),
    "menvcfg": replace(CSRS["menvcfg"], fields=(CBIE, PMM)),
    "menvcfgh": replace(CSRS["menvcfgh"], fields=(replace(PMM, lsb=0, xlens=(32,)),)),
}


def execute(
    code: list[str],
    xlen: int,
    initial: int,
    write: Callable[[int, str], int] = lambda value, op: value,
    defines: tuple[str, ...] = (),
    operand_transform: Callable[[int, str], int] = lambda value, op: value,
) -> tuple[list[int], list[int], int]:
    active = [True]
    instructions: list[str] = []
    for raw in "\n".join(code).splitlines():
        line = raw.strip()
        if line.startswith("#ifdef "):
            line = f"#if defined({line.split()[1]})"
        if line.startswith(("#if ", "#else", "#endif")):
            line = line.split("//", 1)[0].strip()
        elif not line.startswith("#"):
            line = line.split("#", 1)[0].strip()
        if line.startswith("#if "):
            condition = line[4:]
            if condition.startswith("__riscv_xlen == "):
                enabled = xlen == int(condition.split()[-1])
            elif match := re.fullmatch(r"defined\((\w+)\)", condition):
                enabled = match[1] in defines
            else:
                raise AssertionError(f"Unknown condition: {condition}")
            active.append(active[-1] and enabled)
        elif line == "#endif":
            active.pop()
        elif line == "#else":
            active[-1] = active[-2] and not active[-1]
        elif active[-1] and line and not line.startswith(("#", "//")):
            instructions.append(line)
    assert active == [True]
    labels = {line[:-1]: i for i, line in enumerate(instructions) if line.endswith(":")}
    regs: dict[str, int] = {"zero": 0, "x0": 0}
    mask = (1 << xlen) - 1
    csr = initial & mask
    signatures: list[int] = []
    writes: list[int] = []
    pc = 0
    while pc < len(instructions):
        line = instructions[pc]
        pc += 1
        if line.endswith(":"):
            continue
        op, *args = re.split(r"[\s,()]+", line.rstrip(")"))
        if op == "LI":
            value = int(args[1], 0)
        elif op == "csrr":
            value = csr
        elif op == "mv":
            value = regs[args[1]]
        elif op in ("csrw", "csrs", "csrc"):
            operand = operand_transform(regs[args[1]], op) & mask
            candidate = operand if op == "csrw" else (csr | operand if op == "csrs" else csr & ~operand)
            csr = write(candidate & mask, op) & mask
            writes.append(csr)
            continue
        elif op == "srli":
            value = regs[args[1]] >> int(args[2])
        elif op == "slli":
            value = regs[args[1]] << int(args[2])
        elif op == "andi":
            value = regs[args[1]] & int(args[2], 0)
        elif op == "xori":
            value = regs[args[1]] ^ int(args[2], 0)
        elif op == "and":
            value = regs[args[1]] & regs[args[2]]
        elif op == "or":
            value = regs[args[1]] | regs[args[2]]
        elif op == "xor":
            value = regs[args[1]] ^ regs[args[2]]
        elif op == "not":
            value = ~regs[args[1]]
        elif op == "seqz":
            value = int(regs[args[1]] == 0)
        elif op == "snez":
            value = int(regs[args[1]] != 0)
        elif op == "beqz":
            if regs[args[0]] == 0:
                pc = labels[args[1]]
            continue
        elif op == "j":
            pc = labels[args[0]]
            continue
        elif op == "RVTEST_SIGUPD":
            signatures.append(regs[args[3]])
            continue
        elif op == "RVTEST_SIGUPD_CSR_READ":
            signatures.append(csr)
            regs[args[1]] = csr
            continue
        else:
            raise AssertionError(f"Unknown instruction: {line}")
        if args[0] != "x0":
            regs[args[0]] = value & mask
    return signatures, writes, csr


def field_legalizer(lsb: int, legal: tuple[int, ...], fallback: int) -> Callable[[int, str], int]:
    def write(value: int, op: str) -> int:
        field_value = (value >> lsb) & 3
        return (value & ~(3 << lsb)) | ((field_value if field_value in legal else fallback) << lsb)

    return write


class CsrPrototypeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.data = TestData(TestConfig(xlen=0, flen=64, testsuite="CsrPoc", required_extensions=["Sm"]))
        self.data.int_regs.consume_registers([0])
        self.data.begin_test_chunk()

    def tearDown(self) -> None:
        self.data.end_test_chunk()
        self.data.int_regs.return_register(0)
        self.data.destroy()

    def test_suite_policies_check_all_fields(self) -> None:
        for name in ("mstatus", "mstatush", "menvcfg", "menvcfgh", "senvcfg"):
            csr = CSRS[name]
            for xlen in csr.xlens:
                with self.subTest(csr=name, xlen=xlen):
                    policy = POLICIES[name]
                    self.assertEqual(
                        {f.name for f in policy.select(csr, xlen, checking=True)},
                        {f.name for f in csr.fields if xlen in f.xlens},
                    )

    def test_read_only_summary_and_undescribed_bit_preservation(self) -> None:
        csr = CsrSpec(
            "example",
            0x340,
            "M",
            (
                CsrField("VALUE", 0, 1),
                CsrField("SUMMARY", 4, 1, "RO"),
            ),
        )
        code = csr_bitops_test(self.data, csr, "cg", "readonly")

        def derived(value: int, op: str) -> int:
            return (value & ~0x10) | ((value & 1) << 4)

        signatures, writes, restored = execute(code, 64, 0xA, derived)
        self.assertEqual(signatures, [1, 1, 0, 0, 0, 0, 0, 0])
        self.assertTrue(all(value & 0xE == 0xA for value in writes))
        self.assertEqual(restored, 0xA)
        self.assertNotEqual(execute(code, 64, 0xA)[0], signatures)

    def test_mstatus_context_keeps_signature_accesses_in_m_mode(self) -> None:
        legalize = field_legalizer(11, (0, 1, 3), 3)

        def write(value: int, op: str) -> int:
            if value & (1 << 17):
                self.assertEqual((value >> 11) & 3, 3)
            return legalize(value, op)

        for generator in (csr_access_test, csr_bitops_test, csr_walk_test):
            code = suite_csr_test(self.data, CSRS["mstatus"], generator, "cg", generator.__name__)
            for xlen in (32, 64):
                with self.subTest(generator=generator.__name__, xlen=xlen):
                    _, _, restored = execute(code, xlen, 1 << 11, write, ("U_SUPPORTED", "S_SUPPORTED"))
                    self.assertEqual(restored, 1 << 11)

    def test_scratch_access_and_walk(self) -> None:
        for generator in (csr_access_test, csr_walk_test, csr_bitops_test):
            before = self.data.test_count
            code = generator(self.data, FIELD_CSRS["mscratch"], "cg", generator.__name__)
            self.assertEqual(self.data.test_count - before, 4 if generator is csr_access_test else 128)
            for xlen in (32, 64):
                with self.subTest(generator=generator.__name__, xlen=xlen):
                    signatures, _, restored = execute(code, xlen, 0xABCD)
                    ones = (1 << xlen) - 1
                    expected = (
                        [ones, 0, ones, 0]
                        if generator is csr_access_test
                        else [1 << bit for bit in range(xlen)] + [ones ^ (1 << bit) for bit in range(xlen)]
                    )
                    self.assertEqual(signatures, expected)
                    self.assertEqual(restored, 0xABCD)

    def test_shared_fixed_layout_preserves_upper_bits(self) -> None:
        csr = CsrSpec("example", 0x340, "M", (CsrField("LOW", 0, 32),))
        for generator in (csr_access_test, csr_walk_test, csr_bitops_test):
            before = self.data.test_count
            code = generator(self.data, csr, "cg", generator.__name__)
            self.assertEqual(self.data.test_count - before, 4 if generator is csr_access_test else 64)
            for xlen in (32, 64):
                initial = 0xABCDEF0123456789 & ((1 << xlen) - 1)
                signatures, writes, restored = execute(code, xlen, initial)
                expected = (
                    [0xFFFFFFFF, 0, 0xFFFFFFFF, 0]
                    if generator is csr_access_test
                    else [1 << bit for bit in range(32)] + [0xFFFFFFFF ^ (1 << bit) for bit in range(32)]
                )
                self.assertEqual(signatures, expected)
                self.assertTrue(all(value >> 32 == initial >> 32 for value in writes))
                self.assertEqual(restored, initial)

    def test_sparse_walk_shifts_over_gaps(self) -> None:
        csr = CsrSpec("example", 0x340, "M", (CsrField("A", 1, 1), CsrField("B", 7, 1)))
        code = csr_walk_test(self.data, csr, "cg", "walk")
        for xlen in (32, 64):
            initial = 0xCAFE & ~0x82
            signatures, writes, restored = execute(code, xlen, initial)
            self.assertEqual(signatures, [1, 0, 0, 1, 0, 1, 1, 0])
            self.assertEqual(writes, [initial | value for value in (2, 128, 128, 2, 0)])
            self.assertEqual(restored, initial)

    def test_common_fields_shared_with_xlen_specific_fields(self) -> None:
        common = CsrField("COMMON", 4, 2)
        low = CsrField("RV32_ONLY", 0, 2, xlens=(32,))
        high = CsrField("RV64_ONLY", 32, 2, xlens=(64,))
        csr = CsrSpec("mixed", 0x340, "M", (common, low, high))
        for generator in (csr_access_test, csr_walk_test):
            before = self.data.test_count
            code = generator(self.data, csr, "cg", generator.__name__)
            self.assertEqual(self.data.test_count - before, 12 if generator is csr_access_test else 28)
            for xlen, other in ((32, low), (64, high)):
                mask = common.mask(xlen) | other.mask(xlen)
                initial = 0xABCDEFFF12345678 & ((1 << xlen) - 1)
                bits = [bit for bit in range(xlen) if mask & (1 << bit)]
                candidates = (
                    [mask, 0, mask, 0]
                    if generator is csr_access_test
                    else [1 << bit for bit in bits] + [mask ^ (1 << bit) for bit in bits]
                )
                expected = [value >> field.lsb & 3 for value in candidates for field in (common, other)]
                signatures, writes, restored = execute(code, xlen, initial)
                self.assertEqual(signatures, expected)
                self.assertEqual(writes, [(initial & ~mask) | value for value in candidates] + [initial])
                self.assertEqual(restored, initial)

        # The operation still runs on RV64 when its first observed field is RV32-only.
        csr = replace(csr, fields=(low, common, high))
        code = csr_access_test(self.data, csr, "cg", "reordered")
        self.assertEqual(execute(code, 64, 0)[0], [3, 3, 0, 0, 3, 3, 0, 0])

    def test_mpp_complete_domain_and_legal_write_retention(self) -> None:
        code = csr_field_values_test(self.data, FIELD_CSRS["mstatus"], "MPP", range(4), "cg", "values")
        for defines, legal in (((), (3,)), (("U_SUPPORTED",), (0, 3)), (("S_SUPPORTED",), (1, 3))):
            with self.subTest(defines=defines):
                signatures, _, _ = execute(code, 64, 3 << 11, field_legalizer(11, legal, 3), defines)
                self.assertEqual(signatures, [value if value in legal else 1 for value in range(4)])

        # Return S for the reserved encoding 2 on an M-only implementation.
        def illegal(value: int, op: str) -> int:
            return (value & ~(3 << 11)) | ((1 if (value >> 11) & 3 == 2 else 3) << 11)

        signatures, _, _ = execute(code, 64, 3 << 11, illegal)
        self.assertEqual(signatures, [1, 1, 0, 3])

        # Keeping MPP=M is legal but must fail a supported write of MPP=U.
        signatures, _, _ = execute(code, 64, 3 << 11, lambda value, op: 3 << 11, ("U_SUPPORTED",))
        self.assertEqual(signatures, [3, 1, 1, 3])

        access = csr_access_test(self.data, FIELD_CSRS["mstatus"], "cg", "access")
        signatures, _, _ = execute(access, 64, 3 << 11, field_legalizer(11, (0, 3), 3), ("U_SUPPORTED",))
        self.assertEqual(signatures, [3, 0, 3, 0])

    def test_walk_writes_complete_patterns(self) -> None:
        code = csr_walk_test(self.data, FIELD_CSRS["mstatus"], "cg", "walk")
        for fallback in (1, 3):
            legalize = field_legalizer(11, (1, 3), fallback)
            requests: list[tuple[int, str]] = []

            def record_write(
                value: int,
                op: str,
                requests: list[tuple[int, str]] = requests,
                legalize: Callable[[int, str], int] = legalize,
            ) -> int:
                requests.append(((value >> 11) & 3, op))
                return legalize(value, op)

            signatures, _, _ = execute(code, 64, 3 << 11, record_write, ("S_SUPPORTED",))
            self.assertEqual(signatures, [1, 1, 1, 1])
            self.assertEqual(requests, [(value, "csrw") for value in (1, 2, 2, 1, 3)])

        # Ignoring a supported write still exposes the wrong raw readback.
        signatures, _, _ = execute(code, 64, 3 << 11, lambda value, op: 3 << 11, ("S_SUPPORTED",))
        self.assertEqual(signatures, [3, 1, 1, 3])

    def test_access_detects_ignored_set_and_clear(self) -> None:
        code = csr_access_test(self.data, FIELD_CSRS["mscratch"], "cg", "access")
        ones = (1 << 64) - 1
        for ignored, expected in (("csrs", [ones, 0, 0, 0]), ("csrc", [ones, 0, ones, ones])):
            state = 0

            def write(value: int, op: str, ignored: str = ignored) -> int:
                nonlocal state
                if op != ignored:
                    state = value
                return state

            signatures, _, _ = execute(code, 64, 0, write)
            self.assertEqual(signatures, expected)
            self.assertNotEqual(signatures, [ones, 0, ones, 0])

    def test_warl_envelope_allows_supported_subsets(self) -> None:
        code = csr_field_values_test(
            self.data,
            FIELD_CSRS["menvcfg"],
            "CBIE",
            range(4),
            "cg",
            "values",
            policy=CsrTestPolicy(check_fields=("CBIE",)),
        )
        defines = ("SM1P12P0_OR_LATER_SUPPORTED",)
        for fallback in (0, 1, 3):
            signatures, _, _ = execute(code, 64, 0, field_legalizer(4, (0, 1, 3), fallback), defines)
            self.assertEqual(signatures, [0, 1, 1, 1])
        signatures, _, _ = execute(code, 64, 0, field_legalizer(4, (0,), 0), defines)
        self.assertEqual(signatures, [0, 1, 1, 1])
        signatures, _, _ = execute(code, 64, 0, defines=defines)
        self.assertEqual(signatures, [0, 1, 0, 1])

        required = (*defines, "ZICBOM_SUPPORTED")
        signatures, _, _ = execute(code, 64, 0, field_legalizer(4, (0, 1, 3), 0), required)
        self.assertEqual(signatures, [0, 1, 1, 3])
        self.assertEqual(execute(code, 64, 0, field_legalizer(4, (0,), 0), required)[0], [0, 0, 1, 0])

    def test_field_selection_preserves_other_bits_and_high_view(self) -> None:
        for csr_name, xlen, lsb in (("menvcfg", 64, 32), ("menvcfgh", 32, 0)):
            with self.subTest(csr=csr_name):
                code = csr_walk_test(
                    self.data,
                    FIELD_CSRS[csr_name],
                    "cg",
                    "walk",
                    policy=CsrTestPolicy(write_fields=("PMM",), check_fields=("PMM",)),
                )
                initial = 0xABCDEF00 & ~(3 << lsb)
                signatures, writes, restored = execute(
                    code,
                    xlen,
                    initial,
                    field_legalizer(lsb, (0, 2, 3), 0),
                    ("SM1P12P0_OR_LATER_SUPPORTED",),
                )
                self.assertEqual(signatures, [1] * 4)
                self.assertTrue(all(value & ~(3 << lsb) == initial for value in writes))
                self.assertEqual(restored, initial)
                self.assertEqual(execute(code, xlen, initial)[0], [])
                self.assertEqual(execute(code, 96 - xlen, initial)[0], [])

    def test_observation_is_independent_of_write_selection(self) -> None:
        csr = CsrSpec("example", 0x340, "M", (CsrField("LOW", 0, 8), CsrField("HIGH", 8, 8)))
        code = csr_access_test(
            self.data, csr, "cg", "access", policy=CsrTestPolicy(write_fields=("LOW",), check_fields=("HIGH",))
        )
        self.assertEqual(execute(code, 32, 0xAB00)[0], [0xAB] * 4)
        self.assertIn(0, execute(code, 32, 0xAB00, lambda value, op: value & 0xFF)[0])

    def test_preserved_warl_field_checks_unchanged_value(self) -> None:
        mpp = replace(FIELD_CSRS["mstatus"].fields[0], lsb=8)
        csr = CsrSpec("example", 0x340, "M", (CsrField("LOW", 0, 8), mpp))
        code = csr_access_test(
            self.data, csr, "cg", "preserve", policy=CsrTestPolicy(write_fields=("LOW",), check_fields=("MPP",))
        )
        for initial in (0, 3 << 8):
            self.assertEqual(execute(code, 32, initial)[0], [1] * 4)
        self.assertEqual(execute(code, 32, 3 << 8, lambda value, op: value & 0xFF)[0], [0] * 4)

    def test_bitops_use_required_starting_values(self) -> None:
        code = csr_bitops_test(self.data, FIELD_CSRS["mstatus"], "cg", "bitops")
        for xlen in (32, 64):
            for defines, legal in (((), (3,)), (("U_SUPPORTED",), (0, 3)), (("S_SUPPORTED",), (1, 3))):
                with self.subTest(xlen=xlen, defines=defines):
                    signatures, writes, restored = execute(code, xlen, 3 << 11, field_legalizer(11, legal, 3), defines)
                    expected = []
                    starts = []
                    for op in ("csrs", "csrc"):
                        for initial in legal:
                            for bit in (0, 1):
                                candidate = initial | (1 << bit) if op == "csrs" else initial & ~(1 << bit)
                                expected.append(candidate if candidate in legal else 1)
                                starts.append(initial << 11)
                    self.assertEqual(signatures, expected)
                    self.assertEqual(writes[:-1:2], starts)
                    self.assertEqual(restored, 3 << 11)
                    alternate = execute(code, xlen, 3 << 11, field_legalizer(11, legal, legal[0]), defines)[0]
                    self.assertEqual(signatures, alternate)

        definitions = ("U_SUPPORTED", "S_SUPPORTED")
        reference = execute(code, 64, 3 << 11, field_legalizer(11, (0, 1, 3), 3), definitions)[0]
        for ignored in ("csrs", "csrc"):
            state = 3 << 11

            def write(value: int, op: str, ignored: str = ignored) -> int:
                nonlocal state
                if op != ignored:
                    state = field_legalizer(11, (0, 1, 3), 3)(value, op)
                return state

            self.assertNotEqual(execute(code, 64, 3 << 11, write, definitions)[0], reference)

    def test_configuration_can_require_optional_pmm_values(self) -> None:
        csr = FIELD_CSRS["menvcfgh"]
        pmm = csr.fields[0]
        configured = replace(
            csr, fields=(replace(pmm, legal_values=tuple(replace(v, required=True) for v in pmm.legal_values)),)
        )
        definitions = ("SM1P12P0_OR_LATER_SUPPORTED",)
        for description, expected in ((csr, [0, 1, 1, 1]), (configured, [0, 1, 2, 3])):
            code = csr_field_values_test(self.data, description, "PMM", range(4), "cg", "pmm_values")
            signatures = execute(code, 32, 0, field_legalizer(0, (0, 2, 3), 0), definitions)[0]
            self.assertEqual(signatures, expected)
            stuck_zero = execute(code, 32, 0, lambda value, op: 0, definitions)[0]
            self.assertEqual(signatures == stuck_zero, description is csr)

    def test_subset_writes_observe_collateral_corruption_by_default(self) -> None:
        legalize = field_legalizer(4, (0, 1, 3), 0)
        for generator in (csr_access_test, csr_walk_test, csr_bitops_test):
            code = generator(
                self.data, FIELD_CSRS["menvcfg"], "cg", generator.__name__, policy=CsrTestPolicy(write_fields=("CBIE",))
            )
            definitions = ("SM1P12P0_OR_LATER_SUPPORTED", "ZICBOM_SUPPORTED")
            initial = 2 << 32
            signatures = execute(code, 64, initial, legalize, definitions)[0]
            faulty = execute(code, 64, initial, lambda value, op: legalize(value, op) & ~(3 << 32), definitions)[0]
            self.assertEqual(signatures[1::2], [1] * (len(signatures) // 2))
            self.assertEqual(faulty[1::2], [0] * (len(signatures) // 2))

    def test_invalid_descriptions_and_requests(self) -> None:
        with self.assertRaises(ValueError):
            CsrSpec("overlap", 0x340, "M", (CsrField("A", 0, 4), CsrField("B", 3, 4)))
        with self.assertRaises(ValueError):
            CsrField("too_high", 32, 2)
        with self.assertRaises(ValueError):
            csr_walk_test(self.data, FIELD_CSRS["mscratch"], "cg", "walk", policy=CsrTestPolicy(write_fields=("typo",)))
        with self.assertRaises(ValueError):
            csr_field_values_test(self.data, FIELD_CSRS["mstatus"], "MPP", (4,), "cg", "values")
        with self.assertRaises(ValueError):
            csr_bitops_test(
                self.data, FIELD_CSRS["mscratch"], "cg", "bitops", policy=CsrTestPolicy(write_fields=("typo",))
            )
        mpp = FIELD_CSRS["mstatus"].fields[0]
        no_required = replace(mpp, legal_values=tuple(replace(v, required=False) for v in mpp.legal_values))
        with self.assertRaises(ValueError):
            csr_bitops_test(self.data, replace(FIELD_CSRS["mstatus"], fields=(no_required,)), "cg", "bitops")


if __name__ == "__main__":
    unittest.main()
