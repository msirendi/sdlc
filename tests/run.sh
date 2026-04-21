#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$TESTS_DIR/common_unit_test.sh"
bash "$TESTS_DIR/config_unit_test.sh"
bash "$TESTS_DIR/context_unit_test.sh"
bash "$TESTS_DIR/validate_unit_test.sh"
bash "$TESTS_DIR/status_unit_test.sh"
bash "$TESTS_DIR/test_fix_loop_unit_test.sh"
bash "$TESTS_DIR/bin_wrappers_unit_test.sh"
bash "$TESTS_DIR/execute_integration_test.sh"
bash "$TESTS_DIR/pipeline_integration_test.sh"
bash "$TESTS_DIR/status_integration_test.sh"
