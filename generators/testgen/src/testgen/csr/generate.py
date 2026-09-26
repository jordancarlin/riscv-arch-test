# SPDX-License-Identifier: Apache-2.0

"""CSR patterns sharing one write/preserve/readback implementation."""

from collections.abc import Callable, Iterable, Iterator
from dataclasses import dataclass, replace
from typing import Literal

from testgen.asm.helpers import write_sigupd
from testgen.csr.model import CsrField, CsrSpec, CsrTestPolicy
from testgen.data.state import TestData

_DEFAULT_POLICY = CsrTestPolicy()


@dataclass(frozen=True)
class _Case:
    name: str
    op: Literal["csrw", "csrs", "csrc"]
    value: int
    initial: int | None = None
    condition: str | None = None
    walk_bit: int | None = None
    walk_start: bool = False
    invert_walk: bool = False

    @property
    def written_value(self) -> int:
        if self.op == "csrw":
            return self.value
        if self.op == "csrs":
            return (self.initial or 0) | self.value
        return (self.initial or 0) & ~self.value


def _guard(condition: str | None, lines: list[str]) -> list[str]:
    if condition == "0":
        return []
    return [f"#if {condition}", *lines, "#endif"] if condition and condition != "1" else lines


def _by_xlen(variants: dict[int, list[str]]) -> list[str]:
    """Emit identical instructions once, guarding only the differences."""
    first = next(iter(variants.values()))
    if all(lines == first for lines in variants.values()):
        return first
    return ["#if __riscv_xlen == 32", *variants[32], "#else", *variants[64], "#endif"]


def _case_variants(patterns: dict[int, tuple[_Case, ...]]) -> Iterator[dict[int, _Case]]:
    """Merge ordered pattern streams, keeping cases present at only one XLEN."""
    if len(patterns) == 1:
        xlen, cases = next(iter(patterns.items()))
        for case in cases:
            yield {xlen: case}
        return
    pending = iter(patterns[32])
    current = next(pending, None)
    names32 = {case.name for case in patterns[32]}
    for case in patterns[64]:
        if case.name not in names32:
            yield {64: case}
            continue
        while current is not None and current.name != case.name:
            yield {32: current}
            current = next(pending, None)
        assert current is not None, "CSR patterns must have consistent ordering across XLENs"
        yield {32: current, 64: case}
        current = next(pending, None)
    while current is not None:
        yield {32: current}
        current = next(pending, None)


