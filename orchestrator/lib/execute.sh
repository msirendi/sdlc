#!/usr/bin/env bash

run_claude_step() {
  local step_file="$1"
  local task_file="$2"
  local context_file="$3"
  local repo_root="$4"
  local log_file="$5"
  local summary_file="$6"
  local timeout_seconds="$7"

  local step_name
  step_name=$(basename "$step_file")

  local permission_mode
  local -a claude_args=()
  local step_instructions
  local task_description=""
  local prior_context=""
  local git_status=""
  local full_prompt=""

  permission_mode=$(sdlc_lookup_kv STEP_PERMISSION_MODES "$step_name" "$CLAUDE_PERMISSION_MODE")

  if [[ -n "$CLAUDE_EXTRA_ARGS" ]]; then
    # shellcheck disable=SC2206
    local -a extra_args=($CLAUDE_EXTRA_ARGS)
    claude_args+=("${extra_args[@]}")
  fi

  if [[ -f "$task_file" ]]; then
    task_description=$(cat "$task_file")
  fi

  if [[ -f "$context_file" ]]; then
    prior_context=$(cat "$context_file")
  fi

  step_instructions=$(cat "$step_file")
  git_status=$(sdlc_git_status_summary "$repo_root")

  full_prompt=$(cat <<EOF
You are executing one step of a structured software delivery pipeline.

## Workspace
- Repository root: $repo_root
- Pipeline home: $SDLC_HOME
- Task file: $task_file
- Durable artifacts directory: $repo_root/$ARTIFACTS_DIR_REL
- Reports directory: $repo_root/$REPORTS_DIR_REL
- Logs directory: $(dirname "$log_file")

## Task / Feature Being Built
${task_description:-No task description was provided. Inspect the repository and proceed carefully.}

## Prior Step Context
${prior_context:-This is the first step. There is no prior context yet.}

## Current Git Status
\`\`\`
${git_status:-Working tree clean.}
\`\`\`

## Canonical Artifact Rules
- Write durable markdown deliverables to \`.sdlc/artifacts/\`.
- Write generated reviewer-facing HTML reports to \`.sdlc/reports/\`.
- Do not write anything into \`.sdlc/logs/\` except through normal command output captured by the orchestrator.
- If you revise an earlier artifact, update the existing file instead of creating duplicate variants.
- If the step requires a spec, PR body, or semantic-review notes, use the canonical filenames referenced in the step instructions.

## Step Instructions
$step_instructions

## Final Response Format
Use this exact structure in the final message:
1. Accomplished
2. Files created or modified
3. Commands run and exit codes
4. Issues encountered
5. Status: READY or BLOCKED
EOF
)

  sdlc_log "INFO" "Model: $CLAUDE_MODEL | Effort: $CLAUDE_EFFORT | Permission mode: $permission_mode"
  sdlc_log "INFO" "Timeout: ${timeout_seconds}s | Step log: $log_file"
  sdlc_log "INFO" "Follow progress: tail -f $log_file"

  set +e
  # Background the subshell so the orchestrator's INT/TERM trap can kill it
  # cleanly. A synchronous subshell inside a pipeline blocks bash's signal
  # delivery until the inner command exits, which is why plain Ctrl+C
  # previously did nothing useful on a long-running Claude step.
  #
  # CURRENT_STEP_PID is intentionally not `local` — the orchestrator's
  # interrupt handler reads it from the parent scope to terminate the step.
  (
    # Reset the parent's INT/TERM trap so the subshell does not also run
    # handle_interrupt when the orchestrator signals it — the parent's
    # terminate_current_step already walks the tree, and a second handler
    # would only duplicate log lines and try to re-TERM the heartbeat.
    trap - INT TERM
    cd "$repo_root"
    : > "$log_file"
    : > "$summary_file"
    # Preserve the original stderr on FD 3 before routing the subshell's own
    # stderr (e.g. bash's "Terminated: 15" job-end notice when we SIGKILL it
    # during interrupt handling) into the step log so it doesn't clutter the
    # terminal. The `>&3` in the process substitution below keeps claude's
    # stderr flowing to the operator's terminal at its original destination;
    # without saving it first, `>&2` would point at the log file (thanks to
    # the exec) and claude's stderr would be silently duplicated into the
    # log file and missing from the operator's terminal.
    exec 3>&2 2>>"$log_file"
    # --output-format is pinned to 'text' because $summary_file is written
    # verbatim from claude's stdout below and downstream steps 9 and 10 read
    # it as prose. Any other format (stream-json, json) would silently break
    # them. Stderr is routed into $log_file only so framework chatter never
    # contaminates the summary the retry/validator loop consumes.
    printf '%s' "$full_prompt" | sdlc_run_with_timeout "$timeout_seconds" \
      claude \
        --print \
        --model "$CLAUDE_MODEL" \
        --effort "$CLAUDE_EFFORT" \
        --permission-mode "$permission_mode" \
        --output-format text \
        ${claude_args[@]+"${claude_args[@]}"} \
        2> >(tee -a "$log_file" >&3) \
      | tee "$summary_file" \
      | tee -a "$log_file"
    # Pipeline is: printf | sdlc_run_with_timeout claude | tee summary | tee log.
    # The claude (and timeout-wrapper) exit code is PIPESTATUS[1]; PIPESTATUS[0]
    # is always printf's success and would mask real failures from the retry loop.
    exit "${PIPESTATUS[1]}"
  ) &
  CURRENT_STEP_PID=$!
  wait "$CURRENT_STEP_PID"
  local exit_code=$?
  CURRENT_STEP_PID=""
  set -e

  return "$exit_code"
}
