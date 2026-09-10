# bluestep-ai

<!-- core-tools harness-template 1 -->

> Always-on rules for AI coding agents in this repo. Cursor, Codex and most agents read `AGENTS.md`
> natively; Claude Code reads it through the one-line `CLAUDE.md` bridge next to it. Repo rules go
> here, never in `CLAUDE.md`. Anything that is only true sometimes belongs in a skill under
> `.claude/skills/`, not in this file.

**Rule set:** `core`, from the `core-tools` plugin (`lane/core.md`) — which this repo *is*. It
carries how to read, when to delegate to a subagent, and where a session should end. Read it once at
the start of a session that will do real work here; it is not repeated in this file, so that one
copy stays the only copy.

## What this is

The `core-tools` Claude Code plugin: the `core` rule set, `/task`, `/plan`, `/harness`, the
`explorer` and `implementer` subagents, and `tools/measure.py`. It is the non-BlueStep counterpart
to `bluestep-tools` in `Bluestep-Systems/bspecs`.

## Commands

There is no build, no test suite and no CI here — it is markdown and one Python script. Do not
invent an `npm test`. The checks that exist:

- `python tools/measure.py --since <YYYY-MM-DD>` — session cost from local transcripts.
- `claude plugin install core-tools@bluestep` then `--debug` in a scratch repo — the only real check
  that a skill or agent still loads.

## Rules

1. **Teams get this plugin through the `bluestep` marketplace, whose manifest lives in another
   repo** (`Bluestep-Systems/bspecs`, `.claude-plugin/marketplace.json`). Pushing here changes
   nothing for anyone until the version is bumped and they update. See the `release` skill.
2. **`.claude-plugin/marketplace.json` in this repo is development-only** — it exists so a checkout
   can be added as a local marketplace. Never describe it as how the team installs this.
3. **Two `skills/` directories, and they are not the same.** `skills/` at the repo root is what the
   plugin ships. `.claude/skills/` is project-local, for working *in* this repo, and ships to
   nobody.
4. **A skill reads its own files through `${CLAUDE_PLUGIN_ROOT}`**, never a relative path — the
   installed copy lives in a cache directory, not here.
5. **Every rule in `lane/core.md` cites the design section it came from, or is marked *verify*.**
   That is what stops it growing back into a blob; keep it when you edit that file.
6. **No hooks.** The plugin ships none on purpose. Adding one means measuring a reason first.
7. **`docs/working-habits.md` is for people, not the model** — one screen, linked from the README.
   Rules for the model go in `lane/core.md`.

## Compaction

When compacting, always preserve: the paths of every file changed in this session, the exact
commands used to check the work, every open decision with its reason, and the done-when check for
the current task. Drop verbatim tool output and superseded attempts.
