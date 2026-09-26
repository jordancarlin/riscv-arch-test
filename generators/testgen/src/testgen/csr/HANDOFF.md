# CSR generator handoff

Implementation is ready for review; do not restart the prototype.
After this handoff was requested, the user decided to omit explicit WPRI
fields. Undescribed bits remain preserved on writes and excluded from checks.
WPRI was also removed from the access types and generator branches. The former
all-bit layout test now checks suite field selection; the preservation test
uses undescribed bits. After this simplification, all 18 tests, Ruff, and
Pyright passed. Complete prototype output was byte-for-byte identical before
and after removal, and `EXTENSIONS=Sm,S mise exec -- make tests` succeeded.
No commands are left running.

## Objective and current judgment

Replace the increasingly complicated CSR generators with shared patterns driven
by CSR/field dataclasses, eventually populated from RISC-V UDB. Judge the result
on three criteria:

1. Ease of future development when adding CSRs.
2. Readability of both Python and generated assembly.
3. Quality and robustness of the tests.

The prototype was judged worth integrating into real suites. Sm and S now use
it for scratch registers and complete mstatus/envcfg descriptions. This is not
yet evidence that every legacy CSR test can be replaced. Full functional
coverage equivalence remains unverified, and full mstatus output is large.

The user's latest implementation direction was: if mstatus, menvcfg, and
senvcfg are presented as examples, describe and exercise the whole CSR rather
than showing only MPP or CBIE/PMM. That migration has been implemented, with
explicit suite write exclusions and specialized tests retained.

## Read first

- [README.md](README.md): current behavior, scope, and commands.
- [EVALUATION.md](EVALUATION.md): design comparison and migration limits.
- [catalog.py](catalog.py), [model.py](model.py): descriptions and semantics.
- [suites.py](suites.py): suite write policy and safe mstatus context.
- [generate.py](generate.py): shared test patterns.
- [Sm.py](../priv/extensions/Sm.py), [S.py](../priv/extensions/S.py): production integration.

## User constraints and preferences

- Keep implementation and research within `generators/testgen/src/testgen`.
  Generated assembly and validation artifacts have been inspected outside it
  as needed; avoid unrelated repository exploration.
- Always use `EXTENSIONS=...` for generation and test commands. Work on one or
  two suites at a time, currently `Sm,S`; use `CsrPoc` for isolated examples.
- Use `mise exec -- uv run ...` and `mise exec -- make ...`. Keep Python 3.10
  compatibility and pass Ruff/Pyright.
- Preserve the existing Makefile modification; it predates this work.
- No commit, push, or PR has been requested. Do not spawn subagents without
  authorization. Follow the supplied repository AGENTS.md instructions.
- Keep comments concise. Do not narrate register allocation or explain every
  preservation operation.
- Put a prominent CSR/test-kind banner before the save instruction.
- Start each testcase with its comment, then setup. Place its label immediately
  before the CSR instruction under test. Field-check labels immediately precede
  their `csrr` instructions.
- No blank line between a comment and the instruction it describes. Separate
  testcases with blank lines, and keep each testcase compact.
- Preserve the standard `write_sigupd()` comment.
- Exact comparisons store actual readbacks in the signature. Use a sentinel
  only when checking variable WARL legality or preservation.
- Share RV32/RV64 cases and fields. Guard only differing fields, masks, or upper
  walking bits. Shift walking operands in registers; use Python emission loops,
  not assembly loops.
- Avoid complicated runtime baseline inference.

## Design and important semantics

`model.py` defines frozen `LegalValue`, `CsrField`, and `CsrSpec` dataclasses,
plus `CsrTestPolicy(write_fields, check_fields)`. Fields have RW, WARL, or RO
access, XLEN applicability, and optional legal encodings. Layout and domain
validation catch invalid descriptions. CSR privilege metadata does not switch
execution modes; callers establish the execution context.

