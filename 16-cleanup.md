# Step 16 — Cleanup: Delete Local Branch and Worktree (Manual)

**Mode:** Manual
**Objective:** Remove local development artifacts after the change has been safely merged.

## Inputs

- Local feature branch (e.g. `<handle>/my-fix-branch`)
- Local worktree created for the feature branch
- Confirmation that the merged remote state is authoritative

## Prerequisites

- The feature branch has been merged to `main`.
- No uncommitted or unpublished local work remains in the worktree.

## Procedure

1. **Switch out of the worktree** back to the main working directory:
   ```
   cd <path-to-main-repo>
   ```

2. **Remove the worktree:**
   ```
   git worktree remove ../worktrees/my-fix-branch
   ```
   If the worktree has uncommitted changes (there shouldn't be any), git will warn. Verify nothing is unsaved, then force-remove if needed:
   ```
   git worktree remove --force ../worktrees/my-fix-branch
   ```

3. **Check out `main`:**
   ```
   git checkout main -f
   ```

4. **Delete the local feature branch:**
   ```
   git branch -D <handle>/my-fix-branch
   ```
   Use `-D` only after confirming the branch was merged on GitHub. Squash merges do not always make the branch appear "fully merged" to local git history.

5. **Optionally delete the remote branch** if GitHub did not auto-delete it on merge:
   ```
   git push origin --delete <handle>/my-fix-branch
   ```

6. **Pull latest `main`** to ensure the local copy includes the merged work:
   ```
   git pull --ff upstream main
   ```

7. **Prune stale remote-tracking references:**
   ```
   git fetch --prune
   ```

8. **Verify clean state:**
   - `git worktree list` shows only the main working tree.
   - `git branch` shows no leftover feature branches for this change.
   - `git branch -r` shows no stale remote-tracking branch for this change.

## Outputs

- Local worktree removed
- Local feature branch deleted
- Cleaner local repository state

## Guardrails

- Do not delete the worktree or local branch before confirming the branch is merged.
- Do not destroy uncommitted local work.
- Do not delete the wrong branch.

## Completion criteria

- The worktree directory is removed from disk.
- The local feature branch is deleted.
- The remote feature branch is deleted (or auto-deleted by GitHub).
- `main` is up to date locally.
- No dangling worktree or branch references remain.
