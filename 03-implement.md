# Step 3 — Implement the Technical Spec

**Mode:** Automated
**Objective:** Change the codebase so that the behavior defined in the technical specification is fully implemented, with atomic commits that follow the repository's commit message conventions.

## Inputs

- Approved technical specification from Step 2
- Current repository state on the feature branch
- Existing architecture, conventions, and internal abstractions

## Prerequisites

- The implementation plan is sufficiently specific.
- Dependencies, environment variables, and local tooling needed for development are available.

## Procedure

1. **Follow the change plan sequentially.** Implement each item in the order specified by the spec. Do not skip ahead or interleave unrelated changes.
   - Keep the branch scoped so the eventual PR stays within repository limits: 25 files changed, 800 total lines changed, and 400 changed lines in any single file. If the work exceeds those limits, split it into smaller, single-issue PRs.

2. **For each change:**
   - Write the minimal code that satisfies the spec item.
   - Respect existing codebase conventions: naming, file structure, import style, error handling patterns, logging conventions.
   - If the spec calls for a data model change, implement the migration or schema update first, then the code that depends on it.
   - If new utilities or abstractions are needed, prefer extending existing ones over introducing new patterns.

3. **Commit discipline:**
   - Commit after each logically complete unit of work (one spec item, or a tightly coupled group).
   - Use a header-only commit message in the repository format: `<type>(<scope>): <subject>` or `<type>: <subject>` when no scope is needed.
   - Choose a valid type from `build`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `style`, or `test`.
   - Keep the subject imperative, lowercase at the start, and without a trailing period.
   - Keep every line of the commit message at 100 characters or fewer.
   - Example: `feat(auth): add session expiration enforcement`
   - Put extra rationale in the technical spec or PR description when the header alone is not enough.
   - Do not bundle unrelated changes into a single commit.

4. **Handle discoveries during implementation:**
   - If the spec is ambiguous or incomplete, resolve the ambiguity in the simplest way consistent with the spec's stated objective. Note the decision in the technical spec or PR description.
   - If implementation reveals that the spec needs revision (e.g., an assumption was wrong), update the spec first, then implement.
   - Do not introduce scope beyond what the spec defines without explicit justification.

5. **Avoid premature cleanup:**
   - Do not refactor adjacent code unless the spec calls for it.
   - Do not fix pre-existing linting warnings, formatting issues, or unrelated bugs in the same commits.
   - Opportunistic improvements go in separate PRs tied to their own issue, or are deferred entirely.

6. **Verify as you go:**
   - After each commit, confirm the app still builds and the directly affected code path works at a basic level (manual smoke test or running the relevant subset of tests).

## Outputs

- Code implementing the technical specification
- Any supporting config, schema, or interface changes required by the implementation

## Guardrails

- Do not introduce unrelated cleanup unless it is justified and clearly separable.
- Do not leave partial pathways that satisfy only a subset of the intended behavior.
- Do not defer known correctness issues to later steps if they can be resolved during implementation.

## Completion criteria

- All items in the spec's change plan are implemented.
- Each commit is atomic, well-described, and follows the repository commit message format.
- The app builds without errors.
- No out-of-scope changes are mixed in.
