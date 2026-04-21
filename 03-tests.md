# Step 3 — Author Tests From the Technical Spec (Before Implementation)

**Mode:** Automated
**Objective:** Encode the spec's behavior as committed unit and integration tests *before* any implementation exists. The tests become the executable contract that Step 4 must satisfy.

## Inputs

- Approved technical specification at `.sdlc/artifacts/technical-spec.md`
- Acceptance criteria and test strategy in that spec
- Existing test framework, fixtures, and patterns in the repository

## Prerequisites

- The technical spec exists and is current.
- The implementation has **not** started yet (Step 4 follows this step).
- Test harnesses, fixtures, and a runnable test command exist in the repo, or can be set up here.

## Procedure

### Plan tests directly from the spec

1. **Re-read `.sdlc/artifacts/technical-spec.md`.** For every acceptance criterion and every item in the change plan, derive concrete test cases. Do not look at any prospective implementation — there is none. The spec is the only contract.

2. **Decide the public surface area** the spec implies:
   - New or changed function signatures, module boundaries, or API endpoints.
   - Required inputs, outputs, and error shapes.
   - State transitions, persistence contracts, and event emissions.
   If the spec is ambiguous about a signature or shape, choose the simplest interpretation that satisfies the acceptance criteria and record the choice in a code comment on the test (the implementer must conform to the test, not the other way around). If a choice is genuinely undecidable from the spec, return BLOCKED and ask Step 2 to revise.

### Unit tests

3. **For every function, method, or module entry point** the spec introduces or modifies, write tests covering:
   - **Happy path:** Primary expected input → expected output/behavior.
   - **Boundary values:** Empty inputs, zero/null/undefined, maximum-length strings, off-by-one indices, first/last elements.
   - **Invalid inputs:** Wrong types, missing required fields, malformed data. Assert the failure mode declared in the spec.
   - **State transitions:** Verify before-and-after for each meaningful transition.
   - **Conditional branches:** Every branch the spec describes should be exercised.

4. **Mocking discipline:**
   - Mock external dependencies (DB, network, third-party APIs) — not internal logic.
   - Assert on mock call arguments, not just that the mock was called.
   - Prefer dependency injection over monkey-patching where the codebase supports it.

### Integration tests

5. **For every cross-boundary interaction** in the spec:
   - **Full round-trip:** Request in → processing → persistence → response out. Assert on the response AND the persisted state.
   - **Error propagation:** Simulate downstream failures (DB errors, timeouts, 4xx/5xx). Verify the error surfaces with the right status code, error shape, and no leaked internals.
   - **Concurrency / ordering:** If the spec requires it, test concurrent operations do not corrupt state or deadlock.
   - **Idempotency:** If the operation should be idempotent, call it twice and assert identical outcomes.

### Data setup, naming, and structure

6. **Fixtures and teardown:** Use factories or fixtures, not hand-rolled inline objects. Each test must be independent — no execution-order dependencies.

7. **Naming:** `test_<unit>_<scenario>_<expected_result>`. Group by unit, then by scenario category.

### Verify the tests fail for the right reason

8. **Run the test suite once.** All new tests are expected to be **red** because the implementation does not exist. Confirm they fail with `NotImplementedError`, missing-symbol, or assertion-failed errors that point at the missing implementation — *not* at syntax errors, import errors, or fixture bugs in the tests themselves. A test that errors out before reaching its assertion is not a useful contract.

9. **Commit the tests** in their own commit using the repository's conventional header format:
   ```
   test(<scope>): add tests for <feature>
   ```

## Outputs

- Committed unit and integration tests covering every acceptance criterion in the spec
- Tests are red because the implementation does not exist yet (this is correct)
- Test files are now the executable contract for Step 4

## Guardrails

- **Do not implement any production code in this step.** Only test files, fixtures, and test-only helpers.
- Do not soften, skip, or weaken assertions to make tests pass against a non-existent implementation.
- Do not rely on the spec to be self-evident — if the spec is ambiguous about a signature or behavior, return BLOCKED rather than guess silently. Step 2 owns spec changes.
- Do not add brittle assertions that depend on incidental implementation details unless that detail is contractually important per the spec.
- Do not bundle implementation work into the test commit.

## Completion criteria

- Every acceptance criterion in the spec maps to at least one test.
- Every public interface the spec introduces has unit tests covering happy path, edge cases, and error cases.
- Every cross-boundary integration path has at least one round-trip test and one failure-mode test.
- The test suite runs without crashing on import or fixture errors.
- Failing tests fail by reaching an assertion or detecting missing implementation, not from test-side bugs.
- Tests are committed to the branch.
