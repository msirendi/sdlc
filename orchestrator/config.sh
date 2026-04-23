#!/usr/bin/env bash

# Central defaults for the SDLC pipeline. Repositories may override these by
# creating .sdlc/overrides.sh in the target repository.

: "${SDLC_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

STEPS_DIR="${STEPS_DIR:-$SDLC_HOME}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$SDLC_HOME/templates}"

DEFAULT_TASK_FILE_REL="${DEFAULT_TASK_FILE_REL:-.sdlc/task.md}"
ARTIFACTS_DIR_REL="${ARTIFACTS_DIR_REL:-.sdlc/artifacts}"
REPORTS_DIR_REL="${REPORTS_DIR_REL:-.sdlc/reports}"
LOGS_DIR_REL="${LOGS_DIR_REL:-.sdlc/logs}"

# Claude Code CLI configuration. Opus 4.7 with xhigh effort is the default.
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-opus-4-7}"
CLAUDE_EFFORT="${CLAUDE_EFFORT:-xhigh}"
CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-acceptEdits}"
CLAUDE_EXTRA_ARGS="${CLAUDE_EXTRA_ARGS:-}"

DEFAULT_TIMEOUT="${DEFAULT_TIMEOUT:-1800}"
DEFAULT_RETRIES="${DEFAULT_RETRIES:-2}"
INTER_STEP_DELAY="${INTER_STEP_DELAY:-5}"
DEFAULT_INCLUDE_MANUAL="${DEFAULT_INCLUDE_MANUAL:-false}"
# Emit "still running" heartbeats while a step's Claude call is in flight.
# 30s keeps long-running `--print` invocations visibly alive even when Claude
# does not emit stdout until the final response.
# Set to 0 to disable. Clamped to the default when the override is empty or
# non-numeric so the `[[ -gt 0 ]]` guard in run-pipeline.sh can't crash the
# pipeline on a stray `HEARTBEAT_INTERVAL=""` in overrides.sh.
HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-30}"
if [[ ! "$HEARTBEAT_INTERVAL" =~ ^[0-9]+$ ]]; then
  HEARTBEAT_INTERVAL=30
fi
SKIP_STEPS=()

STEP_TIMEOUTS=(
  "01-branch-setup.md=1200"
  "02-technical-spec.md=1800"
  "03-tests.md=3600"
  "04-implement.md=7200"
  "05-agents-md-check.md=1800"
  "06-run-tests.md=5400"
  "07-fix-test-failures.md=5400"
  "08-open-pr.md=1800"
  "09-review-comments.md=3600"
  "10-semantic-diff-report.md=2400"
  "11-address-findings.md=3600"
  "12-ultra-review.md=3600"
  "13-push-and-hooks.md=1800"
  "14-fix-ci.md=5400"
  "15-rebase.md=2400"
)

# Step 6 (run-tests) is now a run-only reporter; a failed attempt means the
# agent did not produce a parseable test-results.md, not that tests failed.
# 2 retries is enough because MAX_TEST_FIX_ITERATIONS already re-runs Step 6
# up to 3 more times via the 06↔07 loop, giving genuine flakes multiple shots.
STEP_RETRY_COUNTS=(
  "03-tests.md=3"
  "04-implement.md=3"
  "06-run-tests.md=2"
  "07-fix-test-failures.md=2"
  "11-address-findings.md=3"
  "12-ultra-review.md=2"
  "14-fix-ci.md=3"
)

# Test-fix loop: after Step 6 (run-tests) writes its report, the orchestrator
# re-invokes Step 7 (fix) and then Step 6 again until the report's `Result:` line
# reads PASS or this iteration cap is hit. Decoupling 'run' from 'fix' is the
# whole point — keep them separate Claude invocations.
TEST_RUN_STEP="${TEST_RUN_STEP:-06-run-tests.md}"
TEST_FIX_STEP="${TEST_FIX_STEP:-07-fix-test-failures.md}"
TEST_RESULTS_REL="${TEST_RESULTS_REL:-.sdlc/artifacts/test-results.md}"
MAX_TEST_FIX_ITERATIONS="${MAX_TEST_FIX_ITERATIONS:-3}"

# Per-step permission-mode overrides, if needed. Format: "step.md=mode".
STEP_PERMISSION_MODES=()

# Canonical durable outputs that make the pipeline stateful across steps.
STEP_REQUIRED_PATTERNS=(
  "02-technical-spec.md=.sdlc/artifacts/technical-spec.md"
  "06-run-tests.md=.sdlc/artifacts/test-results.md"
  "08-open-pr.md=.sdlc/artifacts/pr-body.md"
  "10-semantic-diff-report.md=.sdlc/reports/semantic_diff_report_*.html"
  "11-address-findings.md=.sdlc/artifacts/semantic-review-actions.md"
  "12-ultra-review.md=.sdlc/artifacts/ultra-review.md"
)

NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"
