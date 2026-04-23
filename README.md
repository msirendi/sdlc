# AI-Governed SDLC Pipeline

This repository is a runnable SDLC package driven by the Claude Code CLI, not just a set of markdown prompts. It contains:

- A 17-step feature delivery process expressed as explicit step files.
- An orchestrator that runs the automated steps in order, including a decoupled
  test-fix loop that separates writing tests, implementing code, running tests,
  and fixing failures into independent Claude Code invocations.
- Repo-initialization helpers and artifact templates so later steps can consume durable outputs.
- Manual closeout checklists for merge and cleanup.

## What this governs

The package is designed to govern the full feature lifecycle in a target repository:

1. Branch setup and isolated worktree creation
2. Technical specification from task intent
3. **Test authoring from the spec (before implementation)**
4. **Implementation against the committed tests (no test execution)**
5. Repository instruction compliance review
6. **Full-suite test execution that emits a structured `Result: PASS|FAIL` report**
7. **Fix implementation to satisfy failing tests (tests are read-only)**
8. Pull request creation
9. Review comment handling
10. Semantic diff analysis
11. Weak-change cleanup
12. Ultra-review (`/ultrareview`) bug and design-issue pass
13. Push and hook enforcement
14. CI remediation
15. Rebase and re-validation
16. Merge checklist
17. Cleanup checklist

Steps `01` through `15` are automated. Steps `16` and `17` are manual by default and remain explicit operator checklists.

### Decoupled test workflow

Steps 3, 4, 6, and 7 are intentionally split so each Claude invocation has one
job:

- Step 3 writes the tests from the spec — no implementation, no test execution.
- Step 4 implements the code against those tests — no test execution, no test edits.
- Step 6 runs the suite and writes `.sdlc/artifacts/test-results.md` — no fixes.
- Step 7 reads the report and fixes production code — no test edits, no test execution.

The orchestrator drives a 6↔7 loop: after Step 6 writes its report, if the
first `Result:` line is not `PASS`, Step 7 runs once and Step 6 re-runs. The
loop iterates up to `MAX_TEST_FIX_ITERATIONS` (default `3`) before halting.
Step 7 is therefore not listed as a top-level planned step when Step 6 is in the
plan; it appears in run logs with an `(iter N)` suffix.

## Repository layout

| Path | Purpose |
| --- | --- |
| `01-branch-setup.md` ... `17-cleanup.md` | The canonical SDLC step instructions |
| [`orchestrator/run-pipeline.sh`](orchestrator/run-pipeline.sh) | Main runner for automated steps |
| [`orchestrator/init-target-repo.sh`](orchestrator/init-target-repo.sh) | Initializes `.sdlc/` inside an existing target repo |
| [`orchestrator/config.sh`](orchestrator/config.sh) | Default model, effort, timeout, retry, and artifact rules |
| [`orchestrator/status.sh`](orchestrator/status.sh) | Prints the latest run summary |
| [`orchestrator/lib/`](orchestrator/lib) | Execution, validation, context, and notification helpers |
| [`templates/`](templates) | Task, spec, PR-body, override, and step templates |
| [`tests/`](tests) | Orchestrator test suite |

## Target repo contract

Each governed repository should contain a tracked `.sdlc/` directory with:

- `.sdlc/task.md`: feature intent and acceptance criteria
- `.sdlc/overrides.sh`: optional per-repo model, timeout, or permission overrides
- `.sdlc/artifacts/technical-spec.md`: canonical spec produced by Step 2
- `.sdlc/artifacts/test-results.md`: structured test-run report produced by Step 6 (the orchestrator parses its first `Result:` line to drive the 6↔7 fix loop)
- `.sdlc/artifacts/pr-body.md`: canonical PR description produced by Step 8
- `.sdlc/artifacts/semantic-review-actions.md`: remediation log produced by Step 11
- `.sdlc/artifacts/ultra-review.md`: `/ultrareview` findings and triage produced by Step 12
- `.sdlc/reports/semantic_diff_report_<ticket-id>.html`: reviewer-facing semantic diff report from Step 10
- `.sdlc/logs/`: run logs, summaries, and rolling pipeline context; gitignored

The init script creates the directories and seed files inside an existing repository for you.

## Prerequisites

