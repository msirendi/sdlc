#!/usr/bin/env bash
set -euo pipefail

SDLC_HOME="${SDLC_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGET_DIR="${1:-$PWD}"

if ! git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'ERROR: %s is not inside a git repository.\n' "$TARGET_DIR" >&2
  exit 1
fi

REPO_ROOT=$(git -C "$TARGET_DIR" rev-parse --show-toplevel)

mkdir -p "$REPO_ROOT/.sdlc/artifacts" "$REPO_ROOT/.sdlc/reports" "$REPO_ROOT/.sdlc/logs"

if [[ ! -f "$REPO_ROOT/.sdlc/task.md" ]]; then
  cp "$SDLC_HOME/templates/task-template.md" "$REPO_ROOT/.sdlc/task.md"
fi

if [[ ! -f "$REPO_ROOT/.sdlc/overrides.sh" ]]; then
  cp "$SDLC_HOME/templates/overrides-template.sh" "$REPO_ROOT/.sdlc/overrides.sh"
  chmod +x "$REPO_ROOT/.sdlc/overrides.sh"
fi

if [[ ! -f "$REPO_ROOT/.sdlc/artifacts/technical-spec.md" ]]; then
  cp "$SDLC_HOME/templates/technical-spec-template.md" \
    "$REPO_ROOT/.sdlc/artifacts/technical-spec.md"
fi

if [[ ! -f "$REPO_ROOT/.sdlc/artifacts/pr-body.md" ]]; then
  cp "$SDLC_HOME/templates/pr-body-template.md" "$REPO_ROOT/.sdlc/artifacts/pr-body.md"
fi

if [[ ! -f "$REPO_ROOT/.gitignore" ]]; then
  touch "$REPO_ROOT/.gitignore"
fi

if ! grep -Fxq '.sdlc/logs/' "$REPO_ROOT/.gitignore"; then
  printf '\n# SDLC pipeline logs\n.sdlc/logs/\n' >> "$REPO_ROOT/.gitignore"
fi

cat <<EOF
Initialized SDLC support in $REPO_ROOT

Created or ensured:
- .sdlc/task.md
- .sdlc/overrides.sh
- .sdlc/artifacts/technical-spec.md
- .sdlc/artifacts/pr-body.md
- .sdlc/reports/
- .sdlc/logs/ (gitignored)

Next:
1. Fill in .sdlc/task.md for the feature.
2. Review .sdlc/overrides.sh and trim any overrides you do not need.
3. From that repo, preview the pipeline:
   sdlc-dry
4. If 'sdlc-dry' is not found, add the sdlc bin directory to PATH:
   export PATH="$SDLC_HOME/bin:\$PATH"
   Or invoke the wrapper directly: "$SDLC_HOME/bin/sdlc-dry"
EOF
