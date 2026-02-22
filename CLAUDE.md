# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the RISC-V Architectural Certification Tests (ACTs) repository implementing the **ACT4 Framework** — a Makefile + Python tool for generating, compiling, and running self-checking ELF tests that certify RISC-V implementations against the ISA specification. Tests are generated from CSV testplans and compiled using the RISC-V Sail reference model to compute expected results.

## Common Commands

All commands run from the repo root. The framework uses `uv` to manage Python dependencies.

```bash
# Generate assembly tests (no compiler/Sail needed)
make tests

# Generate and compile self-checking ELFs for default configs (spike rv32/rv64)
make --jobs $(nproc)

# Run with a specific DUT config
CONFIG_FILES=config/cores/<vendor>/<config>/test_config.yaml make --jobs $(nproc)

# Run tests on Spike simulator
make spike       # both rv32 and rv64
make spike-rv64  # rv64 only
make spike-rv32  # rv32 only

# Run tests on QEMU
make qemu

# Lint and type-check Python
make lint          # ruff check + pyright
make lint-fix      # ruff check --fix
make format        # ruff format

# Clean build artifacts (preserves extensions.txt)
make clean

# Clean generated test sources
make clean-tests

# Limit test generation to specific extensions
EXTENSIONS=I,M,Zifencei make tests

# Exclude specific extensions
EXCLUDE_EXTENSIONS=V make tests

# Coverage generation (generates SystemVerilog fcov reports)
make coverage
```

## Git Workflow

PRs target the `act4` branch (not `dev` or `main`). Use a separate feature branch per change. PRs are squash-merged.

## Python Environment

- **Tool**: `uv` (fast Python package manager); venv at `.venv/` (auto-managed)
- **Python version**: 3.12+
- **Key packages**: pydantic, pyjson5, ruamel-yaml, typer

## Python Project Structure

A `uv` workspace with two packages (defined in the top-level `pyproject.toml`):

- **`framework/`** (`act` package) — The ACT4 framework CLI. Entry point: `act`. Orchestrates test selection (via UDB config), Makefile generation, Sail reference model simulation, signature processing, and self-checking ELF production.
- **`generators/testgen/`** (`testgen` package) — CLI (`testgen`) that reads CSV testplans and generates RISC-V assembly test files in `tests/rv32i/`, `tests/rv64i/`, etc.

Additionally, **`generators/ctp/`** contains standalone scripts for CTP (Certification Test Plan) documentation generation. These are not a workspace package — each script uses PEP 723 inline metadata (`/// script` blocks) to declare its own dependencies, and can be run directly (e.g., `uv run generators/ctp/generate_norm_table.py`).

The top-level `pyproject.toml` defines the `uv` workspace and shared dev dependencies (`ruff`, `pyright`). Run `uv run <script>` or use the installed scripts (`act`, `testgen`) via `uv run`.

## Architecture and Data Flow

### Privileged vs. Unprivileged Tests

These two test types use fundamentally different pipelines:

- **Unprivileged**: CSV-driven. Testplans (`testplans/<EXT>.csv`) define instructions and coverpoints → `testgen` generates `.S` files in `tests/rv{32,64}{i,e}/`. Coverpoint Python generators live in `generators/testgen/src/testgen/coverpoints/` and use `@add_coverpoint_generator`. Coverpoint `.svh` files in `coverpoints/unpriv/` are **generated** by `covergroupgen.py` from hand-written templates in `generators/coverage/templates/`.

- **Privileged**: No CSV testplans. Python generators live in `generators/testgen/src/testgen/priv/extensions/` (e.g., `Sm.py`, `ExceptionsZc.py`) using a similar registry/decorator pattern. Tests land in `tests/priv/`. Coverpoint `.svh` files in `coverpoints/priv/` are **hand-written**, not generated.

### Generated vs. Hand-Written Files

Never manually edit generated files — they are overwritten by `make tests`:

- **Generated**: `tests/rv64i/`, `tests/rv32i/`, `tests/rv64e/`, `tests/rv32e/`, `tests/priv/`, `tests/priv/headers/`, `coverpoints/unpriv/*.svh`, `framework/src/act/fcov/coverage/RISCV_imported_decode_pkg.svh`
- **Hand-written**: `testplans/*.csv`, `generators/coverage/templates/*.sv`, `generators/testgen/src/testgen/coverpoints/`, `generators/testgen/src/testgen/priv/extensions/`, `coverpoints/priv/*.svh`, `coverpoints/norm/*.yaml`, `coverpoints/param/*.yaml`

