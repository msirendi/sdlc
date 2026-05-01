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

# Example: pin a different Codex model or effort level.
# CODEX_MODEL="azure/gpt-5.5"
# CODEX_EFFORT="xhigh"

# Example: adjust how often liveness/progress heartbeats print while Codex is
# still working. Set to 0 to disable.
# HEARTBEAT_INTERVAL=30

# Example: tighten the Codex approval policy or sandbox for a specific step.
# STEP_APPROVAL_POLICIES+=("10-semantic-diff-report.md=on-request")
# STEP_SANDBOX_MODES+=("10-semantic-diff-report.md=workspace-write")

# Example: cap how many 06↔07 test-fix iterations the orchestrator drives
# before halting (defaults to 3). Lower this to fail fast in CI; raise it for
# repos with large suites where partial fixes are common.
# MAX_TEST_FIX_ITERATIONS=5

# Example: pass additional Codex CLI flags (space-separated).
# CODEX_EXTRA_ARGS="--skip-git-repo-check --ephemeral"
