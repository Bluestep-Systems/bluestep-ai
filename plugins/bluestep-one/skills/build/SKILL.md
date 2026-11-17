---
name: build
description: "Build, publish and check a BlueStep One custom component, one gate at a time — fresh types, type check and tests, copies check, required-fields check, push to draft, build over /gql from a signed-in tab, publish only a new sha that built green, served-sha check after a full reload, a measured UX check of the served screen against the project's thresholds, live check on your own test record, and for a UI change the design check against an approved canvas export. With --clone, also looks up, creates or registers the component, then clones and sets up its repo. Needs the Claude desktop app's built-in browser pane for the build, publish and checks. Use when a task changes a component. Usage: /bluestep-one:build <component name or id> [--clone | --no-publish]."
---

# /bluestep-one:build — one component, from commit to a checked screen

The details of each gate are in `${CLAUDE_PLUGIN_ROOT}/skills/reference/build/` (`types.md`,
`typecheck.md`, `publish.md`, `served-check.md`, `ux-check.md`, `design-check.md`). Read the one a
gate names when that gate runs. Gates 5 to 9 run in a tab of the Claude desktop app's built-in
browser pane; without the desktop app, the run stops after gate 4.

## Before anything

Read `.claude/bluestep-one.json` (missing: "run `/bluestep-one:setup` first", stop). Find the
component in `components[]` by name or id; take its `id` and `repo`. A build or publish runs only
on an id there. Work is done in the component repo, under the repo's own `AGENTS.md` where it has
one. Never `b6p push`; never edit `types/`.

With `--clone` on a component already in `components[]`: if its `repo` folder has no checkout,
clone it (`types.md` › *Clone, then register*, steps 1–2; the entry is already there, so write
none); either way, set the checkout up. No lookup and no create.

A component not in `components[]` is not registered yet. Without `--clone`, stop: name it, and say
that `--clone` looks it up and creates or registers it. With `--clone`, follow `types.md` › *A new
component repo*: look it up, register a match the user confirms, provision a row with no repo,
create only a true miss; clone, then register; set the checkout up. Never miss these:

- No create, provision or catalog update before the user's yes in chat, in one sentence.
- No create without a summary, a description and use cases: propose them from the task or ask.
- A found component is shown to the user (name, repo, id) and registered only on their yes.
- A taken-name refusal goes back to the lookup, never to a second create under another name the
  agent picks.
- The entry goes into `.claude/bluestep-one.json` only after the clone and `git checkout draft`
  worked, and never twice for one id.

No tab signed in to `one.host`, no yes, or another refusal: say why in one line and hand over that
file's manual steps.

## The gates

Each is a gate: a failure stops the run there, says which gate and why, and nothing after it runs.

1. **Types.** `node "${CLAUDE_PLUGIN_ROOT}/tools/fetch-types.mjs" --out <shared types folder>`:
   all seven, banner checked (`types.md`). With `--clone`, the component is cloned (and found or
   created and registered when it was not listed) first (*Before anything*), and its checkout set
   up as `types.md` › *A new
   component repo* › *Set up the checkout* says: files are replaced only on the untouched platform
   scaffold, every other file is kept. Then go on.
2. **Type check and tests.** `node "${CLAUDE_PLUGIN_ROOT}/tools/typecheck.mjs" <repo>` exits 0,
   and `node --test` in the repo passes (`typecheck.md`).
3. **Copies.** `node "${CLAUDE_PLUGIN_ROOT}/tools/copies.mjs" <repo>` exits 0, or every changed
   source has been carried over or named as not needed (`typecheck.md`).

   **3b. Required fields.** `node "${CLAUDE_PLUGIN_ROOT}/tools/required.mjs" <repo>` exits 0: a
   component that writes a platform form checks the form's own required fields, through
   `host.formEntries.validate` (directly, or through the form kit's `useFormValidation` and
   `validateAll()`) or the shared `src/data/required.ts` (copied unchanged) with a
   coverage test (`typecheck.md` › *Required-fields check*). For the repo that holds the module's
   source, add `--source <that repo>/src/data/required.ts`. Exit 1 stops the run until the
   component reads the flags from the form definition; there is no "named as not needed" here.
4. **Push.** On `draft` only, files staged by name (never `git add .`: `.scratch/` would go to the
   platform). `git -C <repo> push origin draft`. Note the sha.
5. **Build.** POSTs to `/gql` from a tab of the desktop app's built-in browser pane, signed in to
   `one.host` (`publish.md`): check who is signed in, then a lone
   `buildCustomComponent(id)` mutation, then poll `customComponentBuild(id, sha)` until
   `SUCCEEDED`. The gateway has no build tool. On `FAILED` with "source fetch answered 404", build
   the same commit again, as `publish.md` › *Known failures* says (how many tries, and when to
   stop and hand the build to the *Build* tab). With no signed-in tab, ask the user
   to sign in to that site in the app's browser; if a POST is refused, ask them to press *Rebuild
   draft* in the component's *Build* tab.
6. **Publish.** Read `publishedSha`. Publish only when it differs from the built sha and the build
   of exactly that sha is `SUCCEEDED`. **Ask the user before each publish**, naming the component
   and the commit, and saying in a line what changes for the people who use it, unless the
   project's `AGENTS.md` says otherwise; `--no-publish` stops here. Then a lone
   `publishCustomComponent(id)` mutation, from the same tab. Publish one screen once its tasks are
   all in (`publish.md` › *When*).
7. **Served.** Full reload; the network shows `/component/<name>/<sha>`, or `publishedSha` over
   `/gql` reads the sha (`served-check.md`). Not the sha just published: stop, nothing is checked.

   **7b. UX check.** On the same tab, after a full reload: paste
   `${CLAUDE_PLUGIN_ROOT}/tools/ux-probe.js`, `uxc.open("#/page/<id>")` for each page the component
   is placed on, and `uxc.start("<label>")` with a click for the step a user takes first (open a
   record, a tab, a card), each closed by `await uxc.stop()`; then `uxc.names()` on the finished
   screen and `uxc.report()` into `.scratch/ux-check.json`. Reads only: the steps are opens and
   clicks on the user's own test record, never a save. `node "${CLAUDE_PLUGIN_ROOT}/tools/ux-check.mjs"
   .scratch/ux-check.json` exits 0: time to first content and to the last skeleton gone, `/gql`
   POSTs until idle, layout shift, console errors, failed requests and duplicate control names,
   each under `uxCheck` of `.claude/bluestep-one.json` (`ux-check.md`). Exit 1 stops the run with
   its table: fix and publish again (gates 2 to 7), or, for a number the screen cannot meet yet
   (a server read with no batch form), raise that one key in `uxCheck` with the reason written
   where the project keeps its design decisions, and the missing server read reported to the
   platform team. A layout shift sampled from a hidden pane is no pass near its
   threshold: show the pane and run again.
8. **Live check.** On the user's own test record, named with `testPrefix`, never one another
   person owns. Write each finding down where the project keeps findings before the run goes on.
9. **Design check**, for a UI change with an approved canvas export: the export served beside the
   live screen, both at 1440 px, one row per difference in the change's `design-audit.md` with
   **Fix** or **Keep** and a reason (`design-check.md`). Fixes go into one fix-up publish (gates 2
   to 8 again).

## Report

One line per gate (passed / stopped, with the sha, build state, served sha and the UX check's
table), the findings written down, and the rows written to `design-audit.md`. Nothing is marked
done until the task's done-when is re-read against what was seen live.
