# CSR prototype decision

**Adopt the model-based approach for common CSR test generation.** It is a
better foundation than continuing to extend masks and positional WARL tuples.
The prototype establishes the design decision; it is not a complete replacement
for Sm, S, and U today. Migration should preserve specialized architectural
tests and their functional coverage.

## Comparison against the three criteria

| Criterion                   | Old implementation                                                                                                                                     | Model-based prototype                                                                                                                                                                             | Judgment                                                                            |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Adding CSRs                 | Simple for an ordinary register. Field locations, masks, reserved encodings, guards, and high views are spread across suite code and helper arguments. | Describe fields once; access, value, and operand patterns share the description. Write/check selection is independent of architecture.                                                            | Better for growth, especially repeated WARL fields.                                 |
| Reading Python and assembly | Short basic access helper; increasingly complex walk logic. Legal behavior is implicit in masks and reserved-value exceptions.                         | Explicit fields and allowed/required encodings. One emitter handles preservation and checks; small functions select patterns. Assembly names fields and separates setup, operation, and readback. | Better overall; WARL membership checks still take several instructions.             |
| Test quality and robustness | Strong ordinary RW testing, but reserved-value rejection is incomplete and exact comparisons can depend on a particular legalization.                  | Retains operand tests, checks complete declared legal domains, checks required write retention, and observes collateral changes by default.                                                       | Better in the tested cases, provided descriptions accurately reflect configuration. |

### Development cost

Adding `sscratch` required one registry entry. The initial partial envcfg
examples reused field descriptions without emitter changes. Completing
`mstatus`, `menvcfg`, and `senvcfg` then required RO/WPRI handling, reference
comparisons for other WARL fields, and explicit mstatus execution context.
Their full layouts and RV32 high views are now modeled. Only the two mseccfg
entries remain partial; the catalog contains nine CSR descriptions.

This is not a claim that every new CSR is data-only. A counter, WLRL field,
alias, or dependent field introduces different behavior. That behavior needs
an explicit test pattern or field model, not another boolean switch in a
universal emitter. A future UDB adapter should supply descriptions and supported
values; it should not own coverage selection or assembly generation.

### Readability and cost

Review `model.py`, `catalog.py`, and the public functions in `generate.py`.
The responsibilities are separate: architectural facts, test selection, and
emission. The generator has no CSR-name dispatch. The model is about 100 lines
and the emitter about 430, excluding catalog, examples, and evaluation tools.
This is evidence of bounded scope, not a line-count comparison against the
broader production helper module.

Exact signatures contain field readbacks. Only variable WARL/preservation
checks use sentinels. Compact comments name the operation and field; signature
updates retain the standard helper comment. Full-width writes reduce to a value load, CSR write, CSR read,
and signature update. WARL checks are longer because they explicitly test the
allowed domain; support guards are resolved by the preprocessor.

There is a modest code-size cost for ordinary RW operand walks: the standalone
access-plus-operand test body grows from 1,904 to 2,028 bytes on RV32, and from
3,696 to 3,948 bytes on RV64. Both implementations shift the walking operand;
the new emitter reloads the all-ones starting value for each clear operation.
These sizes include the standalone signature comparison macro and are not ACT
ELF sizes. Generated source shares common fields and cases across XLENs,
guarding only different masks, width-specific fields, and upper walking bits.

Field-focused examples are smaller, but not directly size-comparable: the old
masked helper still walks XLEN positions, while the new one targets the selected
field. For MPP with U/S present, old access-plus-walk emits 70/134 signature
checks on RV32/RV64; new access-plus-bitops emits 16. Production migration must
review any coverage bins that intentionally require operands outside the field.

The complete mstatus walk is substantially longer than that isolated MPP
fixture: each operation checks every described field, including
read-only summaries and untouched fields. This improves observation but costs
more assembly and signature entries than one whole-CSR masked comparison.

## Test evidence

Reproduce with the commands in [README.md](README.md).

| Experiment                                                                               | Old                                     | New                                   |
| ---------------------------------------------------------------------------------------- | --------------------------------------- | ------------------------------------- |
| RV32 scratch: stuck-zero/stuck-one at every bit, plus rotated set/clear operand decoding | Detects 66/66 faults, 68 checks         | Detects 66/66 faults, 68 checks       |
| RV64 scratch: same faults                                                                | Detects 130/130 faults, 132 checks      | Detects 130/130 faults, 132 checks    |
| MPP: S present, U absent; unsupported zero write legalizes to S or M                     | Signatures differ between legal choices | Both legal choices accepted           |
| MPP: M-only; reserved write incorrectly reads back S                                     | Fault missed                            | Fault detected                        |
| CBIE: Zicbom present, field incorrectly stuck at zero                                    | Fault detected                          | Fault detected                        |
| Write CBIE while corrupting untouched PMM                                                | Not evaluated                           | Fault detected by default observation |

