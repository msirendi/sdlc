# Ultra Review — SDLC-3

- **Branch:** `marek/sdlc-3-cli-ux`
- **Base:** `main`
- **Tip at review time:** `ac96888` (post Step 11 remediation)
- **Reviewer session:** Claude Opus 4.7 acting as Step 12 executor

## Tool note

Step 12's procedure prescribes `claude -p "/ultrareview" --permission-mode acceptEdits`. In this environment `/ultrareview` responds with the verbatim sentinel `/ultrareview isn't available in this environment.` and exits 0. This is the same gap that SDLC-2's ultra-review recorded (`Finding 1`) and deferred pending a decision on how the pipeline should behave when a prescribed slash command is unavailable; the branch under review did not address that separate concern and neither does this one.

Rather than capture the sentinel as "the review," I performed the equivalent careful-reviewer pass from this orchestrator session over the full `git diff origin/main..HEAD` (11 files, +748 / −137) and recorded the findings below in the structure `/ultrareview` would produce. Claims are verified empirically where feasible — the stderr-duplication finding below, for example, is confirmed with a minimal shell reproducer before being acted on.

## Findings

### Finding 1 — `/ultrareview` skill still missing; Step 12 hardcodes it as the sole review mechanism

- **Severity:** Medium (design / operability — pre-existing, not introduced by SDLC-3)
- **File:** `12-ultra-review.md:20-24`
- **Location:** Procedure step 1
  ```
  claude -p "/ultrareview" --permission-mode acceptEdits
  ```
- **Explanation:** The SDLC-2 ultra-review flagged this and left it as `defer`; the concern carries unchanged into SDLC-3. On Claude Code installs that ship without `/ultrareview`, the command exits 0 after printing `/ultrareview isn't available in this environment.`. The orchestrator's validator cannot distinguish that sentinel from a real review, so a future automated run could blow past Step 12 with an empty "review" and no triage. The step file documents neither the skill as a prerequisite nor an inline-prompt fallback, and this branch did not widen Step 12's scope to address it (correctly — out of scope for an operator-ergonomics ticket). Carrying the existing defer forward.

### Finding 2 — `exec 2>>"$log_file"` silently duplicates Claude's stderr in the log file and drops it from the operator's terminal

- **Severity:** High (regression introduced by SDLC-3 — confirmed by reproducer)
- **File:** `orchestrator/lib/execute.sh:104`
- **Location:**
  ```bash
  exec 2>>"$log_file"
  # ...
  printf '%s' "$full_prompt" | sdlc_run_with_timeout "$timeout_seconds" \
    claude ... 2> >(tee -a "$log_file" >&2) \
    | tee "$summary_file" \
    | tee -a "$log_file"
  ```
- **Explanation:** The intent of the exec is to keep bash's "Terminated: 15" job-end notice out of the operator's terminal on Ctrl+C. The side effect is broader than intended. After the exec, the subshell's FD 2 points at the step log file, so the `>&2` inside the stderr process substitution `tee -a "$log_file" >&2` now also points at the step log file. That means each line of Claude's stderr is written to the log file **twice** — once via `tee -a "$log_file"` and once via `tee`'s stdout (now redirected to the log file via FD 2). At the same time, Claude's stderr no longer reaches the operator's terminal at all (previously, `>&2` pointed at the parent's stderr). The commit comment on line 102–103 claims "Claude's stderr is still captured explicitly below," which is technically true, but it is captured *twice* and no longer surfaced to the operator.

  Confirmed with a minimal reproducer:
  ```
  (exec 2>>log.txt; (echo stdout; echo stderr >&2) 2> >(tee -a log.txt >&2) | tee summary.txt | tee -a log.txt)
  # stdout on terminal: "stdout" only      ← stderr missing
  # log.txt:             stderr
  #                      stderr            ← duplicated
  #                      stdout
  ```
  The fix is to save the original stderr to FD 3 before the exec and have the process substitution's tee write via `>&3`, so bash's internal job messages still get filed but Claude's stderr is un-duplicated and the terminal copy is restored. Verified with the same reproducer: `exec 3>&2 2>>log.txt` + `tee -a log.txt >&3` produces one stderr line in log.txt and one on the terminal.

### Finding 3 — `print_version`'s `.git` check is wrong inside a git worktree

- **Severity:** Low (correctness on an alternate install layout)
- **File:** `bin/sdlc:90-96`
- **Location:**
  ```bash
  print_version() {
    local sha="unknown"
    if command -v git >/dev/null 2>&1 && [[ -d "$SDLC_HOME/.git" ]]; then
      sha=$(git -C "$SDLC_HOME" rev-parse --short HEAD 2>/dev/null || printf 'unknown')
    fi
    printf 'sdlc (SDLC_HOME=%s, revision=%s)\n' "$SDLC_HOME" "$sha"
  }
  ```
