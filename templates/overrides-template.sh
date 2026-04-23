#!/usr/bin/env bash

# Copy this file into <repo>/.sdlc/overrides.sh and keep only the overrides you
# actually need. These values are sourced by the orchestrator before execution.
#
# Upgrade note (SDLC-2, 2026-04): the step numbering changed. Old `.sdlc/overrides.sh`
# files that reference pre-SDLC-2 filenames (e.g. `03-implement.md`, `05-tests.md`,
# `07-open-pr.md`) are silently ignored because no step file by that name is planned.
# If your overrides stop having an effect after upgrading, diff the current step
# filenames in the pipeline root against the names in your overrides and update
# accordingly. See README.md for the current numbering.

# Example: slower repositories can extend individual step timeouts.
# STEP_TIMEOUTS+=("04-implement.md=10800")

# Example: skip manual checklist steps during automated execution (default).
# SKIP_STEPS=("16-merge.md" "17-cleanup.md")

# Example: pin a different Claude model or effort level.
# CLAUDE_MODEL="claude-opus-4-7"
# CLAUDE_EFFORT="xhigh"

# Example: adjust how often liveness/progress heartbeats print while Claude is
# still working. Set to 0 to disable.
# HEARTBEAT_INTERVAL=30

# Example: tighten the permission mode for a specific step.
# STEP_PERMISSION_MODES+=("10-semantic-diff-report.md=plan")

# Example: cap how many 06↔07 test-fix iterations the orchestrator drives
# before halting (defaults to 3). Lower this to fail fast in CI; raise it for
# repos with large suites where partial fixes are common.
# MAX_TEST_FIX_ITERATIONS=5

# Example: pass additional Claude CLI flags (space-separated).
# CLAUDE_EXTRA_ARGS="--max-budget-usd 10.00 --fallback-model claude-sonnet-4-6"
