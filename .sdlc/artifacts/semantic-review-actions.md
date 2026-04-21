# Semantic Review Actions — SDLC-2

Decision log for every edit flagged as `Weakly justified` or
`Unclear / possibly superfluous` in
`.sdlc/reports/semantic_diff_report_SDLC-2.html`.

The report's audit-item list contains one `Unclear / possibly superfluous`
entry; the footer sections "Potentially superfluous changes" and "Changes that
need author explanation" surface additional weak/unclear concerns that are
acted on here under the same framework.

## Block 7 — Committed `.sdlc/artifacts/*.md` inflating the diff

- `.sdlc/task.md`, `.sdlc/artifacts/pr-body.md`, `.sdlc/artifacts/test-results.md`
  - Label: `Unclear / possibly superfluous`
  - Action: `justified`
  - Rationale: These artifacts are not opportunistic extras; the orchestrator
    validates their presence via `STEP_REQUIRED_PATTERNS` in
    `orchestrator/config.sh` (lines 71–78 add `test-results.md` to the list),
    and `README.md` documents them as canonical per-repo outputs. Step 6's
    procedure explicitly instructs the agent to commit `test-results.md` so it
    is durable across pipeline iterations, and Step 8 requires `pr-body.md`.
    Gitignoring them would break the pipeline's durability contract across
    runs and would require a broader policy change that is out of scope for
    this ticket. Keeping them committed is load-bearing, not churn.

## Footer item — Paragraph in `02-technical-spec.md` about Step 3

- `02-technical-spec.md:64-68` (Test strategy Step 3 contract paragraph)
  - Label: `Potentially superfluous` (footer bucket)
  - Action: `justified`
  - Rationale: The paragraph is not exhortation; it names the concrete
    downstream consumer contract ("Step 3 will return BLOCKED and route back
    here" if the strategy is too thin) and the specific level of detail Step
    3 needs (function/method names, expected error types, edge cases).
    Removing it would force spec authors to infer Step 3's BLOCKED rule from
    the Step 3 file itself, which is the opposite of "the code must be clear
    to the next reader". Kept as-is.

## Footer item — Step 6 retry budget dropped from 3 to 2

- `orchestrator/config.sh` (`STEP_RETRY_COUNTS` entry for `06-run-tests.md`)
  - Label: `Weakly justified` (author-explanation bucket)
  - Action: `justified`
  - Rationale: Added an explanatory comment above `STEP_RETRY_COUNTS` calling
    out that Step 6 is now a run-only reporter — a failed attempt means the
    agent did not produce a parseable `test-results.md`, not that tests
    failed — and that the new 06↔07 loop (capped at
    `MAX_TEST_FIX_ITERATIONS=3`) already re-runs Step 6 up to three more
    times, so genuine flakes still get multiple shots. The drop from 3 to 2
    is intentional and no longer requires git-blame archaeology to understand.

## Footer item — `UNKNOWN → run fix anyway` policy

- `orchestrator/lib/test_fix_loop.sh` (`sdlc_test_results_status` helper)
  - Label: `Weakly justified` (author-explanation bucket)
  - Action: `justified`
  - Rationale: The existing comment explained why UNKNOWN is treated as a
    non-pass but did not acknowledge the counter-argument the report raised
    (that running Step 7 on a malformed report can mask a Step 6 regression
    as a fix problem). Rewrote the comment to name the trade-off explicitly:
    UNKNOWN almost always means Step 6 is broken, we still invoke Step 7
    anyway because halting would silently let a red branch through to
    open-PR, and the Step 6 bug surfaces via the fix step's logs. The policy
    is unchanged; the rationale is now reviewable at the call site.

## Footer item — No compatibility path for `.sdlc/overrides.sh` with old step numbers

- `templates/overrides-template.sh` (new upgrade note in file header)
  - Label: `Weakly justified` (author-explanation bucket)
  - Action: `fixed`
  - Rationale: The report correctly flagged that operators with existing
    `.sdlc/overrides.sh` files referencing pre-SDLC-2 step filenames (e.g.
    `03-implement.md`, `05-tests.md`, `07-open-pr.md`) would see their
    overrides silently become no-ops because those step files no longer
    exist. Added a dated upgrade note at the top of the overrides template
    that explicitly calls out this behavior and tells operators to diff the
    current step filenames against their overrides. A runtime validator for
    stale override keys was considered but rejected as scope creep — the doc
    note addresses the "silent no-op may confuse operators" concern directly
    without expanding the orchestrator's surface area in this PR.
