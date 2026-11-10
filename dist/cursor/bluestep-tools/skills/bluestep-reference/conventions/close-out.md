---
description: "The close-out of a task in a project with change propagation turned on: when it runs, naming the task, proposing the open change-log entries that belong to it, the one question (now / later / not needed) and what each answer writes, and the one line for changes made straight in a target org. Load at the end of a task in a workspace with .bluestep/project.json, or when the user says platform work in the source org is done."
---

# Close-out: does this change go to the target orgs?

Every task skill points here; none restates it. The config file, the log and the card are described
in the `/b6p-propagate` references, linked below.

## When it runs

- At a task skill's last step: `/quick-task`, `/spec-execute` after a spec's last task,
  `/task-comment`. Or when the user says the work is done.
- Only when both hold:
  - a `.bluestep/project.json` exists in the session's folder or one of its parents
    ([project-config.md](../../b6p-propagate/references/project-config.md));
  - the `.bluestep/changes.jsonl` next to it has open source entries
    ([change-log.md](../../b6p-propagate/references/change-log.md)).
- Otherwise do nothing and say nothing.
- On Cursor and Codex no hook writes the log: the agent appended an entry after each platform write
  itself ([change-log.md](../../b6p-propagate/references/change-log.md)). Those entries count the same.

## 1. Name the task

- Take it from the conversation, or from a `Tracking:` line in the spec or the quick-task doc.
- Say which task you found. The user confirms it, names another, or picks "no task".
- With no task, offer to create one in the project's list. Create it only on a yes
  ([task-card.md](../../b6p-propagate/references/task-card.md)).

## 2. Propose the entries

- A change made in the platform UI during the task (the user did it, or was asked to) has no
  entry unless one was written by hand. Append it first, as
  [change-log.md](../../b6p-propagate/references/change-log.md) › "Writing an entry by hand" says.
- Propose this session's open source entries, plus earlier open source entries on the same
  components.
- List them in plain words: type, name or FID, what was done.
- The user confirms the list, or drops or adds entries. Claim only what the user confirmed; the rest
  stays open.

## 3. Ask once

"Does this change go to the target orgs?" Name the targets from the config.

- **Now** — claim the entries for the task, then hand to `/b6p-propagate <task>`
  ([SKILL.md](../../b6p-propagate/SKILL.md)). With no task, hand the confirmed entries to
  `/b6p-propagate`.
- **Later** — claim the entries for the task. Build the card's "Propagation list"
  ([task-card.md](../../b6p-propagate/references/task-card.md)), show it, and write it on a yes. Set
  the "Propagation" dropdown to Pending. With no task, the entries stay open; say so in one line.
- **Not needed** — claim the entries as `not-needed`. With a task, set the dropdown to Not needed.

Claim shapes are in [change-log.md](../../b6p-propagate/references/change-log.md). A list without
the dropdown field is skipped silently.

## Changes made straight in a target org

Open entries with the target role get no question. One line per target: the source is behind in
`<target name>`, with the components. `/b6p-propagate refresh` brings them back when the user wants.

## Never block or nag

- Ask once. A "no", or no answer, is final for the session: do not ask again or remind later.
- Never hold back a push, a publish or the task skill's own finish for this.
- When `/task-comment` already asked its "other orgs?" question in this session, that was this
  question. Do not ask it twice.
