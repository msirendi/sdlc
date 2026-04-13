#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$TESTS_DIR/status_unit_test.sh"
bash "$TESTS_DIR/status_integration_test.sh"
