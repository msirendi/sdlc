# Ultra Review — SDLC-2

- **Branch:** `marek/sdlc-2-decouple-tests`
- **Base:** `main`
- **Tip at review time:** `b4906da` (post Step 11 remediation)
- **Reviewer session:** Claude Opus 4.7 acting as Step 12 executor

## Tool note

Step 12's procedure prescribes `claude -p "/ultrareview" --permission-mode acceptEdits`. In this environment `/ultrareview` is not installed — the slash command responds with the verbatim sentinel `/ultrareview isn't available in this environment.` (exit 0). This is the same gap the SDLC-TEST ultra-review recorded under its Finding 3, and it was not remediated on `main` before this branch was cut.

Rather than capture the sentinel as the "review," I performed the equivalent careful-reviewer pass from this orchestrator session over the full `git diff origin/main..HEAD` (42 files, +1,221 / −400) and recorded the findings below in the structure `/ultrareview` would produce. The skill's continued absence is Finding 1 and is triaged as `defer` with the existing follow-up context.

## Findings

### Finding 1 — `/ultrareview` skill is still missing; Step 12 hardcodes it as the sole review mechanism

- **Severity:** Medium (design / operability — pre-existing, not introduced by SDLC-2)
- **File:** `12-ultra-review.md:20-24`
- **Location:** Procedure step 1
  ```
  claude -p "/ultrareview" --permission-mode acceptEdits
  ```
- **Explanation:** This SDLC-2 PR renumbered `11-ultra-review.md` → `12-ultra-review.md` but carried forward the prior issue: on Claude Code installs that ship without `/ultrareview`, the command responds with `/ultrareview isn't available in this environment.` and exits 0. The orchestrator's validator would treat that as a successful step with an empty review, skipping every subsequent finding-triage check. The step documents neither the skill as a prerequisite nor an inline-prompt fallback. This is the direct continuation of the prior ultra-review's Finding 3 and was also noted as an open concern in the SDLC-1 merge.

### Finding 2 — `sdlc_test_results_status` can exit 141 (SIGPIPE) under `set -o pipefail` on large results reports

- **Severity:** Medium (correctness footgun in the newly-introduced loop driver)
- **File:** `orchestrator/lib/test_fix_loop.sh:15-29`
- **Location:** The sed|head pipeline
  ```
  marker=$(sed -n 's/^[[:space:]]*Result:[[:space:]]*//Ip' "$results_file" | head -n 1)
  ```
- **Explanation:** `run-pipeline.sh:2` enables `set -euo pipefail`, and `execute_test_loop` calls `results_status=$(sdlc_test_results_status "$results_file")` inside that shell context. `sed … | head -n 1` causes `sed` to receive SIGPIPE once `head` closes its input. Under `pipefail`, the pipeline exit code is then 141, and `set -e` aborts the orchestrator even though the parse succeeded. I reproduced this locally — with a 500K-line file containing `Result: PASS` on every line, the same pipeline returns exit 141 while correctly setting `marker=PASS`. For the typical small `.sdlc/artifacts/test-results.md` (currently ~1.2 KB), sed finishes before `head` closes, and the bug does not trigger. But on repos whose report includes verbose traces (hundreds of failures, full stacks), the orchestrator would spuriously halt with `set -e`. The fix is to read until the first match without pipes — e.g. `awk '/^[[:space:]]*[Rr]esult:/ { sub(…); print; exit }'`.

### Finding 3 — `06-run-tests.md` documents a two-state `Result:` contract but the parser has three states

- **Severity:** Low (spec/parser drift in the newly-introduced step)
- **File:** `06-run-tests.md:70-72`
- **Location:** The "do not deviate" paragraph under the structured-report format
  ```
  - The first non-blank `Result:` line MUST read either `Result: PASS` or `Result: FAIL`.
  ```
