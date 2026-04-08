# Step 1 — Branch Setup, Worktree, and Environment

**Mode:** Automated
**Objective:** Establish an isolated development environment using a correctly named feature branch and an attached worktree that is ready to run locally.

## Inputs

- Work item identifier (e.g. <ticket-id> such as `AIP-441`)
- Branch name: `marek/<ticket-id>`
- Repository root with clean local Git state
- Local `.env` to copy into the worktree

## Prerequisites

- Local Git remotes are configured.
- The target branch name does not already exist locally or remotely at the wrong commit.
- Any uncommitted local changes have been stashed, committed, or otherwise isolated.

## Procedure

1. **Create the feature branch** from the current `main` HEAD:
   ```
   git checkout main && git pull origin main
   git checkout -b marek/<ticket-id>
   ```

2. **Publish the branch** to the remote so it tracks correctly:
   ```
   git push -u origin marek/<ticket-id>
   ```

3. **Create and open a worktree** for the branch so `main` stays clean:
   ```
   git worktree add ../worktrees/<ticket-id> marek/<ticket-id>
   cd ../worktrees/<ticket-id>
   ```

4. **Copy the environment file** from the project root (or the main worktree) into the new worktree:
   ```
   cp <path-to-main>/.env .env
   ```

5. **Install dependencies** if the worktree requires its own `node_modules`, venv, or equivalent.

6. **Verify** the worktree is functional:
   - `git branch` shows the feature branch as active.
   - `git log --oneline -1` matches the latest `main` commit.
   - The app builds or the test runner initializes without environment errors.

## Outputs

- Local branch `marek/<ticket-id>`
- Remote branch `origin/marek/<ticket-id>` tracking the local branch
- New worktree checked out to `marek/<ticket-id>`
- `.env` present in the worktree

## Guardrails

- Do not develop directly on `main`.
- Do not create a detached HEAD worktree.
- Do not silently reuse an incorrectly configured branch.
- Do not overwrite an existing `.env` in the worktree without confirming replacement is intended.

## Completion criteria

- Remote branch `origin/marek/<ticket-id>` exists and tracks the local branch.
- A dedicated worktree directory is open with a valid `.env`.
- No uncommitted or untracked state carries over from `main`.
