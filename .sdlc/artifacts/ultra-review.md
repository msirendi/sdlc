# Ultra Review — SDLC-TEST

- **Branch:** `codex/test-claude-ultra-review-20260419-114154`
- **Base:** `main`
- **Tip at review time:** `1344b2d` (post Step 10 remediation)
- **Reviewer session:** Claude Opus 4.7 acting as Step 11 executor

## Tool note

Step 11's procedure asks for the output of the `claude -p "/ultrareview" --permission-mode acceptEdits` slash command. In this environment `/ultrareview` is not installed: `claude -p "/ultrareview"` returns verbatim `/ultrareview isn't available in this environment.` (exit code 0). Rather than capture that sentinel as the "review," I performed the equivalent careful-reviewer pass from this orchestrator session over the full `git diff main..HEAD` and recorded the findings below in the same structure `/ultrareview` would produce. The missing skill itself is Finding 3 below and is triaged as a deferred follow-up.

## Findings

### Finding 1 — Summary file contains stderr noise, breaking the clean-summary contract

- **Severity:** Medium (correctness / downstream-contract regression)
- **File:** `orchestrator/lib/execute.sh:87-114`
- **Location:** The `run_claude_step` pipeline
  ```
  printf … | sdlc_run_with_timeout … claude … 2>&1 | tee "$log_file"
  …
  cp "$log_file" "$summary_file"
  ```
- **Explanation:** Claude's stdout (the final assistant message) and stderr (framework status, warnings, progress chatter from `--print`) are merged via `2>&1` and teed into `$log_file`. `$summary_file` is then produced by `cp "$log_file" "$summary_file"`, so any stderr line claude emits — for example transport warnings, deprecation notices, or rate-limit info — lands in the summary that downstream Steps 9 and 10 read back as "the final assistant response." On the `main` branch this did not happen because `codex exec --output-last-message "$summary_file"` wrote the clean final message directly; switching to Claude dropped that path and did not replace it. The explanatory comment on line 90 claims the log "contains the final assistant message as prose," but that is only true when claude happens to emit nothing on stderr. The resulting summary can cause the validator's `Status: READY` regex to match a stderr line by accident, or cause Step 09 to include framework noise in the context it seeds to later steps.

### Finding 2 — `CLAUDE_EXTRA_ARGS` example references a nonexistent `--max-turns` flag

- **Severity:** Medium (documentation correctness / copy-paste bomb)
- **Files:**
  - `templates/overrides-template.sh:20` — `CLAUDE_EXTRA_ARGS="--max-turns 40 --max-budget-usd 10.00"`
  - `tests/execute_integration_test.sh:144` — same string used as test fixture
  - `tests/execute_integration_test.sh:151-152` — assertion that `--max-turns 40` is forwarded
- **Explanation:** `claude --help` does not list a `--max-turns` flag (confirmed by `claude --help 2>&1 | grep max-turns` returning empty). `--max-budget-usd` is real, but a user who copies the template example into `.sdlc/overrides.sh` will cause every automated step to exit nonzero with `error: unknown option '--max-turns'` before the claude session even begins. The integration test happens to pass only because the `claude` stub does not validate its argv. This is a real, silent bug — the test matrix thinks it is asserting a valid user-facing capability.

### Finding 3 — Step 11 hard-depends on an `/ultrareview` skill that ships separately from Claude Code

- **Severity:** High (design / operability — pipeline halts on installs without the skill)
- **File:** `11-ultra-review.md:20-24`
- **Explanation:** The procedure's step 1 prescribes `claude -p "/ultrareview" --permission-mode acceptEdits` and treats that as the sole way to generate findings. `/ultrareview` is not a stock slash command: on this environment `claude -p "/ultrareview"` responds with `/ultrareview isn't available in this environment.` and exits 0 — which would bypass the retry loop entirely and hand the orchestrator an empty-review sentinel, not findings. Any operator whose Claude Code install lacks the skill will either get a sentinel review (bad) or will have to manually edit the step (worse). The step does not document the skill as a prerequisite, does not ship the skill alongside the package, and has no inline-prompt fallback.

### Finding 4 — Step 11 required-pattern check is existence-only; does not enforce `## Actions` section

