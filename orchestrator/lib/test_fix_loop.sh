#!/usr/bin/env bash

# Helpers for the Step 6 (run-tests) ↔ Step 7 (fix-test-failures) loop. The
# orchestrator drives this loop so that running tests and fixing code stay in
# separate Claude invocations.

# Read the first `Result:` line from a test-results report and echo PASS, FAIL,
# or UNKNOWN. The orchestrator treats UNKNOWN as a non-pass and still invokes
# the fix step. Trade-off: a malformed report is almost always a Step 6
# regression, and running Step 7 against it masks that by presenting it as a
# fix problem. We accept the masking because the alternative — halting on
# UNKNOWN — lets a silently-broken Step 6 sail a red branch through to
# open-PR. UNKNOWN is rare enough in practice that surfacing the Step 6 bug
# via the fix step's own logs is the smaller hazard.
#
# awk reads until the first match and exits, which avoids the sed|head SIGPIPE
# race that would otherwise exit 141 under the orchestrator's `set -o pipefail`
# when test-results.md is large enough for head to close the pipe before sed
# finishes.
sdlc_test_results_status() {
  local results_file="$1"
  if [[ -z "$results_file" || ! -f "$results_file" ]]; then
    printf 'UNKNOWN\n'
    return
  fi
  local marker
  marker=$(awk '
    /^[[:space:]]*[Rr][Ee][Ss][Uu][Ll][Tt]:/ {
      sub(/^[[:space:]]*[Rr][Ee][Ss][Uu][Ll][Tt]:[[:space:]]*/, "")
      print
      exit
    }
  ' "$results_file")
  marker=$(printf '%s' "$marker" | tr '[:lower:]' '[:upper:]')
  case "$marker" in
    PASS*) printf 'PASS\n' ;;
    FAIL*) printf 'FAIL\n' ;;
    *)     printf 'UNKNOWN\n' ;;
  esac
}