- **Explanation:** In a regular clone `$SDLC_HOME/.git` is a directory, but in a `git worktree add`-created worktree it is a regular file containing `gitdir: /path/to/repo/.git/worktrees/<name>`. The `-d` check short-circuits to false, so operators who install SDLC via worktree see `revision=unknown` despite being in a perfectly valid checkout. A practical hazard because the pipeline itself recommends worktrees for parallel work. The fix is to drop the `-d` predicate entirely and rely on `git -C "$SDLC_HOME" rev-parse --short HEAD` with its own `2>/dev/null || printf unknown` fallback — it already handles the not-a-repo case cleanly.

### Finding 4 — `$SDLC_HOME/README.md` in the `--help` output is literal, not expanded

- **Severity:** Low (UX)
- **File:** `bin/sdlc:29-87`
- **Location:** Inside the `'EOF'`-quoted heredoc of `print_help`, specifically the `SEE ALSO` line:
  ```
  SEE ALSO
    $SDLC_HOME/README.md
  ```
- **Explanation:** The heredoc delimiter `'EOF'` is intentionally single-quoted so the `$PWD` placeholder in the `USAGE` section, and the `.sdlc/` relative paths elsewhere, remain literal-descriptive. However, the `SEE ALSO` footer is meant to give the operator a concrete filesystem path to read next, and printing the literal `$SDLC_HOME/README.md` defeats that — a brand-new operator has no idea what `SDLC_HOME` resolves to until they read the earlier `sdlc --version` section (which they have probably not run yet). The fix is to close the quoted heredoc before SEE ALSO, emit the interpolated path separately, and keep the rest of the docstring unchanged.

### Finding 5 — `handle_interrupt` always logs `SIGINT` even when the trap fires on `SIGTERM`

- **Severity:** Low (cosmetic / log accuracy)
- **File:** `orchestrator/run-pipeline.sh:65-74`
- **Location:**
  ```bash
  handle_interrupt() {
    printf '\n' >&2
    sdlc_log "WARN" "Interrupt received. Terminating current step and exiting..."
    stop_heartbeat
    terminate_current_step
    sdlc_log "WARN" "Pipeline halted by user (SIGINT)."
    exit 130
  }
  trap handle_interrupt INT TERM
  ```
- **Explanation:** The integration test deliberately uses SIGTERM because a non-interactive bash parent installs `SIG_IGN` on SIGINT for its `&`-backgrounded children. With the trap installed on both `INT` and `TERM`, any future code path that kills `sdlc` via `kill PID` (which sends SIGTERM by default) will log `Pipeline halted by user (SIGINT)`, which is false and will confuse post-mortem readers. Either swap the signal name for a signal-agnostic phrase ("Pipeline halted by user (signal)") or distinguish SIGINT from SIGTERM in separate trap installs. I'll apply the signal-agnostic fix — cheapest and still correct.

### Finding 6 — Step subshell inherits the parent's `INT`/`TERM` trap, so `handle_interrupt` runs twice on Ctrl+C

- **Severity:** Low (log noise, no correctness impact)
- **File:** `orchestrator/lib/execute.sh:96-125` (the subshell body)
- **Location:** The `( ... ) &` that runs Claude inherits the `trap handle_interrupt INT TERM` installed at `run-pipeline.sh:76`.
- **Explanation:** When `terminate_current_step` signals the subshell with SIGTERM, the subshell's inherited trap fires `handle_interrupt` a second time. Inside the subshell, `CURRENT_STEP_PID` is empty (it was assigned in the parent after the fork), `STEP_HEARTBEAT_PID` points at the parent's heartbeat PID, and `sdlc_log` writes to the orchestrator log. The duplicate handler is mostly a no-op but it does emit duplicate `Interrupt received` / `Pipeline halted` lines into the orchestrator log, and it may redundantly try to TERM the heartbeat (which the parent has already handled). Fix: reset the trap inside the subshell with `trap - INT TERM` so the default action (terminate with 143 / 130) applies instead of the inherited handler. The parent's `wait` is already tolerant of the exit code (the retry loop only inspects it numerically).

### Finding 7 — Pre-argument scan hijacks any positional value that happens to equal `--help`/`--version`