class _Emitter:
    def __init__(self, test_data: TestData, csr: CsrSpec, *, walking: bool) -> None:
        self.data = test_data
        self.csr = csr
        self.regs = test_data.int_regs.get_registers(5 if walking else 4)
        self.saved, self.operand, self.field_reg, self.temp = self.regs[:4]
        self.walk = self.regs[4] if walking else None
        self.previous_bit = {32: 0, 64: 0}

    def load(self, reg: int, values: dict[int, int]) -> list[str]:
        values = {xlen: value & ((1 << xlen) - 1) for xlen, value in values.items()}
        # Equal bit patterns share a positive literal. Otherwise signed values
        # let XLEN-wide constants such as all ones share the same instruction.
        if len(set(values.values())) != 1:
            values = {
                xlen: value - (1 << xlen) if value & (1 << (xlen - 1)) else value for xlen, value in values.items()
            }
        if all(value == (1 << xlen) - 1 for xlen, value in values.items()):
            values = dict.fromkeys(values, -1)
        literals = {xlen: str(value) if -1 <= value <= 1 else f"{value:#x}" for xlen, value in values.items()}
        return _by_xlen({xlen: [f"LI(x{reg}, {value})"] for xlen, value in literals.items()})

    def write(self, values: dict[int, int], masks: dict[int, int], source: int | None = None) -> list[str]:
        """Replace selected bits using the saved CSR for everything else."""
        if all(mask == (1 << xlen) - 1 for xlen, mask in masks.items()):
            if source is not None:
                return [f"csrw {self.csr.name}, x{source}"]
            if not any(values.values()):
                return [f"csrw {self.csr.name}, zero"]
            return [*self.load(self.operand, values), f"csrw {self.csr.name}, x{self.operand}"]
        lines = [
            *self.load(self.temp, {xlen: ~mask for xlen, mask in masks.items()}),
            f"and x{self.field_reg}, x{self.saved}, x{self.temp}",
        ]
        if source is None:
            lines.extend(self.load(self.temp, {xlen: value & masks[xlen] for xlen, value in values.items()}))
            source = self.temp
        lines.extend([f"or x{self.operand}, x{self.field_reg}, x{source}", f"csrw {self.csr.name}, x{self.operand}"])
        return lines

    def extract(self, field: CsrField, source: int, dest: int, xlens: Iterable[int]) -> list[str]:
        lines: list[str] = []
        if field.lsb:
            lines.append(f"srli x{dest}, x{source}, {field.lsb}")
        elif source != dest:
            lines.append(f"mv x{dest}, x{source}")
        if field.width is not None and any(field.width < xlen for xlen in xlens):
            mask = (1 << field.width) - 1
            if mask < 2048:
                lines.append(f"andi x{dest}, x{dest}, {mask:#x}")
            else:
                lines.extend([*self.load(self.temp, dict.fromkeys(xlens, mask)), f"and x{dest}, x{dest}, x{self.temp}"])
        return lines

    def legal(self, field: CsrField) -> list[str]:
        lines = ["# Legal WARL value: 1 if valid, 0 otherwise.", f"LI(x{self.operand}, 0)"]
        for value in field.legal_values:
            lines.extend(
                _guard(
                    value.condition,
                    [
                        f"LI(x{self.temp}, {value.value})",
                        f"xor x{self.temp}, x{self.field_reg}, x{self.temp}",
                        f"seqz x{self.temp}, x{self.temp}",
                        f"or x{self.operand}, x{self.operand}, x{self.temp}",
                    ],
                )
            )
        return lines

    def check(
        self, field: CsrField, cases: dict[int, _Case], masks: dict[int, int], label: str | None = None
    ) -> list[str]:
        lines = [
            *([label] if label else []),
            f"csrr x{self.field_reg}, {self.csr.name}",
            *self.extract(field, self.field_reg, self.field_reg, cases),
        ]
        if field.lsb or field.width is not None:
            lines.insert(0, f"# Check {self.csr.name}.{field.name}.")
        conditions = {}
        for xlen, case in cases.items():
            value = (case.written_value >> field.lsb) & ((1 << field.bit_width(xlen)) - 1)
            supported = next((v for v in field.legal_values if v.value == value), None)
            conditions[xlen] = supported.required_condition if supported else "0"
        if not field.legal_values or all(conditions[xlen] == "1" and field.mask(xlen) & masks[xlen] for xlen in cases):
            signature_reg = self.field_reg
        else:
            signature_reg = self.operand
            checks = {}
            for xlen in cases:
                if not field.mask(xlen) & masks[xlen]:
                    checks[xlen] = [
                        "# Preserved WARL value: 1 if unchanged, 0 otherwise.",
                        *self.extract(field, self.saved, self.operand, (xlen,)),
                        f"xor x{self.operand}, x{self.field_reg}, x{self.operand}",
                        f"seqz x{self.operand}, x{self.operand}",
                    ]
                elif conditions[xlen] == "0":
                    checks[xlen] = self.legal(field)
                elif conditions[xlen] == "1":
                    checks[xlen] = [f"mv x{self.operand}, x{self.field_reg}"]
                else:
                    checks[xlen] = [
                        f"#if {conditions[xlen]}",
                        f"mv x{self.operand}, x{self.field_reg}",
                        "#else",
                        *self.legal(field),
                        "#endif",
                    ]
            lines.extend(_by_xlen(checks))
        lines.extend(write_sigupd(signature_reg, self.data).splitlines())
        return lines

    def operation(self, cases: dict[int, _Case], masks: dict[int, int]) -> list[str]:
        case = next(iter(cases.values()))
        lines: list[str] = []
        source = None
        if case.walk_bit is not None:
            assert self.walk is not None
            movements = {}
            for xlen, variant in cases.items():
                assert variant.walk_bit is not None
                movements[xlen] = (
                    self.load(self.walk, {xlen: 1 << variant.walk_bit})
                    if variant.walk_start
                    else [f"slli x{self.walk}, x{self.walk}, {variant.walk_bit - self.previous_bit[xlen]}"]
                )
                self.previous_bit[xlen] = variant.walk_bit
            lines.extend(_by_xlen(movements))
            source = self.walk
        if case.initial is not None:
            lines.extend(self.write({xlen: variant.initial or 0 for xlen, variant in cases.items()}, masks))
        values = {xlen: variant.value for xlen, variant in cases.items()}
        if case.op == "csrw":
            if case.invert_walk:
                lines.extend([*self.load(self.temp, masks), f"xor x{self.operand}, x{self.walk}, x{self.temp}"])
                source = self.operand
            lines.extend(self.write(values, masks, source))
        else:
            if case.initial is None and any(values[xlen] & mask != mask for xlen, mask in masks.items()):
                raise ValueError("Set/clear access tests must select every bit or specify an initial value")
            if source is None:
                lines.extend(self.load(self.operand, values))
                source = self.operand
            lines.append(f"{case.op} {self.csr.name}, x{source}")
        return lines


