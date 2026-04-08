# Step 4 — Check Against AGENTS.md and Resolve Discrepancies

**Mode:** Automated
**Objective:** Ensure the implementation and working practices comply with repository-specific agent instructions and documented engineering constraints.

## Inputs

- Current implementation on the feature branch
- Repository file `AGENTS.md`

## Prerequisites

- Code changes from the technical spec have been implemented (Step 3).
- `AGENTS.md` is present and readable.

## Procedure

1. **Read `AGENTS.md` in full.** Do not skim. Pay attention to:
   - Required file/folder structure and naming conventions.
   - Mandated patterns (e.g., error handling, logging, dependency injection, config access).
   - Prohibited patterns or anti-patterns explicitly called out.
   - Testing requirements (coverage thresholds, required test types, naming conventions).
   - Documentation requirements (docstrings, inline comments, ADRs).
   - Any style, linting, or formatting mandates beyond what the linter enforces automatically.

2. **Diff your changes against the rules.** For every file you touched:
   - Verify naming (files, functions, variables, classes, DB columns) matches the stated conventions.
   - Verify structural placement (correct directory, correct module boundary).
   - Verify the patterns used (error handling, validation, API response shapes, logging levels) match what `AGENTS.md` prescribes.
   - Check that any new public interfaces have the required documentation.

3. **List every discrepancy.** For each one, note:
   - The rule from `AGENTS.md`.
   - The specific code location that violates it.
   - The fix required.

4. **Resolve each discrepancy.** Apply the fix. If a rule conflicts with the technical spec, prefer the rule unless you have a documented reason to deviate — in which case, note the deviation and rationale in a comment or commit message.

5. **Re-read `AGENTS.md` one more time** after all fixes to confirm nothing was missed.

## Outputs

- Updated implementation and artifacts aligned with `AGENTS.md`
- No known unresolved conflicts between the branch and agent instructions

## Guardrails

- Do not treat `AGENTS.md` as advisory if it contains explicit requirements.
- Do not assume general repository habits override written agent instructions.
- Do not leave known discrepancies for reviewers to discover later.
- No new code should be introduced that is outside the scope of fixing discrepancies.

## Completion criteria

- Zero known violations of `AGENTS.md` remain in the changed files.
- Any intentional deviations are documented with rationale.
