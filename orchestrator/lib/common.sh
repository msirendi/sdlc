#!/usr/bin/env bash

sdlc_log() {
  local level="$1"
  shift
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '[%s] [%s] %s\n' "$timestamp" "$level" "$*" | tee -a "$LOG_FILE"
  else
    printf '[%s] [%s] %s\n' "$timestamp" "$level" "$*"
  fi
}

sdlc_step_mode() {
  local step_file="$1"
  local mode
  mode=$(sed -n 's/^\*\*Mode:\*\*[[:space:]]*//p' "$step_file" | head -n 1)
  mode=$(printf '%s' "$mode" | tr '[:upper:]' '[:lower:]')
  case "$mode" in
    automated|manual)
      printf '%s\n' "$mode"
      ;;
    *)
      printf 'unknown\n'
      ;;
  esac
}

sdlc_git_status_summary() {
  local repo_root="$1"
  git -C "$repo_root" status --short 2>/dev/null || true
}

sdlc_git_has_non_log_changes() {
  local repo_root="$1"
  local status
  status=$(git -C "$repo_root" status --porcelain=v1 2>/dev/null || true)
  status=$(printf '%s\n' "$status" | grep -vE '^[ MADRCU?!]{2} \.sdlc/logs/' || true)
  [[ -n "$status" ]]
}

sdlc_lookup_kv() {
  local array_name="$1"
  local key="$2"
  local default_value="${3:-}"
  local value="$default_value"
  local entry

  eval "set -- \"\${${array_name}[@]+\"\${${array_name}[@]}\"}\""
  for entry in "$@"; do
    case "$entry" in
      "$key="*)
        value="${entry#*=}"
        ;;
    esac
  done

  printf '%s\n' "$value"
}

sdlc_run_with_timeout() {
  local timeout_seconds="$1"
  shift

  if [[ -z "$timeout_seconds" || "$timeout_seconds" -le 0 ]]; then
    "$@"
    return $?
  fi

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout_seconds" "$@"
    return $?
  fi

  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_seconds" "$@"
    return $?
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$timeout_seconds" "$@" <<'PY'
import subprocess
import sys

timeout = int(sys.argv[1])
command = sys.argv[2:]

try:
    completed = subprocess.run(command, check=False, timeout=timeout)
except subprocess.TimeoutExpired:
    sys.exit(124)

sys.exit(completed.returncode)
PY
    return $?
  fi

  "$@"
}

sdlc_require_command() {
  local command_name="$1"
  local hint="$2"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    sdlc_log "ERROR" "$command_name not found. $hint"
    exit 1
  fi
}
