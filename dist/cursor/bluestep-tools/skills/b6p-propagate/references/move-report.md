# The move report (read by `/b6p-propagate` before and after each target of a propagation or refresh)

What the user is told about one target: the restore points before anything is written, then the
read-back and the report after. How the plan is built: `plan.md`. How the card is updated:
`task-card.md`.

## Restore points: named in the plan, before writing

Every plan ends with the restore points for its target. The report repeats them.

- **Backup folder:** per component, `.bluestep/backups/<U>/<Component>/<stamp>/`, a copy of the
  target `draft/` taken before the mirror (`plan.md`, section 9).
- **b6p history:** the newest entry in the component's version history before this move, the one
  to roll back to. A publish in this move adds its own entry, labeled with the description the user
  chose.
- **Before-values of config writes:** for every config write, the item, its value before, and the
  new value. Gateway writes keep no history, so this list is the only record of what was there:
  write it to `.bluestep/backups/<U>/<stamp>-config-before.json` before the first config write of
  that target, so it outlasts the conversation.
- **Created objects:** every object the move creates, with its type and name. A person can remove
  them in the platform UI. The gateway cannot remove most of them.
- **Deleted objects:** every object the move deletes, with its type and name, and for a script the
  backup folder holding its last code (`plan.md`, section 6, "Deletes"). Nothing else brings it
  back; settings and wiring are not in that copy.

## Read back after each target

Read everything back before reporting it as done:

- **Code:** the push's own live check (`/b6p-push` step 5: `liveVerified`, `historyRecorded`), then
  which build is live (the `b6p-push` skill's `references/verify-live-build.md`).
- **Config:** a fresh read of each item in that org, through its read route in `config-matrix.md`. A
  value that does not match the plan did not land.
- **Created objects:** a fresh read of each one. A query or view also gets the completeness
  read-back, and a script its permissions read-back (the `bluestep-reference` skill's
  `conventions/mcp-platform-authoring.md`, step 6).
- **Deleted objects:** a lookup by exact name (and FID) in that org finds nothing. A read by id that
  still answers proves nothing (`plan.md` section 2).

## The per-target report

One report per target, in this order. Leave out an empty section.

1. **Moved:** each artifact that landed: what it is, what was done (created, changed, wired,
   published, saved as a draft).
2. **Already there:** artifacts that were equal in the target.
3. **Created:** each new object, with the id it got in this target. That id is for this report
   only; it is never used in another org.
4. **Not moved:** each artifact left out, with the reason: gone in source, marked not to move,
   waiting on an overlapping change, or held back by a step for a person.
5. **Did not land:** the step that failed, the platform's message in plain words, and, for a
   missing right, the right's name. Nothing after that step ran.
6. **You must still do:** steps for a person (units, anything with no tool), and the "check by
   hand" lines: per created object, the settings this surface could not copy; per config item, the
   ones it could not read or write here (`config-matrix.md`).
7. **Scheduled formulas:** each write that ran a formula, or may have, with the time. Each run
   happens once per matching record. To see what a run did, read the formula's log (`read_log`, which
   needs the `ORG_LOGS` endorsement, or the platform's log viewer).
8. **Restore points:** as named in the plan, with any change from what the plan said.

## The table shown to the user

Open the report with a short table in plain words. Do not use the words "snapshot" or "push" in it.

| Step | What | Result |
|---|---|---|
| 1 | Option list "<list name>" | Created |
| 2 | Field "<Form> > <Field>" | Created; check by hand: <settings> |
| 3 | "<script>" can use the new field | Done |
| 4 | Code of "<script>" | Live; ran the formula once per matching record |
| 5 | Query "<query name>" | Not moved: waits for a unit a person must create |

Result words: **Created**, **Done**, **Live**, **Saved as a draft**, **Already there**,
**Not moved** (with the reason), **Failed** (with the reason), **Waits for you**.

## After the report

- **The card:** tick the lines that landed in this target, add its "check by hand" lines and the
  run date (`task-card.md`). Show the new text first and write it on yes.
- **A target that stopped:** say what landed and what did not, then ask whether to go on with the
  next target (`plan.md`, section 11).
- **At the end of a rollout:** one line per target (done, stopped at step N, skipped, not reached),
  and the "Propagation" dropdown state the card now shows (`task-card.md`).
