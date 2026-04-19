# Step 14 — Rebase if Needed

**Mode:** Automated
**Objective:** Keep the feature branch current with the target base branch and resolve integration conflicts before final merge.

## Inputs

- Feature branch (e.g. `name/my-fix-branch`)
- Latest target base branch, normally `main`

## Prerequisites

- The branch is in a reviewable, testable state.
- Rebasing is permitted by repository workflow.

## Procedure

1. **Check if a rebase is needed:**
   ```
   git fetch origin main
   git log --oneline name/my-fix-branch..origin/main
   ```
   If this outputs commits, `main` has moved ahead and a rebase is warranted.

   Also rebase if:
   - The PR shows merge conflicts on GitHub.
   - CI ran against a stale `main` and results may not reflect the current state.

2. **If no new commits on `main`:** Skip this step.

3. **Perform the rebase:**
   ```
   git checkout name/my-fix-branch
   git rebase origin/main
   ```

4. **Resolve conflicts, if any:**
   - For each conflicting file, open the file and understand both sides of the conflict before resolving.
   - Prefer the intent of *both* changes. Do not blindly accept "ours" or "theirs."
   - After resolving each file:
     ```
     git add <resolved-file>
     git rebase --continue
     ```
   - If a conflict is complex (both sides modified the same logic for different reasons), resolve it carefully and add a brief comment in the code explaining the merge decision if the result is non-obvious.

5. **After rebase completes:**
   - **Run the full test suite** (Step 6) again. Rebase can introduce subtle breakage even without conflicts (e.g., a removed import that your code depends on, a renamed function, a changed config key).
   - Fix any failures before proceeding.

6. **Force-push the rebased branch:**
   ```
   git push --force-with-lease origin name/my-fix-branch
   ```
   Use `--force-with-lease` (not `--force`) to avoid overwriting commits pushed by others.

7. **Verify on GitHub:**
   - The PR diff is clean and conflict-free.
   - CI has been re-triggered on the rebased branch.
   - Wait for CI to pass (Step 13).

## Outputs

- Feature branch rebased onto current base branch when needed
- Conflicts resolved and validations refreshed

## Guardrails

- Do not rebase blindly if the branch is already current.
- Do not lose review fixes or test updates during conflict resolution.
- Do not skip re-validation after conflict-heavy rebases.

## Completion criteria

- The feature branch is based on the latest `main`.
- No merge conflicts remain.
- The full test suite passes on the rebased branch.
- CI is green after the force-push.
