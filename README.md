# Software Development Lifecycle — Task Descriptions

Precise, execution-oriented specification of the full lifecycle from product intent to code merged into production.

## Automated Steps

| Step | File | Summary |
|------|------|---------|
| 1 | [`01-branch-setup.md`](01-branch-setup.md) | Create feature branch, publish remote, open worktree, copy `.env` |
| 2 | [`02-technical-spec.md`](02-technical-spec.md) | Review Linear ticket, produce implementation-ready technical spec |
| 3 | [`03-implement.md`](03-implement.md) | Implement the spec with atomic commits |
| 4 | [`04-agents-md-check.md`](04-agents-md-check.md) | Audit against `AGENTS.md`, fix all violations |
| 5 | [`05-tests.md`](05-tests.md) | Write thorough unit and integration tests |
| 6 | [`06-run-tests.md`](06-run-tests.md) | Run full test suite (unit + integration + e2e), fix all failures |
| 7 | [`07-open-pr.md`](07-open-pr.md) | Push and open PR with structured description |
| 8 | [`08-review-comments.md`](08-review-comments.md) | Address every PR review comment with fixes and concise responses |
| 9 | [`09-semantic-diff-report.md`](09-semantic-diff-report.md) | Generate semantic diff report grouped by engineering purpose |
| 10 | [`10-address-findings.md`](10-address-findings.md) | Remove, fix, or justify all unclear/weakly justified changes |
| 11 | [`11-push-and-hooks.md`](11-push-and-hooks.md) | Push changes, fix any pre-commit hook failures |
| 12 | [`12-fix-ci.md`](12-fix-ci.md) | Diagnose and fix all CI failures |
| 13 | [`13-rebase.md`](13-rebase.md) | Rebase onto latest `main` if it has advanced |

## Manual Steps

| Step | File | Summary |
|------|------|---------|
| 14 | [`14-merge.md`](14-merge.md) | Merge feature branch to `main` on GitHub |
| 15 | [`15-cleanup.md`](15-cleanup.md) | Delete local branch and worktree |

## Intended use

Each step file is an explicit task description for an automation or operator. Every file contains:
- Objective and mode (automated / manual)
- Inputs and prerequisites
- Procedure with concrete commands
- Outputs
- Guardrails
- Completion criteria

## Conventions

- Treat `main` as the integration baseline unless repository conventions require a different default branch.
- Do not skip tests, validations, reviews, or cleanup tasks unless an explicit higher-priority instruction overrides them.
