# SPDX-License-Identifier: Apache-2.0

"""CSR descriptions. Unenumerated WARL fields use configured reference readbacks."""

from dataclasses import replace
from types import MappingProxyType

from testgen.csr.model import CsrField, CsrSpec, LegalValue

CBIE = CsrField(
    "CBIE",
    4,
    2,
    "WARL",
    (
        LegalValue(0, required=True),
        LegalValue(1, required="defined(ZICBOM_SUPPORTED)"),
        LegalValue(3, required="defined(ZICBOM_SUPPORTED)"),
    ),
)
PMM = CsrField("PMM", 32, 2, "WARL", (LegalValue(0, required=True), LegalValue(2), LegalValue(3)), xlens=(64,))
MPP = CsrField(
    "MPP",
    11,
    2,
    "WARL",
    (
        LegalValue(0, "defined(U_SUPPORTED)", required=True),
        LegalValue(1, "defined(S_SUPPORTED)", required=True),
        LegalValue(3, required=True),
    ),
)

MSTATUS_FIELDS = (
    CsrField("SIE", 1, 1, "WARL"),
    CsrField("MIE", 3, 1, "RW"),
    CsrField("SPIE", 5, 1, "WARL"),
    CsrField("UBE", 6, 1, "WARL"),
    CsrField("MPIE", 7, 1, "RW"),
    CsrField("SPP", 8, 1, "WARL"),
    CsrField("VS", 9, 2, "WARL"),
    MPP,
    CsrField("FS", 13, 2, "WARL"),
    CsrField("XS", 15, 2, "RO", description="Summary of additional extension state."),
    CsrField("MPRV", 17, 1, "WARL"),
    CsrField("SUM", 18, 1, "WARL"),
    CsrField("MXR", 19, 1, "WARL"),
    CsrField("TVM", 20, 1, "WARL"),
    CsrField("TW", 21, 1, "WARL"),
    CsrField("TSR", 22, 1, "WARL"),
    CsrField("SPELP", 23, 1, "WARL"),
    CsrField("SDT", 24, 1, "WARL", description="Setting SDT clears SIE."),
    CsrField("SD32", 31, 1, "RO", xlens=(32,), description="SD: FS, XS, or VS is Dirty."),
    CsrField("UXL", 32, 2, "WARL", xlens=(64,)),
    CsrField("SXL", 34, 2, "WARL", xlens=(64,)),
    CsrField("SBE", 36, 1, "WARL", xlens=(64,)),
    CsrField("MBE", 37, 1, "WARL", xlens=(64,)),
    CsrField("GVA", 38, 1, "WARL", xlens=(64,)),
    CsrField("MPV", 39, 1, "WARL", xlens=(64,)),
    CsrField("MPELP", 41, 1, "WARL", xlens=(64,)),
    CsrField("MDT", 42, 1, "WARL", xlens=(64,), description="Setting MDT clears MIE."),
    CsrField("SD64", 63, 1, "RO", xlens=(64,), description="SD: FS, XS, or VS is Dirty."),
)

ENVCFG_LOW_FIELDS = (
    CsrField("FIOM", 0, 1, "WARL"),
    CsrField("LPE", 2, 1, "WARL"),
    CsrField("SSE", 3, 1, "WARL"),
    CBIE,
    CsrField("CBCFE", 6, 1, "WARL"),
    CsrField("CBZE", 7, 1, "WARL"),
)
MENVCFG_FIELDS = (
    *ENVCFG_LOW_FIELDS,
    PMM,
    CsrField("DTE", 59, 1, "WARL", xlens=(64,)),
    CsrField("CDE", 60, 1, "WARL", xlens=(64,)),
    CsrField("ADUE", 61, 1, "WARL", xlens=(64,)),
    CsrField("PBMTE", 62, 1, "WARL", xlens=(64,)),
    CsrField("STCE", 63, 1, "WARL", xlens=(64,)),
)
SENVCFG_FIELDS = (
    *ENVCFG_LOW_FIELDS,
    PMM,
)


def high_fields(fields: tuple[CsrField, ...]) -> tuple[CsrField, ...]:
    """Map the upper 32 bits to the RV32 high CSR view."""
    return tuple(replace(field, lsb=field.lsb - 32, xlens=(32,)) for field in fields if field.lsb >= 32)


# mstatush has neither UXL/SXL nor SD; those positions are WPRI on RV32.
MSTATUSH_FIELDS = high_fields(tuple(f for f in MSTATUS_FIELDS if 36 <= f.lsb < 63))

# Required nonzero PMM encodings need implementation data. Their architectural
# domain alone does not establish which optional PMLEN values are implemented.
CSRS = MappingProxyType(
    {
        "mscratch": CsrSpec("mscratch", 0x340, "M", (CsrField("VALUE", 0),)),
        "sscratch": CsrSpec("sscratch", 0x140, "S", (CsrField("VALUE", 0),), condition="defined(S_SUPPORTED)"),
        "mstatus": CsrSpec("mstatus", 0x300, "M", MSTATUS_FIELDS),
        "mstatush": CsrSpec("mstatush", 0x310, "M", MSTATUSH_FIELDS, xlens=(32,)),
        "menvcfg": CsrSpec("menvcfg", 0x30A, "M", MENVCFG_FIELDS, condition="defined(SM1P12P0_OR_LATER_SUPPORTED)"),
        "menvcfgh": CsrSpec(
            "menvcfgh",
            0x31A,
            "M",
            high_fields(MENVCFG_FIELDS),
            condition="defined(SM1P12P0_OR_LATER_SUPPORTED)",
            xlens=(32,),
        ),
        "senvcfg": CsrSpec("senvcfg", 0x10A, "S", SENVCFG_FIELDS, condition="defined(S1P12P0_OR_LATER_SUPPORTED)"),
        "mseccfg": CsrSpec("mseccfg", 0x747, "M", (PMM,), condition="defined(MSECCFG_SUPPORTED)"),
        "mseccfgh": CsrSpec(
            "mseccfgh", 0x757, "M", high_fields((PMM,)), condition="defined(MSECCFG_SUPPORTED)", xlens=(32,)
        ),
    }
)
