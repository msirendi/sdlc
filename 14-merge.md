# Step 14 — Merge Feature Branch to Main (Manual)

**Mode:** Manual
**Objective:** Finalize the change by merging the reviewed and validated remote feature branch into `main` through GitHub.

## Inputs

- Remote feature branch (e.g. `marek/<ticket-id>`)
- Pull request associated with the branch
- Current review and CI status

## Prerequisites

- Required reviews are complete.
- Required CI checks are passing.
- The branch is approved for merge according to repository policy.

## Procedure

1. **Pre-merge checklist — verify all of the following before clicking merge:**
   - [ ] PR has the required number of approving reviews.
   - [ ] All CI checks are green.
   - [ ] No unresolved review comments remain.
   - [ ] The branch is up to date with `main` (no "branch is behind" warning).
   - [ ] The PR title and description are accurate and complete.

2. **Select the merge strategy** per project convention:
   - **Squash and merge:** Preferred when the branch has many small or WIP commits that should collapse into one clean commit on `main`. Ensure the squash commit message is well-written (ticket ID, imperative summary, brief body if needed).
   - **Rebase and merge:** Preferred when each commit on the branch is already atomic and well-described, and the linear history is valuable.
   - **Merge commit:** Use only if the project explicitly requires merge commits for traceability.

3. **Merge on GitHub.** Confirm the merge completed and the branch indicator shows "Merged."

4. **Verify `main`:**
   - Check that the commit(s) appear on `main`.
   - Confirm CI on `main` passes after the merge. If it fails, treat it as a post-merge incident and investigate immediately.

## Outputs

- Feature branch merged into `main`
- GitHub PR reflects merged state

## Guardrails

- Do not merge with unresolved review concerns.
- Do not merge while required CI checks are failing.
- Do not use a merge strategy that violates repository policy.

## Completion criteria

- The feature branch is merged into `main` on GitHub.
- CI on `main` is green.
- The PR status is "Merged."
