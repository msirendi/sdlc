#!/usr/bin/env bash

# Copy this file into <repo>/.sdlc/overrides.sh and keep only the overrides you
# actually need. These values are sourced by the orchestrator before execution.

# Example: slower repositories can extend individual step timeouts.
# STEP_TIMEOUTS+=("03-implement.md=10800")

# Example: skip manual checklist steps during automated execution (default).
# SKIP_STEPS=("15-merge.md" "16-cleanup.md")

# Example: pin a different Claude model or effort level.
# CLAUDE_MODEL="claude-opus-4-7"
# CLAUDE_EFFORT="xhigh"

# Example: tighten the permission mode for a specific step.
# STEP_PERMISSION_MODES+=("09-semantic-diff-report.md=plan")

# Example: pass additional Claude CLI flags (space-separated).
# CLAUDE_EXTRA_ARGS="--max-turns 40 --max-budget-usd 10.00"
