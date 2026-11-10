# The project config file (read by `/b6p-propagate enable`, and by every step that needs the orgs or the task list)

`.bluestep/project.json` turns the propagation flow on for one workspace. It names the source org,
the target orgs in rollout order, the task list, and what never moves. It holds project values
only; nothing in it is personal, so anyone who opens the workspace uses the same file.

## Where it lives

At the workspace root, next to the `U######/` component folders. The change-log hook and the skill
find it from any subfolder: they start at the session's folder and walk up the parents to the first
`.bluestep/project.json`. The log (`changes.jsonl`, see `references/change-log.md`) sits next to it.

## Shape (v1)

```json
{
  "v": 1,
  "source": { "org": "U######", "name": "<source org name>" },
  "targets": [
    { "org": "U######", "name": "<first target name>", "doNotMove": [] },
    { "org": "U######", "name": "<second target name>", "doNotMove": ["<component>"] }
  ],
  "tracker": {
    "kind": "clickup",
    "listId": "<list id>",
    "listField": "Propagation list",
    "statusField": "Propagation"
  },
  "doNotMove": ["<component>"]
}
```

| Key | Required | What it holds |
|---|---|---|
| `v` | yes | Format version. `1` today. |
| `source.org` | yes | The org changes start in, as `U` plus digits. |
| `source.name` | yes | Its name as the user confirmed it at `enable`. |
| `targets` | yes | One entry per target org, **in rollout order**. A move goes to the first, then the next. One entry is the usual sandbox-to-production case. |
| `targets[].org`, `targets[].name` | yes | Same as `source`. |
| `targets[].doNotMove` | no | Names never moved to that target only. Empty or missing means none. |
| `tracker.kind` | yes | `"clickup"` in v1. |
| `tracker.listId` | yes | The list the project's tasks live in. |
| `tracker.listField` | no | The long-text field that holds the propagation list. Default `"Propagation list"`. |
| `tracker.statusField` | no | The dropdown that mirrors the state. Default `"Propagation"`. |
| `doNotMove` | no | Names never moved to any target. |

A `doNotMove` name is a component folder name (the `<ComponentName>` in `U######/<ComponentName>/`)
or the exact name of another artifact (a form, a query, an option list). A move leaves those out
unless the user names one for that move. The card fields and their text are in
`references/task-card.md`.

## On and off

- **On:** the file exists. Nothing else is installed per project.
- **Off:** delete the file. The hook then exits at its first check, the task skills skip their
  close-out line, and `/b6p-propagate` says the flow is off and offers `enable`. The log can stay as
  history; nothing reads it while the flow is off.
- To add, remove or reorder targets, edit the file, or run `enable` again (it shows the current
  values and asks what to change).

## `enable`

Run by `/b6p-propagate enable`. Each write below is shown first and made on the user's yes.

Ask one thing per question, in this order, with the agent tool's question tool where it has one:
the source, the targets, the task list, what never moves. Offer the likely answers as choices (orgs
from `available_tenants`, "None" for what never moves); never send the four as one list.

1. **Ask for the orgs.** The source, then each target in rollout order. The user may give a name or
   a U-number.
2. **Confirm each org's name.** Call the gateway's `available_tenants` and match each org to its
   `orgKey` and `name`. Show the list of source and targets with their names; the user confirms.
   - An org **not in that list** is not unreachable: the list shows only AI-enabled orgs for this
     token. Ask for its U-number, make one read on it through `invoke_org_tool`, and ask the user for
     its name. A read that answers confirms it. How orgs are resolved is in the `bluestep-reference`
     skill's `conventions/mcp-platform-authoring.md`.
3. **Ask for the task list** (its id) and for anything never to move, for the whole project and per
   target. Leave the field names at their defaults unless the list uses other names.
4. **Write `.bluestep/project.json`.**
5. **Add one line to the project's own rules** in `AGENTS.md`, under its `## Project rules` heading,
   on the user's yes. The line names no org; the values stay in the config file:

   ```markdown
   - This workspace propagates platform changes (`.bluestep/project.json`). Where no hook logs them, append each platform write to `.bluestep/changes.jsonl` as `/b6p-propagate`'s `references/change-log.md` says; when work is done, run the close-out (`bluestep-reference` › `conventions/close-out.md`).
   ```

   Do not touch the rest of `AGENTS.md`. No `## Project rules` heading → add it at the end of the
   file, with the line under it. **No `AGENTS.md` at all** → never write one holding only this line:
   the other skills read a rules file without the template's marker as a project not set up, and
   offer `/b6p-setup` at every push. Offer `/b6p-setup` first (it writes the project files), then
   add the line. If the user says no, write nothing and say that the line is missing, so Cursor and
   Codex agents will not log their writes here.
6. **Git, only if the workspace is a git repo** (a `.git` in the workspace root): add
   `.bluestep/backups/` to the workspace's `.gitignore` if it is not there. When the repo root is a
   parent folder, say which one and ask; on a yes, write `.bluestep/backups/` to a `.gitignore` in
   the workspace root, never to the parent's. Backups are per machine. The config
   and the log are meant to be shared; committing them is the user's call. In a plain folder there
   is nothing to do: never run `git init`, never commit, never assume a remote.
7. **Report** the file written, the rules line, and the `.gitignore` line if any.

## What the flow needs on a machine

Only what the plugin's machine setup installs (versions in `/b6p-setup`'s
`assets/tool-versions.json`), plus two things that belong to each user:

| Needed | Why |
|---|---|
| `b6p` | Pulls and pushes code. |
| Node | The change-log hook runs its logic in node. Without it the hook logs nothing, silently. |
| Git with its bash | Hooks run in bash (Git Bash on Windows). Git itself is not needed by the flow. |
| The user's own `b6p` login | Every pull and push runs as that user. |
| The user's own gateway token (`B6PT_TOKEN`) | Every gateway read and write. Setup: `/b6p-setup`'s `references/platform-token.md`. |

Optional. Each is an extra route when present, never the only one:

- **A ClickUp connector** in the user's agent tool, **or the user's own ClickUp token**. Without
  either, the skill prints the card text for the user to paste. The routes are in
  `references/task-card.md`.
- **A browser the agent drives**, signed in to the org. It reads and writes the settings only
  `/gql` reaches (`bluestep-reference` › `reference/gql-in-a-tab.md`). Without it, those settings
  become "check by hand" lines in the plan.

No personal environment variable, repo-local skill or desktop-only tool is ever required. The hook
runs on Claude Code only; on Cursor and Codex the agent writes the log entries itself
(`references/change-log.md`).
