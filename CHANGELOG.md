# Changelog

## 0.3.0 — 2026-09-10

**`/harness` is now `/repo-setup`.** The old name said the wrong thing: "harness" reads as *test
harness* to most developers, and this skill runs nothing — it writes markdown. Worse, `lane/core.md`
already uses "the harness" to mean the tool you are running inside, so one word meant two things in
one plugin. If you had 0.2.0, `/harness` is gone; there is no alias, because a day-old skill with one
install is the cheapest possible moment to rename.

**Its description now says when to call it, not how it works.** That line is the only part loaded in
every session, and it decides whether the skill is ever picked — so it leads with the situations that
should reach for it (a command CI runs that the rules never mention, a stale command, rules that live
only in `CLAUDE.md` so Cursor and Codex see nothing, a repo with no `AGENTS.md`) instead of with the
files it writes. `SKILL.md` opens with **When to run this** and a two-row table of the modes, rather
than two paragraphs of rationale.

**Audited against the [agents.md](https://agents.md) convention, which found two real gaps.** The
template now has droppable **Commit and PR** and **Security** sections — both are recommended there
and neither had a slot. And the skill now sorts rules into **four** destinations instead of three:
anything true of one directory only goes in a nested `AGENTS.md` *in that directory*, because agents
read the nearest file and the closest one wins. In a monorepo that is the difference between a short
root file and a long one, and it costs nothing in sessions that never enter the directory. The skill
also now states plainly that `CLAUDE.md` is a Claude Code bridge and **not** part of that convention.

**The `explorer` and `implementer` subagents are removed.** Claude Code ships `Explore`, `Plan` and
`general-purpose`, which cover the same two jobs, so ours were charging ~145 tokens of listing in
every session to duplicate built-ins. `/task` and `/plan` now ask for a read-only search subagent or
a general-purpose one **by role**, name Claude Code's equivalent in passing, and say what to do where
the tool has no subagents at all — run it in a fresh session, which is what the task file is for.
That keeps the delegation rules in `lane/core.md` working on Codex and Cursor, where they never had
our agents anyway.

Always-on cost of the plugin drops from ~405 to ~260 tokens.

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
