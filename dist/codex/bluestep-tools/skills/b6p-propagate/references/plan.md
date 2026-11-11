# The plan (read by `/b6p-propagate` for a propagation and a refresh)

How a move is built and run: what to move, what it depends on, how each artifact is matched in
a target, the plan per target and its approval, the guard at every write, the code path, and the
rollout loop. The config file is in `project-config.md`, the log in `change-log.md`, the card in
`task-card.md`, every config item's read and write route in `config-matrix.md`, and the report
and restore points in `move-report.md`.

## 1. Collect what to move

Take the first of these that applies:

- **A task, and a log here.** The entries claimed for that task (`change-log.md`). Entries with
  `role:"target"` are direct changes in a target: they are never moved.
- **A task, no log here** (another machine, or nothing claimed for it). Parse the card's
  "Propagation list" (`task-card.md`). Each line is one artifact. A ticked line in a target's
  section is already there.
- **No task.** Show the open source entries, grouped by component, with session and date. The
  user picks. There is no card to tick: the plan and the report are the only record. Once the
  first target ran, claim the picked entries as `no-task` (`change-log.md`) so the close-out does
  not offer them again.
- **None of these.** Ask the user for the components.

Then:

- Several entries on one artifact become one item.
- An entry with `org:null` (a `/gql` write) is mapped to an org by its host through
  `available_tenants`. A host that maps to no org is asked about.
- An artifact in the project's or that target's `doNotMove` list (`project-config.md`) is left
  out, unless the user names it.

## 2. Resolve each item in the source

Read each item in the source org. The logged id belongs to the source, so it is valid there; check
that its FID or name still matches the entry.

- **A delete item:** the item's latest entry has `op:"delete"`. It is meant to be gone: check that a
  lookup by exact name (and FID, when it has one) finds nothing in the source. It moves as a delete
  (section 6, "Deletes").
- **Gone from the source** with no delete entry: ask once whether it was deleted on purpose. A yes
  makes it a delete item (append its entry by hand, `change-log.md`); otherwise mark it "gone in
  source" and skip it.
- **Gone means not found by name.** On some release lines a read by id still answers for a deleted
  script. Never take an answer by id as proof that it exists.
- **Type `unknown`:** find the object by reading. If it is still unclear, ask.

## 3. The dependency walk

Changes made by hand in the platform UI are not logged. The walk finds them. Start from every
item, read in the source, and add what each one uses:

- **A script:** the forms, fields, queries and record types it uses (its `declarations/` from the
  fresh source pull, plus the read routes in `config-matrix.md`), and its field access.
- **The code in its `draft/`:**
  - every `runFormula("…")` identifier: the formula with that FID or On-Demand Identifier;
  - every `B.find.mergeReport("…")` FID: that merge report;
  - every import of another component: that component;
  - every endpoint path it calls: the endpoint with that path.
- **A form or field:** the option lists its fields use, and its record type.
- **A query, view or MEFR:** its form and the fields its criteria and columns use.

A delete item is walked the other way: what still uses it in each target (the gateway's "used by"
read, `inspector` where the org serves it, plus a search of the target's pulled code for its name,
FID or identifier). Anything that still uses it stops its delete step in that target, and the plan
names what uses it.

Each new item is added as a `found` entry (shape in `change-log.md`) and, with a task, claimed
with the rest.
Walk until nothing new turns up. A found component is walked in turn only when it is missing in a
target or its code differs there. The plan shows which items came from the log and which were
found.

## 4. Match each item in each target

- **By FID first, then by exact name.** Fields: by `formulaId`, then by name, inside the matched
  form.
- **Never by id.** Two orgs can share an id by chance (the `bluestep-reference` skill's
  `gotchas/cross-org-push.md` and `gotchas/field-ids-not-portable-across-propagation.md`).
- Every item ends in one of these:
  - **already there** (equal in the target): no step; its card line is ticked;
  - **differs**: a change step;
  - **missing**: a create step;
  - **two candidates** by name: ask; never pick one;
  - for a delete item: **present** is a delete step; **not found** is already there, ticked.
- **A target that changed a component on its own** shows as a diff in that target's plan. The user
  decides. Nothing is merged.

## 5. The overlap check

For each component in the move, look for other entries on it that are open (no claim), or claimed
by another task but not yet ticked for this target on its card. If there are any, show whose they
are (task or session), when, and what they did. Moving the code carries both changes. The user
chooses:

- **Move both.** The other entries ride along; the report names them.
- **Wait.** The component stays out of this move, with every step that depends on it. Its card line
  stays `[ ]`.

## 6. Build one plan per target

Read `list_org_tools` for every org in the move first. The two release lines serve different
tools, and an org can change line between two sessions.

**Order of the steps:**

1. option lists
2. record types
3. forms
4. fields
5. queries, views and MEFRs, each created complete
6. scripts
7. wiring and permissions
8. config
9. reference check
10. code
11. deletes, in reverse order: scripts, then queries, views and MEFRs, fields, forms, record types,
    option lists. Code that stopped using an object is published before the object goes.

**Each step has two parts.** One line in plain words, then the concrete call: org, tool,
arguments, and the `expectedVersion` read in this move for a write on an existing object.

