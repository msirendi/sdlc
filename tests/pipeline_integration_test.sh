#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/testlib.sh
source "$TESTS_DIR/testlib.sh"

RUN_PIPELINE_SCRIPT="$REPO_ROOT/orchestrator/run-pipeline.sh"

setup_pipeline_fixture() {
  use_temp_dir
  FAKE_REPO="$TEST_TEMP_DIR/target-repo"
  FAKE_BIN="$TEST_TEMP_DIR/bin"

  create_git_repo "$FAKE_REPO"
  mkdir -p "$FAKE_BIN"

  # Stub claude so sdlc_require_command passes; nothing invokes it under --dry-run.
  cat <<'STUB' > "$FAKE_BIN/claude"
#!/usr/bin/env bash
printf 'claude stub invoked (unexpected under --dry-run)\n' >&2
exit 1
STUB
  chmod +x "$FAKE_BIN/claude"

  # The pipeline discovers steps from SDLC_HOME; point it at this repository
  # so the renumbered step files are exercised end-to-end.
  PIPELINE_ENV=(
    "PATH=$FAKE_BIN:$PATH"
    "SDLC_HOME=$REPO_ROOT"
  )
}

run_pipeline_dry_run() {
  set +e
  CAPTURED_OUTPUT=$(env "${PIPELINE_ENV[@]}" \
    bash "$RUN_PIPELINE_SCRIPT" --repo "$FAKE_REPO" --dry-run "$@" 2>&1)
  CAPTURED_STATUS=$?
  set -e
}

latest_manifest_path() {
  local logs_dir="$FAKE_REPO/.sdlc/logs"
  local manifest=""
  manifest=$(find "$logs_dir" -mindepth 2 -maxdepth 2 -type f -name 'pipeline-manifest.md' \
    | LC_ALL=C sort | tail -n 1)
  printf '%s\n' "$manifest"
}

test_pipeline_dry_run_default_plan_excludes_manual_steps() {
  setup_pipeline_fixture
  run_pipeline_dry_run
  assert_exit_code 0 "$CAPTURED_STATUS" "Expected --dry-run to succeed when claude is on PATH."

  local manifest
  manifest=$(latest_manifest_path)
  if [[ ! -s "$manifest" ]]; then
    fail "Expected pipeline-manifest.md to be written under .sdlc/logs/<run-id>/."
  fi

  local contents
  contents=$(cat "$manifest")
  assert_contains "$contents" '- `01-branch-setup.md`' "Expected Step 01 to appear in the default plan."
  assert_contains "$contents" '- `03-tests.md` (automated' \
    "Expected Step 03 (tests) to be planned before Step 04 (implement) so tests are authored first."
  assert_contains "$contents" '- `04-implement.md` (automated' \
    "Expected Step 04 (implement) to follow Step 03 in the planned order."
  assert_contains "$contents" '- `06-run-tests.md` (automated' \
    "Expected Step 06 (run-tests) to appear in the default plan."
  assert_contains "$contents" '- `12-ultra-review.md` (automated' \
    "Expected the renumbered Step 12 (ultra-review) to appear in the default plan."
  assert_contains "$contents" '- `15-rebase.md` (automated' \
    "Expected automated steps to run through Step 15 after renumbering."

  # Step 7 is driven by the 06↔07 test-fix loop and must not be listed as a
  # standalone planned step when Step 6 is in the plan.
  assert_not_contains "$contents" '- `07-fix-test-failures.md` (automated' \
    "Did not expect Step 07 to be a top-level planned step when Step 06 is also planned."

  # Manual steps must appear only in the 'skipped' section.
  assert_contains "$contents" '## Manual steps skipped by default' \
    "Expected the manifest to list manual steps that were skipped."
  assert_not_contains "$contents" '- `16-merge.md` (manual, timeout' \
    "Did not expect manual Step 16 in the planned-steps section by default."
  assert_not_contains "$contents" '- `17-cleanup.md` (manual, timeout' \
    "Did not expect manual Step 17 in the planned-steps section by default."
}

test_pipeline_dry_run_include_manual_adds_manual_checklist_steps() {
  setup_pipeline_fixture
  run_pipeline_dry_run --include-manual
  assert_exit_code 0 "$CAPTURED_STATUS" "Expected --include-manual --dry-run to succeed."

  local manifest
  manifest=$(latest_manifest_path)
  local contents
  contents=$(cat "$manifest")
  assert_contains "$contents" '- `16-merge.md` (manual' \
    "Expected manual Step 16 in the planned list when --include-manual is set."
  assert_contains "$contents" '- `17-cleanup.md` (manual' \
    "Expected manual Step 17 in the planned list when --include-manual is set."
  assert_not_contains "$contents" '## Manual steps skipped by default' \
    "Did not expect a 'skipped' section when all manual steps are included."
}

test_pipeline_dry_run_only_flag_plans_single_step() {
  setup_pipeline_fixture
  run_pipeline_dry_run --only 12-ultra-review.md
  assert_exit_code 0 "$CAPTURED_STATUS" "Expected --only to succeed for the ultra-review step."

  local manifest
  manifest=$(latest_manifest_path)
  local contents
  contents=$(cat "$manifest")
  assert_contains "$contents" '- `12-ultra-review.md` (automated' \
    "Expected --only 12-ultra-review.md to keep the requested step in the plan."
  assert_not_contains "$contents" '- `01-branch-setup.md`' \
    "Expected --only to exclude earlier steps from the plan."
  assert_not_contains "$contents" '- `13-push-and-hooks.md`' \
    "Expected --only to exclude later steps from the plan."
}

