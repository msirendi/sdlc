#!/usr/bin/env bash

run_codex_step() {
  local step_file="$1"
  local task_file="$2"
  local context_file="$3"
  local repo_root="$4"
  local log_file="$5"
  local summary_file="$6"
  local timeout_seconds="$7"

  local step_name
  step_name=$(basename "$step_file")

  local sandbox
  local -a sandbox_args=()
  local -a codex_args=()
  local step_instructions
  local task_description=""
  local prior_context=""
  local git_status=""
  local full_prompt=""

  sandbox=$(sdlc_lookup_kv STEP_SANDBOXES "$step_name" "$CODEX_SANDBOX")
  read -r -a sandbox_args <<< "$sandbox"

  if [[ "$CODEX_EPHEMERAL" == "true" ]]; then
    codex_args+=(--ephemeral)
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

  sdlc_log "INFO" "Model: $CODEX_MODEL | Reasoning: $CODEX_REASONING | Sandbox: $sandbox"
  sdlc_log "INFO" "Timeout: ${timeout_seconds}s | Step log: $log_file"

  set +e
  printf '%s' "$full_prompt" | sdlc_run_with_timeout "$timeout_seconds" \
    codex exec \
      -C "$repo_root" \
      -m "$CODEX_MODEL" \
      -c "model_reasoning_effort=\"$CODEX_REASONING\"" \
      "${sandbox_args[@]}" \
      "${codex_args[@]}" \
      --output-last-message "$summary_file" \
      - 2>&1 | tee "$log_file"
  local -a pipe_status=("${PIPESTATUS[@]}")
  set -e

  return "${pipe_status[1]}"
}
