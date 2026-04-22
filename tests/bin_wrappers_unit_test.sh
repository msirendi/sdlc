#!/usr/bin/env bash
# Unit tests for the PATH-installable command wrappers under bin/.
#
# These tests make sure that `sdlc`, `sdlc-init`, `sdlc-dry`, and `sdlc-status`
# can be invoked from any directory (i.e. they are on PATH when installed) and
# correctly delegate to the orchestrator scripts.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./testlib.sh
. "$TESTS_DIR/testlib.sh"

BIN_DIR="$REPO_ROOT/bin"

test_bin_directory_is_populated() {
  local name
  for name in sdlc sdlc-init sdlc-dry sdlc-status; do
    if [[ ! -f "$BIN_DIR/$name" ]]; then
      fail "Missing wrapper: $BIN_DIR/$name"
    fi
    if [[ ! -x "$BIN_DIR/$name" ]]; then
      fail "Wrapper not executable: $BIN_DIR/$name"
    fi
    local first_line
    first_line=$(head -n 1 "$BIN_DIR/$name")
    assert_equals "#!/usr/bin/env bash" "$first_line" \
      "Wrapper $name should start with a bash shebang."
  done
}

test_sdlc_is_discoverable_on_path() {
  # Simulate the documented install step (export PATH="$SDLC_HOME/bin:$PATH")
  # in an isolated environment and confirm each command resolves.
  use_temp_dir
  local fake_home="$TEST_TEMP_DIR/home"
  mkdir -p "$fake_home"

  local resolved
  local name
  for name in sdlc sdlc-init sdlc-dry sdlc-status; do
    # env -i wipes the environment before running the inner command, so the
    # PATH/HOME assignments are only set on the inner invocation.
    resolved=$(env -i PATH="$BIN_DIR:/usr/bin:/bin" HOME="$fake_home" \
      command -v "$name" || true)
    if [[ -z "$resolved" ]]; then
      fail "$name is not discoverable on PATH when $BIN_DIR is prepended."
    fi
    assert_equals "$BIN_DIR/$name" "$(canonicalize_path "$resolved")" \
      "$name should resolve to the shipped wrapper."
  done
}

test_sdlc_dry_run_against_target_repo() {
  # End-to-end smoke test: invoking `sdlc --dry-run` via the wrapper should
  # produce the pipeline manifest for a freshly-created git repo, without
  # requiring the user to cd into SDLC_HOME or set any env vars.
  sdlc_require_cmd_or_skip() {
    if ! command -v git >/dev/null 2>&1; then
      printf 'SKIP - git not available\n' >&2
      return 1
    fi
    return 0
  }
  sdlc_require_cmd_or_skip || return 0

  use_temp_dir
  local target_repo="$TEST_TEMP_DIR/target"
  create_git_repo "$target_repo"
  git -C "$target_repo" -c user.email=test@example.com -c user.name=Test \
    commit --allow-empty -q -m "init"

  # A fake `claude` binary satisfies the require-command check that
  # run-pipeline.sh performs even under --dry-run.
  local shim_dir="$TEST_TEMP_DIR/shims"
  mkdir -p "$shim_dir"
  cat >"$shim_dir/claude" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$shim_dir/claude"

  # PATH contains only the wrapper dir, the shim dir, and core system tools.
  # No SDLC_HOME is exported -- the wrapper must infer it from its own path.
  local output
  local status=0
  output=$(cd /tmp && env -i \
    HOME="$TEST_TEMP_DIR/home" \
    PATH="$BIN_DIR:$shim_dir:/usr/bin:/bin" \
    sdlc "$target_repo" --dry-run 2>&1) || status=$?

  assert_exit_code 0 "$status" "sdlc --dry-run should exit cleanly. Output: $output"
  assert_contains "$output" "Dry run requested" \
    "Expected the pipeline dry-run banner."
  assert_contains "$output" "Repository: $(basename "$target_repo")" \
    "Expected the pipeline to identify the target repository."
  assert_contains "$output" "Plan: 01-branch-setup.md" \
    "Expected the planned steps to be logged."

  # sdlc-dry should be equivalent to `sdlc --dry-run`.
  local dry_output
  dry_output=$(cd /tmp && env -i \
    HOME="$TEST_TEMP_DIR/home" \
    PATH="$BIN_DIR:$shim_dir:/usr/bin:/bin" \
    sdlc-dry "$target_repo" 2>&1) || status=$?
  assert_contains "$dry_output" "Dry run requested" \
    "sdlc-dry should also trigger the dry-run code path."
}