- **Explanation:** `sdlc_test_results_status` returns PASS, FAIL, or UNKNOWN, and the orchestrator treats UNKNOWN as non-pass (loop continues). The step file never mentions UNKNOWN, so an agent reading only the step file cannot predict the orchestrator's behavior on malformed output, and a reader auditing the contract cannot tell whether UNKNOWN is dead code or load-bearing. Add a one-line note: anything that doesn't begin with `PASS` or `FAIL` is treated as UNKNOWN (non-pass) by the test-fix loop.

### Finding 4 — `07-fix-test-failures.md` has no guidance when `test-results.md` is absent, even though `--only 07-…` is the documented escape hatch

- **Severity:** Low (operational gap in the newly-introduced step)
- **File:** `07-fix-test-failures.md:9-21`
- **Location:** Inputs / Prerequisites / Procedure step 1
- **Explanation:** The step assumes `.sdlc/artifacts/test-results.md` exists (it is listed as an input and a prerequisite). But the pipeline integration test `test_pipeline_manifest_includes_fix_step_when_targeted_directly` and the README both advertise `sdlc --only 07-fix-test-failures.md` as the standalone-fix escape hatch. If an operator targets Step 7 on a fresh branch where Step 6 has not yet run, the file does not exist, and the step's procedure gives the agent no instruction for that state. Add a sentence: if the file is missing, return BLOCKED and ask the operator to run Step 6 first.

### Finding 5 — `DEFAULT_RETRIES`/`STEP_RETRY_COUNTS` are named "retries" but function as "max attempts"

- **Severity:** Low (pre-existing naming, not introduced by SDLC-2)
- **File:** `orchestrator/config.sh:23,50-58`, `orchestrator/run-pipeline.sh:256-257`
- **Explanation:** `while [[ "$attempt" -le "$max_retries" ]]; do` with `max_retries=2` gives 2 attempts total, not 1 attempt + 2 retries. The SDLC-2 change touched `STEP_RETRY_COUNTS` (dropped Step 6 from 3→2 and added Step 7=2), which amplifies the confusion because the comment above the array now says "retries" while the loop consumes it as "attempts." This is a pre-existing misnomer. Rename both to `MAX_ATTEMPTS` and `STEP_MAX_ATTEMPTS` for clarity, or adjust the loop bound to `attempt <= max_retries + 1` to match the name. Not an SDLC-2 regression.

### Finding 6 — `STEP_REQUIRED_PATTERNS` validates existence but not freshness, so a stale `test-results.md` silently satisfies Step 6

