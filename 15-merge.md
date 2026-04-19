# Step 15 — Merge Feature Branch to Main (Manual)

**Mode:** Manual
**Objective:** Finalize the change by merging the reviewed and validated remote feature branch into `main` through GitHub.

## Inputs

- Remote feature branch (e.g. `<handle>/my-fix-branch`)
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
   - [ ] The PR is tied to a single Linear issue and includes a supported closing keyword (for example `Fixes #AI-441`).
   - [ ] The PR stays within repository size limits, or a maintainer-approved exception is documented.
   - [ ] The PR title and description are accurate and complete.

2. **Use the repository merge strategy:**
   - **Squash and merge:** Default and expected for this repository. Ensure the resulting squash commit subject follows `<type>(<scope>): <subject>` and is ready to use as-is.
   - **Rebase and merge:** Maintainer exception only when each commit is already logical, complete, and compliant with the commit message guidelines.
   - **Merge commit:** Do not use.

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
- Do not rewrite the squash commit subject into a non-conforming format at merge time.

## Completion criteria

- The feature branch is merged into `main` on GitHub.
- CI on `main` is green.
- The PR status is "Merged."
