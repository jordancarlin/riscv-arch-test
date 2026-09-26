# SPDX-License-Identifier: Apache-2.0

"""Architectural descriptions for the CSR generation proof of concept."""

from dataclasses import dataclass
from typing import Literal


@dataclass(frozen=True)
class LegalValue:
    value: int
    condition: str | None = None  # C preprocessor expression
    required: bool | str = False  # Must retain writes, optionally under this condition.

    @property
    def required_condition(self) -> str:
        if self.required is False:
            return "0"
        if self.required is True:
            return self.condition or "1"
        return f"({self.condition}) && ({self.required})" if self.condition else self.required


@dataclass(frozen=True)
class CsrField:
    name: str
    lsb: int
    width: int | None = None  # None extends through XLEN-1.
    access: Literal["RW", "WARL", "RO"] = "RW"
    # An omitted WARL domain uses the configured reference model's readback.
    legal_values: tuple[LegalValue, ...] = ()
    xlens: tuple[int, ...] = (32, 64)
    description: str = ""

    def __post_init__(self) -> None:
        if self.lsb < 0 or (self.width is not None and self.width <= 0):
            raise ValueError(f"Invalid layout for {self.name}")
        if not self.xlens or not set(self.xlens) <= {32, 64}:
            raise ValueError(f"Invalid XLENs for {self.name}")
        if self.access not in ("RW", "WARL", "RO"):
            raise ValueError(f"Unsupported field access: {self.access}")
        if self.access != "WARL" and self.legal_values:
            raise ValueError(f"Only WARL fields can have a legal domain: {self.name}")
        if len({v.value for v in self.legal_values}) != len(self.legal_values):
            raise ValueError(f"Duplicate legal values for {self.name}")
        for xlen in self.xlens:
            width = self.bit_width(xlen)
            if width <= 0 or self.lsb + width > xlen:
                raise ValueError(f"{self.name} does not fit RV{xlen}")
            if any(not 0 <= v.value < 1 << width for v in self.legal_values):
                raise ValueError(f"Legal value does not fit {self.name}")

    def bit_width(self, xlen: int) -> int:
        return self.width if self.width is not None else xlen - self.lsb

    def mask(self, xlen: int) -> int:
        return ((1 << self.bit_width(xlen)) - 1) << self.lsb


@dataclass(frozen=True)
class CsrSpec:
    name: str
    address: int
    privilege: Literal["M", "S", "U"]
    fields: tuple[CsrField, ...]
    condition: str | None = None
    xlens: tuple[int, ...] = (32, 64)

    def __post_init__(self) -> None:
        if not 0 <= self.address <= 0xFFF:
            raise ValueError(f"Invalid CSR address: {self.address}")
        if not self.xlens or not set(self.xlens) <= {32, 64}:
            raise ValueError(f"Invalid XLENs for {self.name}")
        if len({f.name for f in self.fields}) != len(self.fields):
            raise ValueError(f"Duplicate fields in {self.name}")
        for xlen in self.xlens:
            used = 0
            for field in self.fields:
                if xlen in field.xlens:
                    mask = field.mask(xlen)
                    if used & mask:
                        raise ValueError(f"Overlapping fields in {self.name} on RV{xlen}")
                    used |= mask


@dataclass(frozen=True)
class CsrTestPolicy:
    """Select fields to modify and observe; preserve all unselected bits on writes.

    None selects all described fields, including checks on preserved fields.
    Undescribed bits are preserved on writes and never compared.
    These generators require stable fields and reversible writes. Privilege
    transitions and setup of other CSRs remain the caller's responsibility.
    """

    write_fields: tuple[str, ...] | None = None
    check_fields: tuple[str, ...] | None = None

    def select(self, csr: CsrSpec, xlen: int, *, checking: bool = False) -> tuple[CsrField, ...]:
        names = self.check_fields if checking else self.write_fields
        if names is not None and set(names) - {f.name for f in csr.fields}:
            raise ValueError(f"Unknown fields for {csr.name}: {names}")
        return tuple(f for f in csr.fields if xlen in f.xlens and (names is None or f.name in names))