- **A query, view or MEFR is created complete**, criteria and display columns included. No tool can
  change those afterwards (`conventions/mcp-platform-authoring.md`, create-time rules).
- **A create with no undo through the gateway** is marked so. Removing it is a step for a person
  in the platform UI.
- **Units, and anything with no tool,** are steps for a person, in their place in the order. Every
  step that depends on one is held back and says what it waits for.
- **Each created object has a "check by hand" list:** the create settings this surface cannot read
  in the source (`config-matrix.md`). With a browser the agent drives, signed in to the source,
  `/gql` reads most of them and the list is shorter.
- **Config:** one line per item: the source value, the target value, and the call. An item that
  cannot be read in an org is a "check by hand" line, never assumed equal. A `/gql`-only item is a
  step only with a driven browser signed in to that org; otherwise it is a "check by hand" line.
  Nothing is skipped silently.
- **Permissions on an older-release org:** `grant_permission`, never `set_permissions` without a
  `mode` (it replaces every permission there).
- **Reference check:** after the creates and the wiring, and before any publish, every reference
  the code uses must resolve in the target: the forms, queries and fields in its declarations,
  each `runFormula` identifier, each `B.find.mergeReport` FID, each component import and each
  endpoint path. A missing one stops the target before the code step.
- **Code:** per component, the files added, changed, and found only in the target (section 9).
- **Scheduled formulas** carry their marks (section 10).
- **Deletes:** through the gateway only where the target's `list_org_tools` serves a delete tool
  for that type. Otherwise a step for a person in the platform UI, with the object's edit link read
  from the target in this move, and the host and name the person checks before deleting. Before a
  script's delete step, pull its target copy and save its `draft/` to the backups folder
  (`move-report.md`): no tool brings a deleted component back. Before a script's delete step, its
  wiring is removed through the gateway (its queries, forms, field access), each removal in the
  plan: a deleted script keeps its links, its objects then refuse to be deleted, and no tool can
  read or remove a link of a script that is gone. After the person says it is done,
  read it back by name (section 2, "Gone means not found by name"). Each delete gets its own yes
  (section 7).
- **Same version by chance:** when an object shows the same `version` in the source and the
  target, `expectedVersion` cannot catch a wrong-org write. The plan says so for that step; the
  org check alone guards it.
- **Restore points and what a person must do** close the plan (`move-report.md`).

**Example** (placeholders only):

```
Plan for <target name> (U<target>), 4 steps
1. Create the option list "<list name>" (no undo through the gateway)
   invoke_org_tool -> org=U<target>, tool=option_list, arguments={ name, items }
   check by hand: folder
2. Add the field "<Form> > <Field>"
   invoke_org_tool -> org=U<target>, tool=batch_fields, arguments={ ... }
   check by hand: <settings from config-matrix.md>
3. Let "<script>" use the new field
   invoke_org_tool -> org=U<target>, tool=script_field_access, arguments={ ... }
4. Publish the code of "<script>" (2 files changed; may run the formula)
   b6p --yes --json push --file "U<target>/<Component>/draft/scripts/app.ts" --snapshot --message "<description>"
You must still: <steps for a person>
Restore points: <from move-report.md>
```

## 7. The approval

