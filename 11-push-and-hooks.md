# Step 11 — Push Changes and Fix Pre-Commit Hook Issues

**Mode:** Automated
**Objective:** Publish the latest branch state to the remote and resolve any repository-enforced pre-commit or pre-push issues encountered during the process.

## Inputs

- Updated local branch (e.g. `marek/<ticket-id>`)
- Repository hook configuration

## Prerequisites

- Local changes intended for publication are committed.
- The correct remote tracking relationship is configured.

## Procedure

1. **Stage and commit** any remaining uncommitted work. Ensure commit messages follow the project's conventions.

2. **Push to the remote:**
   ```
   git push origin marek/<ticket-id>
   ```

3. **If pre-commit hooks fire and block the commit or push:**
   - Read the hook output carefully. Identify every distinct issue reported.
   - Common categories:
     - **Linting errors** (ESLint, Ruff, Flake8, etc.): Fix the code. Do not add `// eslint-disable` or `# noqa` unless the rule is genuinely inapplicable and you can articulate why.
     - **Formatting violations** (Prettier, Black, etc.): Run the formatter and stage the result.
     - **Type errors** (TypeScript, mypy, Pyright): Fix the types. Do not cast to `any` or add `# type: ignore` to suppress.
     - **Secret detection** (detect-secrets, gitleaks): Remove the secret from the code. Rotate the credential if it was ever committed. Add the file to `.gitignore` or use environment variables.
     - **File size or binary checks:** Remove the offending file from the commit.
     - **Test guards** (if hooks run tests): Fix the failing test per Step 6.

4. **After each fix:**
   - Re-stage the corrected files.
   - Re-attempt the commit or push.
   - Repeat until hooks pass cleanly.

5. **Never bypass hooks:**
   - Do not use `--no-verify`.
   - Do not temporarily remove hooks from `.pre-commit-config.yaml` or `.husky/`.
   - If a hook is genuinely broken (e.g., references a removed tool), raise it as a separate issue — do not disable it in this branch.

6. **Confirm the push succeeded:**
   ```
   git log --oneline origin/marek/<ticket-id> -5
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
- No suppression comments (`eslint-disable`, `noqa`, `type: ignore`) were added purely to silence hook failures.
