---
name: plan
description: Start a spec for work that needs design. Writes requirements.md, then design.md, then tasks.md under .claude/specs/<feature>/, with explicit approval between each. Use when the user wants to plan a feature or a change that touches several parts of a repo; for a small scoped change, use /task.
---

# /plan — requirements, design, tasks

A spec lives at `.claude/specs/<feature>/` as three files. Each phase needs explicit approval
before the next. The point is a self-contained spec: it names the files and interfaces involved,
says what is out of scope, and ends with a check that proves the whole thing works. Once it is
approved, implementation runs in fresh sessions with clean context.

## Phase 0 — setup

1. Ask for the **feature name** (kebab-case) and a **one-line description**.
2. If a ticket system MCP is available and the user has a ticket, offer to seed from it. Fetch
   only the description, not the whole thread.
3. Create `.claude/specs/<feature>/`.

## Phase 1 — requirements

1. Copy `${CLAUDE_PLUGIN_ROOT}/skills/plan/templates/requirements.template.md` to
   `.claude/specs/<feature>/requirements.md` and fill it in.
2. **STOP.** Say: "Requirements drafted at `.claude/specs/<feature>/requirements.md`. Review and
   approve before I go on to design." Wait for an explicit yes.

## Phase 2 — design

1. Read the parts of the repo the feature touches, scoped: grep for the symbols and read the
   functions around the hits. For a wide survey, delegate to the `explorer` subagent and use its
   summary. Do not load whole directories into this context.
2. Copy `templates/design.template.md` to `.claude/specs/<feature>/design.md` and fill it in.
   It must name the files and interfaces that change, the approach, how data moves, edge cases,
   and how to roll back.
3. **STOP.** Ask for approval before tasks.

## Phase 3 — tasks

1. Copy `templates/tasks.template.md` to `.claude/specs/<feature>/tasks.md`.
2. Break the work into tasks. Each task: a checkbox, the specific file paths it touches, and is
   small enough to finish in one session. Order them so a task never depends on a later one.
3. Tag a task `[mechanical]` only when it repeats a pattern an earlier task in the same spec has
   already proved, makes no new decisions, and adds nothing new. The first instance of any pattern
   is never mechanical. When in doubt, leave the tag off.
4. Fill **Verification** at the bottom: the end-to-end check for the whole feature.
5. **STOP.** Ask for approval before any implementation.

## After approval

Tell the user to implement one task per session, and to start a fresh session for it. Give the
first task as a copyable line:

```
/task <feature> 1
```

`/task` with a spec name and task number reads that task from `tasks.md` and runs it as one
living document. When a task's reads would otherwise fill the main session, delegate it to the
`implementer` subagent with the spec name and task number; it returns a summary and the main
session reviews the diff and ticks the box.