The fault comparison interprets actual emitted bodies with controlled CSR
models. It treats CSR signature macros as reads; it does not model production
macro internals. MPP cases run at both XLENs. The scratch comparison uses old
access-plus-walk against new access-plus-bitops. The WARL fault comparison also
includes the new direct value walk. These are targeted experiments, not a
complete fault model or proof of coverage equivalence.

Independent instruction execution used Spike and Sail at RV32 and RV64:

- 32 normal runs passed: old/new `mscratch`, MPP-only `mstatus`, CBIE-only
  `menvcfg`, new `sscratch`, and new `menvcfg` with both CBIE and PMM.
- Eight runs with `csrs` deliberately removed failed as expected, covering
  both scratch implementations, both XLENs, and both simulators.
- Eighteen Python regression tests passed, including restore/preservation,
  conditional domains, required WARL starts, configuration-specific PMM
  requirements, shared/XLEN-specific fields, suite field selection, RO summaries,
  WPRI preservation, and mstatus execution context. Ruff and Pyright passed
  for the prototype package.

The simulator harness uses its own linker layout, signature comparison, trap
exit, and HTIF termination. Expected signatures come from controlled CSR models;
Spike and Sail execute the compiled instructions. It does not validate ACT
headers, production traps, UDB integration, or functional coverage. The complete
generated example files do use the normal privileged assembly writer.

## Alternatives considered

1. **Keep the old API and add named tuples/helpers.** Lowest migration cost,
   but masks and per-call exceptions still duplicate architectural knowledge.
2. **A central CSR table plus CSR-specific generator dispatch.** Centralizes
   names, but most new behavior still creates branches in each pattern.
3. **Infer WARL baselines at runtime.** Can accommodate unknown supported
   values, but complicates output and can mistake a faulty readback for setup.
4. **Descriptions plus small pattern functions.** Chosen. Complete writes
   need no baseline; operand tests use explicitly required starting values.

## Replacement boundaries

Production integration replaces the generic access/walk tests for `mscratch`,
`sscratch`, complete `mstatus`, `menvcfg`, `senvcfg`, and the RV32 high views
`mstatush` and `menvcfgh`. The separate partial-field suite examples have been
removed. Existing specialized SD, address, trap, and privilege tests remain.
`EXTENSIONS=Sm,S mise exec -- make spike` passed the complete Sm/S run on
RV32-max and RV64-max through the actual ACT build and run pipeline.
The covergroup and coverpoint names are retained; testcase
names identify the field and operation, with common cases shared across XLENs.
Functional coverage has not been rerun.

For **Sm and S**, migrate ordinary access, value walks, operand walks, and
enumerated-field sweeps to descriptions and shared functions. Start with
scratch CSRs and the demonstrated MPP/CBIE/PMM fields. Preserve the existing
coverage intent and configuration gates as each call site moves.

For **U**, keep the numeric access-permission sweeps. They test unnamed and
unimplemented addresses as well as known CSRs. A catalog of implemented CSRs
must not narrow them. Registry metadata can help named permission tests, but
U's main sweep gains little from replacing its existing range-based logic.

Keep address, trap, counter, alias, WLRL, and privilege-transition tests as
dedicated functions. They may consume the same CSR descriptions, but should
not be forced through stable-field write/readback generation. The complete
mstatus description uses explicit suite policy for unsafe writes and a fixed
MPP=M/MPRV=0 execution context. The mseccfg descriptions remain partial.

Unenumerated WARL fields use the configured reference model's exact readback,
as the old suite did. Complete field coverage is not a claim of complete WARL
constraint modeling. MPP/CBIE/PMM retain explicit legalization predicates;
other fields can gain configuration-specific domains without changing the
suite call sites. The existing write exclusions are listed in `suites.py`;
excluded fields remain described and observed.

PMM's nonzero supported encodings remain implementation-dependent. The model
can express required support and regression tests exercise it, but the sample
catalog does not claim to know that support. Permitted-domain checks alone
cannot detect missing optional functionality. Configuration data must narrow
domains and mark supported values required before certification migration.

The remaining work is production migration and validation, not another open-ended
architecture experiment: fill descriptions, map real coverage bins, preserve
numeric permission coverage, and run each affected suite through ACT with
`EXTENSIONS=Sm`, `EXTENSIONS=S`, or `EXTENSIONS=U`. Do not delete an old helper
until all its callers have equivalent coverage and pass their focused runs.
