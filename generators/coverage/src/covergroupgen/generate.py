##################################
# generate.py
#
# David_Harris@hmc.edu 15 August 2025
# SPDX-License-Identifier: Apache-2.0
#
# Generate functional covergroups for RISC-V instructions
##################################

import csv
import importlib.resources
import math
import re
from dataclasses import dataclass
from difflib import get_close_matches
from pathlib import Path
from types import ModuleType

from rich import print as rprint
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    TaskProgressColumn,
    TextColumn,
    TimeElapsedColumn,
)


def _progress(description: str) -> Progress:
    """Construct the standard project progress display."""
    return Progress(
        SpinnerColumn(),
        TextColumn(f"[cyan]{description}"),
        BarColumn(),
        MofNCompleteColumn(),
        TaskProgressColumn(),
        TextColumn("elapsed:"),
        TimeElapsedColumn(),
        transient=True,
    )


def _load_testgen_script(filename: str) -> ModuleType:
    """Load a module from ``generators/testgen/scripts/`` by file path.

    That directory is not a Python package, so its helpers (the single source
    of truth for several vector rules) must be imported by path. These modules
    are large, so they are loaded once into module-level globals rather than
    per use.
    """
    import importlib.util

    repo_root = Path(__file__).resolve().parents[4]
    mod_path = repo_root / "generators" / "testgen" / "scripts" / filename
    if not mod_path.exists():
        raise FileNotFoundError(f"Required testgen script not found: {mod_path}")
    spec = importlib.util.spec_from_file_location(mod_path.stem, mod_path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Could not create import spec for {mod_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _load_ssstrictv_skip_combinations() -> dict[str, set[str]]:
    """Load the SsstrictV (column, instruction) skip table as ``{column: {instrs}}``."""
    module = _load_testgen_script("ssstrictv_skip_combinations.py")
    raw: dict[str, list[str]] = module.SKIP_COMBINATIONS
    return {col: set(instrs) for col, instrs in raw.items()}


# Loaded once at import; both are large testgen modules consulted per instruction.
_VECTOR_TESTGEN_COMMON = _load_testgen_script("vector_testgen_common.py")


SSSTRICTV_SKIP_COMBINATIONS = _load_ssstrictv_skip_combinations()


# Coverpoints whose template name depends on the SEW (element width).
SEW_DEPENDENT_CPS = {
    "cp_vs2_edges_f",
    "cp_vs1_edges_f",
    "cp_custom_shift_wv",
    "cp_custom_shift_wx",
    "cp_custom_shift_vv",
    "cp_custom_shift_vx",
    "cp_custom_shift_vi",
    "cp_custom_vindexVV",
    "cp_custom_vindexVX",
    "cp_custom_vindexCorners",
    "cr_vs2_vs1_edges_f",
    "cp_fs1_edges_v",
    "cr_vs2_fs1_edges",
    "cr_vl_lmul",
}

# Vector extension prefixes used to identify vector architectures.
VECTOR_PREFIXES = ("Vx", "Zv", "Vls", "Vf")

# Priv-side architectures that need vector-flavored covergroups (header_vector etc.).
# These priv testplans use the same vector helpers as unpriv vector covergroups
# but do not undergo per-SEW expansion.
PRIV_VECTOR_PREFIXES = ("ExceptionsV", "SsstrictV", "MisalignV")

# Subset of vector prefixes that support widening instructions.
VECTOR_WIDEN_PREFIXES = ("Vx", "Vls", "Vf", "Zvfhmin", "Zvfbfmin", "Zvfbfwma")


def _sew_variants_for(arch: str) -> list[str] | None:
    """Return the SEW suffixes *arch* expands into (e.g. Vx → 8/16/32/64), or None.

    A vector testplan is duplicated into one variant per returned SEW, replacing
    the base entry.
    """
    if any(prefix in arch for prefix in ("Vx", "Vls", "Zvbb", "Zvkb")):
        return ["8", "16", "32", "64"]
    if "Vf" in arch:
        return ["16", "32", "64"]  # SEW 8 is not supported for vector floating point
    if "Zvknhb" in arch:
        return ["32", "64"]
    return None


# Map instruction Type code → (has_vd_reg_group, has_vs1_reg_group, has_vs2_reg_group).
# Used to suppress per-operand off_group / overlap crosses for instructions whose
# encoding hardcodes an operand field (e.g. vid.v has no vs1/vs2 registers — those
# bits are part of the opcode, so unaligned-vs1 / unaligned-vs2 bins can never fire).
# vd is recorded as "present" for stores (the vs3 data register lives in the rd field
# and still has an EMUL-aligned register group constraint).
_TYPE_OPERANDS: dict[str, tuple[bool, bool, bool]] = {
    "VVVM": (True, True, True),
    "VVV": (True, True, True),
    "VVVMR": (True, True, True),
    "VVIM": (True, False, True),
    "VVI": (True, False, True),
    "VVXM": (True, False, True),
    "VVX": (True, False, True),
    "VVFM": (True, False, True),
    "VVM": (True, False, True),
    "VV": (True, False, True),
    "VVR": (True, True, False),
    "VFVM": (True, False, True),
    "VI": (True, False, False),
    "VM": (True, False, False),
    "VF": (True, False, False),
    "FV": (False, False, True),
    "XV": (False, False, True),
    "XVM": (False, False, True),
    "VX": (True, False, False),
    "VXM": (True, False, False),
    "VXVM": (True, False, True),
    "VXXM": (True, False, False),
    "VSX": (True, False, False),
    "VSXM": (True, False, False),
    "VSXVM": (True, False, True),
    "VSXXM": (True, False, False),
    # Vector integer types from Vx.csv
    "WVV": (True, True, True),
    "WVX": (True, False, True),
    "WVV_ACC": (True, True, True),
    "WVX_ACC": (True, False, True),
    "WWV": (True, True, True),
    "WWX": (True, False, True),
    "VWV": (True, True, True),
    "VWX": (True, False, True),
    "VWI": (True, False, True),
    "VVV_ACC": (True, True, True),
    "VVX_ACC": (True, False, True),
    "VVV_SAT": (True, True, True),
    "VVX_SAT": (True, False, True),
    "VVI_SAT": (True, False, True),
    "VVSR": (True, True, True),
    "WVWSR": (True, True, True),
    "MVV": (True, True, True),
    "MVX": (True, False, True),
    "MVI": (True, False, True),
    "MVVM": (True, True, True),
    "MVXM": (True, False, True),
    "MVIM": (True, False, True),
    "MMM": (True, True, True),
    "MM": (True, False, True),
    "VVVP": (True, True, True),
    "VVXP": (True, False, True),
    "VVIP": (True, False, True),
    "VEXT": (True, False, True),
    "VMVR": (True, False, True),
    "VCOMPRESS": (True, True, True),
    "VID": (True, False, False),
}


def _operand_presence(instr_type: str) -> tuple[bool, bool, bool]:
    """Return (has_vd, has_vs1, has_vs2) register-group presence for a given Type.

    Unknown types default to (True, True, True) so we don't accidentally drop bins
    for new types that are added without updating this table.
    """
    return _TYPE_OPERANDS.get(instr_type, (True, True, True))


def _max_legal_lmul_for_instruction(instr: str) -> int:
    """Return the largest legal LMUL for ``instr`` (≤ 8).

    Mirrors the rules in ``priv/_ssstrictv_helpers.max_legal_lmul``:

    * Segment LS instructions require ``NF * EMUL ≤ 8`` so EMUL ≤ 8/NF.
    * Widening / narrowing ops have an operand with EEW = 2*SEW so EMUL = 2*LMUL,
      capping LMUL at 4.
    * Otherwise LMUL ≤ 8.
    """
    _c = _VECTOR_TESTGEN_COMMON
    nf = _c.getInstructionSegments(instr)
    if nf and nf > 1:
        cap = 8 // nf
        for m in (8, 4, 2, 1):
            if m <= cap:
                return m
        return 1
    if instr in _c.vd_widen_ins or instr in _c.vs2_widen_ins:
        return 4
    return 8


_LMUL_CROSS_RE = re.compile(r"cp_ssstrictv_lmul(\d+)_(vd|vs1|vs2)_off_group")


def _filter_per_operand_crosses(rendered: str, has_vd: bool, has_vs1: bool, has_vs2: bool, max_lmul: int) -> str:
    """Drop cross lines tied to operands the instruction's Type does not encode.

    The ``cp_ssstrictv_lmulgt1_off_group`` template emits one cross per (lmul,
    operand) pair. Two reasons we may drop a cross:

    * Operand absent in the Type encoding (e.g. ``vid.v`` has no vs1/vs2).
    * The (LMUL, instruction) combination is illegal — e.g. widening ops cap at
      LMUL=4 because vd has EEW=2*SEW, and segment LS caps at LMUL=8/NF.
    """
    if has_vd and has_vs1 and has_vs2 and max_lmul >= 8:
        return rendered
    out_lines: list[str] = []
    for line in rendered.splitlines(keepends=True):
        stripped = line.lstrip()
        m = _LMUL_CROSS_RE.search(stripped)
        if m and stripped.startswith("cp_ssstrictv_lmul"):
            lmul = int(m.group(1))
            role = m.group(2)
            if role == "vd" and not has_vd:
                continue
            if role == "vs1" and not has_vs1:
                continue
            if role == "vs2" and not has_vs2:
                continue
            if lmul > max_lmul:
                continue
        out_lines.append(line)
    return "".join(out_lines)


def _write_if_changed(path: Path, content: str) -> None:
    """Write content only if it differs from the existing file, to avoid unnecessary rebuilds."""
    if path.exists() and path.read_text() == content:
        return
    path.write_text(content)


##################################
# Reading testplans and templates
##################################


def _parse_testplan_csv(csv_path: Path) -> dict[tuple[str, str], list[str]]:
    """Parse a single testplan CSV into a dict of (instruction, type) -> coverpoints."""
    tp: dict[tuple[str, str], list[str]] = {}
    with csv_path.open() as csvfile:
        for row in csv.DictReader(csvfile):
            if "Instruction" not in row:
                raise ValueError(
                    f"Error reading testplan {csv_path.name}. "
                    "Did you remember to shrink the .csv files after expanding?"
                )
            instr = row["Instruction"]
            instr_type = row.get("Type", "")

            cps: list[str] = []
            del row["Instruction"]
            for key, value in row.items():
                if not isinstance(value, str) or value == "":
                    continue
                if key == "Type":
                    # TODO: Expand the list of aliased types to avoid duplicate sample function templates
                    sample_type = value.removesuffix("_RD_NX0")
                    cps.append(f"sample_{sample_type}")
                else:
                    # For special entries, append the value as a suffix
                    # e.g. cp_rd_edges with value "lui" becomes cp_rd_edges_lui
                    if value != "x":
                        key = f"{key}_{value}"
                    cps.append(key)

            tp[(instr, instr_type)] = cps
    return tp


def read_testplans(testplan_dir: Path) -> dict[str, dict[tuple[str, str], list[str]]]:
    """Read all CSV testplan files and return a dict mapping extension name to testplan.

    Each CSV file produces one testplan entry keyed by the file's stem (e.g. "I", "Zba").
    Some extensions are expanded:
      - "I" is duplicated as "E"
      - Vector extensions are expanded into per-SEW variants (e.g. Vx → Vx8/16/32/64);
        see _sew_variants_for for the exact prefix → SEW mapping.
    """
    testplans: dict[str, dict[tuple[str, str], list[str]]] = {}

    for csv_path in testplan_dir.glob("*.csv"):
        arch = csv_path.stem
        tp = _parse_testplan_csv(csv_path)
        testplans[arch] = tp

        # Duplicate I testplan for E
        if arch == "I":
            testplans["E"] = tp

        # Expand vector extensions into per-SEW variants, replacing the base entry
        sew_variants = _sew_variants_for(arch)
        if sew_variants is not None:
            for sew in sew_variants:
                testplans[f"{arch}{sew}"] = tp
            del testplans[arch]

    return testplans


def _filter_testplans(
    test_plans: dict[str, dict[tuple[str, str], list[str]]],
    extensions: str,
    exclude: str,
) -> dict[str, dict[tuple[str, str], list[str]]]:
    """Filter testplans by comma-separated include/exclude extension lists.

    Matches against post-expansion keys (e.g. Vx8, not Vx).
    """
    include_set: set[str] | None = None
    if extensions != "all":
        include_set = {ext.strip() for ext in extensions.split(",") if ext.strip()}
    exclude_set: set[str] = set()
    if exclude:
        exclude_set = {ext.strip() for ext in exclude.split(",") if ext.strip()}

    return {
        arch: tp
        for arch, tp in test_plans.items()
        if (include_set is None or arch in include_set) and arch not in exclude_set
    }


def read_covergroup_templates(package: str = "covergroupgen.templates") -> dict[str, str]:
    """Recursively read all .sv covergroup templates from the given package and its sub-packages."""
    templates: dict[str, str] = {}
    for item in importlib.resources.files(package).iterdir():
        if item.is_file() and item.name.endswith(".sv"):
            templates[item.name.removesuffix(".sv")] = item.read_text()
        elif item.is_dir() and not item.name.startswith("__"):
            templates.update(read_covergroup_templates(f"{package}.{item.name}"))
    return templates


##################################
# Template helpers
##################################


def _instruction_id(instr: str) -> str:
    """Return the SystemVerilog enum identifier for an instruction mnemonic."""
    return "INSTR_" + re.sub(r"[^A-Za-z0-9]+", "_", instr).strip("_").upper()


def customize_template(templates: dict[str, str], name: str, arch: str = "", instr: str = "", effew: str = "") -> str:
    """Look up a template by name and substitute placeholders.

    Placeholders replaced: INSTRNODOT, INSTR, ARCHPREFIXUPPER, ARCHPREFIX,
    ARCHUPPER, ARCHCASE, ARCH, and (if effew is set) TWOEFFEW, EFFEW, EFFVSEW.
    ARCHPREFIX is the arch with any trailing digits stripped (e.g. "Vx16" -> "Vx").
    """
    if name not in templates:
        available = list(templates.keys())
        similar = get_close_matches(name, available, n=5, cutoff=0.4)
        msg = f"No template found for '{name}'. "
        if similar:
            msg += f"Similar templates: {', '.join(similar)}. "
        templates_dir = importlib.resources.files("covergroupgen.templates")
        msg += f"To add support, create a new .sv template in '{templates_dir}'."
        raise ValueError(msg)

    arch_prefix = re.sub(r"\d+$", "", arch)
    result = (
        templates[name]
        .replace("INSTRNODOT", instr.replace(".", "_"))
        .replace("INSTR", instr)
        .replace("DECODEID", _instruction_id(instr))
        .replace("ARCHPREFIXUPPER", arch_prefix.upper())
        .replace("ARCHPREFIX", arch_prefix)
        .replace("ARCHUPPER", arch.upper())
        .replace("ARCHCASE", arch)
        .replace("ARCH", arch.lower())
    )
    if effew:
        result = (
            result.replace("TWOEFFEW", str(2 * int(effew)))
            .replace("EFFEW", str(int(effew)))
            .replace("EFFVSEW", str(int(math.log2(int(effew))) - 3))
        )
    return result


def _get_effew(arch: str) -> str:
    """Extract the effective element width (SEW) from an architecture name.

    Examples: "Vx32" -> "32", "Zvfhmin" -> "16"
    """
    match = re.search(r"(\d+)$", arch)
    if match:
        return match.group(1)
    if arch in ("Zvfhmin", "Zvfbfmin", "Zvfbfwma"):
        return "16"
    if arch.startswith("Zvk"):
        return "32"
    raise ValueError(f"Arch does not contain an expected integer: '{arch}'")


def _is_vector(arch: str) -> bool:
    return arch.startswith(VECTOR_PREFIXES)


def _is_priv_vector(arch: str) -> bool:
    """Priv testplans whose covergroups need vector helpers but no SEW expansion."""
    return arch.startswith(PRIV_VECTOR_PREFIXES)


def _is_vector_widen(arch: str, instr: str) -> bool:
    """Check if this is a vector widening instruction."""
    return arch.startswith(VECTOR_WIDEN_PREFIXES) and (instr.startswith(("vw", "vfw")) or ".w" in instr)


def _has_effew_suffix(arch: str) -> bool:
    """Whether *arch* uses the per-SEW EFFEW{N} testplan filter."""
    return _is_vector(arch) or bool(re.match(r"ExceptionsVf\d+$", arch))


def _get_sorted_instr_keys(tp: dict[tuple[str, str], list[str]], arch: str) -> list[tuple[str, str]]:
    """Get sorted instruction keys, filtering by EFFEW for vector/per-SEW priv arches."""
    keys = sorted(tp.keys())
    if _has_effew_suffix(arch):
        effew = _get_effew(arch)
        keys = [k for k in keys if f"EFFEW{effew}" in tp[k]]
    return keys


def _matches_xlen(cps: list[str], has_rv32: bool, has_rv64: bool) -> bool:
    """Check if an instruction's coverpoints match the requested XLEN filter.

    An instruction matches when its RV32/RV64 markers agree with the filter.
    Instructions without an RV32 or RV64 marker match any XLEN.
    """
    return ("RV32" in cps) == has_rv32 and ("RV64" in cps) == has_rv64


def _any_xlen_exclusion(
    rv_marker: str, instr_keys: list[tuple[str, str]], tp: dict[tuple[str, str], list[str]]
) -> bool:
    """Check if any instruction lacks the given RV marker (meaning it's XLEN-specific)."""
    return any(rv_marker not in tp[key] for key in instr_keys)


_VLS_PER_SEW_ARCHES = {"Vls8", "Vls16", "Vls32", "Vls64"}


def _indexed_ls_eew(instr: str) -> int | None:
    """Return the index EEW if *instr* is an indexed load/store, else None.

    Matches vluxeiN, vsuxeiN, vloxsegMeiN, vsoxsegMeiN. Does NOT match
    vrgatherei16 (not a load/store).
    """
    m = re.match(r"v[sl](ox|ux)(seg\d+)?ei(\d+)\.", instr)
    return int(m.group(3)) if m else None


def _should_gate_maxindexeew(arch: str, instr: str) -> tuple[int, str] | None:
    """Return (eew, macro_prefix) to gate on, or None if no gate should be emitted.

    Unpriv per-SEW Vls{N} arches gate indexed LS covergroups behind
    MAXINDEXEEW_GE{eew}. Priv MisalignV / ExceptionsVls covergroups gate
    behind XLEN{eew} so EEW=64 indexed-LS coverage is suppressed on RV32
    (see sail-riscv issue 1719: Sail RV32 takes illegal-instruction on
    EEW=64 indexed LS while other sims take a load access fault, producing
    mismatched mcause in the signature). Vx (vrgather) never gates.
    """
    eew = _indexed_ls_eew(instr)
    if not eew or eew <= 8:
        return None
    if arch in _VLS_PER_SEW_ARCHES:
        return (eew, "MAXINDEXEEW_GE")
    if arch in ("MisalignV", "ExceptionsVls"):
        # XLEN16 macro does not exist; XLEN is always >= 32, so only gate eew=64.
        if eew >= 64:
            return (eew, "XLEN")
        return None
    return None


def _ffLS_feasible(instr: str, sew: int) -> bool:
    """Check if cp_custom_ffLS (which requires LMUL=2) is feasible for this instruction at the given SEW.

    Returns False when EMUL * nf > 8 with LMUL=2, meaning the configuration is impossible.
    """
    # Extract EEW from instruction name (e.g., vle32ff.v → 32, vlseg3e64ff.v → 64)
    eew_m = re.search(r"e(\d+)ff", instr)
    if not eew_m:
        return True
    eew = int(eew_m.group(1))
    # Extract nf (number of fields) from segmented instructions
    nf_m = re.search(r"seg(\d+)", instr)
    nf = int(nf_m.group(1)) if nf_m else 1
    lmul = 2
    emul = eew * lmul // sew
    return emul * nf <= 8


##################################
# Content generation
##################################


def _resolve_coverpoint(cp: str, arch: str, instr: str) -> str | None:
    """Resolve a raw testplan coverpoint to its final template name, or None to skip it.

    Applies, in order: metadata-column skips, the SsstrictV skip table, the
    cp_custom_ffLS feasibility gate, and the SEW-conditional suffix rules
    (_sew_ge{N}, the SEW-dependent suffix, _eew_eq_sew, _sew_lte_{N}).
    """
    # Skip metadata columns (sample_*, RV32/RV64, EFFEW*, cp_ibm).
    if cp.startswith(("sample_", "EFFEW", "cp_ibm")) or cp in {"RV32", "RV64"}:
        return None

    # SsstrictV: honor the curated (column, instruction) skip table that records
    # simulator-failure / unimplemented combinations. Skipping here removes the
    # bins from the covergroup so they do not count as missing coverage.
    if arch.startswith("SsstrictV") and instr in SSSTRICTV_SKIP_COMBINATIONS.get(cp, ()):
        return None

    # cp_custom_ffLS requires LMUL=2; Use a fallback when this isn't possible
    if cp == "cp_custom_ffLS" and _is_vector(arch) and not _ffLS_feasible(instr, int(_get_effew(arch))):
        cp = "cp_custom_ffLS_lmul_lt2"

        eew_m = re.search(r"e(\d+)ff", instr)
        eew = int(eew_m.group(1)) if eew_m else 0
        if eew >= 32:
            cp += f"_eew{eew}"

    # _sew_ge{N}: only applies when arch SEW >= N; strip the suffix when it does.
    ge_match = re.search(r"_sew_ge(\d+)$", cp)
    if ge_match:
        if not _is_vector(arch) or int(_get_effew(arch)) < int(ge_match.group(1)):
            return None
        cp = re.sub(r"_sew_ge\d+$", "", cp)

    # Append SEW suffix for SEW-dependent coverpoints.
    if any(sew_cp in cp for sew_cp in SEW_DEPENDENT_CPS):
        cp = cp + "_sew" + _get_effew(arch)

    # _eew_eq_sew[_lte{N}]: only emit when the indexed-LS EEW equals the arch SEW.
    if re.search(r"_eew_eq_sew(?:_lte\d+)?$", cp):
        eew = _indexed_ls_eew(instr)
        if eew is not None and _is_vector(arch) and int(_get_effew(arch)) != eew:
            return None

    # _sew_lte_{N}: only emit when arch SEW <= N; strip the suffix when it does.
    # Exclude `_eew_eq_sew_lte{N}` which is a vs3-range variant, not a SEW gate.
    if re.search(r"_sew_lte_?\d+$", cp) and not re.search(r"_eew_eq_sew_lte\d+$", cp):
        digits = re.search(r"(\d+)$", cp)
        if digits:
            if int(_get_effew(arch)) > int(digits.group(1)):
                return None
            cp = re.sub(r"_sew_lte_\d+", "", cp)

    return cp


def _gen_instrs(
    instr_keys: list[tuple[str, str]],
    templates: dict[str, str],
    tp: dict[tuple[str, str], list[str]],
    arch: str,
    has_rv32: bool,
    has_rv64: bool,
) -> tuple[str, str]:
    """Generate covergroup definitions and init content for matching instructions.

    Returns (covergroup_content, init_content).
    """
    covergroup_lines: list[str] = []
    init_lines: list[str] = []

    for instr, _instr_type in instr_keys:
        cps = tp[(instr, _instr_type)]
        if not _matches_xlen(cps, has_rv32, has_rv64):
            continue

        vectorwiden = _is_vector_widen(arch, instr)

        # Gate indexed LS covergroups by MAXINDEXEEW for unpriv per-SEW
        # Vls{N} arches, and by XLEN for priv MisalignV / ExceptionsVls.
        # Priv ei64 covergroups are suppressed on RV32 because Sail RV32
        # takes illegal-instruction on EEW=64 indexed LS while other sims
        # take a load access fault (see sail-riscv issue 1719). Vx (vrgather)
        # never gates.
        gate = _should_gate_maxindexeew(arch, instr)
        if gate:
            idx_eew, macro_prefix = gate
            covergroup_lines.append(f"`ifdef {macro_prefix}{idx_eew}\n")
            init_lines.append(f"`ifdef {macro_prefix}{idx_eew}\n")

        # Instruction header
        if vectorwiden:
            effew = _get_effew(arch)
            covergroup_lines.append(customize_template(templates, "instruction_vector_widen", arch, instr, effew=effew))
            init_lines.append(customize_template(templates, "init_vector_widen", arch, instr, effew=effew))
        else:
            covergroup_lines.append(customize_template(templates, "instruction", arch, instr))
            init_lines.append(customize_template(templates, "init", arch, instr))

        # SsstrictV templates reference a small set of helpers (vtype_lmul_*,
        # std_trap_vec, mask_enabled, vd_v0, vd/vs1/vs2_all_reg_unaligned_lmul_*,
        # vstart_zero, vl_nonzero, vtype_prev_vill_*, vtype_all_lmulge1).
        # We include a SsstrictV-scoped header rather than the full standard
        # vector header so the SsstrictV covergroups don't pick up dozens of
        # unrelated 32-bin sweeps (vd_all_reg, vs1_all_reg, etc.) that aren't in
        # SsstrictV's testplan and would inflate the corpus past the linker's
        # ±1MiB JAL range. Other priv vector arches (ExceptionsVx/Vls/Vf)
        # intentionally use a small, focused set of coverpoints (cp_vill /
        # cp_vstart / cp_vstart_gt_vl) and must not pull in either header.
        if arch.startswith("SsstrictV"):
            covergroup_lines.append('    `include "general/RISCV_coverage_ssstrictv_helpers.svh"\n')

        # Coverpoint entries (skip metadata columns: sample_*, RV32, RV64, EFFEW*)
        # VCS requires coverpoints to be declared before cross references.
        early_cps = {"cp_frm_2", "cp_frm_3", "cp_frm_4", "std_vec"}
        ordered_cps = sorted(cps, key=lambda cp: (0 if cp in early_cps else 2 if cp.startswith("cr_") else 1, cp))
        # Per-operand cross filtering depends only on the instruction, so resolve
        # its operand presence and max LMUL once rather than per coverpoint.
        has_vd, has_vs1, has_vs2 = _operand_presence(_instr_type)
        max_lmul = _max_legal_lmul_for_instruction(instr)
        for cp in ordered_cps:
            resolved = _resolve_coverpoint(cp, arch, instr)
            if resolved is None:
                continue
            rendered = customize_template(templates, resolved, arch, instr) + "\n"
            covergroup_lines.append(_filter_per_operand_crosses(rendered, has_vd, has_vs1, has_vs2, max_lmul))

        # Instruction footer
        if vectorwiden:
            covergroup_lines.append(customize_template(templates, "endgroup_vector_widen", arch, instr))
        else:
            covergroup_lines.append(customize_template(templates, "endgroup", arch, instr))

        if gate:
            covergroup_lines.append("`endif\n")
            init_lines.append("`endif\n")

    return "".join(covergroup_lines), "".join(init_lines)


def _gen_covergroup_samples(
    instr_keys: list[tuple[str, str]],
    templates: dict[str, str],
    tp: dict[tuple[str, str], list[str]],
    arch: str,
    has_rv32: bool,
    has_rv64: bool,
) -> str:
    """Generate covergroup sample function calls for matching instructions."""
    lines: list[str] = []
    for instr, _instr_type in instr_keys:
        cps = tp[(instr, _instr_type)]
        if not _matches_xlen(cps, has_rv32, has_rv64):
            continue

        gate = _should_gate_maxindexeew(arch, instr)
        if gate:
            idx_eew, macro_prefix = gate
            lines.append(f"`ifdef {macro_prefix}{idx_eew}\n")

        if arch.startswith(VECTOR_WIDEN_PREFIXES):
            if _is_vector_widen(arch, instr):
                effew = _get_effew(arch)
                lines.append(customize_template(templates, "covergroup_sample_vector_widen", arch, instr, effew=effew))
            else:
                lines.append(customize_template(templates, "covergroup_sample_vector", arch, instr))
        elif arch != "E":  # E currently breaks coverage
            lines.append(customize_template(templates, "covergroup_sample", arch, instr))

        if gate:
            lines.append("`endif\n")

    return "".join(lines)


def _sign_extend(expression: str, width: int) -> str:
    """Return a SystemVerilog expression sign-extended to XLEN."""
    first_field = expression.split(",", 1)[0].lstrip("{") if expression.startswith("{") else expression
    match = re.fullmatch(r"(.+)\[(\d+)(?::\d+)?\]", first_field)
    if match is None:
        raise ValueError(f"Cannot find the sign bit in {expression}")
    sign_bit = f"{match.group(1)}[{match.group(2)}]"
    return f"{{{{(XLEN-{width}){{{sign_bit}}}}}, {expression}}}"


def _immediate_expression(instr: str, instr_type: str) -> str:
    """Return the encoded immediate for an instruction format."""
    if instr_type == "B":
        return _sign_extend("{decoded_insn[31], decoded_insn[7], decoded_insn[30:25], decoded_insn[11:8], 1'b0}", 13)
    if instr_type == "CB":
        return _sign_extend(
            "{decoded_insn[12], decoded_insn[6:5], decoded_insn[2], decoded_insn[11:10], decoded_insn[4:3], 1'b0}",
            9,
        )
    if instr_type == "CBP":
        return _sign_extend("{decoded_insn[12], decoded_insn[6:2]}", 6)
    if instr_type in {"CBS", "CIS"}:
        return "{decoded_insn[12], decoded_insn[6:2]}"
    if instr == "c.addi16sp":
        return _sign_extend(
            "{decoded_insn[12], decoded_insn[4:3], decoded_insn[5], decoded_insn[2], decoded_insn[6], 4'b0}",
            10,
        )
    if instr_type in {"CI", "CIU", "CN"}:
        return _sign_extend("{decoded_insn[12], decoded_insn[6:2]}", 6)
    if instr_type == "CIW":
        return "{decoded_insn[10:7], decoded_insn[12:11], decoded_insn[5], decoded_insn[6], 2'b0}"
    if instr_type in {"CJ", "CJAL"}:
        return _sign_extend(
            "{decoded_insn[12], decoded_insn[8], decoded_insn[10:9], decoded_insn[6], decoded_insn[7], "
            "decoded_insn[2], decoded_insn[11], decoded_insn[5:3], 1'b0}",
            12,
        )
    if instr_type == "CSRI":
        return "decoded_insn[19:15]"
    if instr_type in {"I", "JR", "PRE", "FL", "L"}:
        return _sign_extend("decoded_insn[31:20]", 12)
    if instr_type in {"IMM", "U"}:
        return _sign_extend("decoded_insn[31:12]", 20)
    if instr_type == "IS":
        return "decoded_insn[25:20]"
    if instr_type == "ISW":
        return "decoded_insn[24:20]"
    if instr_type == "J":
        return _sign_extend("{decoded_insn[31], decoded_insn[19:12], decoded_insn[20], decoded_insn[30:21], 1'b0}", 21)
    if instr_type in {"MVI", "MVIC", "MVIM", "VMVVI", "VVI", "VVIM", "VVI_SAT"}:
        return _sign_extend("decoded_insn[19:15]", 5)
    if instr_type in {"VVIP", "VVIP_DOWN", "VVIU", "VVI_EGS4", "VVI_EGS8", "VWI", "WVI"}:
        return "decoded_insn[19:15]"
    if instr_type in {"FS", "S"}:
        return _sign_extend("{decoded_insn[31:25], decoded_insn[11:7]}", 12)
    if instr_type in {"CL", "CFL", "CS", "CFS"}:
        if instr in {"c.ld", "c.fld", "c.sd", "c.fsd"}:
            return "{decoded_insn[6:5], decoded_insn[12:10], 3'b0}"
        return "{decoded_insn[5], decoded_insn[12:10], decoded_insn[6], 2'b0}"
    if instr_type in {"CLB", "CSB"}:
        return "{decoded_insn[5], decoded_insn[6]}"
    if instr_type in {"CLH", "CSH"}:
        return "{decoded_insn[5], 1'b0}"
    if instr_type in {"CILS", "CFLS"}:
        if instr in {"c.ldsp", "c.fldsp"}:
            return "{decoded_insn[4:2], decoded_insn[12], decoded_insn[6:5], 3'b0}"
        return "{decoded_insn[3:2], decoded_insn[12], decoded_insn[6:4], 2'b0}"
    if instr_type in {"CSS", "CFSS"}:
        if instr in {"c.sdsp", "c.fsdsp"}:
            return "{decoded_insn[9:7], decoded_insn[12:10], 3'b0}"
        return "{decoded_insn[8:7], decoded_insn[12:9], 2'b0}"
    raise ValueError(f"No immediate decoder for {instr} ({instr_type})")


def _direct_sample_statements(instr: str, instr_type: str, statements: list[str]) -> list[str]:
    """Replace disassembly operand offsets with encoded fields."""
    rd = (
        "{2'b01, decoded_insn[9:7]}"
        if instr_type in {"CA", "CBP", "CBS", "CU"}
        else "{2'b01, decoded_insn[4:2]}"
        if instr_type in {"CL", "CLB", "CLH", "CIW"}
        else "decoded_insn[11:7]"
    )
    rs1 = (
        "{2'b01, decoded_insn[9:7]}"
        if instr_type in {"CA", "CB", "CBP", "CBS", "CFL", "CFS", "CL", "CLB", "CLH", "CS", "CSB", "CSH", "CU"}
        else "decoded_insn[11:7]"
        if instr_type in {"CI", "CIS", "CIU", "CJALR", "CJR", "CR"}
        else "5'd2"
        if instr_type == "CIW"
        else "decoded_insn[19:15]"
    )
    rs2 = (
        "{2'b01, decoded_insn[4:2]}"
        if instr_type in {"CA", "CFS", "CS", "CSB", "CSH"}
        else "decoded_insn[6:2]"
        if instr_type in {"CFSS", "CR", "CSS"}
        else "decoded_insn[24:20]"
    )
    fd = "{2'b01, decoded_insn[4:2]}" if instr_type == "CFL" else "decoded_insn[11:7]"
    fs2 = (
        "{2'b01, decoded_insn[4:2]}"
        if instr_type == "CFS"
        else "decoded_insn[6:2]"
        if instr_type == "CFSS"
        else "decoded_insn[24:20]"
    )
    replacements = {
        "add_rd": rd,
        "add_rd_pair": rd,
        "add_rs1": rs1,
        "add_rs2": rs2,
        "add_rs3": "decoded_insn[31:27]",
        "add_fd": fd,
        "add_fs1": "decoded_insn[19:15]",
        "add_fs2": fs2,
        "add_fs3": "decoded_insn[31:27]",
    }
    fixed_fields = {"add_vd", "add_vs1", "add_vs2", "add_vs3", "add_vm"}
    result: list[str] = []
    for statement in statements:
        match = re.fullmatch(r"ins\.(add_[a-zA-Z0-9_]+)\([^)]*\);", statement)
        if match is None:
            result.append(statement)
            continue
        method = match.group(1)
        if method in replacements:
            result.append(f"ins.{method}({replacements[method]});")
        elif method in {"add_imm", "add_imm_addr", "add_mem_offset"}:
            result.append(f"ins.{method}({_immediate_expression(instr, instr_type)});")
        elif method in fixed_fields:
            result.append(f"ins.{method}();")
        else:
            result.append(statement)
    return result


def _instruction_sample_bodies(
    instr_keys: list[tuple[str, str]],
    templates: dict[str, str],
    tp: dict[tuple[str, str], list[str]],
    has_rv32: bool,
    has_rv64: bool,
) -> dict[str, tuple[str, list[str]]]:
    """Return each instruction's format and sample statements for one XLEN."""
    result: dict[str, tuple[str, list[str]]] = {}
    for instr, instr_type in instr_keys:
        cps = tp[(instr, instr_type)]
        xlen_marked = "RV32" in cps or "RV64" in cps
        if xlen_marked and ((has_rv32 and "RV32" not in cps) or (has_rv64 and "RV64" not in cps)):
            continue
        samples = [customize_template(templates, cp, "", instr) for cp in cps if cp.startswith("sample_")]
        if not samples:
            continue
        body = [line.strip() for line in "".join(samples).splitlines()[1:-1] if line.strip()]
        body = _direct_sample_statements(instr, instr_type.removesuffix("_RD_NX0"), body)
        if instr in result:
            raise ValueError(f"Multiple instruction formats for {instr} at the same XLEN")
        result[instr] = (instr_type.removesuffix("_RD_NX0"), body)
    return result


def _decode_action(
    instr: str,
    rv32: dict[str, tuple[str, list[str]]],
    rv64: dict[str, tuple[str, list[str]]],
    indent: str,
) -> list[str]:
    """Generate direct operand decoding for one mnemonic."""
    lines = [f"{indent}ins.set_instruction({_instruction_id(instr)});\n"]
    rv32_metadata = rv32.get(instr)
    rv64_metadata = rv64.get(instr)
    if rv32_metadata is None and rv64_metadata is None:
        return lines
    if rv32_metadata is not None and rv32_metadata == rv64_metadata:
        _instr_type, body = rv32_metadata
        lines.extend(f"{indent}{statement}\n" for statement in body)
        return lines

    for macro, metadata in (("UDB_MXLEN_32", rv32_metadata), ("UDB_MXLEN_64", rv64_metadata)):
        if metadata is None:
            continue
        _instr_type, body = metadata
        lines.append(f"{indent}`ifdef {macro}\n")
        lines.extend(f"{indent}  {statement}\n" for statement in body)
        lines.append(f"{indent}`endif\n")
    return lines


def _generate_fallback_decode(
    fallback_source: str,
    rv32: dict[str, tuple[str, list[str]]],
    rv64: dict[str, tuple[str, list[str]]],
    indent: str,
) -> tuple[list[str], set[str]]:
    """Generate direct decode entries for reserved vector encodings."""
    lines = [f"{indent}casez (decoded_insn)\n"]
    decoded: set[str] = set()
    pattern = re.compile(r'^\s*(32\'b[01?_]+): return "([^"]+)";')
    for source_line in fallback_source.splitlines():
        match = pattern.match(source_line)
        if match is None:
            continue
        encoding, instr = match.groups()
        decoded.add(instr)
        lines.append(f"{indent}  {encoding}: begin\n")
        lines.extend(_decode_action(instr, rv32, rv64, f"{indent}    "))
        lines.append(f"{indent}  end\n")
    lines.append(f"{indent}  default: ins.set_instruction(INSTR_ILLEGAL);\n")
    lines.append(f"{indent}endcase\n")
    return lines, decoded


def _generate_instruction_decode(
    disassembler_source: str,
    fallback_source: str,
    rv32: dict[str, tuple[str, list[str]]],
    rv64: dict[str, tuple[str, list[str]]],
) -> tuple[str, set[str]]:
    """Convert the diagnostic disassembler case into direct instruction decoding."""
    start = disassembler_source.index("  casez (instr)")
    end = disassembler_source.index("  endcase", start) + len("  endcase")
    source_lines = disassembler_source[start:end].splitlines()
    lines = [
        "// This file is autogenerated by covergroupgen.\n",
        "ins_t ins;\n",
        "bit [31:0] decoded_insn;\n",
        "bit [4:0] rdBits;\n",
        "bit [4:0] crs2Bits;\n",
        "bit signed [5:0] immCIType;\n",
        "bit signed [9:0] immCIASPType;\n",
        "bit [9:0] immCIWType;\n\n",
        "ins = new(hart, issue, traceDataQ);\n",
        "decoded_insn = ins.current.insn[1:0] == 2'b11 ? ins.current.insn : {16'b0, ins.current.insn[15:0]};\n",
        "rdBits = decoded_insn[11:7];\n",
        "crs2Bits = decoded_insn[6:2];\n",
        "immCIType = {decoded_insn[12], decoded_insn[6:2]};\n",
        "immCIASPType = {decoded_insn[12], decoded_insn[4:3], decoded_insn[5], decoded_insn[2], decoded_insn[6], 4'b0};\n",
        "immCIWType = {decoded_insn[10:7], decoded_insn[12:11], decoded_insn[5], decoded_insn[6], 2'b0};\n\n",
    ]
    decoded: set[str] = set()
    format_pattern = re.compile(r'\$sformat\(decoded,\s*"([^"]+)"')
    for source_line in source_lines:
        if source_line.strip() == "casez (instr)":
            lines.append("casez (decoded_insn)\n")
            continue
        match = format_pattern.search(source_line)
        if match is not None:
            instr = match.group(1).split()[0]
            decoded.add(instr)
            prefix = source_line[: source_line.index("$sformat")]
            leading = prefix[: len(prefix) - len(prefix.lstrip())]
            lines.append(f"{prefix}begin\n")
            lines.extend(_decode_action(instr, rv32, rv64, f"{leading}  "))
            lines.append(f"{leading}end\n")
        elif source_line.strip().startswith("default:"):
            leading = source_line[: len(source_line) - len(source_line.lstrip())]
            lines.append(f"{leading}default: begin\n")
            fallback_lines, fallback_decoded = _generate_fallback_decode(fallback_source, rv32, rv64, f"{leading}  ")
            lines.extend(fallback_lines)
            decoded.update(fallback_decoded)
            lines.append(f"{leading}end\n")
        else:
            lines.append(f"{source_line}\n")

    missing = (set(rv32) | set(rv64)) - decoded
    if missing:
        raise ValueError(f"Instructions missing from direct decoder: {', '.join(sorted(missing))}")
    return "".join(lines), decoded


##################################
# File writers
##################################


def _write_extension_files(
    arch: str,
    tp: dict[tuple[str, str], list[str]],
    templates: dict[str, str],
    output_dir: Path,
    *,
    vector: bool,
) -> None:
    """Write the _coverage.svh / _coverage_init.svh pair for one extension.

    When *vector* is True the vector-flavored header/sample templates are used,
    an EFFEW substitution is made available in the header, and the instruction
    key list is filtered to the matching SEW.
    """
    per_sew = vector or _has_effew_suffix(arch)
    effew = ""
    if per_sew:
        try:
            effew = _get_effew(arch)
        except ValueError:
            # Priv vector archs (SsstrictV, ExceptionsV*, MisalignV) have no SEW expansion or EFFEW.
            effew = ""
    instr_keys = _get_sorted_instr_keys(tp, arch) if per_sew else sorted(tp.keys())

    # Priv vector archs (SsstrictV, ExceptionsV*, MisalignV) don't expand per-SEW, so
    # neither the EFFEW defines in header_vector nor the EFFVSEW gate in the vector
    # sample header/end apply — use the non-vector templates for them.
    use_vector_sample = vector and bool(effew)
    header_tmpl = "header_vector" if use_vector_sample else "header"
    sample_header_tmpl = "covergroup_sample_header_vector" if use_vector_sample else "covergroup_sample_header"
    sample_end_tmpl = "covergroup_sample_end_vector" if use_vector_sample else "covergroup_sample_end"

    lines: list[str] = [customize_template(templates, header_tmpl, arch, effew=effew)]
    init_lines: list[str] = [customize_template(templates, "initheader", arch)]

    # Covergroup definitions: common instructions, then RV32-only, then RV64-only
    instr_content, init_content = _gen_instrs(instr_keys, templates, tp, arch, True, True)
    lines.append(instr_content)
    init_lines.append(init_content)

    for rv32, rv64, exclude_marker in ((True, False, "RV64"), (False, True, "RV32")):
        if _any_xlen_exclusion(exclude_marker, instr_keys, tp):
            guard = customize_template(templates, "RV32" if rv32 else "RV64", arch)
            end = customize_template(templates, "end", arch)
            instr_content, init_content = _gen_instrs(instr_keys, templates, tp, arch, rv32, rv64)
            lines.extend([guard, instr_content, end])
            init_lines.extend([guard, init_content, end])

    # Covergroup sample functions with the same XLEN ifdef structure
    lines.append(customize_template(templates, sample_header_tmpl, arch, effew=effew))
    lines.append(_gen_covergroup_samples(instr_keys, templates, tp, arch, True, True))
    for rv32, rv64, exclude_marker in ((True, False, "RV64"), (False, True, "RV32")):
        if _any_xlen_exclusion(exclude_marker, instr_keys, tp):
            lines.append(customize_template(templates, "RV32" if rv32 else "RV64", arch))
            lines.append(_gen_covergroup_samples(instr_keys, templates, tp, arch, rv32, rv64))
            lines.append(customize_template(templates, "end", arch))
    lines.append(customize_template(templates, sample_end_tmpl, arch))

    _write_if_changed(output_dir / f"{arch}_coverage.svh", "".join(lines))
    _write_if_changed(output_dir / f"{arch}_coverage_init.svh", "".join(init_lines))


@dataclass
class _CovergroupJob:
    """One per-extension covergroup file pair to write."""

    arch: str
    tp: dict[tuple[str, str], list[str]]
    output_dir: Path
    vector: bool


def _plan_unpriv_jobs(
    test_plans: dict[str, dict[tuple[str, str], list[str]]],
    output_dir: Path,
) -> list[_CovergroupJob]:
    """Collect the unpriv per-extension covergroup jobs (writes go in output_dir/unpriv)."""
    unpriv_dir = output_dir / "unpriv"
    unpriv_dir.mkdir(parents=True, exist_ok=True)
    return [_CovergroupJob(arch, tp, unpriv_dir, _is_vector(arch)) for arch, tp in test_plans.items()]


def write_coverage_headers(
    test_plans: dict[str, dict[tuple[str, str], list[str]]],
    output_dir: Path,
    templates: dict[str, str],
) -> None:
    """Generate and write the shared coverage header files in the coverage/ subdirectory."""
    coverage_dir = output_dir / "coverage"
    coverage_dir.mkdir(parents=True, exist_ok=True)

    # Collect extension names from both unpriv testplans and existing priv covergroups
    keys = set(test_plans.keys())
    priv_path = output_dir / "priv"
    if priv_path.exists():
        keys.update(f.stem.split("_")[0] for f in priv_path.iterdir() if f.name.endswith("_coverage.svh"))
    sorted_keys = sorted(keys)

    # RISCV_coverage_config.svh — ifdef includes for each extension
    lines: list[str] = [customize_template(templates, "config_header")]
    for arch in sorted_keys:
        lines.append(f"`ifdef {arch.upper()}_COVERAGE\n")
        lines.append(f'  `include "{arch}_coverage.svh"\n')
        lines.append("`endif\n")
    _write_if_changed(coverage_dir / "RISCV_coverage_config.svh", "".join(lines))

    # RISCV_coverage_base_init.svh — init calls for each extension
    lines = [customize_template(templates, "base_init_header")]
    for arch in sorted_keys:
        lines.append(customize_template(templates, "coverageinit", arch))
    _write_if_changed(coverage_dir / "RISCV_coverage_base_init.svh", "".join(lines))

    # RISCV_coverage_base_sample.svh — sample calls for each extension
    lines = [customize_template(templates, "base_sample_header")]
    for arch in sorted_keys:
        lines.append(customize_template(templates, "coveragesample", arch))
    _write_if_changed(coverage_dir / "RISCV_coverage_base_sample.svh", "".join(lines))


def _merge_instruction_testplans(
    test_plans: dict[str, dict[tuple[str, str], list[str]]],
    instruction_formats: dict[tuple[str, str], list[str]],
) -> dict[tuple[str, str], list[str]]:
    """Merge testplan and extra instruction formats into a single mapping with unique instruction entries.

    Vector extensions are SEW-expanded (e.g. Vx → Vx8/16/32/64), so the same
    instruction appears in multiple testplan variants.  Merging first-occurrence-wins
    collapses those duplicates before the instruction sample file is generated.
    """
    merged = dict(instruction_formats)
    for arch in sorted(test_plans.keys()):
        if arch == "E":
            continue  # E is a duplicate of I
        tp = test_plans[arch]
        for key in _get_sorted_instr_keys(tp, arch):
            if key not in merged:
                merged[key] = tp[key]
    return merged


def write_instruction_sample_file(
    test_plans: dict[str, dict[tuple[str, str], list[str]]],
    instruction_formats: dict[tuple[str, str], list[str]],
    templates: dict[str, str],
    output_dir: Path,
) -> None:
    """Generate the global instruction and operand decoder."""
    coverage_dir = output_dir / "coverage"
    coverage_dir.mkdir(parents=True, exist_ok=True)

    merged_tp = _merge_instruction_testplans(test_plans, instruction_formats)
    instr_keys = sorted(merged_tp.keys())
    rv32 = _instruction_sample_bodies(instr_keys, templates, merged_tp, True, False)
    rv64 = _instruction_sample_bodies(instr_keys, templates, merged_tp, False, True)

    repo_root = Path(__file__).resolve().parents[4]
    fcov_dir = repo_root / "framework" / "src" / "act" / "fcov"
    content, decoded = _generate_instruction_decode(
        (fcov_dir / "disassemble.svh").read_text(),
        (fcov_dir / "coverage" / "RISCV_disasm_fallback.svh").read_text(),
        rv32,
        rv64,
    )
    ids = {_instruction_id(instr): instr for instr in decoded}
    if len(ids) != len(decoded):
        raise ValueError("Instruction names do not map to unique SystemVerilog identifiers")
    enum_values = ["INSTR_ILLEGAL", *sorted(ids)]
    enum = (
        "// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.\n"
        "// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0\n"
        "// This file is autogenerated by covergroupgen.\n"
        "typedef enum int {\n  "
    )
    enum += ",\n  ".join(enum_values)
    enum += "\n} instruction_id_t;\n"
    _write_if_changed(coverage_dir / "RISCV_instruction_ids.svh", enum)
    _write_if_changed(coverage_dir / "RISCV_instruction_sample.svh", content)


def _plan_priv_jobs(
    testplan_dir: Path,
    output_dir: Path,
    extensions: str = "all",
    exclude: str = "",
) -> list[_CovergroupJob]:
    """Collect the priv per-instruction covergroup jobs from testplans/priv/*.csv.

    Reads CSVs from testplan_dir / "priv"; writes go in output_dir / "priv".
    Extensions with handwritten coverage files are skipped. Returns [] when
    there is no priv testplan directory.
    """
    priv_plan_dir = testplan_dir / "priv"
    if not priv_plan_dir.exists():
        return []

    priv_output_dir = output_dir / "priv"
    priv_output_dir.mkdir(parents=True, exist_ok=True)

    priv_plans = {csv_path.stem: _parse_testplan_csv(csv_path) for csv_path in priv_plan_dir.glob("*.csv")}

    # Mirror the unpriv per-SEW expansion for ExceptionsVf so a single
    # ExceptionsVf.csv produces ExceptionsVf{16,32,64} covergroup files (one
    # per non-reserved vector-FP SEW). Per-instruction filtering is driven by
    # the EFFEW{N} columns in the testplan via _get_sorted_instr_keys, so this
    # block doesn't need to drop any rows itself.
    if "ExceptionsVf" in priv_plans:
        ex_vf_tp = priv_plans["ExceptionsVf"]
        for effew in ("16", "32", "64"):
            priv_plans[f"ExceptionsVf{effew}"] = ex_vf_tp
        del priv_plans["ExceptionsVf"]

    if extensions != "all" or exclude != "":
        priv_plans = _filter_testplans(priv_plans, extensions, exclude)

    return [_CovergroupJob(arch, tp, priv_output_dir, _is_priv_vector(arch)) for arch, tp in priv_plans.items()]


##################################
# Entry point
##################################


def generate_covergroups(testplan_dir: Path, output_dir: Path, extensions: str = "all", exclude: str = "") -> None:
    """Main entry point: read testplans, generate all coverage files."""
    all_test_plans = read_testplans(testplan_dir)
    if extensions != "all" or exclude != "":
        test_plans = _filter_testplans(all_test_plans, extensions, exclude)
    else:
        test_plans = all_test_plans

    templates = read_covergroup_templates()
    instruction_formats = _parse_testplan_csv(testplan_dir / "coverage" / "instruction_formats.csv")

    jobs = _plan_unpriv_jobs(test_plans, output_dir)
    jobs += _plan_priv_jobs(testplan_dir, output_dir, extensions, exclude)
    with _progress("Generating covergroups...") as progress:
        task_id = progress.add_task("covergroups", total=len(jobs))
        for job in jobs:
            _write_extension_files(job.arch, job.tp, templates, job.output_dir, vector=job.vector)
            progress.advance(task_id)

    write_coverage_headers(all_test_plans, output_dir, templates)
    write_instruction_sample_file(all_test_plans, instruction_formats, templates, output_dir)
    rprint(f"[bold green]✓ Generated covergroups for {len(test_plans)} extension(s)[/]")
