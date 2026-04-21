# Step 4 — Implement the Technical Spec Against the Tests

**Mode:** Automated
**Objective:** Change the codebase so that the behavior defined in the technical specification is fully implemented and the tests committed in Step 3 will pass. Use atomic commits that follow the repository's commit message conventions.

This step is **implementation-only**. It does not run the test suite. Step 6 runs tests; Step 7 fixes any failures.

## Inputs

- Approved technical specification at `.sdlc/artifacts/technical-spec.md`
- Committed tests from Step 3 — these are the executable contract for this step
- Current repository state on the feature branch
- Existing architecture, conventions, and internal abstractions

## Prerequisites

- Step 3 has committed unit and integration tests that encode the spec.
- The implementation plan in the spec is sufficiently specific.
- Dependencies, environment variables, and local tooling needed for development are available.

## Procedure

1. **Read the tests committed by Step 3 first.** They define the public surface area and behavior contract:
   - Function and method signatures the implementation must expose.
   - Module boundaries, file locations, and import paths the tests assume.
   - Expected return shapes, error types, and side effects (DB writes, mock call arguments, persisted state).
   - Edge cases the tests pin down explicitly.
   The tests are the source of truth for what "done" looks like at the code level. The spec gives you the "why," the tests give you the "what."

2. **Follow the spec's change plan sequentially.** Implement each item in the order specified. Do not skip ahead or interleave unrelated changes.
   - Keep the branch scoped so the eventual PR stays within repository limits: 25 files changed, 800 total lines changed, and 400 changed lines in any single file. If the work exceeds those limits, split it into smaller, single-issue PRs.

3. **For each change:**
   - Write the minimal code that satisfies the spec item *and* makes the relevant tests' assertions reachable.
   - Conform to the test contract — match the function names, signatures, error types, and return shapes the tests expect. Do not rename around the tests.
   - Respect existing codebase conventions: naming, file structure, import style, error handling, logging.
   - If the spec calls for a data model change, implement the migration or schema update first, then the code that depends on it.
   - If new utilities or abstractions are needed, prefer extending existing ones over introducing new patterns.

4. **Commit discipline:**
   - Commit after each logically complete unit of work (one spec item, or a tightly coupled group).
   - Use a header-only commit message in the repository format: `<type>(<scope>): <subject>` or `<type>: <subject>` when no scope is needed.
   - Choose a valid type from `build`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `style`, or `test`.
   - Keep the subject imperative, lowercase at the start, and without a trailing period.
   - Keep every line of the commit message at 100 characters or fewer.
   - Example: `feat(auth): add session expiration enforcement`
   - Put extra rationale in the technical spec or PR description when the header alone is not enough.
   - Do not bundle unrelated changes into a single commit.
   - Do not modify the test files committed in Step 3 — they are read-only here. (See "Handle test/spec conflicts" below.)

5. **Handle test/spec conflicts:**
   - If implementation reveals a test that contradicts the spec or appears wrong, **do not edit the test in this step**. The test is the contract.
   - First confirm whether the spec is the bug:
     - If the spec needs revision, update `.sdlc/artifacts/technical-spec.md`, then return BLOCKED so Step 3 can be re-run to regenerate the affected tests.
     - If the test is genuinely wrong but the spec is right, also return BLOCKED with a note pointing at the offending test — Step 3 owns test edits.
   - Do not silently rewrite tests to match a convenient implementation.

6. **Handle other discoveries during implementation:**
   - If the spec is ambiguous on something the tests do not pin down, resolve in the simplest way consistent with the spec's stated objective. Note the decision in the technical spec or PR description.
   - Do not introduce scope beyond what the spec defines without explicit justification.

7. **Avoid premature cleanup:**
   - Do not refactor adjacent code unless the spec calls for it.
   - Do not fix pre-existing linting warnings, formatting issues, or unrelated bugs in the same commits.
   - Opportunistic improvements go in separate PRs tied to their own issue, or are deferred entirely.

8. **Build sanity check after each commit:**
   - Confirm the project still builds, type-checks, and imports cleanly. Build/type errors here will mask real test results in Step 6.
   - **Do not run the test suite, individual tests, or any test-runner command in this step.** Test execution is Step 6's job. Running tests here re-couples writing code with running tests, which is exactly what this pipeline separates.

## Outputs

- Code implementing the technical specification
- Any supporting config, schema, or interface changes required by the implementation
- A buildable, type-clean branch (test results are not assessed here)

## Guardrails

- **Do not run the test suite or any individual test in this step.** Test execution lives in Step 6.
- **Do not modify the test files committed by Step 3.** If they are wrong, return BLOCKED and route to Step 2 (spec) or Step 3 (regenerate tests).
- Do not introduce unrelated cleanup unless it is justified and clearly separable.
- Do not leave partial pathways that satisfy only a subset of the intended behavior.
- Do not defer known correctness issues to later steps if they can be resolved during implementation.

## Completion criteria

- All items in the spec's change plan are implemented.
- The implementation conforms to the function/method signatures and error contracts the Step 3 tests expect.
- Each commit is atomic, well-described, and follows the repository commit message format.
- The project builds and type-checks without errors.
- No test files committed in Step 3 have been modified.
- No out-of-scope changes are mixed in.
