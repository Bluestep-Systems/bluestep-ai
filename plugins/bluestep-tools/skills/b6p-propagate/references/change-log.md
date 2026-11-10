# The change log (read by `/b6p-propagate`, the close-out, and any agent writing an entry by hand)

`.bluestep/changes.jsonl` records every platform write made in the project's orgs. It sits next to
`.bluestep/project.json` (`references/project-config.md`). It has one JSON object per line, in UTF-8
without a BOM, each line ending in a single LF. Lines are only ever appended: never edit, reorder or
delete one. Two sessions writing at once each add whole lines and never touch the other's.

A line is either an **entry** (a write happened) or a **claim** (some entries are dealt with).
A reader skips a line that does not parse, or whose `v` it does not know, and says so.

## Entry (v1)

```json
{"v":1,"kind":"entry","id":"<at>-<4 hex>","at":"<ISO time>","session":"<id>","org":"U######","source":"gateway","tool":"update_script","op":"change","type":"script","objId":"<id or null>","name":"<name or null>","fid":"<FID or null>","role":"source","target":null,"surface":"claude-code"}
```

| Field | Value |
|---|---|
| `v` | `1`. |
| `kind` | `"entry"`. |
| `id` | `at`, a `-`, and 4 random hex characters. Unique within the log. |
| `at` | UTC time in ISO 8601, ending in `Z`. |
| `session` | The Claude Code session id; on other surfaces, the agent's conversation id (below). |
| `org` | `U` plus digits. `null` for a `/gql` write until it is mapped. |
| `host` | Only on `/gql` entries: the origin the tab was on, `https://…`. |
| `source` | Who wrote the line: `b6p`, `gateway`, `gql` (the hook), `agent` (written by hand), `found` (added by the dependency walk). |
| `tool` | The inner gateway tool, `b6p push`, the GraphQL mutation's operation name, or `platform-ui` for a change made in the platform's own screens. |
| `op` | `create`, `change`, `wire`, `delete`, `publish`, `draft`, or `unknown`. |
| `type` | `script`, `form`, `field`, `option_list`, `view`, `record_type`, `mefr`, `folder`, `permission`, or `unknown`. |
| `objId` | The object's id from the call's arguments, or the created id from the response. `null` when not known. |
| `name` | The object's name; for a `b6p` push, the component folder name. |
| `fid` | The FID, when the id or the arguments carry one. |
| `role` | `source` or `target`, from the config. `null` while `org` is `null`. |
| `target` | The target's name from the config when `role` is `target`; else `null`. |
| `surface` | `claude-code`, `cursor`, or `codex`. |

A `role:"target"` entry is either a write a move made there (the move claims it as `move`) or a
change made straight in a target (no claim lists it). The second is allowed and never open work;
the close-out says in one line that the source is behind there.

## Claim (v1)

```json
{"v":1,"kind":"claim","at":"<ISO time>","by":"task:<task id>","entries":["<entry id>","<entry id>"]}
```

`by` is one of:

- `task:<task id>` — the entries belong to that task. Written at close-out, for "now" and "later".
- `not-needed` — the entries never go to the targets.
- `refresh` — the entries came from `/b6p-propagate refresh` and are already in step.
- `no-task` — the entries were moved by `/b6p-propagate` with no task. Written by the move, for
  the entries the user picked, once their first target ran.
- `move` — `role:"target"` entries that a move or a refresh wrote itself: this session's entries
  in that org since the target's plan was approved. Written after each target's read-back, so
  they never read as changes made straight in the target.

The close-out writes `task:` and `not-needed` claims (`bluestep-reference` ›
`conventions/close-out.md`); `/b6p-propagate` writes `refresh`, `no-task` and `move` ones. A claim names entries by `id` and carries no `id` of its own.

## Open work

An entry is open when `role` is `source` and no claim lists its `id`. A `/gql` entry is mapped first:
match its `host` to an org through `available_tenants` (`defaultHost`); if none matches, ask the user.
`/b6p-propagate status` and the close-out read only open entries. Claimed entries never come back as
open work. A `role:"target"` entry that no claim lists is a direct target change: not open work,
but named once at close-out. Whether a claimed entry has reached each target is on the task card, not in the log
(`references/task-card.md`).

## What the hook logs

`change-log.sh` (`PostToolUse`, plus `PostToolUseFailure` for a `b6p` push that exits 1 after going live; Claude Code only) appends one entry for each successful write in an
org listed in the config:

