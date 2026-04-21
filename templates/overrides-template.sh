#!/usr/bin/env bash

# Copy this file into <repo>/.sdlc/overrides.sh and keep only the overrides you
# actually need. These values are sourced by the orchestrator before execution.

# Example: slower repositories can extend individual step timeouts.
# STEP_TIMEOUTS+=("04-implement.md=10800")

# Example: skip manual checklist steps during automated execution (default).
# SKIP_STEPS=("16-merge.md" "17-cleanup.md")

# Example: pin a different Claude model or effort level.
# CLAUDE_MODEL="claude-opus-4-7"
# CLAUDE_EFFORT="xhigh"

# Example: tighten the permission mode for a specific step.
# STEP_PERMISSION_MODES+=("10-semantic-diff-report.md=plan")

# Example: cap how many 06↔07 test-fix iterations the orchestrator drives
# before halting (defaults to 3). Lower this to fail fast in CI; raise it for
# repos with large suites where partial fixes are common.
# MAX_TEST_FIX_ITERATIONS=5

# Example: pass additional Claude CLI flags (space-separated).
# CLAUDE_EXTRA_ARGS="--max-budget-usd 10.00 --fallback-model claude-sonnet-4-6"
