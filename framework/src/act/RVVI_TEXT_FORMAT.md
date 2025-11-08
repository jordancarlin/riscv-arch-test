# RVVI-Text Format Conversion

This document describes the changes made to convert the coverage log format from a custom RVVI format to the official RVVI-Text specification.

## Overview

The sail_to_rvvi.py script has been updated to output RVVI-Text format as specified in:
https://github.com/riscv-verification/RVVI/blob/master/RVVI-TEXT/README.md

## Key Changes

### Old Format
```
ORDER 0 PC 80000000 INSN 00000013 MODE 3
ORDER 1 PC 80000004 INSN 00100093 MODE 3 X 1 0000000000000001
ORDER 2 PC 80000008 INSN 00200113 MODE 3 X 2 0000000000000002
```

### New RVVI-Text Format
```
VERSION 0 1
VENDOR sail_to_rvvi 1 0
PARAMS 6 ILEN 32 XLEN 64 FLEN 64 VLEN 512 NHART 1 RETIRE 1
RET 80000000 00000013 MODE 3
RET 80000004 00100093 X 1 0000000000000001
RET 80000008 00200113 X 2 0000000000000002
```

## Validation

The output format is validated using the official rvviTextChecker.py tool from the RVVI repository.

## Testing

Example usage:
```bash
python3 framework/src/act/sail_to_rvvi.py input.trace output.rvvi --xlen 64 --flen 32
```
