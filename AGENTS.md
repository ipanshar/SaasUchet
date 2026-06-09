# AGENTS.md

Guidance for coding agents working in `SaasUchet`.

## Scope

- This file is the primary agent instructions file for Codex-style workflows.
- Repository-specific architecture, stack, and product context live in `CLAUDE.md`.
- When both files apply, use `AGENTS.md` for agent workflow rules and `CLAUDE.md` for project implementation details.
- Direct user instructions take priority over repository files.

## Project Context

- Product: business accounting app for the Kazakhstan market.
- Main stacks: Flutter mobile app, Go backend, PostgreSQL.
- UI language: Russian.
- Preserve existing contracts and prefer additive changes.

## Working Rules

1. Do not write tests.
2. Do not run tests.
3. Manual verification is performed by the user.
4. Do not include unrelated or чужие changes in your commit without explicit user approval.
5. If the working tree is already dirty, commit only the files created or changed for the current task.

## Session Completion

After each completed development session:

1. Create a `git commit`.
2. Push the result to `main`.
3. Use a Russian commit message.
4. Keep the commit message concise and no longer than 200 characters.

## Implementation Notes

- Before changing code, read `CLAUDE.md` for architecture and repository conventions.
- Do not introduce new frameworks or large architectural shifts without discussion.
- Avoid breaking mobile-to-backend API compatibility.

## Key Reference

- `CLAUDE.md`: detailed project architecture, API, stack, and constraints.
