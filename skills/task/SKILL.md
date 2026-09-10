---
name: task
description: Short workflow for a small, clearly scoped change or bug fix. Keeps one living document at .claude/tasks/<slug>.md with goal, files, done-when check, decisions and state, so the next session (or another tool) can pick it up without the transcript. Use for work that does not need design; for a feature, use /plan.
---

# /task — one task, one living document

The lightweight workflow. One markdown file you can review while the work happens, and that a
fresh session can resume from. If the work turns out to need design decisions or touches many
parts of the repo, **STOP and suggest `/plan` instead.**

## Steps

1. **Gather context.** From `$ARGUMENTS` or by asking, get: what needs to change (or the bug),
   expected vs actual behaviour for a bug, and any file or symbol the user already knows about.
   Ask once if the request is ambiguous; do not start reading to guess.

2. **Read scoped, not whole-file.** Grep for the symbols, strings or behaviour named in the
   request; read only the functions around the hits with offset and limit. Over about 300 lines,
   never read a whole file. If a code-intelligence tool is available (go to definition, find
   references), prefer it to grep-then-read. For a broad "where does X happen" question across
   many files, delegate to a read-only search subagent if the tool has one (in Claude Code,
   `Explore`), so the file bulk never enters this context.

3. **Draft the task file.** Copy `${CLAUDE_PLUGIN_ROOT}/skills/task/task.template.md` to
   `.claude/tasks/<slug>.md` (create the folder if missing; `<slug>` is short kebab-case). Fill
   every header line. **Files** lists real paths. **Done when** is a check someone can run, not a
   feeling. **Run** is the exact command. **Can I edit directly?** is one of `yes`, `use a
   worktree`, `review first`; pick from how risky the change is, and say why in one clause.
   Under **State**, write the plan as a short checklist. Keep the whole file under 60 lines.

4. **STOP. Give the user the file path and ask them to approve the approach before you edit
   any code.** Wait for an explicit yes.

5. **Implement.** Touch only the files listed. Tick each checklist item as it lands. When you make
   a choice along the way, write it under **Decisions** with the reason, at the moment you make it.
   If reality diverges from the plan, change the file rather than drifting from it. Run the
   **Run** command; if it fails, say so with the output.

6. **Wrap up.** Update **State** to done / next / blocked. Propose a commit message (title and
   body) from the diff; do not run `git commit` unless the user says so. The task file stays in
   the repo as the record. If the user is about to start something unrelated, say so and offer
   `/clear`.

## With a spec: `/task <feature> <n>`

When `$ARGUMENTS` names a spec in `.claude/specs/<feature>/` and a task number, skip step 1:
the task is the one numbered `<n>` in that spec's `tasks.md`. Read `requirements.md` and
`design.md` once, scoped to what that task needs. Step 3's task file is
`.claude/tasks/<feature>-<n>.md` and its **Done when** comes from the task line and the spec's
Verification. When the task is done and reviewed, tick its box in `tasks.md`. If the task's reads
would fill this session, delegate it to a general-purpose subagent with the same two arguments and
the instruction to implement only that task, then review its summary and diff instead. Where the
tool has no subagents, run it in a fresh session; this file is what makes that possible.

## Resuming

If `.claude/tasks/<slug>.md` already exists for the slug, read it first and continue from
**State**. Do not reopen the previous transcript.
