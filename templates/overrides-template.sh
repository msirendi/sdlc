#!/usr/bin/env bash

# Copy this file into <repo>/.sdlc/overrides.sh and keep only the overrides you
# actually need. These values are sourced by the orchestrator before execution.

# Example: slower repositories can extend individual step timeouts.
# STEP_TIMEOUTS+=("03-implement.md=10800")

# Example: skip manual checklist steps during automated execution (default).
# SKIP_STEPS=("14-merge.md" "15-cleanup.md")

# Example: run with a different sandbox profile.
# STEP_SANDBOXES+=("09-semantic-diff-report.md=--sandbox workspace-write")

# Example: disable ephemeral sessions if you want local Codex session files.
# CODEX_EPHEMERAL="false"
