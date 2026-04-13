#!/usr/bin/env bash
set -euo pipefail

SDLC_HOME="${SDLC_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
source "$SDLC_HOME/orchestrator/config.sh"
# shellcheck disable=SC1091
source "$SDLC_HOME/orchestrator/lib/common.sh"

status_error() {
  sdlc_log "ERROR" "$*" >&2
  exit 1
}

find_latest_run_dir() {
  local logs_dir="$1"
  local run_dirs=()
  local run_dir

  if [[ ! -d "$logs_dir" ]]; then
    return 1
  fi

  while IFS= read -r run_dir; do
    run_dirs+=("$run_dir")
  done < <(find "$logs_dir" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)

  if [[ ${#run_dirs[@]} -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${run_dirs[$((${#run_dirs[@]} - 1))]}"
}

parse_manifest() {
  local manifest_file="$1"
  local line=""
  local in_planned_steps=false

  PLANNED_STEPS=()
  MANIFEST_REPO_PATH=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == '- Repository: `'* ]]; then
      MANIFEST_REPO_PATH="${line#- Repository: \`}"
      MANIFEST_REPO_PATH="${MANIFEST_REPO_PATH%\`}"
      continue
    fi

    if [[ "$line" == '## Planned steps' ]]; then
      in_planned_steps=true
      continue
    fi

    if [[ "$line" == '## '* && "$in_planned_steps" == "true" ]]; then
      break
    fi

    if [[ "$in_planned_steps" == "true" && "$line" == '- `'* ]]; then
      line="${line#- \`}"
      PLANNED_STEPS+=("${line%%\`*}")
    fi
  done < "$manifest_file"
}

parse_orchestrator_log() {
  local log_file="$1"
  local line=""

  COMPLETED_STEPS=()
  FAILED_STEP=""
  ELAPSED_SECONDS=""
  REPO_NAME=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == *"[INFO] Repository: "* ]]; then
      REPO_NAME="${line##*] Repository: }"
      continue
    fi

    if [[ "$line" == *"[INFO] Completed "* ]]; then
      COMPLETED_STEPS+=("${line##*] Completed }")
      continue
    fi

    if [[ "$line" == *"Pipeline halted at "* ]]; then
      FAILED_STEP="${line##*] Pipeline halted at }"
      continue
    fi

    if [[ "$line" =~ ([0-9]+)s\ elapsed\.?$ ]]; then
      ELAPSED_SECONDS="${BASH_REMATCH[1]}"
    fi
  done < "$log_file"
}

array_contains() {
  local needle="$1"
  shift
  local entry

  for entry in "$@"; do
    if [[ "$entry" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

format_duration() {
  local total_seconds="$1"
  local hours=0
  local minutes=0
  local seconds=0

  hours=$((total_seconds / 3600))
  minutes=$(((total_seconds % 3600) / 60))
  seconds=$((total_seconds % 60))

  if [[ "$hours" -gt 0 ]]; then
    printf '%dh %dm %ds\n' "$hours" "$minutes" "$seconds"
    return
  fi

  if [[ "$minutes" -gt 0 ]]; then
    printf '%dm %ds\n' "$minutes" "$seconds"
    return
  fi

  printf '%ds\n' "$seconds"
}

main() {
  local repo_root=""
  local logs_dir=""
  local latest_run_dir=""
  local run_id=""
  local manifest_file=""
  local orchestrator_log=""
  local step_name=""

  sdlc_require_command "git" "Install git and retry."

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    status_error "$PWD is not inside a git repository."
  fi

  repo_root=$(git rev-parse --show-toplevel)
  logs_dir="$repo_root/$LOGS_DIR_REL"

  if ! latest_run_dir=$(find_latest_run_dir "$logs_dir"); then
    printf 'No pipeline runs found.\n'
    exit 0
  fi

  run_id=$(basename "$latest_run_dir")
  manifest_file="$latest_run_dir/pipeline-manifest.md"
  orchestrator_log="$latest_run_dir/orchestrator.log"

  if [[ ! -f "$manifest_file" ]]; then
    status_error "Latest run $run_id is missing $manifest_file."
  fi

  if [[ ! -f "$orchestrator_log" ]]; then
    status_error "Latest run $run_id is missing $orchestrator_log."
  fi

  PLANNED_STEPS=()
  COMPLETED_STEPS=()
  FAILED_STEP=""
  ELAPSED_SECONDS=""
  REPO_NAME=""
  MANIFEST_REPO_PATH=""

  parse_manifest "$manifest_file"
  parse_orchestrator_log "$orchestrator_log"

  if [[ ${#PLANNED_STEPS[@]} -eq 0 ]]; then
    status_error "Latest run $run_id does not list any planned steps in $manifest_file."
  fi

  if [[ -z "$REPO_NAME" && -n "$MANIFEST_REPO_PATH" ]]; then
    REPO_NAME=$(basename "$MANIFEST_REPO_PATH")
  fi

  if [[ -z "$REPO_NAME" ]]; then
    REPO_NAME=$(basename "$repo_root")
  fi

  printf 'Run ID: %s\n' "$run_id"
  printf 'Repository: %s\n' "$REPO_NAME"
  printf 'Steps:\n'

  for step_name in "${PLANNED_STEPS[@]}"; do
    if [[ -n "$FAILED_STEP" && "$step_name" == "$FAILED_STEP" ]]; then
      printf '  ✗ failed %s\n' "$step_name"
      continue
    fi

    if array_contains "$step_name" "${COMPLETED_STEPS[@]}"; then
      printf '  ✓ completed %s\n' "$step_name"
      continue
    fi

    printf '  – skipped %s\n' "$step_name"
  done

  if [[ -n "$ELAPSED_SECONDS" ]]; then
    printf 'Elapsed: %s\n' "$(format_duration "$ELAPSED_SECONDS")"
  else
    printf 'Elapsed: unavailable\n'
    printf 'Note: the latest run may still be in progress or was interrupted.\n'
  fi

  printf 'Logs: %s\n' "$latest_run_dir"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
