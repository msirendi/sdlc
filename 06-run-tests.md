# Step 6 — Run Full Test Suite and Resolve All Failures

**Mode:** Automated
**Objective:** Validate the branch against the complete repository test surface and fix any regressions or environment-sensitive failures encountered. Do not skip any tests.

## Inputs

- Current branch state with implementation and tests
- All repository test commands needed to exercise unit, integration, and end-to-end coverage

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
   - Each failing test's name, file, and error message.
   - Any warnings or deprecation notices.

3. **Triage each failure.** For every failing test, determine:
   - **Caused by this branch:** The test fails because of code you changed or introduced. → Fix the code or the test, whichever is wrong.
   - **Pre-existing failure:** The test was already failing on `main`. → Verify by checking out `main` and running the same test. If confirmed pre-existing, do not fix it in this branch (out of scope), but note it.
   - **Flaky test:** The test passes on retry without code changes. → Note it, but do not mask it with retries or skips.

4. **Fix branch-caused failures.** For each:
   - Identify the root cause (logic bug, incorrect assertion, missing mock, stale fixture, environment issue).
   - Fix the root cause — do not weaken assertions, add `skip` decorators, or catch-and-ignore errors to make the test pass.
   - Re-run the failing test in isolation to confirm the fix.

5. **Re-run the full suite** after all fixes. Repeat until the suite is fully green (excluding confirmed pre-existing failures).

6. **Do not skip any tests.** If a test is slow, let it run. If a test requires infrastructure (database, API keys, containers), ensure the environment is configured. If the environment genuinely cannot run a specific test locally, document which tests were not run and why.

## Outputs

- Passing full test suite on the branch
- Any necessary fixes made in response to failures
- Pre-existing failures documented with the commit hash on `main` where they also fail

## Guardrails

- Do not skip tests.
- Do not rely on partial or filtered test runs as the final validation step.
- Do not ignore flaky or timing-sensitive failures without understanding whether the branch contributed to them.
- Do not claim success unless the full suite has actually been run.

## Completion criteria

- The full test suite (unit + integration + e2e) has been executed with zero filters.
- All tests pass, except any that are confirmed pre-existing failures on `main`.
- No tests have been skipped, weakened, or removed to achieve a green run.