test_sdlc_help_prints_user_facing_overview() {
  # `sdlc --help` is the primary discoverability hook for a new operator, so
  # pin the sections that should always be visible without invoking the
  # orchestrator. This also guards against accidental regressions where a
  # future refactor drops the help interception back into run-pipeline.sh.
  local output
  local status=0
  output=$("$BIN_DIR/sdlc" --help 2>&1) || status=$?
  assert_exit_code 0 "$status" "sdlc --help should exit 0. Output: $output"
  assert_contains "$output" "USAGE" \
    "Expected the USAGE section in sdlc --help output."
  assert_contains "$output" "TYPICAL FLOW" \
    "Expected the TYPICAL FLOW section so agents see the sdlc-init / task.md / sdlc sequence."
  assert_contains "$output" "Press Ctrl+C" \
    "Expected the DURING A RUN section to document that Ctrl+C halts cleanly."
  assert_contains "$output" "sdlc-status" \
    "Expected help to cross-reference sdlc-status for inspecting runs."

  local short_output
  local short_status=0
  short_output=$("$BIN_DIR/sdlc" -h 2>&1) || short_status=$?
  assert_exit_code 0 "$short_status" "sdlc -h should exit 0. Output: $short_output"
  assert_contains "$short_output" "USAGE" \
    "Expected -h to be accepted as a short alias for --help."
}

test_sdlc_help_short_circuits_orchestrator_without_git_repo() {
  # A raw `sdlc` invocation outside a git repo errors out. `sdlc --help` must
  # not inherit that failure mode — the help screen must be available even
  # when the caller has not yet bootstrapped a target repo.
  use_temp_dir
  local fake_home="$TEST_TEMP_DIR/home"
  mkdir -p "$fake_home"

  local output
  local status=0
  output=$(cd "$TEST_TEMP_DIR" && env -i \
    HOME="$fake_home" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    sdlc --help 2>&1) || status=$?

  assert_exit_code 0 "$status" \
    "sdlc --help should succeed even when invoked outside a git repo. Output: $output"
  assert_contains "$output" "USAGE" \
    "Expected the USAGE section when --help is requested outside a git repo."
}

test_sdlc_version_prints_home_and_revision() {
  local output
  local status=0
  output=$("$BIN_DIR/sdlc" --version 2>&1) || status=$?
  assert_exit_code 0 "$status" "sdlc --version should exit 0. Output: $output"
  assert_contains "$output" "sdlc (SDLC_HOME=" \
    "Expected --version to surface SDLC_HOME so operators can confirm which install is on PATH."
}

test_sdlc_status_reports_no_runs_when_fresh() {
  # sdlc-status must be invocable directly (prior implementation was missing),
  # and it must succeed with the documented message on a repo that has never
  # run the pipeline.
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  use_temp_dir
  local target_repo="$TEST_TEMP_DIR/status-target"
  create_git_repo "$target_repo"

  local output
  local status=0
  output=$(cd "$target_repo" && env -i \
    HOME="$TEST_TEMP_DIR/home" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    sdlc-status 2>&1) || status=$?

  assert_exit_code 0 "$status" "sdlc-status should succeed on a fresh repo. Output: $output"
  assert_contains "$output" "No pipeline runs found." \
    "sdlc-status should print the documented empty-state message."
}

run_test_suite
