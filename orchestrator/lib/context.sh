#!/usr/bin/env bash

update_context() {
  local step_name="$1"
  local summary_file="$2"
  local context_file="$3"

  {
    printf '\n---\n'
    printf '## Completed: %s\n\n' "$step_name"
    if [[ -s "$summary_file" ]]; then
      cat "$summary_file"
    else
      printf 'No summary file was captured.\n'
    fi
    printf '\n'
  } >> "$context_file"

  if [[ -f "$context_file" ]]; then
    local size
    size=$(wc -c < "$context_file" | tr -d ' ')
    if [[ "$size" -gt 24000 ]]; then
      tail -c 16000 "$context_file" > "${context_file}.tmp"
      mv "${context_file}.tmp" "$context_file"
    fi
  fi
}
