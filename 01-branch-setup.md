# Step 1 — Branch Setup, Worktree, and Environment

**Mode:** Automated
**Objective:** Establish an isolated development environment using a new git branch from `main` and an attached worktree that is ready to run locally.

## Inputs

- Work item identifier (e.g. `AI-441`)
- Branch name (e.g. `name/my-fix-branch`)
- Repository root with clean local Git state
- Local `.env` to copy into the worktree

## Prerequisites

- Local Git remotes are configured.
- The target branch name does not already exist locally or remotely at the wrong commit.
- Any uncommitted local changes have been stashed, committed, or otherwise isolated.

## Procedure

1. **Create the feature branch** from the current `main` HEAD:
   ```
   git checkout main
   git pull --ff-only origin main
   git checkout -b name/my-fix-branch
   ```

2. **Publish the branch** to the remote so it tracks correctly:
   ```
   git push -u origin name/my-fix-branch
   ```

3. **Create and open a worktree** for the branch so `main` stays clean:
   ```
   git worktree add ../worktrees/my-fix-branch name/my-fix-branch
   cd ../worktrees/my-fix-branch
   ```

4. **Copy the environment file** from the project root (or the main worktree) into the new worktree:
   ```
   cp <path-to-main>/.env .env
   ```

5. **Install dependencies** if the worktree requires its own `node_modules`, venv, or equivalent.

6. **Install repository hooks** so policy and size checks run locally:
   ```
   pre-commit install
   pre-commit install --hook-type pre-push
   pre-commit run --all-files
   ```

7. **Verify** the worktree is functional:
   - `git branch` shows the feature branch as active.
   - `git log --oneline -1` matches the latest `main` commit.
   - Local hooks are installed and passing.
   - The app builds or the test runner initializes without environment errors.

## Outputs

- Local branch `name/my-fix-branch`
- Remote branch `origin/name/my-fix-branch` tracking the local branch
- New worktree checked out to `name/my-fix-branch`
- `.env` present in the worktree
- Repository hooks installed locally

## Guardrails

- Do not develop directly on `main`.
- Do not create a detached HEAD worktree.
- Do not silently reuse an incorrectly configured branch.
- Do not overwrite an existing `.env` in the worktree without confirming replacement is intended.

## Completion criteria

- Remote branch `origin/name/my-fix-branch` exists and tracks the local branch.
- A dedicated worktree directory is open with a valid `.env`.
- Repository hooks are installed and passing locally.
- No uncommitted or untracked state carries over from `main`.
