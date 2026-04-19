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

  set +e
  (
    cd "$repo_root"
    # --output-format is pinned to 'text' because the summary-capture step below
    # assumes $log_file contains the final assistant message as prose. Any other
    # format (stream-json, json) would silently break downstream steps 9 and 10.
    printf '%s' "$full_prompt" | sdlc_run_with_timeout "$timeout_seconds" \
      claude \
        --print \
        --model "$CLAUDE_MODEL" \
        --effort "$CLAUDE_EFFORT" \
        --permission-mode "$permission_mode" \
        --output-format text \
        ${claude_args[@]+"${claude_args[@]}"} \
        2>&1 | tee "$log_file"
    # Pipeline is: printf | sdlc_run_with_timeout claude ... | tee. The claude
    # (and timeout-wrapper) exit code is PIPESTATUS[1]; PIPESTATUS[0] is always
    # printf's success and would mask real failures from the retry loop.
    exit "${PIPESTATUS[1]}"
  )
  local exit_code=$?
  set -e

  # Capture the final Claude response as the step summary. The `--print` flag
  # sends the last assistant message to stdout, which is what we tee'd above.
  if [[ -s "$log_file" ]]; then
    cp "$log_file" "$summary_file"
  fi

  return "$exit_code"
}
