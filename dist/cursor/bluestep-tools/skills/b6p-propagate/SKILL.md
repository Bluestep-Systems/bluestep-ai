---
name: b6p-propagate
description: Move a change made in one BlueStep org (a sandbox, a template or config org, a sibling) to its target orgs — code, config, and any new fields, option lists, queries or forms — one target at a time, after one plan and one approval per target; or bring components back from a target (refresh). Use when the user wants a change "pushed to production", "promoted", "propagated", "rolled out to the other orgs", or a sandbox brought up to date, in a workspace with `.bluestep/project.json`; `enable` sets that file up.
compatibility: Needs the b6p CLI and its login, and the bluestep-gateway MCP server with the user's own token. A ClickUp connector and a browser the agent drives are optional.
---

# /b6p-propagate — move a change to its target orgs

`/b6p-propagate [task]` moves a change from the project's **source** org to its **targets**, in the
order the project lists them. `/b6p-propagate refresh <component>… [from <target>]` brings
components from a target back to the source. `/b6p-propagate enable` turns the flow on in a
workspace; `/b6p-propagate status` shows what is open and where each change has landed.

Everything here reads the platform, never the workspace's old copies. Nothing is written to any
org without the user's yes on a plan that lists it. The references hold the detail; read each when
its step comes, and do not restate them.

## Steps

```
- [ ] 0. Preflight
- [ ] 1. Orgs confirmed by name (once per session)
- [ ] 2. Collect what to move
- [ ] 3. Per target: match, plan, approve, write, read back, card
- [ ] 4. Report
```

### 0. Preflight

- **Flow on?** Find `.bluestep/project.json` in the session folder or a parent
  (`references/project-config.md`). None → say the flow is off in this workspace and offer
  `enable`. Stop there unless the user says yes.
- **b6p** — `/b6p-push` step 0 (version, login, setup). Run it as written there.
- **Gateway** — the connection check in the `bluestep-reference` skill's
  `conventions/mcp-platform-authoring.md` (step 2). Then `list_org_tools` once for the source and
  for each target: the two platform release lines use different tool names, and an org can move
  between sessions. Use each org's own names for the whole move; on `TOOL_NOT_FOUND`, list again,
  never guess.

### 1. Orgs confirmed by name

Once per session, show the source and every target with their names from `available_tenants`, in
rollout order, and ask the user to confirm them. An org missing from that list is confirmed by its
U-number and one read on it (`references/project-config.md`). A "no" stops the move.

### 2. Collect what to move

`references/plan.md` sections 1–5: the task's claimed log entries (`references/change-log.md`), or
the task card's list on a machine with no log (`references/task-card.md`), or the entries the user
picks; resolve each in the source; walk its dependencies; match each one in every target by FID or
exact name, never by id; name overlapping changes. Leave out what the project, or a target, marks
as not to move, unless the user names it.

### 3. Per target, in order

1. **Plan** — `references/plan.md` section 6, with the config items and their routes from
   `references/config-matrix.md`: what is created (in dependency order), wired, changed and
   published, each step in plain words plus its concrete call; what a person must do by hand; each
   created object's "check by hand" list; every write that runs a scheduled formula; the restore
   points (`references/move-report.md`). A delete in the source is moved as a delete, last, with
   its own yes; with no delete tool for that type it is a step for a person.
2. **Approve** — section 7. The plan is the approval echo of `mcp-platform-authoring.md` step 5. The
   first target is approved alone; later targets with the same plan shape may be approved together;
   Publish or Save draft is chosen here. A call not in the approved plan needs its own yes.
3. **Write** — sections 8–9. The org guard holds at every write: the folder's `U######` is this
   target's, every gateway write carries this target's `org` and an `expectedVersion` read in this
   move, every `/gql` write first checks the tab is signed in to this target. Code goes with
   `b6p push --file` from this target's own folder, read as `/b6p-push` steps 4–5.
4. **Read back, update the card** — `references/move-report.md` and `references/task-card.md`:
   read everything back, tick what landed, show the new card text and write it on a yes. Claim the
   target-role log entries this move wrote in that org as `move` (`references/change-log.md`).
5. **On a failure** — section 11: stop this target, say what landed, ask whether to go on with the
   next. A refusal for a missing right names the right.

### 4. Report

`references/move-report.md`: one table per target in plain words, the restore points, what a person
must still do, and the end-of-rollout line. With no task, claim the moved entries as `no-task`
(`references/change-log.md`).

## refresh

`references/plan.md` section 12: per component, pull both copies, back up the source's `draft/`,
mirror the target's code into the source, compare config, and leave the source's schedule,
`disabled`, `runImmediate`, `formulaType` and `legacyPermissions` as they are unless the user says yes to a question
that names the risk. One plan, one approval, the same org guard. Claim the resulting log entries as
`refresh`.

## enable and status

- **enable** — `references/project-config.md` › `enable`: ask for the source and the targets in
  rollout order, confirm them by name, ask for the task list, write `.bluestep/project.json`, and
  on a yes add the one line to the project's own rules in `AGENTS.md`.
- **status** — read `.bluestep/changes.jsonl` and, when a task is named, its card: open entries by
  component, and per target what has landed. Read only.

## What this skill must NOT do

- Do NOT write to any org without the user's yes on a plan that lists the write.
- Do NOT use `b6p deploy`, a push URL from another org, or `/b6p-push`'s `--root` fallback
  (the `bluestep-reference` skill's `gotchas/cross-org-push.md`).
- Do NOT carry an id from one org into a call on another; match by FID or exact name.
- Do NOT open the platform's web script editor during a move: it writes the draft by itself.
- Do NOT turn a scheduled formula's `runImmediate` on or off unless that is an approved difference.
- Do NOT block, delay or question work outside a move: changes made straight in a target, work
  with no task and workspaces without `.bluestep/project.json` are the user's business.
