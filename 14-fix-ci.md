# Step 14 — Fix CI Issues

**Mode:** Automated
**Objective:** Bring the branch to a clean continuous integration state by resolving all failing or blocking CI checks. Do not merge with a red pipeline.

## Inputs

- Current pull request and branch state
- CI job results, logs, annotations, and artifacts

## Prerequisites

- The latest branch state has been pushed.
- CI has run or been triggered for the current commits.

## Procedure

1. **Check CI status** on the PR or via CLI:
   ```
   gh pr checks <pr-number>
   ```
   Wait for all jobs to complete. Do not proceed while jobs are still running.

2. **If all jobs pass:** This step is done. Move on.

3. **If any job fails, diagnose each failure:**

   ### Read the full log
   Open the failed job's log — not just the summary. Scroll to the first error, not the last. CI often cascades, and the root cause is at the top.

   ### Categorize the failure:

   - **Test failure:** A test that passes locally fails in CI.
     - Check for environment differences: missing env vars, different DB state, timezone, locale, file paths.
     - Check for test ordering dependencies (tests that pass in isolation but fail when run together).
     - Check for timing / race conditions in async tests.
     - Reproduce locally with the same flags CI uses (e.g., `--ci`, `--forceExit`, `--runInBand`).

   - **Lint / type / format failure:** The CI linter is stricter or configured differently from local.
     - Pull the CI config and run the exact same command locally.
     - Fix the issue in code, not in CI config.

   - **Build failure:** Compilation or bundling fails.
     - Check for missing dependencies (installed locally but not in `package.json` / `requirements.txt`).
     - Check for import path case sensitivity (macOS is case-insensitive, CI Linux is not).

   - **Repository policy failure:** CI rejects the branch because it violates documented workflow constraints (for example PR size or scope rules).
     - Split the work into smaller, single-issue or stacked PRs, or coordinate a maintainer-approved exception.
     - Do not disable or weaken the policy check in this branch.

   - **Infrastructure failure:** CI runner issue, Docker pull timeout, flaky third-party service.
     - Retry the job once. If it fails again on the same step with the same error, treat it as a real issue.
     - If it's genuinely infrastructure (e.g., Docker Hub rate limit), document it and retry later.

4. **Fix the root cause locally.** Do not apply CI-only workarounds (e.g., retry directives, conditional skips, increased timeouts as a bandage).

5. **Push the fix** and wait for CI to re-run. Repeat until all jobs are green.

6. **If a failure is pre-existing on `main`:**
   - Verify by checking CI status on the `main` branch.
   - If confirmed, note it in the PR description. Do not fix it in this branch unless it is trivial and clearly unrelated to your changes.

## Outputs

- Passing required CI checks
- Branch updated with fixes for CI-detected issues

## Guardrails

- Do not treat secondary cascading errors as root causes.
- Do not rely only on local assumptions when CI indicates an environment-specific issue.
- Do not merge while required CI checks are still failing.

## Completion criteria

- All CI jobs pass on the feature branch.
- No CI failures were papered over with retries, skips, or config hacks.
- Any pre-existing `main` failures are documented in the PR.