- **Severity:** Low (systemic design trade-off, not introduced by SDLC-2)
- **File:** `orchestrator/lib/validate.sh:33-48`, `orchestrator/config.sh:76`
- **Explanation:** `validate_step` uses `compgen -G` to check that the required path matches. If Step 6 runs but the agent fails to rewrite `.sdlc/artifacts/test-results.md` (for whatever reason), validation still passes because the file exists from a prior commit, and `execute_test_loop` reads a stale `Result:`. If the stale report says PASS, Step 7 is skipped and the pipeline proceeds on an unverified branch. The SDLC-2 change introduces the first load-bearing file in this class (the 06↔07 loop actively depends on the file's content), so the trade-off is newly observable even though the validator behavior is old. A cheap mitigation would be to require the results file's mtime to be newer than the step's invocation timestamp.

### Finding 7 — `test_sdlc_is_discoverable_on_path` sets environment variables that `env -i` immediately wipes

- **Severity:** Low (test-code cleanliness in the newly-added `bin_wrappers_unit_test.sh`)
- **File:** `tests/bin_wrappers_unit_test.sh:42-44`
- **Location:**
  ```
  resolved=$(PATH="$BIN_DIR:/usr/bin:/bin" HOME="$fake_home" \
    env -i PATH="$BIN_DIR:/usr/bin:/bin" HOME="$fake_home" \
    command -v "$name" || true)
  ```
- **Explanation:** The leading `PATH=… HOME=…` assignments apply only to the `env` process itself, and `env -i` wipes the environment before exec'ing `command`. The outer assignments are dead code. They do not affect correctness but they are misleading — a future reader will read them as load-bearing. Drop them.

## Actions

### Finding 1 — `/ultrareview` skill missing
- **File:** `12-ultra-review.md:20-24`
- **Severity:** Medium
- **Action:** defer
- **Rationale:** Pre-existing gap carried forward by the renumbering, not introduced by SDLC-2; fixing it requires either adding a skill or rewriting the step's procedure, both of which are out of scope for a PR whose theme is "decouple test authoring, execution, and repair." Captured as SDLC follow-up in this action log. The existing workflow (orchestrator records the sentinel-or-review as Step 12 output and the operator triages in `## Actions`) is functional.
- **Follow-up ticket:** SDLC-3 (to be opened) — "Ship `/ultrareview` with the package or add a prompt-based fallback to `12-ultra-review.md`."

### Finding 2 — SIGPIPE in `sdlc_test_results_status`
- **File:** `orchestrator/lib/test_fix_loop.sh:15-29`
- **Severity:** Medium
- **Action:** fix
- **Rationale:** Newly-introduced code in this PR, latent correctness bug that triggers on large reports, easy single-file fix that the existing unit tests in `test_fix_loop_unit_test.sh` pin.
- **Commit SHA:** (see commit below)

### Finding 3 — Spec/parser drift over `Result:` state model
- **File:** `06-run-tests.md:70-72`
- **Severity:** Low
- **Action:** fix
- **Rationale:** Newly-introduced step file; one-line doc addition that makes the parser's UNKNOWN bucket explicit so future readers and agents understand loop behavior.
- **Commit SHA:** (see commit below)

### Finding 4 — Step 7 missing "no results file" guidance
- **File:** `07-fix-test-failures.md:9-21`
- **Severity:** Low
- **Action:** fix
- **Rationale:** Newly-introduced step; the `--only 07-…` escape hatch is tested and documented, so the missing-file case is a real operator-visible gap. Small addition to the Prerequisites and Procedure sections.
- **Commit SHA:** (see commit below)

### Finding 5 — `DEFAULT_RETRIES` naming
- **File:** `orchestrator/config.sh:23,50-58`
- **Severity:** Low
- **Action:** defer
- **Rationale:** Pre-existing misnomer; fixing it is a mechanical rename across `config.sh`, `run-pipeline.sh`, every test referencing `STEP_RETRY_COUNTS`, and any downstream `.sdlc/overrides.sh`. The rename is not thematic to SDLC-2 and would inflate this PR's already-large diff.
- **Follow-up ticket:** SDLC-4 (to be opened) — "Rename `STEP_RETRY_COUNTS` to `STEP_MAX_ATTEMPTS` (or adjust the loop semantics)."

### Finding 6 — `STEP_REQUIRED_PATTERNS` validates existence, not freshness
- **File:** `orchestrator/lib/validate.sh:33-48`
- **Severity:** Low
- **Action:** defer
- **Rationale:** Pre-existing validator behavior, not introduced by SDLC-2. The concrete impact on the test-fix loop is real but requires agent failure to trigger. Adding a freshness check is a semantic change to the validator that affects every step with a required pattern (spec, PR body, semantic report, ultra-review, test results), not just Step 6.
- **Follow-up ticket:** SDLC-5 (to be opened) — "`validate_step` should assert required outputs have an mtime at-or-after the step invocation."

### Finding 7 — Redundant env assignments in `bin_wrappers_unit_test.sh`
- **File:** `tests/bin_wrappers_unit_test.sh:42-44`
- **Severity:** Low
- **Action:** fix
- **Rationale:** Newly-introduced test code; the leading `PATH=… HOME=…` are misleading dead code that a future reader would spend time decoding. Three-line cleanup with no behavior change.
- **Commit SHA:** (see commit below)

## Summary

- 7 findings surfaced.
- 4 fixes applied on this branch (Findings 2, 3, 4, 7). See commit below.
- 3 deferred to follow-up tickets (Findings 1, 5, 6) — all pre-existing / out-of-scope for SDLC-2's "decouple test steps" theme.
- 0 rejected.

Status: READY
