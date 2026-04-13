# Orchestrating AI Agents Across Your SDLC

This guide has been reviewed and aligned to the implementation in this repository as of April 12, 2026.

## Review summary

The original draft was directionally useful, but it had several problems that would have prevented dependable use:

1. It described a hypothetical 16-step pipeline that did not match the 15 step files in this repository.
2. It specified shell scripts and templates, but none of them actually existed here.
3. It assumed GNU `timeout`, which is not available by default on macOS.
4. It let critical outputs live only in agent conversation state instead of canonical files.
5. It auto-committed per step, which conflicts with the branch hygiene and commit-discipline rules in the step files themselves.

Those issues are now resolved in this repo.

## What now exists

This repository is the SDLC package. It can be kept anywhere on disk and used to govern feature work in other repositories.

### Implemented files

- [`orchestrator/run-pipeline.sh`](orchestrator/run-pipeline.sh): runs the automated steps in sequence
- [`orchestrator/init-target-repo.sh`](orchestrator/init-target-repo.sh): bootstraps `.sdlc/` in a target repo
- [`orchestrator/config.sh`](orchestrator/config.sh): defaults for model, retries, timeouts, and required artifacts
- [`orchestrator/lib/`](orchestrator/lib): execution, validation, context, notification, and common helpers
- [`templates/task-template.md`](templates/task-template.md): seed feature brief
- [`templates/technical-spec-template.md`](templates/technical-spec-template.md): seed durable technical spec
- [`templates/pr-body-template.md`](templates/pr-body-template.md): seed PR body
- [`templates/overrides-template.sh`](templates/overrides-template.sh): optional repo overrides

### Verified Codex CLI assumptions

The local CLI surface was checked against `codex-cli 0.118.0` on April 12, 2026. This implementation uses flags that are present in `codex exec --help`:

- `-C`
- `-m`
- `-c`
- `--full-auto`
- `--sandbox`
- `--ephemeral`
- `--output-last-message`

## Operating model

There are now two layers, but they are concrete rather than hypothetical:

### 1. Central SDLC package

This repository contains:

- The canonical step instructions
- The orchestrator and helper scripts
- The shared templates

### 2. Per-feature state inside the target repo

Each governed repository keeps feature-specific state in `.sdlc/`:

- `.sdlc/task.md`
- `.sdlc/overrides.sh`
- `.sdlc/artifacts/technical-spec.md`
- `.sdlc/artifacts/pr-body.md`
- `.sdlc/artifacts/semantic-review-actions.md`
- `.sdlc/reports/semantic_diff_report_<ticket-id>.html`
- `.sdlc/logs/<run-id>/...`

This is the key implementation change: later steps now consume durable files, not just prior chat context.

## Step inventory

The real governed flow in this repository is:

| Step | File | Mode |
| --- | --- | --- |
| 1 | `01-branch-setup.md` | Automated |
| 2 | `02-technical-spec.md` | Automated |
| 3 | `03-implement.md` | Automated |
| 4 | `04-agents-md-check.md` | Automated |
| 5 | `05-tests.md` | Automated |
| 6 | `06-run-tests.md` | Automated |
| 7 | `07-open-pr.md` | Automated |
| 8 | `08-review-comments.md` | Automated |
| 9 | `09-semantic-diff-report.md` | Automated |
| 10 | `10-address-findings.md` | Automated |
| 11 | `11-push-and-hooks.md` | Automated |
| 12 | `12-fix-ci.md` | Automated |
| 13 | `13-rebase.md` | Automated |
| 14 | `14-merge.md` | Manual |
| 15 | `15-cleanup.md` | Manual |

The runner skips the two manual steps by default and calls them out explicitly at the end.

## How the orchestration works

1. Bootstrap the target repo with `init-target-repo.sh`.
2. Write the feature brief in `.sdlc/task.md`.
3. Run `run-pipeline.sh` from this package against the target repo.
4. The runner reads each step file, injects task context plus summaries from earlier steps, and invokes Codex.
5. The runner validates required outputs for steps that must leave durable artifacts.
6. The runner writes logs and rolling context to `.sdlc/logs/<run-id>/`.
7. Manual steps remain as explicit operator checklists after the automated pipeline finishes.

## Step-file hardening that was added

The step library now has explicit durable outputs where automation needs them:

- Step 2 writes `.sdlc/artifacts/technical-spec.md`
- Step 3 consumes `.sdlc/artifacts/technical-spec.md`
- Step 7 writes `.sdlc/artifacts/pr-body.md`
- Step 9 writes `.sdlc/reports/semantic_diff_report_<ticket-id>.html`
- Step 10 writes `.sdlc/artifacts/semantic-review-actions.md`
- Step 4 handles missing `AGENTS.md` gracefully instead of assuming it exists
- Step 11 falls back to this package’s commit-title rules when the target repo has no `Contributing.md`

## Recommended usage

### Bootstrap a target repository

```bash
/path/to/this/repo/orchestrator/init-target-repo.sh /path/to/target-repo
```

### Dry-run the full automated SDLC

```bash
SDLC_HOME=/path/to/this/repo \
  /path/to/this/repo/orchestrator/run-pipeline.sh \
  --repo /path/to/target-repo \
  --dry-run
```

### Run the automated SDLC

```bash
SDLC_HOME=/path/to/this/repo \
  /path/to/this/repo/orchestrator/run-pipeline.sh \
  --repo /path/to/target-repo
```

### Resume a later step

```bash
SDLC_HOME=/path/to/this/repo \
  /path/to/this/repo/orchestrator/run-pipeline.sh \
  --repo /path/to/target-repo \
  --start-from 08-review-comments.md
```

## Extending the package

If you add steps or tighten outputs:

- start from [`templates/step-template.md`](templates/step-template.md)
- keep outputs in `.sdlc/artifacts/` or `.sdlc/reports/`
- add required artifact checks in [`orchestrator/config.sh`](orchestrator/config.sh) when later steps depend on them
- keep manual operator work as explicit manual steps instead of hiding it in prose

## Bottom line

This repo can now be used as the governing SDLC package for feature implementation. The instructions are no longer only descriptive; they are wired into a runner, a bootstrap flow, and a durable artifact model that carries state across the full delivery lifecycle.
