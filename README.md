# core-tools

Base workflow tooling for AI coding agents, for repos that are **not** BlueStep component
workspaces (those use `bluestep-tools`). One plugin, one install per machine.

## Install

```
/plugin marketplace add Bluestep-Systems/bspecs
/plugin install core-tools@bluestep
```

The plugin is listed in the `bluestep` marketplace. This repo also carries its own
`.claude-plugin/marketplace.json` so a checkout can be added as a marketplace while developing:
`claude plugin marketplace add <path-to-checkout>` then `claude plugin install core-tools@bluestep-ai`.

## What is in it

| Piece | Path | What it is for |
| --- | --- | --- |
| `core` rule set | `lane/core.md` | Layer 1 rules for the model: how to read, when to delegate, session boundaries. One copy, here — a repo's `AGENTS.md` names it rather than copying it in, so it cannot drift per repo. |
| Working habits | `docs/working-habits.md` | One screen of what a **person** does to keep sessions cheap. Read it once. |
| `/repo-setup` | `skills/repo-setup/` | Audits or writes a repo's own setup: a short `AGENTS.md` that names its rule set, the `CLAUDE.md` bridge, and a skill per repo workflow. `--check` reports drift and writes nothing; without it, missing files are created and existing files are never touched. |
| `/task` | `skills/task/` | One living document at `.claude/tasks/<slug>.md` for a small, clearly scoped change. Approval gate before any edit. |
| `/plan` | `skills/plan/` | Requirements, design, tasks in `.claude/specs/<feature>/`, with approval between each. For work that needs design. |
| `measure.py` | `tools/measure.py` | Session-cost measurement over Claude Code transcripts. |

## Not in this version

`/handoff` (writes a task file and tells you to `/clear`) is planned, and waits on the measurement
of the compaction cap; see the `agent-workflow-efficiency` spec in the `code` workspace, task 8.

**No subagents.** 0.1.0 shipped `explorer` and `implementer`; 0.3.0 removed them. Claude Code now
ships `Explore`, `Plan` and `general-purpose`, which do the same jobs, so ours were paying ~145
tokens of listing in every session to duplicate built-ins. `/task` and `/plan` now ask for a
read-only search subagent or a general-purpose one by role, and say what to do when the tool has
neither.

## Rules of the plugin

- Nothing here repeats what the harness already does.
- `lane/core.md` cites the design section for every rule, or marks it *verify*.
- Skills load on demand; the always-on cost of this plugin is its skill and agent listing only.
