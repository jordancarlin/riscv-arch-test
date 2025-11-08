#!/usr/bin/env python3
"""
Test script for RVVI-Text format conversion.
This script validates that the sail_to_rvvi.py converter produces valid RVVI-Text output.
"""

import subprocess
import sys
from pathlib import Path


def test_conversion():
    """Test basic Sail trace to RVVI-Text conversion."""
    # Sample Sail trace
    test_trace = """[0] [M]: 0x80000000 (0x00000013) nop
[1] [M]: 0x80000004 (0x00100093) addi x1, x0, 1
x1 <- 0x0000000000000001
"""
    
    # Write test input
    test_input = Path("/tmp/test_conversion.trace")
    test_output = Path("/tmp/test_conversion.rvvi")
    test_input.write_text(test_trace)
    
    # Run conversion
    result = subprocess.run(
        ["python3", "framework/src/act/sail_to_rvvi.py", 
         str(test_input), str(test_output), "--xlen", "64"],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"Conversion failed: {result.stderr}", file=sys.stderr)
        return False
    
    # Verify output contains required elements
    output = test_output.read_text()
    required = ["VERSION", "VENDOR", "PARAMS", "RET", "MODE"]
    
    for element in required:
        if element not in output:
            print(f"Missing required element: {element}", file=sys.stderr)
            return False
    
    print("✓ Conversion test passed")
    return True


if __name__ == "__main__":
    sys.exit(0 if test_conversion() else 1)