### Adding a New Extension (End-to-End)

1. **CSV Testplan** (`testplans/<EXT>.csv`) — Defines every instruction, its type, supported XLENs, and which coverpoints apply. This drives all subsequent generation.

2. **Coverpoint Templates** (`generators/coverage/templates/`) — SystemVerilog templates for each coverpoint (`<cp_name>.sv`) and instruction format sample (`sample_<TYPE>.sv`). Used by `generators/coverage/covergroupgen.py` to produce `.svh` covergroup files.

3. **Coverpoint Test Generators** (`generators/testgen/src/testgen/coverpoints/`) — Python functions decorated with `@add_coverpoint_generator("<cp_name>")` that produce assembly code for each coverpoint. Files are auto-discovered. Standard generators use `format_single_test`; special generators (in `special/`) write assembly inline.

4. **Instruction Decoder** (`framework/src/act/fcov/disassemble.svh`) — New instructions must be added to the SystemVerilog case statement. Encodings come from the auto-generated `RISCV_imported_decode_pkg.svh` (do not edit manually).

### Key Framework Files

- `framework/src/act/act.py` — Main CLI entry point
- `framework/src/act/config.py` — `test_config.yaml` parsing (Pydantic models)
- `framework/src/act/parse_udb_config.py` — UDB YAML → internal representation
- `framework/src/act/select_tests.py` — Selects which tests apply to a given DUT config
- `framework/src/act/makefile_gen.py` — Generates the `work/` Makefile that compiles ELFs
- `framework/src/act/sig_modify.py` — Processes Sail signatures into self-checking ELF data

### DUT Configuration (`config/`)

Each DUT config directory (e.g., `config/cores/cvw/cvw-rv64gc/`) contains:

- `test_config.yaml` — Compiler, Sail binary, paths
- `<dut>.yaml` — UDB config (extensions, parameters)
- `rvmodel_macros.h` — DUT-specific assembly macros (halt pass/fail, I/O, boot)
- `link.ld` — Linker script
- `sail.json`, `rvtest_config.svh`, `rvtest_config.h` — Currently hand-written; future auto-generation planned

Reference configs under `config/sail/` and `config/spike/` are good models to follow.

### Test Assembly Infrastructure (`tests/env/`)

Common test headers (`arch_test.h`, `test_macros.h`, `signature.h`, etc.) live in `tests/env/`. Generated test `.S` files (`tests/rv64i/`, `tests/rv32i/`, etc.) are produced by `make testgen` and should not be manually edited.

### Coverpoints (`coverpoints/`)

- `coverpoints/norm/` — YAML files mapping normative ISA rules to coverpoints (per extension)
- `coverpoints/param/` — YAML files listing UDB parameters that affect each extension's coverpoints
- `coverpoints/unpriv/` — Generated `.svh` covergroups (from `covergroupgen.py`); `coverpoints/priv/` — Hand-written `.svh` covergroups

## Code Style

- Python: 120-char line length, ruff + pyright enforced. Type annotations required (`ANN` rules enabled). Use `pathlib` (`PTH` rules). `print()` is allowed.
- All source files must include an SPDX license identifier comment.
- `generators/coverage/` and `generators/testgen/scripts/` are excluded from linting (legacy code).

## Testplan CSV Format

```csv
Instruction,Type,RV32,RV64,cp_asm_count,cp_rs1,cp_rs2,cp_rd,...
add,R,x,x,x,x,x,x,...
addi,I,x,x,x,x,,x,...
```

- Mark XLEN support with `x`
- Mark applicable coverpoints with `x` (or a variant suffix like `20bit`)
- See `testplans/I.csv` for a complete reference example

## Test Output and Debugging

Self-checking ELFs produce stdout output:

- **PASSED**: `RVCP-SUMMARY: Test File "<test_name.S>": PASSED`
- **FAILED**: `RVCP-SUMMARY: Test File "<test_name.S>": FAILED` (includes failing PC, instruction, and register mismatch details)

**Debugging test failures** (triage in this order):

1. Check for configuration mismatch (DUT supports feature but UDB says it doesn't, or vice versa)
2. Check the objdump file to understand what the test is doing
3. Verify Sail model config matches UDB config (framework doesn't validate this automatically)
4. Only then suspect a DUT bug

## Contributing

See `CONTRIBUTION.md` for full details. Key points:

- `make lint` must pass
- Add `// SPDX-License-Identifier: Apache-2.0` to new files
- Pre-commit hooks are configured (`.pre-commit-config.yaml`): run `pre-commit run --all-files` before PRs