- **Severity:** Low (validation completeness)
- **File:** `orchestrator/config.sh:63`
- **Location:** `"11-ultra-review.md=.sdlc/artifacts/ultra-review.md"` in `STEP_REQUIRED_PATTERNS`
- **Explanation:** The step's Completion criteria state the artifact "must contain the `/ultrareview` findings plus an `## Actions` section," but the validator only checks that the file exists and is nonempty. A step that writes findings without the `## Actions` header would pass validation silently, defeating the triage-decision guarantee.

### Finding 5 — `CLAUDE_EXTRA_ARGS` can silently override orchestrator-pinned flags

- **Severity:** Low (configuration safety)
- **File:** `orchestrator/lib/execute.sh:100` — `${claude_args[@]+"${claude_args[@]}"}` appended after the pinned flags
- **Explanation:** The extra-args array is appended after `--output-format text` and `--permission-mode "$permission_mode"`. If a user sets `CLAUDE_EXTRA_ARGS="--output-format json"` they will get two `--output-format` flags; most CLI parsers take last-wins, which silently breaks the downstream contract the inline comment explicitly warns about (Finding 1 is the consumer of this contract). There is no guard and no documentation of which flags are reserved by the orchestrator.

## Actions

### Finding 1 — Summary file contains stderr noise

- **Action:** Fix
- **Rationale:** Clean summary contract is the load-bearing invariant the Step 10 remediation (pinned `--output-format text`) was already reinforcing; leaving stderr in the summary re-opens the same silent-break class of bug. Change execute.sh so claude's stdout is written to `$summary_file` directly while the combined stream still reaches `$log_file` for debugging. Preserves live-streaming visibility.
- **Commit:** Included in `fix(sdlc): address ultra-review findings`.

### Finding 2 — `CLAUDE_EXTRA_ARGS` example uses nonexistent `--max-turns`

- **Action:** Fix
- **Rationale:** Template examples are copy-pasted verbatim into production overrides; this one currently 100% breaks invocation. Replace with two real claude CLI flags (`--max-budget-usd 10.00 --fallback-model claude-sonnet-4-6`) in both the template and the integration test so the test continues to prove multi-token word-splitting against a string that operators can actually use.
- **Commit:** Included in `fix(sdlc): address ultra-review findings`.

### Finding 3 — Step 11 depends on `/ultrareview` skill that isn't bundled

- **Action:** Defer
- **Rationale:** Two plausible remediations — (a) ship the `/ultrareview` skill as part of this package; (b) rewrite the step to inline an equivalent review prompt that doesn't require the skill. Both exceed a single-commit ultra-review fix and both change the intent of the PR the task description defined ("add a dedicated Step 11 ultra-review stage that captures `/ultrareview` findings"). The Step 11 procedure text, its canonical output filename, and its required-patterns entry should stay as-is for this PR; a follow-up should decide between (a) and (b). Today's run documented the tool substitution transparently in the "Tool note" section above.
- **Follow-up ticket:** `SDLC-FOLLOWUP-ULTRAREVIEW-SKILL` — "Bundle `/ultrareview` skill with the SDLC package, or replace the Step 11 slash-command invocation with an inline review prompt, and document the skill as a prerequisite in README.md."

### Finding 4 — Required-pattern check is existence-only

- **Action:** Reject
- **Rationale:** This is the same validator-enhancement class Step 9's semantic review already flagged (Block 2) and Step 10 consciously left unfixed because `STEP_REQUIRED_PATTERNS` is a file-glob matcher, not a content matcher — extending it to content assertions is a generalised enhancement that affects every step, not a Step 11-specific fix. Reopening would contradict Step 10's documented decision.

### Finding 5 — `CLAUDE_EXTRA_ARGS` can override pinned flags

- **Action:** Reject
- **Rationale:** Users who configure `CLAUDE_EXTRA_ARGS` are accepting responsibility for the resulting argv. Adding a reserved-flag check or a deny-list would couple `CLAUDE_EXTRA_ARGS` parsing to the orchestrator's pinned-flag list and mushroom the validation surface for a scenario that is opt-in. Finding 1's fix already removes the most damaging downstream consequence (stderr pollution is no longer the silent consumer of the output-format contract).
