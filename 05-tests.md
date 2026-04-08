# Step 5 — Implement Thorough Unit and Integration Tests

**Mode:** Automated
**Objective:** Add high-value tests that meaningfully validate the behavior introduced by this branch, including edge conditions and integration boundaries.

## Inputs

- Implemented feature changes
- Technical specification and acceptance criteria
- Existing test framework and patterns in the repository

## Prerequisites

- The implementation is stable enough to test.
- Test harnesses and fixtures are available or can be extended.

## Procedure

### Unit tests

1. **Identify every public function, method, or module entry point** introduced or modified by this branch.

2. **For each, write tests covering:**
   - **Happy path:** The primary expected input → expected output/behavior.
   - **Boundary values:** Empty inputs, zero/null/undefined, maximum-length strings, off-by-one indices, first/last elements.
   - **Invalid inputs:** Wrong types, missing required fields, malformed data. Assert that the code fails gracefully with the correct error type and message.
   - **State transitions:** If the function mutates state, verify before-and-after for each meaningful transition.
   - **Conditional branches:** Every `if`/`else`, `switch` case, and guard clause should be exercised by at least one test.

3. **Mocking discipline:**
   - Mock external dependencies (DB, network, third-party APIs) — not internal logic.
   - Assert on mock call arguments, not just that the mock was called.
   - Prefer dependency injection over monkey-patching where the codebase supports it.

### Integration tests

4. **Identify every cross-boundary interaction** introduced or modified:
   - API endpoint → service → data layer round-trips.
   - Inter-service calls or event emissions.
   - Interactions with external systems (queues, caches, file storage).

5. **For each integration path, write tests covering:**
   - **Full round-trip:** Request in → processing → persistence → response out. Assert on the response AND the persisted state.
   - **Error propagation:** Simulate downstream failures (DB errors, timeouts, 4xx/5xx from dependencies). Verify the error surfaces correctly to the caller with the right status code, error shape, and no leaked internals.
   - **Concurrency / ordering:** If relevant, test that concurrent operations do not corrupt state or deadlock.
   - **Idempotency:** If the operation should be idempotent, call it twice with the same input and assert identical outcomes.

6. **Data setup and teardown:**
   - Use factories or fixtures for test data — not hand-rolled inline objects with magic values.
   - Each test must be independent. No test should depend on the execution order or side effects of another test.
   - Clean up any persisted state in teardown, or use transactions that roll back.

7. **Naming and structure:**
   - Test names must describe the scenario and expected outcome: `test_<unit>_<scenario>_<expected_result>`.
   - Group tests by the unit under test, then by scenario category (happy path, error, edge case).

## Outputs

- New or expanded unit tests
- New or expanded integration tests
- Test coverage that directly maps back to the technical spec and acceptance criteria

## Guardrails

- Do not rely only on shallow happy-path tests.
- Do not label a test as integration if it only exercises isolated pure logic.
- Do not skip difficult cases because they are harder to encode.
- Do not add brittle assertions that depend on incidental implementation details unless that detail is contractually important.

## Completion criteria

- Every public interface touched by this branch has unit tests covering happy path, edge cases, and error cases.
- Every cross-boundary integration path has at least one round-trip test and one failure-mode test.
- All new tests pass in isolation and in parallel.
- Test names clearly communicate what is being verified.
