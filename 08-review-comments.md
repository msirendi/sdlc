# Step 8 — Address PR Review Comments

**Mode:** Automated
**Objective:** Incorporate reviewer feedback with thoughtful code changes and concise comment responses that close the loop on each addressed point.

## Inputs

- Pull request under review (e.g. `#585`)
- All review comments, inline comments, threads, and unresolved discussions on the PR
- Current branch state

## Prerequisites

- The PR is accessible.
- The current branch corresponds to the PR under review.

## Procedure

1. **Fetch all review comments** on the PR:
   ```
   gh pr view <pr-number> --comments
   gh api repos/<owner>/<repo>/pulls/<pr-number>/comments
   ```
   Or read them on the GitHub web UI. Do not miss inline comments, review-level comments, or threaded replies.

2. **For each comment, determine the category:**
   - **Code change requested:** The reviewer wants something fixed, refactored, renamed, or restructured.
   - **Question:** The reviewer wants clarification about intent, rationale, or behavior.
   - **Suggestion:** Optional improvement the reviewer is proposing.
   - **Nitpick:** Minor style or preference note.

3. **For code change requests:**
   - Understand the reviewer's concern fully before changing anything. Re-read the surrounding code and the reviewer's exact words.
   - Implement the fix. Prefer the reviewer's suggested approach unless you have a specific, articulable reason not to.
   - If you disagree, explain why concisely and propose an alternative — do not silently ignore the comment.

4. **For questions:**
   - Answer directly. If the answer reveals a gap in the code's self-documentation (unclear naming, missing comment), fix the code so the question wouldn't arise for the next reader.

5. **For suggestions and nitpicks:**
   - Accept and implement unless doing so introduces risk or conflicts with project conventions. If declining, state why in one sentence.

6. **Respond to each comment** on GitHub after implementing the fix:
   - Keep responses to one or two sentences maximum.
   - State what you did: `Fixed — renamed to X`, `Added null check`, `Good catch — updated the test`.
   - Do not over-explain or re-describe the code. The diff speaks for itself.
   - Do not leave any comment unaddressed.

7. **Commit the fixes.** Group related review-feedback fixes into a single commit:
   ```
   fix(auth): address review feedback
   ```
   If a fix is substantial (not just a rename or one-liner), give it its own commit with a descriptive header that still follows `<type>(<scope>): <subject>`.

8. **Push and notify** the reviewer that comments have been addressed.

## Outputs

- Updated branch incorporating review feedback
- Concise reviewer responses on addressed comments

## Guardrails

- Do not respond without actually addressing the concern unless a clear rationale is provided.
- Do not leave long conversational replies.
- Do not ignore partially hidden, outdated, or nested threads if they still represent unresolved concerns.

## Completion criteria

- Every review comment has a corresponding code change (or a concise explanation of why not).
- Every review comment has a response on GitHub.
- Responses are concise — no multi-paragraph justifications.
- Changes are pushed and the reviewer can re-review.
