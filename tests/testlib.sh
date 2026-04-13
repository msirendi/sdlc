#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
# shellcheck disable=SC2034
STATUS_SCRIPT="$REPO_ROOT/orchestrator/status.sh"

# shellcheck disable=SC2034
CHECK_MARK=$'\342\234\223'
# shellcheck disable=SC2034
CROSS_MARK=$'\342\234\227'
# shellcheck disable=SC2034
SKIP_MARK=$'\342\200\223'

# shellcheck disable=SC2034
CAPTURED_OUTPUT=""
# shellcheck disable=SC2034
CAPTURED_STATUS=0
TEST_TEMP_DIR=""

fail() {
  printf 'Assertion failed: %s\n' "$*" >&2
  return 1
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Expected values to match.}"
  if [[ "$expected" != "$actual" ]]; then
    fail "$message Expected [$expected], got [$actual]."
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Expected output to contain substring.}"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "$message Missing [$needle] in [$haystack]."
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Expected output to omit substring.}"
  if [[ "$haystack" == *"$needle"* ]]; then
    fail "$message Found unexpected [$needle] in [$haystack]."
  fi
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Unexpected exit code.}"
  if [[ "$expected" -ne "$actual" ]]; then
    fail "$message Expected [$expected], got [$actual]."
  fi
}

join_lines() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi

  printf '%s\n' "$@"
}

join_array() {
  local array_name="$1"

  eval "set -- \"\${${array_name}[@]+\"\${${array_name}[@]}\"}\""
  join_lines "$@"
}

make_temp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/sdlc-status-test.XXXXXX"
}

use_temp_dir() {
  TEST_TEMP_DIR=$(make_temp_dir)
  trap cleanup_temp_dir EXIT
}

cleanup_temp_dir() {
  if [[ -n "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

canonicalize_path() {
  local path="$1"
  local path_dir=""
  local path_base=""

  path_dir=$(cd "$(dirname "$path")" && pwd -P)
  path_base="$(basename "$path")"

  printf '%s/%s\n' "$path_dir" "$path_base"
}

capture_command() {
  local workdir="$1"
  shift

  set +e
  # shellcheck disable=SC2034
  CAPTURED_OUTPUT=$(cd "$workdir" && "$@" 2>&1)
  # shellcheck disable=SC2034
  CAPTURED_STATUS=$?
  set -e
}

create_git_repo() {
  local repo_dir="$1"

  mkdir -p "$repo_dir"
  git -C "$repo_dir" init -q >/dev/null 2>&1
}

create_run_dir() {
  local repo_root="$1"
  local run_id="$2"
  local run_dir="$repo_root/.sdlc/logs/$run_id"

  mkdir -p "$run_dir"
  printf '%s\n' "$run_dir"
}

write_manifest() {
  local run_dir="$1"
  local repo_path="$2"
  local step_name=""

  shift 2

  {
    printf '# Pipeline Run Manifest\n\n'
    printf -- "- Repository: \`%s\`\n" "$repo_path"
    printf -- "- Task file: \`%s/.sdlc/task.md\`\n" "$repo_path"
    printf -- "- Run id: \`%s\`\n" "$(basename "$run_dir")"
    printf -- "- Include manual steps: \`false\`\n\n"
    printf '## Planned steps\n'
    for step_name in "$@"; do
      printf -- "- \`%s\` (automated, timeout 1800s)\n" "$step_name"
    done
    printf '\n## Manual steps skipped by default\n'
    printf -- "- \`14-merge.md\`\n"
    printf -- "- \`15-cleanup.md\`\n"
  } > "$run_dir/pipeline-manifest.md"
}

write_orchestrator_log() {
  local run_dir="$1"
  local repo_name="$2"
  local elapsed_seconds="$3"
  local failed_step="$4"
  local failed_count=0
  local step_name=""

  shift 4

  if [[ -n "$failed_step" ]]; then
    failed_count=1
  fi

  {
    if [[ -n "$repo_name" ]]; then
      printf '[2026-04-13 14:25:31] [INFO] Repository: %s\n' "$repo_name"
    fi
    printf '[2026-04-13 14:25:31] [INFO] Logs: %s\n' "$run_dir"
    for step_name in "$@"; do
      printf '[2026-04-13 14:30:54] [INFO] Completed %s\n' "$step_name"
    done
    if [[ -n "$failed_step" ]]; then
      printf '[2026-04-13 14:24:14] [ERROR] Pipeline halted at %s\n' "$failed_step"
    fi
    if [[ -n "$elapsed_seconds" ]]; then
      printf '[2026-04-13 14:24:14] [INFO] Run complete: %s succeeded, %s failed, %ss elapsed.\n' "$#" "$failed_count" "$elapsed_seconds"
    fi
  } > "$run_dir/orchestrator.log"
}

run_test_suite() {
  local tests=""
  local test_name=""
  local total=0
  local failed=0

  tests=$(declare -F | awk '{print $3}' | LC_ALL=C sort | grep '^test_' || true)

  while IFS= read -r test_name; do
    if [[ -z "$test_name" ]]; then
      continue
    fi

    total=$((total + 1))

    if ( "$test_name" ); then
      printf 'ok - %s\n' "$test_name"
    else
      failed=$((failed + 1))
      printf 'not ok - %s\n' "$test_name" >&2
    fi
  done <<EOF
$tests
EOF

  if [[ "$total" -eq 0 ]]; then
    fail "No tests were defined."
  fi

  if [[ "$failed" -gt 0 ]]; then
    printf '%s of %s tests failed.\n' "$failed" "$total" >&2
    return 1
  fi

  printf '%s tests passed.\n' "$total"
}
