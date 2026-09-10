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
| `core` rule set | `lane/core.md` | Layer 1 rules for the model: how to read, when to delegate, session boundaries. A project's `AGENTS.md` carries these; nothing is inherited from parent folders. |
| Working habits | `docs/working-habits.md` | One screen of what a **person** does to keep sessions cheap. Read it once. |
| `/harness` | `skills/harness/` | Writes a repo's own setup: a short `AGENTS.md` that names its rule set, a `CLAUDE.md` bridge, and a skill per repo workflow. Additive — creates what is missing, never touches an existing file; `--check` reports drift. |
| `/task` | `skills/task/` | One living document at `.claude/tasks/<slug>.md` for a small, clearly scoped change. Approval gate before any edit. |
| `/plan` | `skills/plan/` | Requirements, design, tasks in `.claude/specs/<feature>/`, with approval between each. For work that needs design. |
| `explorer` | `agents/explorer.md` | Reads widely, returns a short summary. For "where does X happen" across many files. |
| `implementer` | `agents/implementer.md` | Implements exactly one approved task in its own context and returns a structured summary. |
| `measure.py` | `tools/measure.py` | Session-cost measurement over Claude Code transcripts. |

## Not in this version

`/handoff` (writes a task file and tells you to `/clear`) is planned, and waits on the measurement
of the compaction cap; see the `agent-workflow-efficiency` spec in the `code` workspace, task 8.

## Rules of the plugin

- Nothing here repeats what the harness already does.
- `lane/core.md` cites the design section for every rule, or marks it *verify*.
- Skills load on demand; the always-on cost of this plugin is its skill and agent listing only.
