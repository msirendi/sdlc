# Step 2 — Review Ticket and Develop Technical Spec

**Mode:** Automated
**Objective:** Convert the product intent captured in Linear into an explicit implementation plan with sufficient technical detail to guide coding, testing, and review.

## Inputs

- Linear issue (e.g. `AI-441`)
- Linked context: description, acceptance criteria, design notes, comments, attachments, related tickets
- Current codebase and architecture context
- Canonical output file: `.sdlc/artifacts/technical-spec.md`

## Prerequisites

- The correct branch and worktree are prepared (Step 1).
- Access to Linear and any linked artifacts is available.

## Procedure

1. **Read the ticket thoroughly.** Extract:
   - The user-facing goal or product requirement.
   - Acceptance criteria (explicit and implied).
   - Linked tickets, dependencies, or prior art.
   - Any constraints mentioned by product, design, or other engineers.
   - Whether the work needs to be split into smaller PRs to stay within repository size limits.

2. **Investigate the existing codebase.** Before designing anything:
   - Trace the relevant code paths that will be touched.
   - Identify the data models, services, API routes, and utilities involved.
   - Note existing patterns, conventions, and abstractions the codebase already uses for similar work.
   - Read `AGENTS.md` and any architecture docs if they exist to understand repository-specific guardrails.

3. **Produce the technical spec** in `.sdlc/artifacts/technical-spec.md`. The spec must contain:

   ### 3a. Summary
   One paragraph restating the ticket's objective in engineering terms.

   ### 3b. Scope boundary
   - What is in scope (the minimal set of changes that satisfy the acceptance criteria).
   - What is explicitly out of scope and why.

   ### 3c. Design decisions
   For each non-trivial decision:
   - The choice made and the alternatives considered.
   - Why the chosen approach wins on the axes that matter (simplicity, correctness, performance, consistency with existing patterns).

   ### 3d. Change plan
   An ordered list of concrete changes, grouped by file or module:
   - Data model changes (migrations, schema, types).
   - Business logic changes (services, domain functions).
   - API / interface changes (routes, controllers, serializers).
   - Configuration or infrastructure changes.
   - Each item should state *what* changes and *why*, not just *where*.

   ### 3e. Edge cases and failure modes
   - Enumerate known edge cases and how each is handled.
   - Identify failure modes (network, validation, concurrency) and the expected behavior.

   ### 3f. Test strategy
   - Which behaviors require unit tests.
   - Which integration paths require end-to-end coverage.
   - Any fixtures, mocks, or seed data needed.

   This section becomes the input to Step 3 (test authoring), which will turn it
   into committed tests **before** Step 4 implements anything. Be specific
   enough that Step 3 can derive concrete test cases — function/method names,
   expected error types, and edge cases — without inventing details. If the
   strategy is too thin, Step 3 will return BLOCKED and route back here.

4. **Self-review the spec** against the ticket's acceptance criteria. Every criterion must trace to at least one item in the change plan and one item in the test strategy.

## Outputs

- Technical specification for the ticket at `.sdlc/artifacts/technical-spec.md`
- Traceable mapping from ticket intent to implementation plan

## Guardrails

- Do not start implementation from a vague reading of the ticket.
- Do not omit edge cases, operational constraints, or test implications.
- Do not assume product intent where the ticket is explicit.
- Do not smooth over ambiguity; document it as an open question.
- Do not combine multiple unrelated Linear issues into one implementation plan.

## Completion criteria

- A written technical spec exists at `.sdlc/artifacts/technical-spec.md`.
- Every acceptance criterion is traceable to a planned change and a planned test.
- No implementation work has started yet.
