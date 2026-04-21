# Step 10 — Semantic Diff Report

**Mode:** Automated
**Objective:** Create a reviewer-facing semantic diff report for the branch against `main` that explains the purpose and justification of changes in coherent engineering terms.

## Inputs

- Current feature branch diff against `main`
- Full changed file set
- Repository context needed to understand intent
- Canonical output directory: `.sdlc/reports/`

## Prerequisites

- The implementation and review-driven changes are present on the branch.
- The branch can be compared cleanly against `main`.

## Task description

Create a reviewer-facing semantic diff report for this branch against `main`.

Do not explain the diff line-by-line, and do not assume every change is necessary.

Instead, group the diff into **semantic blocks**, where each block represents one coherent engineering purpose. A block may span multiple hunks or multiple files if they serve the same objective. If a block mixes multiple intentions, split it.

## For each semantic block, produce:

### Block title

### Affected file(s)

### Objective
What problem this block appears intended to solve.

### Why this change exists
Why the author likely made this change — what bug, requirement, operational need, refactor motive, or design constraint it addresses.

### Justification audit
For each meaningful edit in the block, explain how it supports the objective. Label each edit as one of:
- **Strongly justified**
- **Probably justified**
- **Weakly justified**
- **Unclear / possibly superfluous**

Explicitly call out edits whose contribution to the objective is weak, incidental, stylistic, or unexplained.

### Behavioral impact
What runtime, API, config, schema, error-handling, or data-flow behavior changes.

### Reviewer scrutiny
What assumptions, invariants, edge cases, or regressions should be verified. Show relevant NEW code only.

## Critical instructions

- Prioritize **WHY** over **WHAT**.
- Treat unexplained edits as potential review findings.
- Trace each meaningful edit back to the block's objective.
- Do not smooth over ambiguity; if the rationale is uncertain, say so explicitly.
- Separate purpose-driven changes from opportunistic cleanup, import churn, formatting-only edits, renames, or unrelated refactors.
- Do not restate obvious syntax changes unless they matter behaviorally.
- Merge related hunks when they clearly serve one purpose.

## Presentation

Render the output as a self-contained HTML report that mimics the readability of GitHub's split diff as closely as practical:

- Dark GitHub-like theme.
- One section/card per semantic block.
- Two-column layout:
  - Left column: explanation, why, and justification audit.
  - Right column: syntax-highlighted **NEW code only**.
- Show file paths prominently.
- Visually highlight weakly justified or unclear edits.

## End the report with:

- Overall PR objective.
- Potentially superfluous changes.
- Changes that need author explanation.
- Missing or weak test coverage.
- Reviewer questions.

## Output

Write the result to: `.sdlc/reports/semantic_diff_report_<ticket-id>.html`

## Guardrails

- Do not produce a line-by-line walkthrough.
- Do not present all edits as justified by default.
- Do not include old code in the code column.
- Do not hide weak rationale behind generic wording.

## Completion criteria

- `.sdlc/reports/semantic_diff_report_<ticket-id>.html` exists and provides a structured, reviewer-usable semantic explanation of the branch diff against `main`.
