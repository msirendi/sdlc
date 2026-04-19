# Semantic Review Actions — SDLC-TEST

Decision log for every edit flagged as `Weakly justified` or
`Unclear / possibly superfluous` in
`.sdlc/reports/semantic_diff_report_SDLC-TEST.html`.

## Block 1 — Codex → Claude runner switch

- `orchestrator/config.sh:20` and `orchestrator/lib/execute.sh:96`
  (`CLAUDE_OUTPUT_FORMAT` env var)
  - Label: `Weakly justified`
  - Action: `fixed`
  - Rationale: Removed `CLAUDE_OUTPUT_FORMAT` from `config.sh` and pinned
    `--output-format text` in `execute.sh` with a comment explaining the
    downstream contract. The summary-capture step unconditionally treats
    `$log_file` as the final assistant message as prose; any other format
    (stream-json, json) would have silently broken Steps 9 and 10. Eliminating
    the knob matches what the code actually supports. Stale reference in
    `tests/execute_integration_test.sh` removed.

## Block 2 — New Step 11 (`/ultrareview`)

- `11-ultra-review.md:41` (commit-format guidance)
  - Label: `Weakly justified`
  - Action: `fixed`
  - Rationale: Replaced the abstract `fix(<scope>): address ultra-review
    findings` with the concrete example `fix(sdlc): address ultra-review
    findings`, matching Step 10's `refactor(auth): address semantic review
    findings` precedent.

## Block 3 — Downstream step renumbering

- README.md numbering updates
  - Label: `Weakly justified` (cross-refs Block 5)
  - Action: Folded into Block 5 remediation below.

## Block 5 — README rewrite

- `README.md` intro sentence
  - Label: `Weakly justified` (stylistic compression of "not just a set of
    markdown prompts" while adding the Claude Code CLI mention)
  - Action: `fixed`
  - Rationale: Restored the original "not just a set of markdown prompts"
    framing and layered the Claude Code CLI mention on top instead of
    replacing. Now content-additive rather than stylistic churn.
- `README.md` `## What the pipeline governs` / list preamble
  - Label: `Weakly justified`
  - Action: `removed`
  - Rationale: Reverted heading to `## What this governs` and restored the
    preamble "The package is designed to govern the full feature lifecycle in
    a target repository:". Kept only the content-driven numbered-list changes
    (step-count 15→16, step 11 row, step 4 `AGENTS.md` annotation was
    stylistic and reverted).
- `README.md` "Steps X through Y are automated" wording
  - Label: `Weakly justified`
  - Action: `fixed`
  - Rationale: Kept the number bump (13→14 auto, 14/15→15/16 manual) but
    restored the original phrasing style.
- `README.md` repository-layout ellipsis and column prose
  - Label: `Weakly justified`
  - Action: `removed`
  - Rationale: Reverted `…` to `...`, "Canonical SDLC step instructions" back
    to "The canonical SDLC step instructions", and other minor reworded
    descriptions that were not driven by content. Kept the `status.sh` row,
    the `tests/` row, and the `effort` addition to the config row.
- `README.md` target-repo contract bullets (hyphens → em-dashes)
  - Label: `Weakly justified`
  - Action: `removed`
  - Rationale: Reverted the bullet separators from em-dashes back to colons
    to match the rest of the README's style. Kept the new
    `.sdlc/artifacts/ultra-review.md` row and the "model, timeout, or
    permission" wording change on `.sdlc/overrides.sh` (reflects real scope
    under Claude).
- `README.md` Quick-start preamble / shell-alias block relocation
  - Label: `Weakly justified`
  - Action: `removed`
  - Rationale: Reverted the `export SDLC_HOME=…` + four-line alias block at
    the top of Quick Start. The aliases were not defined in the pre-branch
    README and relocating them is the stylistic change the report flagged.
    The `sdlc-status()` function example at the end of the status section
    was restored as the single canonical alias example.
- `README.md` governance rules heading
  - Label: `Weakly justified`
  - Action: `removed`
  - Rationale: Reverted `## Governance rules` → `## Governance rules baked
    into this package` and restored the original bullet phrasing; nothing in
    those bullets is driven by the Claude switch.

## Block 6 — Test coverage expansion

- `tests/common_unit_test.sh`
  - Label: `Weakly justified`
  - Action: `justified`
  - Rationale: Added a top-of-file comment explaining that `sdlc_lookup_kv`
    and `sdlc_git_has_non_log_changes` are the foundational helpers every
    other branch-new test module depends on. Pinning their behavior under
    the same invocation is the base on top of which the branch-specific
    argv/validator assertions run — an unnoticed regression here would
    silently break per-step overrides and dirty-tree detection. The scope is
    now explicit in the file itself.

## Block 7 — Branch-name de-personalization

- `01-branch-setup.md`, `07-open-pr.md`, `12-push-and-hooks.md`,
  `14-rebase.md`, `15-merge.md`, `16-cleanup.md`
  (`marek/my-fix-branch` → `name/my-fix-branch`)
  - Label: `Weakly justified`
  - Action: `fixed` (via the `Unclear` item below)
  - Rationale: Addressed jointly with the placeholder-clarity fix below so
    the rename has a clear reader benefit rather than reading as pure churn.
- Same files, placeholder shape of `name/my-fix-branch`
  - Label: `Unclear / possibly superfluous`
  - Action: `fixed`
  - Rationale: Replaced `name/my-fix-branch` with `<handle>/my-fix-branch`
    across all step instructions. The angle brackets unambiguously signal
    "replace this with your handle" and cannot be mistaken for a literal
    command. This is the clearer placeholder the report suggested and makes
    the bundled rename net-positive rather than cosmetic.
