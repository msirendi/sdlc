Fixes #SDLC-TEST

## Summary
This PR validates the staged SDLC package change that switches the orchestrator from Codex CLI execution to Claude Code CLI execution and introduces a dedicated Step 11 `/ultrareview` stage. It bundles the original staged patch (runner switch, new ultra-review step, step renumbering through Step 14 automated / Steps 15–16 manual, documentation and template updates) together with the test coverage written to exercise those modules and a PIPESTATUS bug uncovered while writing the exit-code propagation test. The work is tracked under Linear `SDLC-TEST` as a disposable validation run against `msirendi/sdlc`.

## Changes
- Orchestrator runner: `orchestrator/lib/execute.sh` invokes `claude --print --model … --effort … --permission-mode … --output-format …` with per-step permission-mode overrides and `CLAUDE_EXTRA_ARGS` passthrough, and the pipeline exit code now reads `PIPESTATUS[1]` (the claude process) instead of `PIPESTATUS[0]` (printf), so real failures and timeouts reach the retry loop.
- Pipeline config: `orchestrator/config.sh` gains Claude-runner defaults and Step 11 entries in `STEP_TIMEOUTS`, `STEP_RETRY_COUNTS`, and `STEP_REQUIRED_PATTERNS`; `orchestrator/run-pipeline.sh` threads the renumbered plan through to Step 14 automated with Steps 15–16 manual.
- Step instructions: adds `11-ultra-review.md` capturing `/ultrareview` findings in `.sdlc/artifacts/ultra-review.md`; renames `11/12/13/14/15 → 12/13/14/15/16` for push-and-hooks, fix-ci, rebase, merge, and cleanup; updates `01-branch-setup.md` and `07-open-pr.md` wording.
- Documentation and templates: rewrites `README.md` for the Claude-based flow and new numbering, removes the stale `orchestrating-ai-agents-sdlc-guide.md`, and updates `templates/overrides-template.sh` to match.
- Tests: adds six new bash test files (`common_unit_test.sh`, `config_unit_test.sh`, `context_unit_test.sh`, `validate_unit_test.sh`, `execute_integration_test.sh`, `pipeline_integration_test.sh`) covering 53 new cases across `sdlc_lookup_kv`, `sdlc_step_mode`, `sdlc_git_has_non_log_changes`, `sdlc_run_with_timeout`, `update_context`, `validate_step`, runner argv and exit-code propagation, and `run-pipeline.sh --dry-run` plan/overrides/filter behavior; registers them in `tests/run.sh`.

## How to test
1. Prerequisites: clone the repo, check out this branch, and ensure `bash`, `git`, and a POSIX `timeout`/`gtimeout` are on PATH. No external services are required and the integration tests stub the `claude` CLI on a per-test PATH, so no Anthropic credentials are needed.
2. Run the full suite: `bash tests/run.sh`.
   Expected: 67 tests pass across 8 files (14 common + 9 config + 4 context + 9 validate + 11 status-unit + 6 execute-integration + 7 pipeline-integration + 7 status-integration), exit 0.
3. Run each new file individually to confirm isolation: `bash tests/common_unit_test.sh && bash tests/config_unit_test.sh && bash tests/context_unit_test.sh && bash tests/validate_unit_test.sh && bash tests/execute_integration_test.sh && bash tests/pipeline_integration_test.sh`.
   Expected: every file exits 0 with TAP-style `ok -` lines and no `not ok`, `FAIL`, or `ERROR`.
4. Exercise the orchestrator plan without executing Claude: inside a fresh git repo, run `bash orchestrator/run-pipeline.sh --dry-run`.
   Expected: the plan prints automated Steps 01→14 and skips Steps 15–16 as manual; `--include-manual` adds them; `--only 11-ultra-review.md` restricts to Step 11; `--start-from 11-ultra-review.md` starts there.
5. Verify the PIPESTATUS fix: `grep -n 'PIPESTATUS\[1\]' orchestrator/lib/execute.sh`.
   Expected: the pipeline exit line references `PIPESTATUS[1]` with the explanatory comment; no reference to `PIPESTATUS[0]` remains on the exit line.

## Risks and considerations
- **PR size exception (documented):** the diff totals 21 files and ~1,455 changed lines, which exceeds the repository's 800-line limit but stays within the 25-file and per-file 400-line limits. The size reflects the scope agreed for this validation PR, which deliberately bundles the staged runner switch with the test coverage written to exercise it; splitting them would leave one side of the pair unvalidated on merge. Reviewers should treat this as a single atomic validation change rather than unrelated work.
- The switch from Codex to Claude changes the runner process, argv shape, and permission model. Anything that shelled out to `codex` directly (outside the orchestrator) or relied on Codex-specific env vars will break; the new integration test asserts the Claude argv but cannot catch callers outside this repo.
- The `PIPESTATUS[0] → PIPESTATUS[1]` fix changes observable behavior: previously every `claude` failure and timeout was silently swallowed and the retry loop was effectively dead. Steps that were "passing" under the old code may now legitimately fail on the first attempt and exercise the retry path — this is the intended behavior but will look like a regression in run logs.
- Step renumbering (11 new, 12–16 shifted) means any downstream automation, dashboards, or docs that reference step numbers by string must be updated in lockstep. Inside this repo all references were swept; external consumers were not.
- The ultra-review artifact (`.sdlc/artifacts/ultra-review.md`) is now a hard required-pattern for Step 11 validation. Runs that complete the step without writing the file will be marked BLOCKED by the validator, which is the intended contract but warrants reviewer attention.
