#!/usr/bin/env bash

validate_step() {
  local step_name="$1"
  local repo_root="$2"
  local log_file="$3"
  local summary_file="$4"

  if [[ ! -s "$log_file" ]]; then
    sdlc_log "ERROR" "Step $step_name produced no output."
    return 1
  fi

  if [[ ! -s "$summary_file" ]]; then
    sdlc_log "ERROR" "Step $step_name did not produce a final summary file."
    return 1
  fi

  local summary_status
  summary_status=$(sed -n 's/^5\.[[:space:]]*Status:[[:space:]]*//Ip; s/^Status:[[:space:]]*//Ip' \
    "$summary_file" | tail -n 1)
  summary_status=$(printf '%s' "$summary_status" | tr '[:lower:]' '[:upper:]')

  if [[ "$summary_status" == BLOCKED* ]]; then
    sdlc_log "ERROR" "Step $step_name reported BLOCKED."
    return 1
  fi

  if [[ -z "$summary_status" ]]; then
    sdlc_log "WARN" "Step $step_name summary did not include an explicit READY/BLOCKED status."
  fi

  local required_patterns
  required_patterns=$(sdlc_lookup_kv STEP_REQUIRED_PATTERNS "$step_name" "")
  if [[ -n "$required_patterns" ]]; then
    local missing=false
    local pattern
    while IFS= read -r pattern; do
      [[ -z "$pattern" ]] && continue
      if ! compgen -G "$repo_root/$pattern" >/dev/null; then
        sdlc_log "ERROR" "Step $step_name is missing required output: $pattern"
        missing=true
      fi
    done <<< "${required_patterns//|/$'\n'}"

    if [[ "$missing" == "true" ]]; then
      return 1
    fi
  fi

  if sdlc_git_has_non_log_changes "$repo_root"; then
    sdlc_log "INFO" "Repository has non-log changes after $step_name."
  else
    sdlc_log "INFO" "Repository has no non-log changes after $step_name."
  fi

  return 0
}