`LegalValue.condition` determines whether an encoding is permitted;
`LegalValue.required` separately determines whether a write must retain it.
WARL with an empty legal-values tuple deliberately uses the configured reference
model's exact readback. It does not mean unrestricted RW, and it does not allow
different valid legalizations between DUT and reference.

The catalog contains nine CSR descriptions:

- Complete mscratch and sscratch.
- Complete mstatus and its RV32 mstatush view, including RO XS/SD, XLEN-specific
  fields. WPRI ranges are implicit.
- Complete menvcfg, its RV32 menvcfgh view, and senvcfg, with implicit WPRI ranges.
- Partial mseccfg/mseccfgh descriptions containing PMM only. These remain on the
  legacy production implementation and must not be presented as complete.

`high_fields()` derives RV32 upper views. mstatush excludes UXL/SXL and SD;
their positions are WPRI in that view.

MPP, CBIE, and PMM have enumerated WARL domains. MPP requires M, and requires U/S
when those modes exist. CBIE requires 0 and requires 1/3 with Zicbom. PMM permits
optional nonzero encodings but still needs implementation-specific PMLEN support
data. Other WARL fields retain reference-model comparisons.

The public generators are `csr_access_test` (ones, zeros, set, clear),
`csr_walk_test` (direct-write walking values), `csr_bitops_test` (individual
set/clear operands), and `csr_field_values_test` (explicit encodings). Call them
inside an active unsplittable `TestChunk`.

The emitter saves/restores the CSR and preserves unselected bits. Undescribed
bits are neither modified nor checked. By default every described field is
checked after each operation, including untouched fields. RW, RO,
reference-compared WARL, and required enumerated writes store actual readbacks.
Other enumerated writes use a legal-domain sentinel; untouched enumerated WARL
fields use equality-to-saved sentinels. Enumerated bitops start from required
writable values. Other fields use zero/all-ones write patterns without assuming
that these values retain. Ordinary patterns allocate four registers; walking
patterns allocate five.

`_case_variants()` merges ordered RV32/RV64 cases; `_by_xlen()` shares identical
instructions. `_Emitter.load()` handles signed and width-specific constants.

## Production integration and safety

Sm uses the model for mscratch, mstatus/mstatush, menvcfg/menvcfgh, and supervisor
sscratch/senvcfg accesses from M-mode. S uses it for sscratch and senvcfg.
Supplemental partial-field suite tests were removed. Specialized SD, address,
trap, and privilege-transition tests remain.

`PrivCommon.py` no longer lists sscratch in the legacy S_CSRS collection; all
three callers were migrated. Its old S_CSR_SENVCFG definition was removed.

`suites.py` separates complete descriptions from write policy:

- mstatus/mstatush exclude UBE, SBE, MBE, UXL, SXL, SDT, and MDT writes.
- menvcfg/menvcfgh exclude DTE and CDE writes.
- Excluded fields remain described and read-checked. Reasons are next to the
  policy definitions; these preserve the prior division of testing and
  reference-model exclusions.

The mstatus wrapper saves the caller's state, establishes MPP=M and MPRV=0,
runs the generator, then restores the original state. MPRV operand tests retain
machine-mode memory access; MPP tests keep MPRV clear. Direct-value walks run
one field at a time to avoid setting MPRV while clearing MPP. One original-state
register stays reserved while the generator runs. This passed the actual
privileged register budget and Spike execution.

## Validation already completed

These are prior results, not checks newly run while writing this handoff:

```sh
EXTENSIONS=Sm,S mise exec -- make spike
EXTENSIONS=Sm,S mise exec -- uv run python -m unittest testgen.csr.test_prototype
EXTENSIONS=CsrPoc mise exec -- uv run python -m testgen.csr.example /tmp/csr-poc
EXTENSIONS=CsrPoc mise exec -- uv run python -m testgen.csr.evaluate /tmp/csr-comparison
```

