# Project Instructions for Codex

## Core Workflow

1. For complex tasks, create a short implementation plan before editing files.
2. For new features and bug fixes, follow TDD:
   - Write or update tests first.
   - Implement the smallest change that passes tests.
   - Refactor only after tests pass.
3. After code changes, review:
   - correctness
   - edge cases
   - security
   - missing tests
   - unnecessary complexity
4. Before finishing, run the relevant verification commands:
   - lint
   - typecheck
   - unit tests
   - integration tests if affected

## Coding Rules

- Prefer small, focused files.
- Keep functions short and readable.
- Validate external input at system boundaries.
- Never hardcode secrets.
- Use environment variables for credentials.
- Do not silently swallow errors.
- Prefer clear names over clever abstractions.

## Git Rules

- Summarize changed files before committing.
- Use conventional commits:
  - feat:
  - fix:
  - refactor:
  - docs:
  - test:
  - chore: