#!/usr/bin/env bash
set -euo pipefail

SDLC_HOME="${SDLC_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SDLC_HOME/orchestrator/config.sh"
source "$SDLC_HOME/orchestrator/lib/common.sh"
source "$SDLC_HOME/orchestrator/lib/context.sh"
source "$SDLC_HOME/orchestrator/lib/notify.sh"
source "$SDLC_HOME/orchestrator/lib/execute.sh"
source "$SDLC_HOME/orchestrator/lib/validate.sh"
source "$SDLC_HOME/orchestrator/lib/test_fix_loop.sh"

# Globals the interrupt handler reads. execute.sh sets CURRENT_STEP_PID to the
# PID of the backgrounded Claude subshell; the heartbeat loop below sets
# STEP_HEARTBEAT_PID. Both stay empty when no step is active.
CURRENT_STEP_PID=""
STEP_HEARTBEAT_PID=""

stop_heartbeat() {
  if [[ -n "$STEP_HEARTBEAT_PID" ]] && kill -0 "$STEP_HEARTBEAT_PID" 2>/dev/null; then
    kill -TERM "$STEP_HEARTBEAT_PID" 2>/dev/null || true
    wait "$STEP_HEARTBEAT_PID" 2>/dev/null || true
  fi
  STEP_HEARTBEAT_PID=""
}

# Signal a process and every descendant, walking the tree so grandchildren
# (the tee children, the Claude CLI, and anything it spawned) don't linger.
# Job control is off in a non-interactive shell, so the backgrounded subshell
# inherits our pgid — `kill -<signal> -PGID` can't single it out. pgrep -P is
# portable across macOS and Linux and makes no assumptions about pgid layout.
signal_process_tree() {
  local signal="$1"
  local root="$2"
  local child
  for child in $(pgrep -P "$root" 2>/dev/null || true); do
    signal_process_tree "$signal" "$child"
  done
  kill "-$signal" "$root" 2>/dev/null || true
}

terminate_current_step() {
  local pid="$CURRENT_STEP_PID"
  [[ -z "$pid" ]] && return 0
  if kill -0 "$pid" 2>/dev/null; then
    signal_process_tree TERM "$pid"
    # Give the subshell up to 2 seconds (20 * 100ms) to drain its tee pipes
    # before escalating to KILL — long enough for the trailing bytes of
    # Claude's response to flush into the summary file so the operator does
    # not lose the partial output on Ctrl+C, short enough that a wedged
    # child does not stall the exit perceptibly.
    local waited=0
    while [[ "$waited" -lt 20 ]] && kill -0 "$pid" 2>/dev/null; do
      sleep 0.1
      waited=$((waited + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
      signal_process_tree KILL "$pid"
    fi
  fi
  wait "$pid" 2>/dev/null || true
  CURRENT_STEP_PID=""
}

handle_interrupt() {
  # Drop a newline so the log line starts on its own line after ^C echo.
  printf '\n' >&2
  sdlc_log "WARN" "Interrupt received. Terminating current step and exiting..."
  stop_heartbeat
  terminate_current_step
  # The trap catches INT and TERM — log a signal-agnostic phrase so a SIGTERM
  # reader doesn't interpret "(SIGINT)" as the actual signal that fired.
  sdlc_log "WARN" "Pipeline halted by user (signal)."
  # 130 = 128 + SIGINT(2), the conventional shell exit code for Ctrl+C; we
  # use the same code on SIGTERM so operators have one reliable post-mortem
  # signal to grep for.
  exit 130
}

trap handle_interrupt INT TERM

emit_heartbeat_loop() {
  local label="$1"
  local interval="$2"
  local start=$SECONDS
  local sleep_pid=""
  # `wait` (unlike the raw `sleep` builtin's child) is interruptible by signals
  # delivered to this subshell. The TERM trap kills the sleep grandchild so it
  # doesn't linger, then exits cleanly.
  trap 'kill "$sleep_pid" 2>/dev/null; exit 0' TERM INT
  while :; do
    sleep "$interval" &
    sleep_pid=$!
    wait "$sleep_pid" 2>/dev/null || true
    sleep_pid=""
    local elapsed=$((SECONDS - start))
    sdlc_log "INFO" "$label still running (elapsed: ${elapsed}s)"
  done
}

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
  --dry-run             Print the execution plan without launching Claude Code
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

sdlc_require_command "claude" "Install it first: npm install -g @anthropic-ai/claude-code"

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

# When the run-tests step (06) is planned, the fix-test-failures step (07) is
# driven internally by the test-fix loop and must not also appear as a separate
# top-level step — so drop it from the manifest. If the operator targeted 07
# directly (without 06), keep it; the for-loop will run it standalone.
test_run_step_planned=false
for step_file in "${FILTERED_STEPS[@]}"; do
  if [[ "$(basename "$step_file")" == "$TEST_RUN_STEP" ]]; then
    test_run_step_planned=true
    break
  fi
done

if [[ "$test_run_step_planned" == "true" ]]; then
  REMAINING_STEPS=()
  for step_file in "${FILTERED_STEPS[@]}"; do
    if [[ "$(basename "$step_file")" == "$TEST_FIX_STEP" ]]; then
      continue
    fi
    REMAINING_STEPS+=("$step_file")
  done
  FILTERED_STEPS=("${REMAINING_STEPS[@]}")
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
  sdlc_log "INFO" "Dry run requested. No Claude Code steps were executed."
  if [[ ${#SKIPPED_MANUAL_STEPS[@]} -gt 0 ]]; then
    sdlc_log "INFO" "Manual checklist steps remain: ${SKIPPED_MANUAL_STEPS[*]}"
  fi
  exit 0
fi

completed=0
failed=0
start_seconds=$SECONDS

# Run a single step with its configured retry budget and validation gate.
# When $2 is non-empty, log/summary filenames are suffixed with `_iter<N>` so
# repeated invocations of the same step (the 06↔07 test-fix loop) do not
# overwrite each other's artifacts.
execute_step_with_retries() {
  local step_file="$1"
  local iter_suffix="${2:-}"
  local step_name
  step_name=$(basename "$step_file")
  local timeout_value
  timeout_value=$(sdlc_lookup_kv STEP_TIMEOUTS "$step_name" "$DEFAULT_TIMEOUT")
  local max_retries
  max_retries=$(sdlc_lookup_kv STEP_RETRY_COUNTS "$step_name" "$DEFAULT_RETRIES")

  local label="$step_name"
  if [[ -n "$iter_suffix" ]]; then
    label="$step_name (iter $iter_suffix)"
  fi

  sdlc_log "INFO" "======================================================"
  sdlc_log "INFO" "Starting $label"
  sdlc_log "INFO" "======================================================"

  local base_name="${step_name%.md}"
  if [[ -n "$iter_suffix" ]]; then
    base_name="${base_name}_iter${iter_suffix}"
  fi

  local attempt=1
  while [[ "$attempt" -le "$max_retries" ]]; do
    local attempt_log="$LOG_DIR/${base_name}_attempt${attempt}.log"
    local attempt_summary="$LOG_DIR/${base_name}_attempt${attempt}_summary.md"

    sdlc_log "INFO" "Attempt $attempt/$max_retries"

    if [[ "$HEARTBEAT_INTERVAL" -gt 0 ]]; then
      emit_heartbeat_loop "$label (attempt $attempt)" "$HEARTBEAT_INTERVAL" &
      STEP_HEARTBEAT_PID=$!
    fi

    set +e
    run_claude_step \
      "$step_file" \
      "$TASK_FILE" \
      "$CONTEXT_FILE" \
      "$REPO_ROOT" \
      "$attempt_log" \
      "$attempt_summary" \
      "$timeout_value"
    local exit_code=$?
    set -e

    stop_heartbeat

    if [[ "$exit_code" -eq 124 ]]; then
      sdlc_log "WARN" "Step $label timed out after ${timeout_value}s."
      notify "SDLC $REPO_NAME: $label timed out"
    elif [[ "$exit_code" -ne 0 ]]; then
      sdlc_log "WARN" "Step $label exited with code $exit_code."
    elif validate_step "$step_name" "$REPO_ROOT" "$attempt_log" "$attempt_summary"; then
      cp "$attempt_log" "$LOG_DIR/${base_name}.log"
      cp "$attempt_summary" "$LOG_DIR/${base_name}_summary.md"
      update_context "$label" "$LOG_DIR/${base_name}_summary.md" "$CONTEXT_FILE"
      emit_step_summary_excerpt "$label" "$LOG_DIR/${base_name}_summary.md"
      return 0
    else
      sdlc_log "WARN" "Validation failed for $label."
    fi

    attempt=$((attempt + 1))
  done

  return 1
}

# Print a short, terminal-friendly excerpt of the step's final response so the
# operator sees what the step accomplished without hunting through logs. Looks
# for the canonical Status line emitted by the "Final Response Format" in
# execute.sh: step files produce `5. Status: READY|BLOCKED` as the fifth and
# final numbered field. validate.sh parses the same two forms (`^5.\s*Status:`
# and bare `^Status:`), so this regex stays in sync with that contract — if the
# final-response template is ever renumbered, both places must be updated.
emit_step_summary_excerpt() {
  local label="$1"
  local summary_path="$2"
  [[ ! -s "$summary_path" ]] && return 0

  local status_line
  status_line=$(grep -E '^[[:space:]]*(5\.[[:space:]]*)?Status:' "$summary_path" | tail -n 1 || true)
  if [[ -n "$status_line" ]]; then
    sdlc_log "INFO" "$label: $(printf '%s' "$status_line" | sed -E 's/^[[:space:]]*//')"
  fi
}

# Drive the run-tests / fix-test-failures loop. Step 6 always runs first so the
# report exists. After each Step 6 result, if it is FAIL/UNKNOWN we run Step 7
# and re-run Step 6, up to MAX_TEST_FIX_ITERATIONS additional fix passes. The
# decoupling here is the whole point: Step 6 only runs tests, Step 7 only fixes
# code, and the orchestrator (not the agent) decides when to iterate.
execute_test_loop() {
  local run_step_file="$1"
  local fix_step_file="$STEPS_DIR/$TEST_FIX_STEP"
  local results_file="$REPO_ROOT/$TEST_RESULTS_REL"
  local results_status

  if [[ ! -f "$fix_step_file" ]]; then
    sdlc_log "ERROR" "Fix step file is missing: $fix_step_file"
    return 1
  fi

  if ! execute_step_with_retries "$run_step_file"; then
    return 1
  fi

  results_status=$(sdlc_test_results_status "$results_file")
  if [[ "$results_status" == "PASS" ]]; then
    sdlc_log "INFO" "Test suite is green after the initial run; skipping $TEST_FIX_STEP."
    return 0
  fi

  local iter=1
  while [[ "$iter" -le "$MAX_TEST_FIX_ITERATIONS" ]]; do
    sdlc_log "INFO" "Test results: $results_status. Running fix iteration $iter/$MAX_TEST_FIX_ITERATIONS."
    if ! execute_step_with_retries "$fix_step_file" "$iter"; then
      sdlc_log "ERROR" "Fix step $TEST_FIX_STEP failed on iteration $iter."
      return 1
    fi

    if ! execute_step_with_retries "$run_step_file" "$iter"; then
      sdlc_log "ERROR" "Re-run of $TEST_RUN_STEP failed on iteration $iter."
      return 1
    fi

    results_status=$(sdlc_test_results_status "$results_file")
    if [[ "$results_status" == "PASS" ]]; then
      sdlc_log "INFO" "Test suite passed after fix iteration $iter."
      return 0
    fi

    iter=$((iter + 1))
  done

  sdlc_log "ERROR" \
    "Test suite still $results_status after $MAX_TEST_FIX_ITERATIONS fix iterations; halting."
  return 1
}

# Step 7 was already filtered out above when Step 6 is planned, so the for-loop
# only encounters it when the operator targeted it directly via --only/--start-from.
for step_file in "${FILTERED_STEPS[@]}"; do
  step_name=$(basename "$step_file")

  success=false
  if [[ "$step_name" == "$TEST_RUN_STEP" ]]; then
    if execute_test_loop "$step_file"; then
      success=true
    fi
  else
    if execute_step_with_retries "$step_file"; then
      success=true
    fi
  fi

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
