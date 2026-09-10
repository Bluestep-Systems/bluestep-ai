---
name: harness
description: Generate a repo's own agent setup — a short AGENTS.md that names its rule set, a CLAUDE.md bridge, and a skill per repo-specific workflow (build, test, release). Reads the repo to find its real commands. Additive and idempotent: writes only what is missing, never touches a file that exists, and --check reports drift without writing. Run it in a repo that has no agent setup, or after the repo gains a tool the setup does not mention.
allowed-tools: Read Write Glob Grep AskUserQuestion Bash(ls:*) Bash(basename:*) Bash(mkdir:*) Bash(test:*) Bash(git:*) Bash(wc:*) Bash(head:*) Bash(sed:*) Bash(cat:*)
---

# /harness — write this repo's agent setup

Shared rules can only say what is true of every repo. Everything that is true of *this* repo — the
build command, the test command, how a release goes out, which directory is generated — has to come
from somewhere, and the cheap place is a generated file the repo keeps.

That is what this skill writes: a short always-on rules file that **names its rule set** instead of
repeating it, and one skill per workflow that only matters sometimes.

**It is additive.** A file that does not exist gets created. A file that exists is never touched,
because these files are meant to be hand-edited after generation and overwriting them would destroy
the point of them. `--check` reports what it would write differently and writes nothing.

## Steps

### 1. Read the mode and the target

The target is the **current directory**; `PROJECT_NAME` is `basename "$PWD"`. If `$ARGUMENTS`
contains `--check`, you are in check mode: **write nothing at all**, and produce only the report in
step 6.

### 2. Look at the repo — cheaply

A generator that costs more to run than the file it writes is not worth running. Use the shell for
each of these; do not read a whole file to find one line, and do not open source files at all.

| Looking for | Where |
| --- | --- |
| Commands | `package.json` (`scripts` via `python -c`/`jq`), `build.gradle`, `pom.xml`, `Makefile`, `pyproject.toml`, `Cargo.toml`, `go.mod` |
| The check sequence that actually gates a merge | `.github/workflows/*.yml` — grep for `run:` lines |
| Generated or vendored directories | `.gitignore` |
| Release or deploy path | CI workflow names, a `deploy`/`release` script, a publish step |
| What is already set up | `AGENTS.md`, `CLAUDE.md`, `.claude/skills/`, `.claude/settings.json` |
| Shell quirks worth one line | whether git and `gh` run through a wrapper on this machine (e.g. `wsl git` on Windows), the default branch (`git symbolic-ref refs/remotes/origin/HEAD`) |

Prefer the CI workflow over the script list when they disagree: CI is the sequence that has to pass.

If the repo shows nothing to write about — no build, no tests, no release — say so and stop. A
generated file that says nothing costs every session and teaches nothing.

### 3. Sort what you found before you write it

Three destinations, and the test is when the rule is true:

1. **True every turn, and no hook can check it** → the rules file (step 4). Keep this short. The
   test from the sources is *"would removing this cause a mistake?"*
2. **Only true sometimes** → a skill (step 5). Build commands, release steps, a debugging recipe, a
   migration procedure. This is most of what you found.
3. **A hook could enforce it deterministically** → note it in the report as a hook candidate. Do
   **not** write a hook; this plugin ships none, and a hook nobody verified is worse than a rule.

### 4. Write the rules file — only if the repo has none

Check **both** names before writing either:

- Neither `AGENTS.md` nor `CLAUDE.md` exists → write both. `AGENTS.md` from
  `${CLAUDE_PLUGIN_ROOT}/skills/harness/templates/AGENTS.md.template` (substitute
  `{{PROJECT_NAME}}`, `{{WHAT_THIS_IS}}`, `{{COMMANDS}}`, `{{RULES}}`), and `CLAUDE.md` from
  `templates/CLAUDE.md.template` verbatim — it is a one-line bridge that carries no rules, because
  Claude Code does not read `AGENTS.md` on its own while Cursor and Codex do not read `CLAUDE.md`.
- `AGENTS.md` exists → skip it, and skip `CLAUDE.md` too unless `CLAUDE.md` is missing entirely, in
  which case write the bridge so the existing rules reach Claude Code.
- **`CLAUDE.md` exists with real rules in it and there is no `AGENTS.md` → write neither.** This is
  the case that looks additive and is not: a fresh `AGENTS.md` beside a populated `CLAUDE.md` gives
  the repo two rules files, and each tool reads a different one. Report it, and offer the migration
  — move the content to `AGENTS.md` and leave the bridge behind — **only** with the user's explicit
  yes. If they decline or say nothing, leave both files exactly as they are.
- `CLAUDE.md` exists and is only a bridge (a comment and `@AGENTS.md`) → treat it as present.

Keep the generated file **under 80 lines**. It names its rule set on one line and does not repeat
it: the `core` rule set lives in `lane/core.md` in this plugin, one copy, and a project that copied
it in would be back to the drift problem the pointer exists to avoid.

### 5. Write a skill per workflow — the missing ones only

For each item sorted into "sometimes" in step 3, write
`.claude/skills/<kebab-name>/SKILL.md` from `${CLAUDE_PLUGIN_ROOT}/skills/harness/templates/SKILL.md.template`.

- **Skip any name that already exists** — do not diff it, do not improve it.
- Skip anything the rules file already covers. Two copies of the build command is how one of them
  goes stale.
- One workflow per skill, and a `description` that says when to use it — that line is the only part
  loaded every session, so it is what decides whether the skill ever gets used.
- Name real commands, not paraphrases. If you did not verify a command exists, do not write it.

### 6. Report, then stop

A short table: for every file, `created`, `skipped (exists)`, or — in check mode — `would create`.
Then, in both modes, the drift worth knowing:

- Something the repo has and the setup never mentions (a test framework, a new CI check, a release
  path) → name it and name the file that would carry it.
- A command in the rules file that no longer exists in `package.json` or CI → say which. This skill
  will not fix it; a hand-edited file is the user's.
- Hook candidates from step 3.

In check mode, stop here. In write mode, list what you created and stop — do not also start using
the setup you just wrote.

## What this does not do

- **No hooks, no settings.** `.claude/settings.json` is the user's; permissions and env vars are
  their call, not a generator's.
- **No rewriting.** There is no `--force`. Regenerating over the top would destroy hand edits, and
  marked regions inside the file were rejected in design: markers in a file we want short and
  readable are not worth it.
- **No B6P projects.** A BlueStep component workspace uses `/project-init` from `bluestep-tools`,
  which writes the `b6p` rule set instead. If you find `U######/` folders or a `b6p` config here,
  say so and stop.
