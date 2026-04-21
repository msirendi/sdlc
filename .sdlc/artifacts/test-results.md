# Test Results

Result: PASS
Run at: 2026-04-21T00:47:16Z
Command: bash tests/run.sh

## Summary
- Total: 85
- Passed: 85
- Failed: 0
- Skipped: 0

## Failures

## Pre-existing failures on main

## Notes
- Test suite executed with no filters via the repository's canonical entry point `tests/run.sh`, which covers all unit and integration suites: `common_unit_test.sh`, `config_unit_test.sh`, `context_unit_test.sh`, `validate_unit_test.sh`, `status_unit_test.sh`, `test_fix_loop_unit_test.sh`, `bin_wrappers_unit_test.sh`, `execute_integration_test.sh`, `pipeline_integration_test.sh`, and `status_integration_test.sh`.
- Per-suite pass counts: common=14, config=12, context=4, validate=9, status_unit=11, test_fix_loop=9, bin_wrappers=4, execute=6, pipeline=9, status_integration=7 (sum = 85).
- This repository has no separate e2e command; integration tests (`*_integration_test.sh`) exercise the end-to-end orchestrator flows against fixture target repositories and are included in `tests/run.sh`.
- No warnings or deprecation notices were emitted by the suites.
- The new `Result:` parse contract is covered by `test_fix_loop_unit_test.sh` and manifest filtering of Step `07` is covered by `pipeline_integration_test.sh` (both passing).
