# Changelog

## 0.2.0 — 2026-09-10

Adds `/harness`. Run it in a repo with no agent setup and it reads the repo — package scripts,
build files, CI workflows, `.gitignore` — then writes a short `AGENTS.md` that **names** the `core`
rule set instead of copying it, a one-line `CLAUDE.md` bridge, and one skill per workflow that only
matters sometimes (build, release, a debugging recipe).

It is additive and there is no `--force`: a file that exists is never touched, because these files
are meant to be hand-edited afterwards. `/harness --check` writes nothing and reports drift — a
command CI runs that the rules file never mentions, a command in the file that no longer exists, a
missing `AGENTS.md` that leaves Cursor and Codex with no rules at all.

Two cases it deliberately refuses: a populated `CLAUDE.md` with no `AGENTS.md` beside it (writing
one would give the repo two rules files and each tool would read a different one — it offers the
migration instead and only with an explicit yes), and a repo with no build, no tests and no release,
where a generated file would cost every session and teach nothing.

## 0.1.0 — 2026-09-10

First cut. Ships the `core` rule set (`lane/core.md`), the person-facing `docs/working-habits.md`,
`/task` and `/plan`, the `explorer` and `implementer` subagents, and `tools/measure.py`.
No hooks. `/harness` and `/handoff` are not in this version.
