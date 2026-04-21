# Feature: SDLC-2 Decouple test authoring, test execution, and test-failure repair

## Summary
Restructure the SDLC pipeline so test authoring happens before implementation, test execution is a pure run-only step, and production-code fixes for failing tests happen in a separate orchestrated repair step. The runner should own the loop between test execution and repair, while the step numbering, documentation, validation rules, and automated tests all reflect the new workflow.

## Requirements
- Renumber the pipeline so `03` is tests, `04` is implement, `05` is agents-md-check, `06` is run-tests, `07` is fix-test-failures, and later steps shift to `08` through `17`.
- Rewrite `03-tests.md` so tests are derived from the technical spec only, committed in a red state, and the step returns `BLOCKED` when the spec is ambiguous.
- Rewrite `04-implement.md` so implementation works against the committed tests, allows build/typecheck only, forbids test execution and test edits, and returns `BLOCKED` back to Steps `02` or `03` when required.
- Rewrite `06-run-tests.md` so it only runs tests, writes `.sdlc/artifacts/test-results.md`, emits a parseable first line `Result: PASS|FAIL`, and performs no fixes.
- Add `07-fix-test-failures.md` so it reads `.sdlc/artifacts/test-results.md`, fixes production code only, treats tests as read-only, and does not execute tests.
- Update the orchestrator so Step `06` and Step `07` run in a loop up to `MAX_TEST_FIX_ITERATIONS` (default `3`), with Step `07` removed from the top-level manifest whenever Step `06` is planned.
- Update config validation and defaults for the new step numbers, step-specific timeouts/retries, loop constants, and required artifact patterns for `test-results.md`.
- Update documentation and command wrappers so the new numbering and decoupled test workflow are explained consistently.
- Add automated coverage for the `Result:` parse contract and for manifest filtering that suppresses duplicate top-level execution of Step `07`.

## Technical Constraints
- Preserve the current Bash-based orchestrator architecture and existing wrapper layout under `bin/`.
- Keep the run/fix separation strict: Step `06` must never mutate code to fix failures, and Step `07` must never edit tests or execute the suite.
- The parse contract for `.sdlc/artifacts/test-results.md` must be deterministic and machine-readable from the first `Result:` line.
- Existing cross-references between step files, README instructions, and tests must remain internally consistent after renumbering.
- The manifest filtering must still allow Step `07` to run directly when explicitly targeted without Step `06`.

## Acceptance Criteria
- The repository contains the renumbered step files and all internal references point to the new numbering.
- `03-tests.md`, `04-implement.md`, `06-run-tests.md`, and `07-fix-test-failures.md` enforce the intended guardrails for the decoupled workflow.
- `orchestrator/run-pipeline.sh` drives the `06 -> 07 -> 06` loop, stops after a passing result or `MAX_TEST_FIX_ITERATIONS`, and does not schedule Step `07` twice when Step `06` is planned.
- `orchestrator/config.sh` exposes the updated step settings, loop constants, and required artifact validation for `.sdlc/artifacts/test-results.md`.
- Tests cover the `Result:` parsing contract and the manifest behavior that filters Step `07` when Step `06` is present.
- README, `templates/overrides-template.sh`, and `bin/sdlc` describe and support the updated numbering and workflow.

## Files Likely Affected
- `03-tests.md`
- `04-implement.md`
- `05-agents-md-check.md`
- `06-run-tests.md`
- `07-fix-test-failures.md`
- `08-open-pr.md`
- `09-review-comments.md`
- `10-semantic-diff-report.md`
- `11-address-findings.md`
- `12-ultra-review.md`
- `13-push-and-hooks.md`
- `14-fix-ci.md`
- `15-rebase.md`
- `16-merge.md`
- `17-cleanup.md`
- `orchestrator/config.sh`
- `orchestrator/lib/test_fix_loop.sh`
- `orchestrator/run-pipeline.sh`
- `README.md`
- `templates/overrides-template.sh`
- `bin/sdlc`
- `tests/test_fix_loop_unit_test.sh`
- `tests/pipeline_integration_test.sh`

## Open Questions
- None. The staged change list defines the required behavior and scope.