test_pipeline_dry_run_start_from_includes_step_and_successors() {
  setup_pipeline_fixture
  run_pipeline_dry_run --start-from 12-ultra-review.md
  assert_exit_code 0 "$CAPTURED_STATUS" "Expected --start-from to succeed for the ultra-review step."

  local manifest
  manifest=$(latest_manifest_path)
  local contents
  contents=$(cat "$manifest")
  assert_contains "$contents" '- `12-ultra-review.md` (automated' \
    "Expected --start-from to include the requested starting step."
  assert_contains "$contents" '- `15-rebase.md` (automated' \
    "Expected --start-from to include later automated steps through Step 15."
  assert_not_contains "$contents" '- `11-address-findings.md`' \
    "Did not expect steps preceding --start-from in the planned list."
}

test_pipeline_dry_run_outside_git_repo_exits_nonzero() {
  use_temp_dir
  FAKE_BIN="$TEST_TEMP_DIR/bin"
  mkdir -p "$FAKE_BIN"
  : > "$FAKE_BIN/claude"
  chmod +x "$FAKE_BIN/claude"

  set +e
  CAPTURED_OUTPUT=$(env "PATH=$FAKE_BIN:$PATH" "SDLC_HOME=$REPO_ROOT" \
    bash "$RUN_PIPELINE_SCRIPT" --repo "$TEST_TEMP_DIR" --dry-run 2>&1)
  CAPTURED_STATUS=$?
  set -e

  assert_exit_code 1 "$CAPTURED_STATUS" "Expected run-pipeline.sh to fail outside a git repository."
  assert_contains "$CAPTURED_OUTPUT" "is not inside a git repository" \
    "Expected a clear error message when --repo is not inside a git repository."
}

test_pipeline_dry_run_applies_overrides_file() {
  setup_pipeline_fixture
  mkdir -p "$FAKE_REPO/.sdlc"
  cat <<'EOF' > "$FAKE_REPO/.sdlc/overrides.sh"
STEP_TIMEOUTS+=("12-ultra-review.md=9999")
EOF

  run_pipeline_dry_run
  assert_exit_code 0 "$CAPTURED_STATUS" "Expected dry-run with an overrides.sh to succeed."

  local manifest
  manifest=$(latest_manifest_path)
  local contents
  contents=$(cat "$manifest")
  assert_contains "$contents" '- `12-ultra-review.md` (automated, timeout 9999s)' \
    "Expected .sdlc/overrides.sh to be sourced so its STEP_TIMEOUTS entry wins over the default."
}

test_pipeline_manifest_excludes_fix_step_when_run_step_planned() {
  # Step 7 (fix-test-failures) runs only inside execute_test_loop when Step 6
  # is also planned. Pin that it is filtered out of the manifest so the
  # planned-steps section honestly reflects what the for-loop will iterate over.
  setup_pipeline_fixture
  run_pipeline_dry_run
  assert_exit_code 0 "$CAPTURED_STATUS" "Expected default dry-run to succeed."

  local manifest
  manifest=$(latest_manifest_path)
  local contents
  contents=$(cat "$manifest")
  assert_contains "$contents" '- `06-run-tests.md` (automated' \
    "Expected Step 06 to be in the planned-steps section."
  assert_not_contains "$contents" '- `07-fix-test-failures.md` (automated' \
    "Did not expect Step 07 in the planned list when Step 06 is also planned -- it runs inside the test-fix loop."
}

test_pipeline_manifest_includes_fix_step_when_targeted_directly() {
  # When the operator targets Step 7 alone via --only, the test-fix loop is not
  # active (Step 6 is not planned), so Step 7 must appear and run as a normal
  # standalone step. This is the escape hatch for re-running just the fix pass.
  setup_pipeline_fixture
  run_pipeline_dry_run --only 07-fix-test-failures.md
  assert_exit_code 0 "$CAPTURED_STATUS" "Expected --only 07-fix-test-failures.md to succeed."

  local manifest
  manifest=$(latest_manifest_path)
  local contents
  contents=$(cat "$manifest")
  assert_contains "$contents" '- `07-fix-test-failures.md` (automated' \
    "Expected Step 07 to appear as a top-level planned step when targeted directly."
  assert_not_contains "$contents" '- `06-run-tests.md` (automated' \
    "Did not expect Step 06 in the plan when --only targets Step 07."
}

test_pipeline_dry_run_is_idempotent_across_invocations() {
  setup_pipeline_fixture

  run_pipeline_dry_run
  assert_exit_code 0 "$CAPTURED_STATUS" "Expected first dry-run to succeed."
  local first_manifest
  first_manifest=$(latest_manifest_path)
  local first_contents
  first_contents=$(cat "$first_manifest")

  # A second dry-run creates a fresh run directory, but the planned-steps
  # section must be byte-identical since inputs and overrides have not changed.
  sleep 1
  run_pipeline_dry_run
  assert_exit_code 0 "$CAPTURED_STATUS" "Expected second dry-run to succeed."
  local second_manifest
  second_manifest=$(latest_manifest_path)

  if [[ "$first_manifest" == "$second_manifest" ]]; then
    fail "Expected the second dry-run to produce a distinct run directory."
  fi

  local first_plan second_plan
  first_plan=$(awk '/^## Planned steps/{flag=1; next} /^## /{flag=0} flag' "$first_manifest")
  second_plan=$(awk '/^## Planned steps/{flag=1; next} /^## /{flag=0} flag' "$second_manifest")
  assert_equals "$first_plan" "$second_plan" \
    "Expected identical planned-step sections across successive dry-runs with unchanged inputs."
}

run_test_suite
