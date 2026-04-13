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

CODEX_MODEL="${CODEX_MODEL:-gpt-5.4}"
CODEX_REASONING="${CODEX_REASONING:-xhigh}"
CODEX_SANDBOX="${CODEX_SANDBOX:---full-auto}"
CODEX_EPHEMERAL="${CODEX_EPHEMERAL:-true}"

DEFAULT_TIMEOUT="${DEFAULT_TIMEOUT:-1800}"
DEFAULT_RETRIES="${DEFAULT_RETRIES:-2}"
INTER_STEP_DELAY="${INTER_STEP_DELAY:-5}"
DEFAULT_INCLUDE_MANUAL="${DEFAULT_INCLUDE_MANUAL:-false}"
SKIP_STEPS=()

STEP_TIMEOUTS=(
  "01-branch-setup.md=1200"
  "02-technical-spec.md=1800"
  "03-implement.md=7200"
  "04-agents-md-check.md=1800"
  "05-tests.md=3600"
  "06-run-tests.md=5400"
  "07-open-pr.md=1800"
  "08-review-comments.md=3600"
  "09-semantic-diff-report.md=2400"
  "10-address-findings.md=3600"
  "11-push-and-hooks.md=1800"
  "12-fix-ci.md=5400"
  "13-rebase.md=2400"
)

STEP_RETRY_COUNTS=(
  "03-implement.md=3"
  "05-tests.md=3"
  "06-run-tests.md=3"
  "10-address-findings.md=3"
  "12-fix-ci.md=3"
)

STEP_SANDBOXES=()

# Canonical durable outputs that make the pipeline stateful across steps.
STEP_REQUIRED_PATTERNS=(
  "02-technical-spec.md=.sdlc/artifacts/technical-spec.md"
  "07-open-pr.md=.sdlc/artifacts/pr-body.md"
  "09-semantic-diff-report.md=.sdlc/reports/semantic_diff_report_*.html"
  "10-address-findings.md=.sdlc/artifacts/semantic-review-actions.md"
)

NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"
