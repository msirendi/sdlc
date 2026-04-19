# AI-Governed SDLC Pipeline

A runnable SDLC package driven by the Claude Code CLI. It contains:

- A 16-step feature delivery process expressed as explicit step files.
- An orchestrator that runs the automated steps in order against any target repository.
- Repo-initialization helpers and artifact templates so later steps consume durable outputs.
- Manual closeout checklists for merge and cleanup.

## What the pipeline governs

Full feature lifecycle in a target repository:

1. Branch setup and isolated worktree creation
2. Technical specification from task intent
3. Implementation
4. Repository instruction compliance review (`AGENTS.md`)
5. Test authoring
6. Full-suite execution
7. Pull request creation
8. Review comment handling
9. Semantic diff analysis
10. Weak-change cleanup
11. Ultra-review (`/ultrareview`) bug and design-issue pass
12. Push and hook enforcement
13. CI remediation
14. Rebase and re-validation
15. Merge checklist (manual)
16. Cleanup checklist (manual)

Steps 1–14 run automated. Steps 15 and 16 are manual operator checklists excluded from automated runs by default.

## Repository layout

| Path | Purpose |
| --- | --- |
| `01-branch-setup.md` … `16-cleanup.md` | Canonical SDLC step instructions |
| [`orchestrator/run-pipeline.sh`](orchestrator/run-pipeline.sh) | Main runner for automated steps |
| [`orchestrator/init-target-repo.sh`](orchestrator/init-target-repo.sh) | Initializes `.sdlc/` inside a target repo |
| [`orchestrator/config.sh`](orchestrator/config.sh) | Default model, effort, timeout, retry, and artifact rules |
| [`orchestrator/status.sh`](orchestrator/status.sh) | Prints the latest run summary |
| [`orchestrator/lib/`](orchestrator/lib) | Execution, validation, context, and notification helpers |
| [`templates/`](templates) | Task, spec, PR-body, override, and step templates |
| [`tests/`](tests) | Orchestrator test suite |

## Target repo contract

Each governed repository contains a tracked `.sdlc/` directory:

- `.sdlc/task.md` — feature intent and acceptance criteria
- `.sdlc/overrides.sh` — optional per-repo model, timeout, or permission overrides
- `.sdlc/artifacts/technical-spec.md` — canonical spec produced by Step 2
- `.sdlc/artifacts/pr-body.md` — canonical PR description produced by Step 7
- `.sdlc/artifacts/semantic-review-actions.md` — remediation log produced by Step 10
- `.sdlc/artifacts/ultra-review.md` — `/ultrareview` findings and triage produced by Step 11
- `.sdlc/reports/semantic_diff_report_<ticket-id>.html` — reviewer-facing report from Step 9
- `.sdlc/logs/` — run logs and rolling pipeline context; gitignored

`init-target-repo.sh` creates the directories and seed files.

## Prerequisites

- `claude` CLI installed: `npm install -g @anthropic-ai/claude-code`
- Claude Code authenticated locally (`claude auth`)
- A git repository to govern
- Any repo-specific access the steps need (e.g. GitHub or Linear CLIs)

## Default model configuration

The orchestrator invokes Claude Code in headless mode (`claude -p`) with:

- Model: `claude-opus-4-7`
- Effort: `xhigh`
- Permission mode: `acceptEdits`

Override any of these per-repo in `.sdlc/overrides.sh` (see [`templates/overrides-template.sh`](templates/overrides-template.sh)).

## Quick start

Clone this repo and export `SDLC_HOME` so helpers resolve the step library:

```bash
export SDLC_HOME=/absolute/path/to/sdlc
```

Optional shell aliases:

```bash
alias sdlc-init='bash "$SDLC_HOME/orchestrator/init-target-repo.sh"'
alias sdlc-dry='bash "$SDLC_HOME/orchestrator/run-pipeline.sh" --dry-run'
alias sdlc='bash "$SDLC_HOME/orchestrator/run-pipeline.sh"'
alias sdlc-status='bash "$SDLC_HOME/orchestrator/status.sh"'
```

1. Initialize SDLC support inside the target repo (once per repo):

   ```bash
   cd /path/to/target-repo
   sdlc-init
   ```

2. Fill in `.sdlc/task.md` with the feature intent and acceptance criteria.

3. Preview the run:

   ```bash
   sdlc-dry
   ```

4. Run the automated pipeline:

   ```bash
   sdlc
   ```

5. Resume or target a single step:

   ```bash
   sdlc --start-from 08-review-comments.md
   sdlc --only 11-ultra-review.md
   ```

## Inspecting run status

Run from anywhere inside a governed repository to inspect the latest pipeline run:

```bash
sdlc-status
```

Output reports the run ID, repository, per-step outcome, elapsed time, and log directory. Step states:

- `✓ completed` — step finished successfully
- `✗ failed` — pipeline halted at that step
- `– skipped` — planned but not executed

If no prior runs exist, the command prints `No pipeline runs found.` and exits 0.

## Governance rules

- Automated steps pass context forward via recorded step summaries, not implicit chat state.
- Durable outputs live under `.sdlc/artifacts/` and `.sdlc/reports/`.
- Manual steps are excluded from automated runs by default and called out explicitly at the end.
- The runner is macOS-friendly and does not assume GNU `timeout` exists.
- Repository-specific files like `AGENTS.md` and `Contributing.md` are used when present; the package works if they are absent.

## Extending the pipeline

Start from [`templates/step-template.md`](templates/step-template.md). Keep new steps:

- Single-purpose
- Explicit about inputs and output paths
- Verifiable through concrete commands
- Durable when later steps depend on their output

Add any new required artifact to `STEP_REQUIRED_PATTERNS` in [`orchestrator/config.sh`](orchestrator/config.sh).

## Tests

```bash
bash tests/run.sh
```