- The full migration passed Spike RV32-max and RV64-max. The runner reported
  all 37 tests passing per configuration. Do not treat 37 as a definitive fresh
  generated-file count: stale outputs may be included. Other Spike
  configurations produced no Sm/S ELFs.
- All 18 Python tests passed, including complete layouts, WPRI preservation,
  derived RO summaries, and safe mstatus writes.
- Ruff and Pyright passed on the CSR package and changed suite sources;
  `git diff --check` passed.
- The fault comparison found both implementations detected all 196 injected
  scratch faults (66 RV32, 130 RV64). New MPP checks accepted alternate valid
  legalization and rejected unsupported privilege results missed by old checks.
  Required CBIE writes and collateral PMM corruption were detected.
- Earlier standalone Spike/Sail runs passed 32 normal scenarios and rejected
  eight deliberately broken scenarios. Those used small field fixtures and
  predate the final complete models. Full-model execution evidence is the ACT
  Sm/S run above.

`evaluate.py` and `simulate.py` intentionally use small `FIELD_CSRS` fixtures
from `test_prototype.py`; they do not validate the full catalog in isolation.
`example.py` generates complete examples using the production suite policies.
It registers CsrPoc only when explicitly imported or run.

Not yet done: functional coverage, full prek, broader simulator regression,
commit, or PR. Do not rerun everything just to reconstruct this handoff.

## Artifacts and workspace state

Generated production examples, relative to the repository root:

- `tests/priv/Sm/Sm_mcsr_access-00.S`: mstatus, menvcfg, mstatush, menvcfgh.
- `tests/priv/Sm/Sm_mcsr_walk-00.S`: full mstatus walks; subsequent numbered files
  contain the remaining chunks, with high-view walks in `-11.S` at handoff.
- `tests/priv/S/S_scsr-00.S` and `S_scsr-01.S`: sscratch/senvcfg integration.

Standalone complete examples are in `/tmp/csr-poc/priv/CsrPoc/`, including
`CsrPoc_mstatus_access-00.S`, `CsrPoc_mstatus_bitops-00.S`,
`CsrPoc_menvcfg_access-00.S`, and `CsrPoc_senvcfg_access-00.S`.
Comparison results are in `/tmp/csr-comparison/comparison.json`; older simulator
results are in `/tmp/csr-simulation/simulation.json`. Temporary artifacts may
need regeneration in a later session. Generated file numbering can change.

At handoff, this entire CSR package is untracked. Tracked source modifications
are Sm.py, S.py, and PrivCommon.py, alongside the pre-existing Makefile change.
Tracked generated diffs are mostly under `tests/priv/Sm`; S output exists but
does not necessarily appear as tracked changes. Do not force-add files.
Generation can produce broad diffs through register RNG, numbering, and chunk
grouping. Never hand-edit generated assembly.

## Suggested continuation

1. Review the complete catalog and generated full-CSR assembly with the user.
   Do not present the small predicate fixtures as full CSR integration.
2. Reassess Python and assembly readability using the three original criteria.
   Full mstatus currently checks every field after every operation, producing
   much larger output than the old masked-read approach. Consider consolidation
   only if exact signatures, WARL semantics, collateral checks, and label
   placement remain clear and correct.
3. Validate functional coverage equivalence before claiming production
   replacement is complete. Fieldwise walks differ from the old XLEN-wide
   masked walks. Use a focused command such as
   `EXTENSIONS=Sm,S mise exec -- make coverage` and report any tool limitations.
4. Tighten configuration-dependent WARL domains, particularly optional PMM
   support and fields currently compared exactly against the reference model.
5. Revisit write exclusions only with the necessary execution environment and
   reference-model support.
6. Continue migration one or two suites at a time. Preserve specialized alias,
   counter, WLRL, address, and privilege-transition tests where shared patterns
   do not express their intent. In particular, retain U's numeric permission
   sweeps over unnamed and unimplemented CSR addresses.

These are review priorities for continuing the work, not reasons to do more
implementation before delivering the requested handoff.
