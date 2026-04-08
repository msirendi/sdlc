# Step 7 — Open Pull Request

**Mode:** Automated
**Objective:** Publish the branch for formal review with a clear, squash-ready PR that accurately frames the intent, scope, and validation status of the change.

## Inputs

- Feature branch (e.g. `name/my-fix-branch`)
- Single Linear issue for the work (e.g. `AI-441`)
- Passing or currently understood validation state
- Summary of implemented behavior and tests

## Prerequisites

- The branch is pushed and reviewable.
- Tests pass (Step 6).

## Procedure

1. **Ensure all commits are pushed:**
   ```
   git push origin name/my-fix-branch
   ```

2. **Confirm the PR scope is acceptable before opening it:**
   - The branch maps to a single Linear issue.
   - The diff stays within repository limits: 25 files changed, 800 total lines changed, and 400 changed lines in any single file.
   - If those limits are exceeded, split the work into stacked or separate PRs unless a maintainer has approved an exception.

3. **Open the PR** via the GitHub CLI or web UI:
   ```
   gh pr create --base main --head name/my-fix-branch --title "<type>(<scope>): <subject>" --body-file <pr-body.md>
   ```

4. **PR title format:**
   ```
   <type>(<scope>): <subject>
   ```
   Or, when scope is unnecessary:
   ```
   <type>: <subject>
   ```
   Use the same conventions as commit messages: valid type, imperative subject, lowercase start, no trailing period, 100 characters max.
   Example: `fix(auth): enforce session expiration`

5. **PR body must contain:**

   A dedicated issue-closing line near the top using a supported keyword and the Linear issue ID:
   ```
   Fixes #AI-441
   ```

   ### Summary
   One paragraph explaining *what* this PR does and *why* — not how. Link the Linear ticket.

   ### Changes
   A concise, grouped list of what changed, organized by concern (data model, business logic, API, config, tests). Each item should be one sentence. This is a map for the reviewer, not a changelog.

   ### How to test
   Step-by-step instructions for manually verifying the behavior, if applicable. Include:
   - Prerequisites (seed data, env vars, running services).
   - Exact commands or UI actions.
   - Expected outcome at each step.

   ### Risks and considerations
   - Known limitations or trade-offs.
   - Areas that warrant extra reviewer scrutiny.
   - Anything deferred to a follow-up ticket.

6. **Assign reviewers** per the project's review policy.

7. **Add labels** (e.g., `feature`, `bugfix`, `breaking`) if the project uses them.

8. **Verify the PR** on GitHub: diff looks clean, no accidental files (`.env`, `.DS_Store`, build artifacts), CI is triggered.

## Outputs

- Open pull request for the feature branch

## Guardrails

- Do not open the PR against the wrong base branch.
- Do not omit testing information.
- Do not understate known limitations or reviewer risk areas.
- Do not use a PR title that cannot be used as the squash commit subject.
- Do not open a PR that spans multiple unrelated issues.

## Completion criteria

- PR is open on GitHub with a complete title and body.
- The PR title follows the repository commit message conventions.
- The PR body links the single Linear issue with a supported closing keyword.
- The diff contains only in-scope changes.
- The diff stays within repository size limits, or an approved exception is documented.
- CI has been triggered and is running.
- Reviewers are assigned.
