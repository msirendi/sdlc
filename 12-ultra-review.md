# Step 12 — Ultra Review

**Mode:** Automated
**Objective:** Run a dedicated review session that reads through the branch changes and flags bugs and design issues a careful reviewer would catch.

## Inputs

- Current feature branch diff against `main`
- `.sdlc/reports/semantic_diff_report_<ticket-id>.html` from Step 10
- `.sdlc/artifacts/semantic-review-actions.md` from Step 11
- Canonical output file: `.sdlc/artifacts/ultra-review.md`

## Prerequisites

- Step 11 completed and its remediation commits are on the branch.
- The test suite is passing after Step 11.

## Procedure

1. **Invoke Claude Code's `/ultrareview` slash command** in a dedicated session scoped to the branch changes:
   ```
   claude -p "/ultrareview" --permission-mode acceptEdits
   ```
   The command produces a review session that reads through the changes and surfaces bugs and design issues a careful reviewer would catch. Use it as a second independent pass on top of Step 10's semantic diff.

2. **Capture the review output** verbatim at `.sdlc/artifacts/ultra-review.md`. Preserve the finding structure (severity, file, location, explanation) so later steps can act on it.

3. **Triage every finding.** For each item, record one of:
   - **Fix:** Apply the code change now. Prefer the reviewer's suggested approach unless there is a specific, articulable reason not to.
   - **Defer:** Out of scope for this PR. Open a follow-up ticket and reference it in the action log.
   - **Reject:** Not a real issue. Record the rationale in one sentence.

4. **Append triage decisions** to `.sdlc/artifacts/ultra-review.md` under a `## Actions` section. For each finding, record:
   - File and location.
   - Severity or category reported by `/ultrareview`.
   - Action taken (fix / defer / reject) and a one-sentence rationale.
   - Commit SHA or follow-up ticket ID where applicable.

5. **Apply the accepted fixes** in a single commit using the repository's conventional header format:
   ```
   fix(sdlc): address ultra-review findings
   ```
   Split into multiple commits only if findings touch unrelated concerns.

6. **Re-run the test suite** by re-running Step 6 (and, if it surfaces failures, Step 7) to confirm no regressions from the applied fixes.

## Outputs

- Review report at `.sdlc/artifacts/ultra-review.md` with findings and triage decisions
- Commits that resolve every accepted finding
- Passing test suite after fixes

## Guardrails

- Do not skip findings without recording a triage decision.
- Do not mark a finding as rejected without a concrete, articulable reason.
- Do not silently defer critical findings; link a follow-up ticket.
- Do not rewrite or soften `/ultrareview` output in the captured report; triage goes in the `## Actions` section.

## Completion criteria

- `.sdlc/artifacts/ultra-review.md` exists and contains the `/ultrareview` findings plus an `## Actions` section.
- Every finding has a triage decision.
- All findings marked `fix` are resolved on the branch.
- All findings marked `defer` have a follow-up ticket recorded.
- The test suite passes on the updated branch.
