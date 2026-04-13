#!/usr/bin/env bash
set -euo pipefail

SDLC_HOME="${SDLC_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SDLC_HOME/orchestrator/config.sh"
source "$SDLC_HOME/orchestrator/lib/common.sh"
source "$SDLC_HOME/orchestrator/lib/context.sh"
source "$SDLC_HOME/orchestrator/lib/notify.sh"
source "$SDLC_HOME/orchestrator/lib/execute.sh"
source "$SDLC_HOME/orchestrator/lib/validate.sh"

START_FROM=""
ONLY_STEP=""
DRY_RUN=false
INCLUDE_MANUAL="$DEFAULT_INCLUDE_MANUAL"
TARGET_DIR="$PWD"

usage() {
  cat <<EOF
Usage: run-pipeline.sh [options]

Run from within a target repository, or pass --repo to point at one.

Options:
  --repo DIR            Target repository root or any directory inside it
  --start-from STEP.md  Start execution from a specific step filename
  --only STEP.md        Execute exactly one step filename
  --include-manual      Include manual checklist steps in the run plan
  --dry-run             Print the execution plan without launching Codex
  -h, --help            Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      TARGET_DIR="$2"
      shift 2
      ;;
    --start-from)
      START_FROM="$2"
      shift 2
      ;;
    --only)
      ONLY_STEP="$2"
      shift 2
      ;;
    --include-manual)
      INCLUDE_MANUAL=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown flag: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'ERROR: %s is not inside a git repository.\n' "$TARGET_DIR" >&2
  exit 1
fi

