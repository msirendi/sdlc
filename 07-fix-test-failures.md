# Step 7 — Fix Implementation to Satisfy Failing Tests (Tests Are Read-Only)

**Mode:** Automated
**Objective:** Read the structured failure report from Step 6 and fix the implementation so the failing tests will pass on the next Step 6 run. This step **does not run tests** and **does not modify tests** — it only changes production code.

The orchestrator drives a loop between Step 6 (run) and Step 7 (fix) until the suite is green or the iteration cap is reached. This step is a single fix pass; the validation that fixes worked happens when Step 6 re-runs.

## Inputs

- `.sdlc/artifacts/test-results.md` written by Step 6
- Production source code on the feature branch
- Read-only: test files committed by Step 3

## Prerequisites

- Step 6 has completed and written `.sdlc/artifacts/test-results.md`.
- The report's first `Result:` line is `FAIL` (if it is `PASS`, this step has nothing to do — exit READY immediately with a one-line summary).

## Procedure

1. **Read `.sdlc/artifacts/test-results.md`.** If the first `Result:` line is `PASS`, finish immediately with status READY and a summary noting "no failures to fix." Do not modify anything.

2. **For each failure listed under `## Failures`:**
   - Read the file and stack trace pinpointed in the report.
   - Open the *test* and read it for understanding only — to learn what behavior is expected. Do not edit it.
   - Open the *production code* the test exercises and find the divergence between actual and expected behavior.

3. **Triage by category:**
   - **branch failures:** Fix the production code so the test's assertions hold. Prefer minimal, targeted changes that align the implementation with the test contract and the technical spec.
   - **pre-existing failures:** Skip. They are not this branch's responsibility; the report already documents them.
   - **flaky failures:** Investigate whether this branch contributed to the flakiness (new concurrency, new I/O, new timing). If yes, fix the root cause. If not, leave a note in the next Step 6 report and do not paper over with retries.

4. **Fix scope rules:**
   - Change only production code. Tests are part of the contract.
   - Apply the smallest fix that satisfies the failing assertions without breaking other tests.
   - If a test reveals a real spec ambiguity (the implementation could legitimately satisfy the spec in several ways, but the test pins down a specific one), conform the implementation to the test. The test was written from the spec in Step 3 and is the more concrete artifact.
   - If a test appears genuinely wrong — it contradicts the spec, encodes an impossible contract, or over-specifies an incidental detail — **do not edit it here**. Return BLOCKED with the offending test path and a one-paragraph rationale. Step 2 (spec) and Step 3 (tests) own corrections to the contract.

5. **Commit each logically distinct fix** using the repository's conventional header format:
   ```
   fix(<scope>): make <test or behavior> pass
   ```
   Group tightly coupled fixes into one commit; do not bundle unrelated fixes.

6. **Do not run the test suite.** Verification that the fixes work is Step 6's responsibility on the next loop iteration. Running tests here re-couples fixing with running and undermines the loop's iteration count.

7. **End with a structured summary** in your final response noting:
   - Number of branch failures addressed.
   - Files modified.
   - Any failures left intentionally unaddressed (with category).
   - Status: READY (fixes applied, awaiting Step 6 re-run) or BLOCKED (a test is wrong; spec/test owner needs to act).

## Outputs

- Production-code commits that target the branch failures listed in `.sdlc/artifacts/test-results.md`
- An unchanged set of test files (Step 3's commits remain authoritative)

## Guardrails

- **Do not modify any test file** (no edits, deletes, renames, skips, xfails, weakened assertions, or new mocks inside test files).
- **Do not run the test suite or any individual test** — the orchestrator re-invokes Step 6 to verify.
- Do not bypass a failing test by deleting the calling code path it covers.
- Do not add catch-all exception handlers or silent fallbacks just to satisfy an assertion.
- Do not mark `pre-existing` failures as fixed unless you actually fixed them in scope.

## Completion criteria

- Every `branch` failure in the report has a corresponding production-code change attempted, OR is escalated as BLOCKED with a clear reason.
- No test files were modified.
- The final response includes the structured summary, ending with `Status: READY` or `Status: BLOCKED`.
