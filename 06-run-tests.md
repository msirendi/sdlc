# Step 6 — Run the Full Test Suite and Emit a Structured Result Report

**Mode:** Automated
**Objective:** Execute the project's complete test surface and write a machine-readable report at `.sdlc/artifacts/test-results.md`. This step **runs** the tests; it does not fix code or modify tests. Step 7 owns failure remediation.

## Inputs

- Current branch state with implementation (Step 4) and tests (Step 3)
- All repository test commands needed to exercise unit, integration, and end-to-end coverage
- Canonical output file: `.sdlc/artifacts/test-results.md`

## Prerequisites

- Local environment is configured to run the full test suite.
- Required services, fixtures, containers, emulators, or credentials for end-to-end tests are available.

## Procedure

1. **Run the entire test suite** using the project's standard test command with no filters or skips:
   ```
   <project test command, e.g.: npm run test, pytest, etc.>
   ```
   Include end-to-end / e2e tests explicitly if they require a separate invocation:
   ```
   <e2e test command, e.g.: npm run test:e2e, pytest tests/e2e/, etc.>
   ```

2. **Capture the full output.** Note:
   - Total tests run, passed, failed, skipped.
   - Each failing test's name, file, line, and full error message and stack trace.
   - Any warnings or deprecation notices.

3. **Triage each failure into one of three categories** for the report (do not fix anything in this step):
   - **branch:** Caused by code on this branch — Step 4's implementation or a Step 3 test that is wrong. Step 7 will route accordingly.
   - **pre-existing:** The same test fails on `main`. Verify by checking out `main` and running just that test, then return to the branch.
   - **flaky:** Passes on retry without code changes. Note it; do not mask it.

4. **Write the structured report** to `.sdlc/artifacts/test-results.md` using exactly this format. The orchestrator parses the `Result:` line; do not deviate from it.

   ```
   # Test Results

   Result: PASS
   Run at: <ISO 8601 timestamp>
   Command: <exact test command(s) executed>

   ## Summary
   - Total: <n>
   - Passed: <n>
   - Failed: <n>
   - Skipped: <n>

   ## Failures
   <One section per failing test, omitted entirely when none.>

   ### <test name>
   - File: <path:line>
   - Category: branch | pre-existing | flaky
   - Error: <one-line summary>
   - Trace: |
     <verbatim stack trace or assertion output>

   ## Pre-existing failures on main
   <List the test names confirmed to fail on main, with the main commit SHA where they fail. Omit the section if none.>

   ## Notes
   <Free-form notes: skipped tests with reasons, environment-specific gaps, anything Step 7 should know.>
   ```

   - The first non-blank `Result:` line MUST read either `Result: PASS` or `Result: FAIL`.
   - `Result: PASS` if and only if every failing test was confirmed `pre-existing` (or there were no failures at all). Any `branch` or unconfirmed failure means `Result: FAIL`.
   - Do not write `Result: PASS` to make the pipeline proceed. The orchestrator's loop reads this line to decide whether to invoke Step 7.
   - Any first `Result:` value that is neither `PASS` nor `FAIL` (or a missing `Result:` line entirely) is treated as UNKNOWN by the loop driver and handled as non-pass — i.e. Step 7 runs. Do not exploit this by omitting the marker; malformed reports indicate a Step 6 bug.

5. **Commit the report** so it is durable across pipeline iterations:
   ```
   chore(sdlc): record test results
   ```
   Re-runs of this step should overwrite the file in place; do not create variant filenames.

## Outputs

- `.sdlc/artifacts/test-results.md` with the structured report described above
- A first-line `Result: PASS` or `Result: FAIL` marker the orchestrator parses
- A committed snapshot of the run

## Guardrails

- **Do not modify production code in this step.** Fixes belong to Step 7.
- **Do not modify test files in this step.** Test edits belong to Step 3.
- **Do not skip, filter, or exclude any tests** to achieve a green run.
- **Do not weaken assertions, add `skip` decorators, or catch-and-ignore errors** to suppress failures.
- Do not write `Result: PASS` when branch failures exist. The orchestrator depends on this marker to decide whether to invoke Step 7.
- Do not investigate root causes here beyond what the triage categorization requires — leave diagnosis to Step 7.

## Completion criteria

- The full test suite (unit + integration + e2e) was executed with zero filters.
- `.sdlc/artifacts/test-results.md` exists and starts with a parseable `Result: PASS` or `Result: FAIL` line.
- Every failure is categorized as `branch`, `pre-existing`, or `flaky` in the report.
- No code or test files were modified by this step.