- **Severity:** Low (theoretical; rejected below)
- **File:** `bin/sdlc:100-111`
- **Location:**
  ```bash
  for arg in "$@"; do
    case "$arg" in
      -h|--help) print_help; exit 0 ;;
      --version) print_version; exit 0 ;;
    esac
  done
  ```
- **Explanation:** This iterates every argument before run-pipeline parses any of them. If a future flag takes a value (`--start-from --help`) or if the operator names a step `--help.md`, the loop would short-circuit into the help screen instead of treating `--help` as a value. Concretely: today's flags that take values are `--start-from STEP` and `--only STEP`, and a step filename cannot start with `--` (the orchestrator's glob is `[0-9][0-9]-*.md`). No real-world invocation triggers the edge case.
- **Triage:** Reject — the surface is fully defended by the step-filename pattern and no flag is documented as accepting `--help` as a value. Recording the logic so a future reviewer does not re-open the same concern.

### Finding 8 — `emit_step_summary_excerpt` misses bolded `**Status: READY**` lines

- **Severity:** Low (agent format drift, not a code bug)
- **File:** `orchestrator/run-pipeline.sh:394-404`
- **Location:**
  ```bash
  status_line=$(grep -E '^[[:space:]]*(5\.[[:space:]]*)?Status:' "$summary_path" | tail -n 1 || true)
  ```
- **Explanation:** The regex requires the literal `Status:` token to start immediately after optional whitespace and an optional `5.`. Some agent responses (visible in this very task file's "Prior Step Context") use `5. **Status: READY**` with markdown emphasis. The system prompt template explicitly prescribes `5. Status: READY or BLOCKED` (plain), so bolded output is a format-contract violation by the agent — widening the regex would silently accept drift rather than push agents back onto the contract.
- **Triage:** Accept as-is. The cost of a missed excerpt is cosmetic (operator sees no one-line summary line; they still have the full summary file). Widening the regex would hide format drift that the Step 10 semantic-diff report can actually catch.

## Actions

| # | File:location | Severity / category | Action | Rationale | Commit |
|---|---|---|---|---|---|
| 1 | `12-ultra-review.md:20-24` | Medium / design (pre-existing) | **Defer** | Slash-command-availability concern is inherited from SDLC-2 and out of scope for an operator-ergonomics PR; the SDLC-2 follow-up context still applies. Follow-up: SDLC-OPS-UR-SKILL (to be filed in the same backlog as the SDLC-2 defer, which has not been scheduled either). | — |
| 2 | `orchestrator/lib/execute.sh:104` | High / regression | **Fix** | Empirically confirmed stderr duplication + terminal silencing; swap in `exec 3>&2 2>>"$log_file"` and route tee's stdout via `>&3`. The intended job-message suppression is preserved (bash's own FD 2 still points at the log file), but Claude's stderr stops getting duplicated and reaches the operator's terminal again. | `32ab573` |
| 3 | `bin/sdlc:92` | Low / correctness | **Fix** | Drop the `[[ -d "$SDLC_HOME/.git" ]]` gate and rely on `git -C "$SDLC_HOME" rev-parse` with its own fallback; that makes `--version` work inside git worktrees without changing regular-clone behavior. | `32ab573` |
| 4 | `bin/sdlc:86` | Low / UX | **Fix** | Close the quoted heredoc before SEE ALSO and print the interpolated `$SDLC_HOME/README.md` path on a separate line so `--help` shows a real filesystem path rather than the literal token. | `32ab573` |
| 5 | `orchestrator/run-pipeline.sh:70` | Low / log accuracy | **Fix** | Change the second WARN line from `Pipeline halted by user (SIGINT).` to `Pipeline halted by user (signal).`; the trap catches both INT and TERM, so a signal-agnostic phrase is both cheapest and honest. | `32ab573` |
| 6 | `orchestrator/lib/execute.sh:97` | Low / log noise | **Fix** | Add `trap - INT TERM` as the first line inside the backgrounded subshell so the inherited handler does not fire a second time. Exit-code propagation is unchanged (parent `wait`s inside `set +e`, and only the numeric code is inspected). | `32ab573` |
| 7 | `bin/sdlc:100-111` | Low / theoretical | **Reject** | No flag in the documented grammar takes `--help` as a value, step filenames are constrained to `[0-9][0-9]-*.md`, so the collision surface is empty; recording the reject so a future reviewer does not re-open it. | — |
| 8 | `orchestrator/run-pipeline.sh:400` | Low / agent drift | **Accept** | The system prompt explicitly prescribes plain `Status:` — widening the regex would silently swallow format-contract violations the semantic-diff report can catch. Missing a bolded Status costs one informational log line, not correctness. | — |
