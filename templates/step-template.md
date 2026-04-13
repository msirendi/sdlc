# Step NN — <step name>

**Mode:** Automated
**Objective:** One sentence describing the outcome this step must produce.

## Inputs

- Task file `.sdlc/task.md`
- Relevant prior artifacts in `.sdlc/artifacts/`
- Repository code and configuration

## Prerequisites

- State what must already be true before this step runs.

## Procedure

1. Give the agent concrete actions in execution order.
2. Name exact files, commands, and validation points where possible.
3. If the step creates a durable deliverable, write it to `.sdlc/artifacts/` or `.sdlc/reports/`.

## Outputs

- List the durable files or code changes this step is expected to create.

## Guardrails

- List the explicit things the agent must not do.

## Completion criteria

- State the objective as observable pass/fail checks.
