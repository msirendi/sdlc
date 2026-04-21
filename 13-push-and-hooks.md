# Step 13 — Push Changes and Fix Pre-Commit Hook Issues

**Mode:** Automated
**Objective:** Publish the latest branch state to the remote and resolve any repository-enforced pre-commit or pre-push issues encountered during the process.

## Inputs

- Updated local branch (e.g. `<handle>/my-fix-branch`)
- Repository hook configuration

## Prerequisites

- Local changes intended for publication are committed.
- The correct remote tracking relationship is configured.

## Procedure

1. **Stage and commit** any remaining uncommitted work. Ensure each commit message follows `Contributing.md`: header only, `<type>(<scope>): <subject>` or `<type>: <subject>`, valid type, imperative lowercase subject, no trailing period, 100 characters max.
   - If the repository does not have `Contributing.md`, use the commit-title rules defined in this SDLC package.

2. **Install hooks locally if they are missing:**
   ```
   pre-commit install
   pre-commit install --hook-type pre-push
   ```

3. **Push to the remote:**
   ```
   git push origin <handle>/my-fix-branch
   ```

4. **If pre-commit hooks fire and block the commit or push:**
   - Read the hook output carefully. Identify every distinct issue reported.
   - Common categories:
     - **Linting errors** (ESLint, Ruff, Flake8, etc.): Fix the code. Do not add `// eslint-disable` or `# noqa` unless the rule is genuinely inapplicable and you can articulate why.
     - **Formatting violations** (Prettier, Black, etc.): Run the formatter and stage the result.
     - **Type errors** (TypeScript, mypy, Pyright): Fix the types. Do not cast to `any` or add `# type: ignore` to suppress.
     - **Secret detection** (detect-secrets, gitleaks): Remove the secret from the code. Rotate the credential if it was ever committed. Add the file to `.gitignore` or use environment variables.
     - **File size or binary checks:** Remove the offending file from the commit.
     - **PR size or scope policy checks:** Split the work into smaller, single-issue or stacked PRs. Do not override the limit in this branch unless a maintainer has approved an exception.
     - **Test guards** (if hooks run tests): Re-run Step 6 to capture the failure in `.sdlc/artifacts/test-results.md`, then run Step 7 to fix the underlying code.

5. **After each fix:**
   - Re-stage the corrected files.
   - Re-attempt the commit or push.
   - Repeat until hooks pass cleanly.

6. **Never bypass hooks:**
   - Do not use `--no-verify`.
   - Do not temporarily remove hooks from `.pre-commit-config.yaml` or `.husky/`.
   - If a hook is genuinely broken (e.g., references a removed tool), raise it as a separate issue — do not disable it in this branch.

7. **Confirm the push succeeded:**
   ```
   git log --oneline origin/<handle>/my-fix-branch -5
   ```
   Verify the remote branch contains all expected commits.

## Outputs

- Remote branch updated with latest intended changes
- Hook-related issues resolved

## Guardrails

- Do not bypass hooks unless there is an explicit, justified exception.
- Do not ignore hook failures because CI will catch them later.
- Do not push partial fixes that leave the local branch in an inconsistent state.

## Completion criteria

- All commits are pushed to the remote branch.
- All pre-commit hooks passed without bypass.
- Repository size and scope checks pass locally or have an approved exception.
- No suppression comments (`eslint-disable`, `noqa`, `type: ignore`) were added purely to silence hook failures.
