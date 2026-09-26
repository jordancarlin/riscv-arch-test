# CSR generation

Sm and S use the CSR model for scratch registers and the complete `mstatus`,
`menvcfg`, and `senvcfg` layouts. Sm also uses their RV32 `mstatush` and
`menvcfgh` views. These replace the corresponding generic access/walk calls;
there are no separate partial-field examples in the suites.

## Review the integration

- `catalog.py`: every meaningful field in these CSRs, including
  XLEN-specific layouts and the read-only XS/SD summaries.
- `model.py`: CSR/field descriptions and write/check selection.
- `suites.py`: explicit Sm/S write exclusions and safe mstatus execution context.
- `generate.py`: common access, value, and operand patterns.
- `priv/extensions/Sm.py` and `S.py`: suite call sites, keeping their existing
  covergroups and coverpoints.

```sh
EXTENSIONS=Sm,S mise exec -- make tests
EXTENSIONS=Sm,S mise exec -- make spike
```

Generated suite examples:

- `tests/priv/Sm/Sm_mcsr_access-00.S`: complete mstatus/menvcfg access tests,
  plus the RV32 high views.
- `tests/priv/Sm/Sm_mcsr_walk-00.S`: mstatus operand walks and readback checks.
- `tests/priv/S/S_scsr-00.S` and `S_scsr-01.S`: sscratch and senvcfg access/walks.

Both Spike RV32-max and RV64-max passed the full Sm/S run. Functional coverage
has not been rerun. Generated file indices can change with testcase grouping.

## Architectural descriptions and suite policy

WPRI ranges are omitted from the descriptions. All undescribed bits are
preserved on writes and omitted from signatures.
RW and RO fields record actual readbacks. RO writes are exercised, including
SD and XS; the reference model supplies their derived values. The existing
specialized SD/extension-state cross-product tests remain in the suites.

WARL fields with enumerated domains use `LegalValue.condition` to determine
permitted encodings and `LegalValue.required` to determine which writes must
retain their value. Required writes record the readback. Other writes record
1 for a legal encoding and 0 otherwise. An untouched enumerated WARL field
records 1 if it retains its saved value. MPP, CBIE, and PMM use these rules.

Other WARL fields use configured reference-model readbacks, retaining the
comparison behavior of the old suite. An empty `legal_values` tuple explicitly
selects this behavior; it does not mean the field is unrestricted RW. This
path does not accommodate different legalizations between DUT and reference.
More configuration-specific domains can replace it as data becomes available.
PMM nonzero support still needs implementation data; legality alone does not
prove that an optional PMLEN is implemented.

The complete description is separate from the suite's write policy. Sm keeps
its existing exclusions for endianness, UXL/SXL, double-trap controls, and
counter-delegation control. These fields remain described and their readbacks
are checked. `suites.py` lists each excluded write and its reason.

mstatus tests establish MPP=M and MPRV=0 while preserving the caller's original
CSR. MPRV operand tests then retain machine-mode memory access; MPP tests keep
MPRV clear. The caller's mstatus is restored afterward. Complete-value walks
of mstatus operate one field at a time, so walking MPRV cannot also clear MPP.

## Output and pattern selection

Common cases and fields are emitted once across RV32/RV64. Guards surround only
width-specific masks, fields, and walking bits. Walking operands are loaded
once per pass and shifted between testcases; there are no assembly loops.
Comments begin each testcase. Labels immediately precede its CSR instruction.
Signature updates retain the standard helper comment.

`csr_access_test` writes ones/zeros, sets all selected bits, and clears them.
`csr_walk_test` writes complete walking-one/zero values. `csr_bitops_test`
walks individual set/clear operands; this preserves the old instruction-test
intent. `csr_field_values_test` writes explicit field encodings.

All patterns save and restore the CSR. By default they observe every described
field, including untouched fields. Select narrower writes/checks with
`CsrTestPolicy`. Call them inside an active unsplittable `TestChunk`. The caller
establishes privilege and execution context; the suite wrapper applies Sm/S
policy. The `privilege` attribute itself does not switch modes.

## Standalone examples and regression tools

```sh
EXTENSIONS=CsrPoc mise exec -- uv run python -m testgen.csr.example /tmp/csr-poc
EXTENSIONS=CsrPoc mise exec -- uv run python -m unittest testgen.csr.test_prototype
EXTENSIONS=CsrPoc mise exec -- uv run python -m testgen.csr.evaluate /tmp/csr-comparison
EXTENSIONS=CsrPoc mise exec -- uv run python -m testgen.csr.simulate /tmp/csr-simulation
```

Complete examples use the same suite policies and are written through the
normal privileged generator to `/tmp/csr-poc/priv/CsrPoc/`. `CsrPoc` is registered
only when `example.py` is imported or run. Its coverage names are illustrative.

The comparison and standalone simulator tools deliberately use small field
fixtures to isolate fault predicates. The simulator requires GCC, nm, Spike,
and Sail on PATH and uses its own harness. Full CSR execution is validated
through the Sm/S ACT run above. Eighteen Python tests additionally cover
field selection, undescribed-bit preservation, derived RO values, and mstatus safety.

`mseccfg` and `mseccfgh` are still partial PMM-only catalog entries and have not
been migrated. Address-domain, counter, alias, WLRL, and privilege-transition
patterns remain dedicated tests. See [EVALUATION.md](EVALUATION.md) for the
original design comparison and migration boundaries.
