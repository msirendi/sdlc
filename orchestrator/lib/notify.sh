#!/usr/bin/env bash

notify() {
  local message="$1"
  local escaped
  escaped=${message//\"/\\\"}

  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$escaped\" with title \"SDLC Pipeline\"" \
      >/dev/null 2>&1 || true
  fi

  if [[ -n "${NOTIFICATION_WEBHOOK:-}" ]]; then
    curl -fsS -X POST "$NOTIFICATION_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"text\":\"$escaped\"}" >/dev/null 2>&1 || true
  fi
}