- A gateway `invoke_org_tool` call whose inner tool is not a read (`list_`, `get_`, `describe_`,
  `lookup_`, `read_`, `find_`, `inspector`, `run_`, `trigger_`, `available_` and the older line's
  `graphql_query` are reads). `type` and `op` come from a table of both release lines' write tools; any other write is `unknown`.
- A `b6p … push` through Bash or PowerShell whose `--json` result says `pushed:true`. The org and
  component come from the `--file` or `--root` path (`/` and `\` read the same). `--snapshot` makes
  it `publish`, else `draft`.
- A browser `javascript_tool` script holding a GraphQL `mutation`, with the tab's origin as `host`.

It does **not** log:

- reads, or calls in an org that is not in the config;
- a gateway call whose response is a platform error, or a push that says `pushed:false`;
- a push whose path has no `U######/<ComponentName>` folder in it;
- changes made in the platform UI (the agent writes those by hand, below, when it knows of them);
- `trigger_formula`, which runs a published formula (the run saves it, with no change to its code or
  config, so there is nothing to move);
- anything on Cursor or Codex;
- anything when node is missing or the hook hits an error. It never blocks and never prints.

The dependency walk in `references/plan.md` is the net for what the log misses.

## Writing an entry by hand

Two cases:

- **Cursor, Codex, any surface without the hook:** after each successful platform write in an org
  of the config, append one entry yourself, right after the write. Not on Claude Code for these
  writes: there the hook writes the entry, and a second copy would count twice.
- **A change made in the platform UI, on every surface, Claude Code included:** the user made it,
  or you asked them to (a delete with no tool, a setting only the UI reaches). Once the user says
  it is done and a read confirms it, append one entry with `tool:"platform-ui"`. The hook cannot
  see these, so this line is the only record.

The entry:

- The same shape, with `source:"agent"` and the right `surface`.
- `session`: on Claude Code, the session id; elsewhere an id you make once per conversation,
  `<surface>-<start time in ISO>` (for example `cursor-2026-01-31T09:15:00Z`), and reuse for every
  entry of that conversation.
- `role` and `target` from the config. Fill `objId`, `name` and `fid` from the call and its
  response, or from the read that confirmed a UI change.
- Write the entry only. Claims are written at close-out and by `/b6p-propagate`, never with the entry.
- A wrong line, the hook's or your own, stays in the log. Append the right entry and claim the wrong
  one `not-needed`; never delete or edit it.

Write the line in one command that appends UTF-8 without a BOM. Both one-liners below put the time in
for `@AT@`; pick new hex for the `3f9a` part on each line. Use the workspace's absolute path. Escape
`"` and `\` inside values as JSON requires.

PowerShell (`>>` and `Add-Content` write UTF-16 or a BOM; this does not):

```powershell
$at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); $line = '{"v":1,"kind":"entry","id":"@AT@-3f9a","at":"@AT@","session":"cursor-<start>","org":"U######","source":"agent","tool":"update_script","op":"change","type":"script","objId":"<id>","name":"<name>","fid":null,"role":"source","target":null,"surface":"cursor"}'.Replace('@AT@', $at); [System.IO.File]::AppendAllText('<workspace>\.bluestep\changes.jsonl', $line + "`n", (New-Object System.Text.UTF8Encoding($false)))
```

Bash:

```bash
at=$(date -u +%Y-%m-%dT%H:%M:%SZ); printf '%s\n' '{"v":1,"kind":"entry","id":"@AT@-3f9a","at":"@AT@","session":"codex-<start>","org":"U######","source":"agent","tool":"update_script","op":"change","type":"script","objId":"<id>","name":"<name>","fid":null,"role":"source","target":null,"surface":"codex"}' | sed "s/@AT@/$at/g" >> '<workspace>/.bluestep/changes.jsonl'
```

A `'` inside a value is written `''` in the PowerShell line and `'\''` in the bash line. A claim
uses the same commands with the claim shape.

## Entries found later

The dependency walk (`references/plan.md`) adds what the code uses or calls but the log does not
have: forms, fields, option lists, record types, queries, other components. Each becomes an entry of
the same shape with `source:"found"`, `tool` set to the read that found it, and `op` set to
`unknown` unless the read shows what changed. It is appended like a hand-written entry, and the
plan marks it as found rather than logged.
