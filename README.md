# AI-Governed SDLC Pipeline

This repository is now a runnable SDLC package, not just a set of markdown prompts. It contains:

- A 15-step feature delivery process expressed as explicit step files.
- A Codex-based orchestrator that runs the automated steps in order.
- Repo-initialization helpers and artifact templates so later steps can consume durable outputs.
- Manual closeout checklists for merge and cleanup.

## What this governs

The package is designed to govern the full feature lifecycle in a target repository:

1. Branch setup and isolated worktree creation
2. Technical specification from task intent
3. Implementation
4. Repository instruction compliance review
5. Test authoring
6. Full-suite execution
7. Pull request creation
8. Review comment handling
9. Semantic diff analysis
10. Weak-change cleanup
11. Push and hook enforcement
12. CI remediation
13. Rebase and re-validation
14. Merge checklist
15. Cleanup checklist

Steps `01` through `13` are automated. Steps `14` and `15` are manual by default and remain explicit operator checklists.

## Repository layout

| Path | Purpose |
| --- | --- |
| `01-branch-setup.md` ... `15-cleanup.md` | The canonical SDLC step instructions |
| [`orchestrator/run-pipeline.sh`](orchestrator/run-pipeline.sh) | Main runner for automated steps |
| [`orchestrator/init-target-repo.sh`](orchestrator/init-target-repo.sh) | Initializes `.sdlc/` inside an existing target repo |
| [`orchestrator/config.sh`](orchestrator/config.sh) | Default model, timeout, retry, and artifact rules |
| [`orchestrator/lib/`](orchestrator/lib) | Execution, validation, context, and notification helpers |
| [`templates/`](templates) | Task, spec, PR-body, override, and step templates |
| [`orchestrating-ai-agents-sdlc-guide.md`](orchestrating-ai-agents-sdlc-guide.md) | Reviewed operating guide aligned to this implementation |

## Target repo contract

Each governed repository should contain a tracked `.sdlc/` directory with:

- `.sdlc/task.md`: feature intent and acceptance criteria
- `.sdlc/overrides.sh`: optional per-repo timeout or sandbox overrides
- `.sdlc/artifacts/technical-spec.md`: canonical spec produced by Step 2
- `.sdlc/artifacts/pr-body.md`: canonical PR description produced by Step 7
- `.sdlc/artifacts/semantic-review-actions.md`: remediation log produced by Step 10
- `.sdlc/reports/semantic_diff_report_<ticket-id>.html`: reviewer-facing semantic diff report from Step 9
- `.sdlc/logs/`: run logs, summaries, and rolling pipeline context; gitignored

The init script creates the directories and seed files inside an existing repository for you.

## Quick start

Prerequisites:

- `codex` CLI installed, for example `npm install -g @openai/codex`
- Codex authenticated locally
- A git repository to govern
- Any repo-specific access needed by the steps, such as GitHub or Linear

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
   sdlc --start-from 08-review-comments.md
   ```

## Checking run status

Use the status command from anywhere inside a governed repository to inspect the
latest pipeline run without browsing `.sdlc/logs/` manually:

```bash
bash "$SDLC_HOME/orchestrator/status.sh"
```

The summary reports the latest run ID, repository name, per-step outcome,
elapsed time, and the log directory path. Step states are shown as:

- `✓ completed`: the step finished successfully
- `✗ failed`: the pipeline halted at that step
- `– skipped`: the step was planned for the run but did not complete

If your shell does not already expose a helper, add one like this:

```bash
sdlc-status() {
  SDLC_HOME="${SDLC_HOME:-/path/to/sdlc}" \
    bash "$SDLC_HOME/orchestrator/status.sh"
}
```

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
