# Step 15 — Cleanup: Delete Local Branch and Worktree (Manual)

**Mode:** Manual
**Objective:** Remove local development artifacts after the change has been safely merged.

## Inputs

- Local feature branch (e.g. `marek/<ticket-id>`)
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
   git worktree remove ../worktrees/<ticket-id>
   ```
   If the worktree has uncommitted changes (there shouldn't be any), git will warn. Verify nothing is unsaved, then force-remove if needed:
   ```
   git worktree remove --force ../worktrees/<ticket-id>
   ```

3. **Delete the local feature branch:**
   ```
   git branch -d marek/<ticket-id>
   ```
   Use `-d` (not `-D`). If git refuses because the branch is "not fully merged," something went wrong — investigate before forcing deletion.

4. **Optionally delete the remote branch** if GitHub did not auto-delete it on merge:
   ```
   git push origin --delete marek/<ticket-id>
   ```

5. **Pull latest `main`** to ensure the local copy includes the merged work:
   ```
   git checkout main && git pull origin main
   ```

6. **Prune stale remote-tracking references:**
   ```
   git fetch --prune
   ```

7. **Verify clean state:**
   - `git worktree list` shows only the main working tree.
   - `git branch` shows no leftover feature branches for this ticket.
   - `git branch -r` shows no stale remote-tracking branch for this ticket.

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