REPO_ROOT=$(git -C "$TARGET_DIR" rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
TASK_FILE="$REPO_ROOT/$DEFAULT_TASK_FILE_REL"
ARTIFACTS_DIR="$REPO_ROOT/$ARTIFACTS_DIR_REL"
REPORTS_DIR="$REPO_ROOT/$REPORTS_DIR_REL"
RUN_ID=$(date +%Y%m%d-%H%M%S)
LOG_DIR="$REPO_ROOT/$LOGS_DIR_REL/$RUN_ID"
CONTEXT_FILE="$LOG_DIR/pipeline-context.md"
LOG_FILE="$LOG_DIR/orchestrator.log"

mkdir -p "$LOG_DIR" "$ARTIFACTS_DIR" "$REPORTS_DIR"

if [[ -f "$REPO_ROOT/.sdlc/overrides.sh" ]]; then
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.sdlc/overrides.sh"
fi

sdlc_require_command "codex" "Install it first: npm install -g @openai/codex"

STEP_FILES=()
while IFS= read -r step_file; do
  STEP_FILES+=("$step_file")
done < <(find "$STEPS_DIR" -maxdepth 1 -type f -name '[0-9][0-9]-*.md' | sort)

if [[ ${#STEP_FILES[@]} -eq 0 ]]; then
  sdlc_log "ERROR" "No step files were found in $STEPS_DIR."
  exit 1
fi

FILTERED_STEPS=()
SKIPPED_MANUAL_STEPS=()
skipping=false
if [[ -n "$START_FROM" ]]; then
  skipping=true
fi

for step_file in "${STEP_FILES[@]}"; do
  step_name=$(basename "$step_file")
  step_mode=$(sdlc_step_mode "$step_file")

  if [[ -n "$ONLY_STEP" ]]; then
    if [[ "$step_name" == "$ONLY_STEP" ]]; then
      FILTERED_STEPS+=("$step_file")
    fi
    continue
  fi

  if [[ "$skipping" == "true" ]]; then
    if [[ "$step_name" == "$START_FROM" ]]; then
      skipping=false
    else
      continue
    fi
  fi

  should_skip=false
  for skipped_step in "${SKIP_STEPS[@]:-}"; do
    if [[ "$step_name" == "$skipped_step" ]]; then
      should_skip=true
      break
    fi
  done
  if [[ "$should_skip" == "true" ]]; then
    continue
  fi

  if [[ "$step_mode" == "manual" && "$INCLUDE_MANUAL" != "true" ]]; then
    SKIPPED_MANUAL_STEPS+=("$step_name")
    continue
  fi

  FILTERED_STEPS+=("$step_file")
done

if [[ ${#FILTERED_STEPS[@]} -eq 0 ]]; then
  sdlc_log "ERROR" "No steps remain after filtering."
  exit 1
fi

{
  printf '# Pipeline Run Manifest\n\n'
  printf -- '- Repository: `%s`\n' "$REPO_ROOT"
  printf -- '- Task file: `%s`\n' "$TASK_FILE"
  printf -- '- Run id: `%s`\n' "$RUN_ID"
  printf -- '- Include manual steps: `%s`\n' "$INCLUDE_MANUAL"
  printf '\n## Planned steps\n'
  for step_file in "${FILTERED_STEPS[@]}"; do
    step_name=$(basename "$step_file")
    step_mode=$(sdlc_step_mode "$step_file")
    timeout_value=$(sdlc_lookup_kv STEP_TIMEOUTS "$step_name" "$DEFAULT_TIMEOUT")
    printf -- '- `%s` (%s, timeout %ss)\n' "$step_name" "$step_mode" "$timeout_value"
  done
  if [[ ${#SKIPPED_MANUAL_STEPS[@]} -gt 0 ]]; then
    printf '\n## Manual steps skipped by default\n'
    for step_name in "${SKIPPED_MANUAL_STEPS[@]}"; do
      printf -- '- `%s`\n' "$step_name"
    done
  fi
} > "$LOG_DIR/pipeline-manifest.md"

sdlc_log "INFO" "Repository: $REPO_NAME"
sdlc_log "INFO" "SDLC home: $SDLC_HOME"
sdlc_log "INFO" "Logs: $LOG_DIR"
sdlc_log "INFO" "Artifacts: $ARTIFACTS_DIR"
sdlc_log "INFO" "Reports: $REPORTS_DIR"
sdlc_log "INFO" "Task file: $TASK_FILE"
sdlc_log "INFO" "Planned steps: ${#FILTERED_STEPS[@]}"

if [[ ! -f "$TASK_FILE" ]]; then
  sdlc_log "WARN" "No task file found at $TASK_FILE. The pipeline will still run."
fi

for step_file in "${FILTERED_STEPS[@]}"; do
  step_name=$(basename "$step_file")
  step_mode=$(sdlc_step_mode "$step_file")
  timeout_value=$(sdlc_lookup_kv STEP_TIMEOUTS "$step_name" "$DEFAULT_TIMEOUT")
  sdlc_log "INFO" "Plan: $step_name ($step_mode, timeout ${timeout_value}s)"
done

if [[ "$DRY_RUN" == "true" ]]; then
  sdlc_log "INFO" "Dry run requested. No Codex steps were executed."
  if [[ ${#SKIPPED_MANUAL_STEPS[@]} -gt 0 ]]; then
    sdlc_log "INFO" "Manual checklist steps remain: ${SKIPPED_MANUAL_STEPS[*]}"
  fi
  exit 0
fi

completed=0
failed=0
start_seconds=$SECONDS

for step_file in "${FILTERED_STEPS[@]}"; do
  step_name=$(basename "$step_file")
  timeout_value=$(sdlc_lookup_kv STEP_TIMEOUTS "$step_name" "$DEFAULT_TIMEOUT")
  max_retries=$(sdlc_lookup_kv STEP_RETRY_COUNTS "$step_name" "$DEFAULT_RETRIES")

  sdlc_log "INFO" "======================================================"
  sdlc_log "INFO" "Starting $step_name"
  sdlc_log "INFO" "======================================================"

  attempt=1
  success=false

  while [[ "$attempt" -le "$max_retries" ]]; do
    attempt_log="$LOG_DIR/${step_name%.md}_attempt${attempt}.log"
    attempt_summary="$LOG_DIR/${step_name%.md}_attempt${attempt}_summary.md"

    sdlc_log "INFO" "Attempt $attempt/$max_retries"
    set +e
    run_codex_step \
      "$step_file" \
      "$TASK_FILE" \
      "$CONTEXT_FILE" \
      "$REPO_ROOT" \
      "$attempt_log" \
      "$attempt_summary" \
      "$timeout_value"
    exit_code=$?
    set -e

    if [[ "$exit_code" -eq 124 ]]; then
      sdlc_log "WARN" "Step $step_name timed out after ${timeout_value}s."
      notify "SDLC $REPO_NAME: $step_name timed out"
    elif [[ "$exit_code" -ne 0 ]]; then
      sdlc_log "WARN" "Step $step_name exited with code $exit_code."
    elif validate_step "$step_name" "$REPO_ROOT" "$attempt_log" "$attempt_summary"; then
      cp "$attempt_log" "$LOG_DIR/${step_name%.md}.log"
      cp "$attempt_summary" "$LOG_DIR/${step_name%.md}_summary.md"
      update_context "$step_name" "$LOG_DIR/${step_name%.md}_summary.md" "$CONTEXT_FILE"
      success=true
      break
    else
      sdlc_log "WARN" "Validation failed for $step_name."
    fi

    attempt=$((attempt + 1))
  done

  if [[ "$success" == "true" ]]; then
    completed=$((completed + 1))
    sdlc_log "INFO" "Completed $step_name"
    notify "SDLC $REPO_NAME: $step_name completed"
  else
    failed=$((failed + 1))
    sdlc_log "ERROR" "Pipeline halted at $step_name"
    notify "SDLC $REPO_NAME: halted at $step_name"
    break
  fi

  if [[ "$INTER_STEP_DELAY" -gt 0 ]]; then
    sleep "$INTER_STEP_DELAY"
  fi
done

elapsed=$((SECONDS - start_seconds))
sdlc_log "INFO" "Run complete: $completed succeeded, $failed failed, ${elapsed}s elapsed."

if [[ ${#SKIPPED_MANUAL_STEPS[@]} -gt 0 ]]; then
  sdlc_log "INFO" "Manual checklist steps still require operator action: ${SKIPPED_MANUAL_STEPS[*]}"
fi

if [[ "$failed" -eq 0 ]]; then
  exit 0
fi

exit 1
