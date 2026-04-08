# Step 10 — Address Unclear and Weakly Justified Changes

**Mode:** Automated
**Objective:** Tighten the branch by either removing, rewriting, or explicitly justifying edits that the semantic diff analysis flagged as weak or unclear.

## Inputs

- `semantic_diff_report.html` from Step 9
- Diff regions labeled `Unclear / possibly superfluous`
- Diff regions labeled `Weakly justified`

## Prerequisites

- Step 9 has been completed.
- The flagged changes can be traced back to specific files or hunks.

## Procedure

1. **Open `semantic_diff_report.html`** and extract every edit tagged as:
   - `Unclear / possibly superfluous`
   - `Weakly justified`

2. **For each flagged edit, determine the correct action:**

   ### Remove
   The edit is genuinely superfluous — it does not support the PR's objective and adds noise to the diff. Revert it. This includes:
   - Formatting-only changes in files not otherwise modified.
   - Import reordering or cleanup unrelated to the feature.
   - Renames or refactors that are not required by the spec.
   - Dead code additions or commented-out blocks.

   ### Fix
   The edit serves the objective but is implemented poorly — unclear naming, missing validation, incomplete logic, or incorrect abstraction. Rewrite it so the justification becomes **Strongly justified** or **Probably justified**.

   ### Justify
   The edit is intentional and necessary, but its purpose was not obvious from the diff alone. Add a code comment or improve naming so that the rationale is self-evident to the next reader. Do not rely on PR description or commit messages to carry this burden — the code itself must be clear.

3. **Document each decision.** For every flagged item, record:
   - The file and location.
   - The label from the report.
   - The action taken (removed / fixed / justified) and a one-sentence rationale.

4. **Commit the changes** in a single commit using the repository's conventional header format:
   ```
   refactor(auth): address semantic review findings
   ```

5. **Re-run the test suite** (Step 6) to confirm no regressions from removals or rewrites.

## Outputs

- Reduced or clarified diff
- Fewer unjustified changes in the branch
- Stronger alignment between code and PR objective

## Guardrails

- Do not keep weak changes merely because they already exist.
- Do not preserve cleanup, style churn, or opportunistic refactors unless they are clearly required.
- Do not respond to semantic flags with explanation alone when the better action is to remove the code.

## Completion criteria

- Every edit flagged as `Unclear / possibly superfluous` or `Weakly justified` has been acted on.
- No superfluous changes remain in the diff.
- Weakly justified edits have been either strengthened, removed, or explicitly annotated.
- The test suite passes after all changes.
