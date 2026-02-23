##################################
# select_tests.py
#
# jcarlin@hmc.edu 6 Sept 2025
# SPDX-License-Identifier: Apache-2.0
#
# Select tests to run based on UDB config and test list
##################################

from typing import Any

from act.parse_test_constraints import TestMetadata


def check_test_params(test_params: dict[str, Any], config_params: dict[str, Any]) -> bool:
    """Check if all parameters in test_params match those in config_params."""
    return all(param in config_params and config_params[param] == value for param, value in test_params.items())


def select_tests(
    test_dict: dict[str, TestMetadata], implemented_extensions: set[str], config_params: dict[str, Any]
) -> dict[str, TestMetadata]:
    """Select tests that match the UDB configuration."""
    selected_tests: dict[str, TestMetadata] = {}
    for test_name, test_metadata in test_dict.items():
        if test_metadata.required_extensions.issubset(implemented_extensions) and check_test_params(
            test_metadata.params, config_params
        ):
            selected_tests[test_name] = test_metadata
    return selected_tests
