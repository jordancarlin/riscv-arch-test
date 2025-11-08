##################################
# sail-to-rvvi.py
#
# jcarlin@hmc.edu 9 May 2025
# SPDX-License-Identifier: Apache-2.0
#
# Convert a Sail log file into RVVI-Text trace format for use
# with RVVI input to riscv-arch-test
##################################

import re
from pathlib import Path


def sailLog2Trace(
    inputLogFile: Path, outputTraceFile: Path, xlen: int = 64, flen: int = 64, vlen: int = 512
) -> None:
    # Regular expression to match instruction lines
    #                             [STEP]     [MODE]:    0xPC              (0xINSN)           DISASM
    insn_pattern = re.compile(r"\[(\d+)\] \[([MSU])\]: 0x([0-9a-fA-F]+) \(0x([0-9a-fA-F]+)\) (.*)")

    # Regular expressions to match register updates
    reg_patterns = {
        "CSR": re.compile(r"CSR .* \(0x([0-9a-fA-F]+)\) (?:<-|->) 0x([0-9a-fA-F]+)"),
        "X": re.compile(r"x(\d+) <- 0x([0-9a-fA-F]+)"),
        "F": re.compile(r"f(\d+) <- 0x([0-9a-fA-F]+)"),
        "V": re.compile(r"v(\d+) <- 0x([0-9a-fA-F]+)"),
    }

    # Mode mapping (M=3, S=1, U=0)
    mode_map = {"M": "3", "S": "1", "U": "0"}

    # TODO: Add support for parsing traps, interrupts, and VM signals

    # Main parsing of log file
    with inputLogFile.open() as f, outputTraceFile.open("w") as outfile:
        # Write RVVI-Text header
        outfile.write("VERSION 0 1\n")
        outfile.write(f"VENDOR sail-to-rvvi 1\n")
        outfile.write(f"PARAMS 6 ILEN 32 XLEN {xlen} FLEN {flen} VLEN {vlen} NHART 1 NRETIRE 1\n")

        lines = f.readlines()
        prev_mode_num = None

        for i in range(len(lines)):
            line = lines[i]

            # Check for instruction line
            insn_match = insn_pattern.search(line)
            if insn_match:
                order, mode, pc, insn, disasm = insn_match.groups()
                mode_num = mode_map.get(mode)

                # Start building the output line with RET element
                output_line = f"RET {pc} {insn}"

                # Check for register updates until the next instruction line
                j = i + 1
                while j < len(lines):
                    reg_match = None
                    reg_type = None
                    for reg, pattern in reg_patterns.items():
                        reg_match = pattern.search(lines[j])
                        if reg_match:
                            reg_type = reg
                            reg_num, reg_val = reg_match.groups()
                            # Use 'C' instead of 'CSR' for CSRs in RVVI-Text
                            if reg_type == "CSR":
                                output_line += f" C {reg_num} {reg_val}"
                            else:
                                output_line += f" {reg_type} {reg_num} {reg_val}"
                            break
                    if insn_pattern.search(lines[j]):
                        break
                    j += 1

                # Add MODE element if it changed or this is the first instruction
                if mode_num != prev_mode_num:
                    output_line += f" MODE {mode_num}"
                    prev_mode_num = mode_num

                # Write the complete line
                outfile.write(output_line + "\n")


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        description="Convert a Sail log file into RVVI-Text trace format for use with RVVI"
    )
    parser.add_argument("input_file", type=Path, help="Input Sail log file to parse")
    parser.add_argument("output_file", type=Path, help="Output trace file for RVVI-Text")
    parser.add_argument("--xlen", type=int, default=64, help="XLEN parameter (default: 64)")
    parser.add_argument("--flen", type=int, default=64, help="FLEN parameter (default: 64)")
    parser.add_argument("--vlen", type=int, default=512, help="VLEN parameter (default: 512)")
    args = parser.parse_args()

    sailLog2Trace(args.input_file, args.output_file, args.xlen, args.flen, args.vlen)


if __name__ == "__main__":
    main()