- `claude` CLI installed, for example `npm install -g @anthropic-ai/claude-code`
- Claude Code authenticated locally (`claude auth`)
- A git repository to govern
- Any repo-specific access needed by the steps, such as GitHub or Linear

## Installing the `sdlc` commands

The pipeline ships real executable wrappers under [`bin/`](bin). Put that
directory on your `PATH` once and every `sdlc*` command becomes invocable from
any shell:

```bash
# Clone this repo anywhere, e.g. ~/sdlc
git clone https://github.com/msirendi/sdlc.git ~/sdlc

# Add to ~/.zshrc (or ~/.bashrc) so it persists across sessions
export SDLC_HOME="$HOME/sdlc"
export PATH="$SDLC_HOME/bin:$PATH"
```

Reopen your shell (or `source` the rc file) and verify:

```bash
command -v sdlc sdlc-init sdlc-dry sdlc-status
```

Each of those resolves to a script in `$SDLC_HOME/bin`. `SDLC_HOME` is inferred
from the wrapper's own location, so the `export SDLC_HOME=...` line is optional
as long as the wrappers live next to the `orchestrator/` directory.

If you prefer not to edit your `PATH`, symlink individual wrappers into a
directory that is already on `PATH`:

```bash
ln -s "$HOME/sdlc/bin/sdlc"        /usr/local/bin/sdlc
ln -s "$HOME/sdlc/bin/sdlc-init"   /usr/local/bin/sdlc-init
ln -s "$HOME/sdlc/bin/sdlc-dry"    /usr/local/bin/sdlc-dry
ln -s "$HOME/sdlc/bin/sdlc-status" /usr/local/bin/sdlc-status
```

The wrappers resolve symlinks, so `SDLC_HOME` still points at the real repo.

## Default model configuration

The orchestrator invokes Claude Code in headless mode (`claude --print`) with:

- Model: `claude-opus-4-7`
- Effort: `xhigh`
- Permission mode: `acceptEdits`

Because `--print` emits the final step response on stdout when the Claude
process exits, the orchestrator also emits heartbeat/progress lines during long
steps. By default those liveness updates print every 30 seconds and include any
tracked artifact paths for the current step.

Override any of these per-repo in `.sdlc/overrides.sh` (see [`templates/overrides-template.sh`](templates/overrides-template.sh)).

## Quick start

1. In the existing repo you want to work on, initialize SDLC support once:

   ```bash
   cd /path/to/existing-repo
   sdlc-init
   ```

   This does not create a new repository. It just adds `.sdlc/` scaffolding to the repo you are already in.

2. Fill in `.sdlc/task.md` for the new task.

3. Preview the run:

   ```bash
   sdlc-dry
   ```

4. Run the automated SDLC:

   ```bash
   sdlc
   ```

5. Resume or target a single step as needed:

   ```bash
   sdlc --start-from 09-review-comments.md
   sdlc --only 12-ultra-review.md
   ```

## Checking run status

Use `sdlc-status` from anywhere inside a governed repository to inspect the
latest pipeline run without browsing `.sdlc/logs/` manually:

```bash
sdlc-status
```

The summary reports the latest run ID, repository name, per-step outcome,
elapsed time, and the log directory path. Step states are shown as:

- `✓ completed`: the step finished successfully
- `✗ failed`: the pipeline halted at that step
- `– skipped`: the step was planned for the run but did not complete

When no prior runs exist for the current repository, the command prints
`No pipeline runs found.` and exits successfully.

## Governance rules baked into this package

- Automated steps pass context forward via recorded step summaries, not implicit chat state.
- Durable outputs are written into canonical `.sdlc/artifacts/` and `.sdlc/reports/` paths.
- Manual steps are not silently skipped; they are excluded by default and called out explicitly at the end of the run.
- The runner is macOS-friendly and does not assume GNU `timeout` exists.
- Repository-specific files such as `AGENTS.md` and `Contributing.md` are used when present; the package still works if they are absent.

## Extending the pipeline

Use [`templates/step-template.md`](templates/step-template.md) for new steps. Keep them:

- Single-purpose
- Explicit about inputs and output paths
- Verifiable through concrete commands
- Durable when later steps depend on their output

Add any new required artifact to `STEP_REQUIRED_PATTERNS` in [`orchestrator/config.sh`](orchestrator/config.sh).

## Tests

```bash
bash tests/run.sh
```
