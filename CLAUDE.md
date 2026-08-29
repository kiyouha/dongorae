# Project Instructions

## Core rules

- Make the smallest correct change.
- Do not read unrelated files.
- Search before reading large files.
- Do not refactor unrelated code.
- Preserve existing APIs, schemas, and behavior unless explicitly requested.
- Follow existing project patterns before introducing new abstractions.
- Run targeted tests before broad tests.
- Keep tool output concise. Filter large logs before reading them.

## Context loading

Do not read all project documentation at session start.

Read only when needed:

- `.ai/CURRENT.md`: when continuing previous work
- `.ai/ARCHITECTURE.md`: when architecture context is required
- `.ai/DECISIONS.md`: before changing an existing design decision
- `.ai/ROADMAP.md`: when selecting or planning the next major task

Use the relevant Skill only for domain-specific work.

## Session continuity

For existing work:

1. Read `.ai/CURRENT.md`.
2. Run `git status --short`.
3. Run `git diff --stat`.
4. Inspect only files related to the current task.
5. Continue from `Next action`.

Before ending unfinished work, update `.ai/CURRENT.md`.

Do not store long explanations, logs, or code dumps in `.ai/CURRENT.md`.

## Development workflow

Default workflow:

1. Locate relevant code.
2. Understand the smallest affected path.
3. Implement minimal change.
4. Run targeted validation.
5. Fix failures.
6. Update project state only if architecture or task state changed.

Use an Explore subagent only when repository exploration would generate substantial temporary context.