def _generate(
    test_data: TestData,
    csr: CsrSpec,
    covergroup: str,
    coverpoint: str,
    policy: CsrTestPolicy,
    cases: Callable[[int, int], Iterable[_Case]],
    title: str,
) -> list[str]:
    """Emit one save/test/restore block, guarding XLEN-specific fields and masks."""
    if test_data.xlen not in (0, 32, 64):
        raise ValueError(f"Unsupported XLEN: {test_data.xlen}")
    masks = {}
    checked = {}
    patterns = {}
    for xlen in csr.xlens:
        if test_data.xlen not in (0, xlen):
            continue
        written = policy.select(csr, xlen)
        checked[xlen] = policy.select(csr, xlen, checking=True)
        if not written:
            continue
        if not checked[xlen]:
            raise ValueError(f"No fields checked for {csr.name} on RV{xlen}")
        masks[xlen] = sum(field.mask(xlen) for field in written)
        patterns[xlen] = tuple(cases(xlen, masks[xlen]))
    if not patterns:
        return []
    emitter = _Emitter(test_data, csr, walking=any(case.walk_bit is not None for p in patterns.values() for case in p))
    try:
        lines = [
            "",
            "# =============================================================================",
            f"# {csr.name} {title}",
            "# =============================================================================",
            f"# Save {csr.name}.",
            f"csrr x{emitter.saved}, {csr.name}",
        ]
        active_guard = None
        for variants in _case_variants(patterns):
            guard = f"__riscv_xlen == {next(iter(variants))}" if variants.keys() != patterns.keys() else None
            if guard != active_guard:
                if active_guard:
                    lines.append("#endif")
                if guard:
                    lines.append(f"#if {guard}")
                active_guard = guard
            case = next(iter(variants.values()))
            block = ["", f"# {csr.name}: {case.name.replace('_', ' ')}"]
            first = True
            for field in csr.fields:
                observed = {xlen: variant for xlen, variant in variants.items() if field in checked[xlen]}
                if not observed:
                    continue
                label = test_data.add_testcase(f"{csr.name}_{case.name}_{field.name}", coverpoint, covergroup)
                if first:
                    operation = emitter.operation(variants, {xlen: masks[xlen] for xlen in variants})
                    block.extend([*operation[:-1], label, operation[-1]])
                check = emitter.check(field, observed, masks, label=None if first else label)
                field_guard = f"__riscv_xlen == {next(iter(observed))}" if observed.keys() != variants.keys() else None
                block.extend(_guard(field_guard, check))
                first = False
            lines.extend(_guard(case.condition, block))
        if active_guard:
            lines.append("#endif")
        lines.extend(["", f"# Restore {csr.name}.", f"csrw {csr.name}, x{emitter.saved}", ""])
        if len(patterns) == 1:
            lines = _guard(f"__riscv_xlen == {next(iter(patterns))}", lines)
        return _guard(csr.condition, lines)
    finally:
        test_data.int_regs.return_registers(emitter.regs)


def csr_access_test(
    test_data: TestData,
    csr: CsrSpec,
    covergroup: str,
    coverpoint: str,
    *,
    policy: CsrTestPolicy = _DEFAULT_POLICY,
) -> list[str]:
    """Write ones/zeros, set ones, and clear ones in the selected fields."""
    return _generate(
        test_data,
        csr,
        covergroup,
        coverpoint,
        policy,
        lambda xlen, mask: (
            _Case("write_ones", "csrw", mask),
            _Case("write_zeros", "csrw", 0),
            _Case("set_ones", "csrs", mask),
            _Case("clear_ones", "csrc", mask),
        ),
        "CSR access tests",
    )


