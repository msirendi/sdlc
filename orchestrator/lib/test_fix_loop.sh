#!/usr/bin/env bash

# Helpers for the Step 6 (run-tests) ↔ Step 7 (fix-test-failures) loop. The
# orchestrator drives this loop so that running tests and fixing code stay in
# separate Claude invocations.

# Read the first `Result:` line from a test-results report and echo PASS, FAIL,
# or UNKNOWN. The orchestrator treats UNKNOWN as a non-pass: the fix step still
# runs, because silently skipping it after a malformed report would let red
# branches sail through to the open-PR step.
sdlc_test_results_status() {
  local results_file="$1"
  if [[ -z "$results_file" || ! -f "$results_file" ]]; then
    printf 'UNKNOWN\n'
    return
  fi
  local marker
  marker=$(sed -n 's/^[[:space:]]*Result:[[:space:]]*//Ip' "$results_file" | head -n 1)
  marker=$(printf '%s' "$marker" | tr '[:lower:]' '[:upper:]')
  case "$marker" in
    PASS*) printf 'PASS\n' ;;
    FAIL*) printf 'FAIL\n' ;;
    *)     printf 'UNKNOWN\n' ;;
  esac
}
