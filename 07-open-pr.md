# Step 7 — Open Pull Request

**Mode:** Automated
**Objective:** Publish the branch for formal review with a clear PR that accurately frames the intent, scope, and validation status of the change.

## Inputs

- Feature branch (e.g. `marek/<ticket-id>`)
- Passing or currently understood validation state
- Summary of implemented behavior and tests

## Prerequisites

- The branch is pushed and reviewable.
- Tests pass (Step 6).

## Procedure

1. **Ensure all commits are pushed:**
   ```
   git push origin marek/<ticket-id>
   ```

2. **Open the PR** via the GitHub CLI or web UI:
   ```
   gh pr create --base main --head marek/<ticket-id> --title "<ticket-id>: <concise summary>" --body-file <pr-body.md>
   ```

3. **PR title format:**
   ```
   <ticket-id>: <imperative verb phrase summarizing the change>
   ```
   Example: `AIP-441: Add session expiration enforcement to auth middleware`

4. **PR body must contain:**

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

5. **Assign reviewers** per the project's review policy.

6. **Add labels** (e.g., `feature`, `bugfix`, `breaking`) if the project uses them.

7. **Verify the PR** on GitHub: diff looks clean, no accidental files (`.env`, `.DS_Store`, build artifacts), CI is triggered.

## Outputs

- Open pull request for the feature branch

## Guardrails

- Do not open the PR against the wrong base branch.
- Do not omit testing information.
- Do not understate known limitations or reviewer risk areas.

## Completion criteria

- PR is open on GitHub with a complete title and body.
- The diff contains only in-scope changes.
- CI has been triggered and is running.
- Reviewers are assigned.