- **This plan is the approval echo** (`conventions/mcp-platform-authoring.md`, step 5, "A plan is
  an echo"). One yes covers exactly the calls listed. A call that is not in the plan, a changed
  argument, or another org needs its own yes. Destructive steps (a delete, a `REMOVE`, a `REPLACE`
  of permissions, removing target-only files) each get their own yes.
- **The first target is approved alone.**
- **Later targets** whose plans have the same shape may be approved together, once the first has
  landed. Same shape means the same steps, calls and marks, with only the org, ids and versions
  different. The grouped approval shows the shared steps once, then each target's own ids and
  versions, and names every target it covers. A target whose plan differs is shown apart.
- **Publish or Save draft** is chosen inside the approval, in the plain words of `/b6p-push` step
  3, with the description for the restore point. Overwrite questions from the push are asked as
  `/b6p-push` step 5 says; `--overwrite` never runs without that yes.
- **No yes:** nothing is written to that target.

## 8. The org guard, at every write

Compare U-numbers, never hosts: one org can answer on several hosts, so two orgs are never told
apart by comparing their hosts. A browser tab has no U-number, though: its host is tied to an org
only through a host that org returned in this move (`/gql` writes, below). That check fails safe:
a valid alternate host stops the step and the user signs in on the host named.

- **Every push.** All three must match the step's target org, or the target stops:
  - the folder's `U######` is that org's U-number;
  - b6p's sync record for the folder comes from this move's pull of that org's URL;
  - that URL is the `webDavUrl` that `get_script` returned with `org` set to that org, in this move.
- **Never** `b6p deploy`, a push with another org's URL, or `--root` with another org's URL (the
  `bluestep-reference` skill's `gotchas/cross-org-push.md`).
- **Every gateway write** passes `org` set to the step's target. A write on an existing object also
  passes the `expectedVersion` read from that org in this move, never one from the source or an
  earlier move. A create has no version: its `org` is its only guard, and the plan says so.
- **Every `/gql` write** first checks that the tab is signed in to the step's org: its host must
  be the host of the `webDavUrl` that org returned in this move. Any other host stops the step and
  asks the user to sign in to that org.
- **`CONCURRENT_MODIFICATION`** (the object changed since it was read): stop that target, read
  again, build the plan again, and ask again.
- **`TOOL_NOT_FOUND`** (the org changed release line): read `list_org_tools` again and build the
  plan again. Never guess a tool.

## 9. The code path

Code is the last step, after the wiring, so the target's `declarations/` show the new wiring.

1. **Audit the source folder, then pull it fresh.** When `U<source>/<Component>/` is already here,
   run `/b6p-audit` on it first: a pull keeps a local file that is newer than the platform's, so a
   local edit never published to the source would ride into the target. Name each such file to the
   user, who chooses: publish it to the source first (its own yes), or carry it on purpose, marked
   "not live in the source" in the plan. Never discard a local edit. Then read `get_script` with
   `org` set to the source for its `webDavUrl`, and `b6p --yes --json pull "<webDavUrl>"`. The copy
   lands in `U<source>/<Component>/`.
2. **Audit an existing target folder first.** When `U<target>/<Component>/` is already here, run
   `/b6p-audit` on it. A local edit never pushed, or a platform change missing from the folder,
   stops that target until the user settles it.
3. **Pull the target fresh** the same way, with `org` set to the target. Only a component *created
   on the platform in this move* is pulled twice: the first pull of a just-created component can
   finish without its sync record (the `b6p-push` skill's `references/root-fallback.md`). An
   existing component pulled into a new local folder needs one pull. If a push still answers `Missing metadata`, stop that target. Never use `--root` in a
   move.
4. **Back up the target `draft/`** to `.bluestep/backups/<U>/<Component>/<stamp>/`.
5. **Mirror the source `draft/` into the target `draft/`.** Leave out the legacy `draft/info/`;
   never copy `declarations/`.
6. **Show the diff:** files added, changed, and found only in the target. Target-only files are
   removed only on a yes. Their platform copies then go through the push's own delete question
   (`/b6p-push` step 5, "Kept files").
   Then search the mirrored files, the README included, for the source org's values: its U-number,
   its host, and every id read from the source in this move (topIds, WebDAV numbers), except the
   `__FID_` and `__SID_` forms, which name the same object in every org. List each hit
   by file and line. In code, a hit is a reference that will not resolve in the target: it stops the
   target until the user settles it. In a README or comment it is only misleading: offer to replace
   it with the target value read in this move. Add nothing of your own to the mirrored files (no
   "propagated from" note): the task card and the version history already say where it came from.
7. **Check the org guard** (section 8).
8. **Push** as `/b6p-push` steps 4–5, with the plan's Publish or Save draft choice and description:
   `b6p --yes --json push --file "U<target>/<Component>/draft/scripts/app.ts" [--snapshot --message "<description>"]`.
   Read the result by its step-5 table.

**Do not open the platform's web script editor during a move.** Opening it writes `draft/.build/`
to the draft by itself, and the next pull or push sees a change nobody made.

## 10. Scheduled formulas that run on save

For every scheduled formula the plan writes to, code or config, read its `runImmediate` in that
org (`/gql`, `config-matrix.md`).

- **On:** every save runs the formula: a publish with or without a code change, a config-only
  write, and the save that turns the flag on. Mark each such step "runs the formula once per
  matching record".
- **Cannot be read** (no driven browser): mark each such step "may run the formula".
- **Never turn `runImmediate` on or off**, unless that is itself a difference the user approved.

## 11. The rollout loop

Targets go in the order of `project.json`. A target whose card section is fully ticked is skipped.

For each target: match, overlap check, plan, approval, run the steps, read back and report
(`move-report.md`), then show the card update and write it on yes (`task-card.md`).

- **A refusal or failure stops that target** at that step; nothing after it runs. What already
  landed stays. Report it, then ask whether to go on with the next target.
- **A refusal for a missing right** (this user's token or login lacks it, such as the endpoint
  privilege) names the right. It is never retried another way: no other tool, no `/gql`, no
  different call.
- **Resume** ("move to the rest") reads the card. Fully ticked targets are skipped. In a target
  that stopped half-way, the match finds what already landed as "already there", and the plan
  covers only what is left.

## 12. Refresh

`refresh <component>… [from <target>]` brings one or more components from one named target (the
only one, when there is just one) to the source. The steps are the ones above with the roles
swapped: the target is read, the source is written.

- Pull both fresh, back up the source `draft/`, and mirror target to source.
- Objects the components need that the source lacks are created in the same order.
- Config differences follow the refresh defaults in `config-matrix.md`. `schedule`, `disabled`,
  `runImmediate`, `formulaType` and `legacyPermissions` stay as they are in the source. Each changes only on its own yes,
  to a question that names the risk (for example, a schedule copied in runs the formula in the
  source on that schedule).
- One approval, the push, the read-back; then the resulting entries are claimed as `refresh`
  (`change-log.md`).
