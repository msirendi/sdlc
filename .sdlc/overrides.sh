#!/usr/bin/env bash

# Override sandbox to allow git operations (workspace-write blocks .git/ writes on macOS).
CODEX_SANDBOX="--dangerously-bypass-approvals-and-sandbox"