def csr_walk_test(
    test_data: TestData,
    csr: CsrSpec,
    covergroup: str,
    coverpoint: str,
    *,
    policy: CsrTestPolicy = _DEFAULT_POLICY,
    walk_zeros: bool = True,
) -> list[str]:
    """Write complete walking-one/zero patterns, preserving unselected bits."""

    def cases(xlen: int, mask: int) -> Iterable[_Case]:
        bits = [bit for bit in range(xlen) if mask & (1 << bit)]
        for invert in (False, True) if walk_zeros else (False,):
            for index, bit in enumerate(bits):
                yield _Case(
                    f"walking_{'zero' if invert else 'one'}_{bit}",
                    "csrw",
                    mask ^ (1 << bit) if invert else 1 << bit,
                    walk_bit=bit,
                    walk_start=index == 0,
                    invert_walk=invert,
                )

    return _generate(test_data, csr, covergroup, coverpoint, policy, cases, "CSR value walks")


def csr_field_values_test(
    test_data: TestData,
    csr: CsrSpec,
    field_name: str,
    values: Iterable[int],
    covergroup: str,
    coverpoint: str,
    *,
    policy: CsrTestPolicy = _DEFAULT_POLICY,
) -> list[str]:
    """Write field encodings, including reserved encodings, preserving other bits."""
    field = next((field for field in csr.fields if field.name == field_name), None)
    if field is None:
        raise ValueError(f"Unknown field {csr.name}.{field_name}")
    values = tuple(values)
    if not values or len(set(values)) != len(values):
        raise ValueError("Field values must be nonempty and unique")

    def cases(xlen: int, mask: int) -> Iterable[_Case]:
        for value in values:
            if not 0 <= value < 1 << field.bit_width(xlen):
                raise ValueError(f"Value {value} does not fit {csr.name}.{field.name}")
            yield _Case(f"{field_name}_value_{value}", "csrw", value << field.lsb)

    return _generate(
        test_data,
        csr,
        covergroup,
        coverpoint,
        replace(policy, write_fields=(field_name,)),
        cases,
        f"{field_name} value tests",
    )


def csr_bitops_test(
    test_data: TestData,
    csr: CsrSpec,
    covergroup: str,
    coverpoint: str,
    *,
    policy: CsrTestPolicy = _DEFAULT_POLICY,
) -> list[str]:
    """Walk set/clear operands, preserving other fields.

    Enumerated WARL fields start from required writable encodings. Fields
    compared with the reference model start from zero/all-ones write patterns.
    """
    for xlen in csr.xlens:
        policy.select(csr, xlen)
        policy.select(csr, xlen, checking=True)
    lines: list[str] = []
    for field in csr.fields:
        if policy.write_fields is not None and field.name not in policy.write_fields:
            continue
        if field.legal_values and not any(v.required for v in field.legal_values):
            raise ValueError(f"{csr.name}.{field.name} needs a required writable value for bit operations")

        def cases(xlen: int, mask: int, field: CsrField = field) -> Iterable[_Case]:
            for op in ("csrs", "csrc"):
                initial_values = (
                    [(0 if op == "csrs" else mask, None)]
                    if not field.legal_values
                    else [(v.value << field.lsb, v.required_condition) for v in field.legal_values if v.required]
                )
                for initial, condition in initial_values:
                    for bit in range(field.lsb, field.lsb + field.bit_width(xlen)):
                        start = "zeros" if initial == 0 else "ones" if initial == mask else f"{initial:x}"
                        yield _Case(
                            f"{field.name}_{op}_bit_{bit}_from_{start}",
                            op,
                            1 << bit,
                            initial,
                            condition,
                            walk_bit=bit,
                            walk_start=bit == field.lsb,
                        )

        lines.extend(
            _generate(
                test_data,
                csr,
                covergroup,
                coverpoint,
                replace(policy, write_fields=(field.name,)),
                cases,
                f"{field.name} CSR set/clear walks",
            )
        )
    return lines
