---
name: b6p-push
description: Publish a BlueStep (B6P) component's local changes to the platform with the b6p CLI — make it live, deploy it, upload it, ship a fix — or save them as a draft only. Use whenever the user wants local edits of a component on the platform, even without the word "push" ("publish this", "make it live", "deploy my changes", "upload the fix", "put it on the platform"). It shows what changed, asks whether to publish or save a draft, and stops to ask before anything on the platform is overwritten or deleted.
compatibility: Needs the b6p CLI 1.0.0 or later on PATH, a b6p access token stored with b6p auth set, and a commit author.
---

# /b6p-push — Publish a component to BlueStep

`b6p script push --file <any file inside the component>` finds the destination from the sync metadata the CLI recorded when the component was pulled; it walks up from that file to the component root. `b6p` is a standalone binary on `PATH`, installed separately — invoke it as the bare `b6p`. The old top-level `b6p push` still works in 1.0.0 but prints a deprecation warning; always write `b6p script push`.

A script's draft is a git repository on the platform, and `draft/` is a clone of it (it holds its own `draft/.git`). A push commits `draft/` and pushes it to the `draft` branch. **The platform then builds that commit** (b6p 1.0 bundles no compiler): when the build changes the output, the platform adds a "Build draft" commit and b6p moves the local `draft/` to it. A publish (`--snapshot`) publishes that build. The script's history is its git history. The platform refuses every older (WebDAV) write to a script's source with HTTP 403.

**Only on a namespace that has the git-only web release.** The release reaches namespaces one at a time. Until the user's namespace has it, b6p 1.0 pushes without the platform build and cannot publish (step 5, `SNAPSHOT_REFUSED`).

## Steps

Copy this checklist and tick it off as you go:

```
- [ ] 0. Preflight: CLI at or above the minimum, login stored, commit author set, folder set up
- [ ] 1. Component identified
- [ ] 2. Diff scope shown
- [ ] 3. User chose Publish or Save draft only (and the description)
- [ ] 4. Push run with --yes --json
- [ ] 5. Result read from the exit code and --json; any question asked; reported
```

### 0. Preflight (before any other `b6p` call)

**CLI version.** Run `b6p --version`; it prints the bare version (e.g. `1.0.0`). The minimum is `tools.b6p.min` in `../b6p-setup/assets/tool-versions.json` (relative to this file) — read it there, never from memory.

- **At or above the minimum** → continue.
- **Older** → STOP. Do **not** run the push. b6p 0.8.x is refused by the platform (HTTP 403), and 0.9.0 fails its first platform request on a CSRF token. Tell the user:
  > Your `b6p` CLI is <version>; this skill needs <minimum> or later. Update it once your namespace has the git-only web release — installed with npm (needs Node.js 24 or newer): `npm i -g @bluestep-systems/b6p-cli@latest`; a downloaded binary: get the new one from https://github.com/Bluestep-Systems/b6p-cli/releases — then retry `/b6p-push <component>`.
- **Not a version number** (no output, an error, a wrapper's own text) → say so and ask the user which version they have before pushing; do not guess. `command not found` → see "If the CLI fails".

**Login.** Run `b6p --json auth status`. It never prompts and prints `{"authenticated": true}` or `false`.

- `false` → STOP, no push. Tell the user:
  > `b6p` has no BlueStep platform access token on this machine yet. Run `b6p auth set` once in your own terminal, then retry `/b6p-push <component>`.
- `true` → continue.

**Commit author.** Every push is a git commit, and b6p never commits as nobody: with no author it exits `1` before touching the platform. It takes the first of `--author "Name <email>"`, the stored default (`b6p config set author "Name <email>"`), `git config user.name` and `user.email` for the script folder, then `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL`. Check: `git -C "U######/<ComponentName>/draft" config user.name` and `git -C "U######/<ComponentName>/draft" config user.email` (they fall back to the global values).

- Both print something → continue; the push carries that name and e-mail.
- Either is empty → the author may still be stored with `b6p config set author` (b6p has no command that prints it). Run the push; if it stops with `No commit author found`, step 5 says what to hand over. Never invent a name or e-mail, and never pass `--author` with a value the user did not give.

**Setup preflight.** Look at the working directory's rules file. Any of these means the folder is not ready: no `AGENTS.md` at all; an `AGENTS.md` with **no** `<!-- bluestep-tools rules-template N -->` marker (a file from before the marker — version 1); a marker **below** the one in `../b6p-setup/templates/AGENTS.md.template`; or a `CLAUDE.md` holding real rules with no `AGENTS.md` beside it. In that case **invoke the `/b6p-setup` skill** (through the Skill tool, so its own tool allowances apply — never re-implement it from memory; its file is `../b6p-setup/SKILL.md`) for its step 2, then continue with this request. It performs what has one correct answer and asks only what a file with the user's own lines raises — an old rules file with project rules, a populated `CLAUDE.md`, a folder with no BlueStep signal — and those questions are asked before this request goes on. If `b6p` is missing or below the step-0 minimum, or `$B6PT_TOKEN` is unset when a `[PLATFORM]` op needs it, run its step 1 first and hand over the commands only a person can run. Never drop the request: if the user would rather go on without setup, continue and say in the report that `/b6p-setup` is there when they want it. The one exception is the user answering "Not a BlueStep repo" or opting the plugin out — then this request ends with that answer, and say so.

### 1. Identify the component

If `$ARGUMENTS` contains a component path (relative to the project root), use it. Otherwise ask the user which component to push.

### 2. Pre-flight checks

- Run `git -C "U######/<ComponentName>/draft" status` to surface what changed and flag anything unexpected. `draft/` is its own git repository, so a `git status` from the project root may not show what the push will commit. Its first line must say `On branch draft`: on any other branch the push refuses (step 5).
- Never edit, commit, reset or switch branches inside `draft/.git` yourself, and never hand-edit `.b6p-build.json` (the build manifest the platform writes into the build folder): the push makes the commit, and the platform checks that manifest before it publishes.
- Summarise the diff scope in one line: "X files changed in `U######/<Component>/draft/`".
- Do not look for the sync metadata yourself: the CLI keeps it outside the component folder. Always run the step-4 `--file` command first — it finds the destination on its own — and use the `--root` fallback only when it answers `Missing metadata`.
- Know what the CLI checks, by content, never by date. Before pushing anything it asks **one question** listing every file whose platform copy changed since the last sync from here, or was never synced from this machine, or that the platform deleted while it still exists here; new files and files equal to the platform copy never ask. A confirmed overwrite is a merge commit, so the platform's version stays in the history. It asks **one more** when a file the platform added or changed since your last sync is missing locally. `--yes` (step 4) answers **Cancel** and **No**, so the push stops or keeps the files, and step 5 says what to do.
- **A file deleted locally is deleted on the platform, with no question,** when the platform did not change it since your last sync: the push commits the working tree as it is. If `git -C … status` lists a `deleted:` file, name it to the user in the diff scope and get their yes for it as part of step 3 — or restore it with `git -C "U######/<ComponentName>/draft" checkout -- <file>` if the delete was not meant. When the platform may have moved since the pull (a days-old pull, a component others edit), suggest `/b6p-audit` first.

### 3. Choose how the change goes out (this also confirms the push)

**Publish** (`--snapshot --message`) commits the change, lets the platform build it, and publishes the build: it updates the **live version**, and the published commit is the restore point in the script's history. **Save draft only** (plain push) commits the change and lets the platform build it, but the live version does not change — rarely what the user wants. Publish is the recommended default: pre-selected, never run without an explicit selection.

The platform publishes only a build it vouches for. If the build is not clean, a plain push still succeeds with a warning, and a publish is refused until it builds cleanly (step 5). Diagnostics in the script's own sources are counted in `typeCheckDiagnostics` and listed in `typeCheckErrors`; they are warnings unless `--fail-on-type-errors` is passed. How the platform's build works: the `bluestep-reference` skill's `reference/server-side-compile.md`.

Most users are non-technical, so present the choice in **plain language — avoid the words "snapshot" and "push" in what they see.** Show the one-line diff scope from step 2, then ask **two** structured questions with clickable options (`AskUserQuestion` in Claude Code) — one at a time, never as a numbered list to answer by hand:

1. **"How should this change go out?"** — two options, plus an "Other" escape (`AskUserQuestion` adds "Other" automatically in Claude Code, so don't author a third option there; where the tool doesn't auto-add one, add it yourself):
   - `Publish — make it live (Recommended)` — "Builds your code and updates the live version everyone sees. The change is kept in the history, so an earlier version can be put back." → `--snapshot --message`.
   - `Save draft only — not live yet` — "Saves your work on the platform without making it live. Use only if you're not ready for it to go live." → plain push.

   Selecting an option is the confirmation to push; if the user cancels, do not push. "Other" is a free-text instruction: follow it rather than forcing it into the two options.
2. On **Publish**, a second question — **"Describe this change"** (it becomes the commit message in the history):
   - `Use suggested description (Recommended)` — a concise plain-language summary you draft from the diff, put in the option label so the user sees what they're accepting.
   - `Let me write my own` — the user types it through the "Other" escape.

### 4. Run the push

**Publish:**

```
b6p --yes --json script push --file "U######/<ComponentName>/draft/scripts/app.ts" --snapshot --message "<description>"
```

**Save draft only:**

```
b6p --yes --json script push --file "U######/<ComponentName>/draft/scripts/app.ts"
```

Any existing file inside the component works for `--file`; `app.ts` is the usual one. A plain push with no `--message` gets the commit message "Push from b6p". A publish with nothing new to commit makes no commit: it publishes the current draft head.

`--yes` is **required**: without it b6p may ask a question you cannot answer and exit `1`. It takes the **safe answer of every question** — **Cancel** to overwriting, **No** to deleting, **Cancel** to switching a script to git — and prints each one on stderr (`[Cancel] / Overwrite all: Cancel  (answered by --yes: …)`); those lines are not errors. An overwrite, a delete or a switch to git happens only on the user's yes (step 5). `--json` puts the result on stdout as one object — step 5's success test.

- **Never add `--enable-git` on the first run.** A script that still publishes over WebDAV must be switched to git before it can take a push, and the switch is **one-way**. Under `--yes` the push declines it and exits `1`; step 5 says how to ask.
- Do not add `--fail-on-type-errors` unless the user asks for it; step 5 reads the diagnostics either way.
- **`Missing metadata`** from `--file` means the component was never pulled with the CLI: read `references/root-fallback.md` for the `--root` push. The step-3 choice still applies.

### 5. Read the result and report

**The exit code and the `--json` object are the success signal, not the prose.** Exit `1` means it did not do everything asked; `0` means it did. The object's **`error`** field carries the same verdict: `null` on success, else `{ kind, message, howTo }` — `message` says what happened and `howTo` the command to go on with. The other fields: `pushed`, `commitSha`, `publishedSha`, `publishError`, `publishRefusal`, `switchedToGit`, `route`, `snapshotRefused`, `build`, `buildCommitSha`, `buildVouched`, `buildError`, `buildErrorKind`, `buildErrorReason`, `buildIncomplete`, `buildFastForward`, `typeCheckDiagnostics`, `typeCheckErrors`, `liveVerified`, `liveMismatches`, `keptPlatformOnly`, `declinedOverwrites`. Two other shapes: `{"cancelled": true}` after a cancelled target-URL question, and `{"error": "…", "errors": […]}` (no `pushed` key) when the command failed before it had a push result. Questions, warnings and next steps are on stderr.

Find the row by `error.kind` (or, for the second shape, by the error text), then act on every "also" row that matches:

| Exit | `error.kind` / text | What happened | What to do |
|---|---|---|---|
| `1` | `NOTHING_PUSHED`, files in `declinedOverwrites` | Stopped before pushing: those files changed on the platform | **Stop and ask**, below |
| `1` | text: `To switch it, run the same command with --enable-git` | The script still publishes over WebDAV; `--yes` declined the switch. Nothing changed | **Switch to git?**, below |
| `1` | text: `No commit author found` | No author; nothing was pushed or touched | Hand over `b6p config set author "Your Name <you@example.com>"` for the user to run with their own name and e-mail, then re-run step 4 |
| `1` | text: `git -C <script>/draft checkout draft` | `draft/` has another branch checked out | Tell the user. Do not switch branches yourself: commits on the other branch are not lost, and they may want them merged into `draft` first |
| `1` | text names a symbolic link outside the draft folder | Refused, nothing changed; the message says how to fix it | Show the message; let the user decide |
| `1` | `NOTHING_PUSHED`, `declinedOverwrites: []` | Nothing pushed: a wrong `--root`, an empty `draft/`, an upload refused | Show `error.message`; fix the cause, re-run |
| `1` | `SNAPSHOT_REFUSED` (`snapshotRefused`: `too-old`, `unknown` or `floor-unset`) | The draft is saved, but the server is older than the git build (`route.serverVersion`), so nothing was built or published (`cannot snapshot, only push saves`) | Say the namespace does not have the release yet; the draft is saved. Do not retry until it does |
| `1` | `BUILD_REFUSED` (`buildErrorReason`: `DRAFT_MOVED`, `DRAFT_TOO_LARGE`, `REPO_MISSING`, `DRAFT_BRANCH_MISSING`) | The draft was pushed, but the platform refused to build it | Show `error.message` and `error.howTo`. `DRAFT_MOVED` → **Draft moved**, below. `DRAFT_TOO_LARGE` → ask the user which large files to remove. `REPO_MISSING` / `DRAFT_BRANCH_MISSING` → a platform problem: report it, do not retry |
| `1` | `BUILD_NOT_REQUESTED` | The platform's draft moved after this push, so no build was asked for | **Draft moved**, below |
| `1` | `BUILD_REQUEST_FAILED` | The draft was pushed; the build request failed | Re-run step 4 once, unchanged (the next push takes in a build that landed after all); then stop |
| `1` | `BUILD_OUTCOME_UNKNOWN` | The draft was pushed; the platform lost the build's answer | `/b6p-pull`, then re-run step 4 once |
| `1` | `BUILD_INCOMPLETE` (`buildIncomplete.status`) | The build ended in a status that does not publish (busy, gate tripped, output withheld, …); nothing published | Show `error.message` and `error.howTo`; a gate trip is the user's decision (`server-side-compile.md`, "The save gate"); do not loop |
| `1` | `BUILD_BLOCKED` (`buildFastForward.state: blocked`, `blockedPaths`) | The platform built the draft, but local files the build replaces are in the way, so the local `draft/` was not moved to the build | Show the paths. Ask before moving or deleting any: keep a copy of each the user edited. Then re-run step 4 |
| `1` | `BUILD_TAKE_IN_FAILED` | Built, but the local `draft/` could not be moved to the build | `/b6p-pull`, then push again if a publish is still needed |
| `1` | `PUBLISH_REFUSED` (`publishRefusal.reason`) | Pushed and built, but the platform refused to publish. The live version did not change | **Publish refused**, below |
| `1` | `PUBLISH_FAILED` | Pushed and built; the publish failed | Show `publishError`; offer to re-run the publish once |
| `1` | `NOT_PUBLISHED` | Pushed; the platform reported no published commit | Say so plainly: not live. Offer to re-run the publish once |
| `1` | `LIVE_MISMATCH` (`liveVerified: false`) | Published, but the live branch reads back at another commit | Say the live version may not be this push; offer to re-run the publish |
| `1` | `TYPE_ERRORS` | Only with `--fail-on-type-errors`: the build reported diagnostics in the script's own sources | As the `typeCheckDiagnostics` row |
| `1` | `{"error", "errors"}` shape, none of the above | The command failed before it had a result (a question with no input, a network or git error) | Read the text; "If the CLI fails" |
| also | `route.mode: push-only` on exit `0` | The server is older than the git build: the draft is saved, but the platform did not build it | Say the namespace does not have the release yet |
| also | `buildVouched: false` on exit `0` | Pushed; the build is not clean. A publish will be refused until it is | Say so; show the diagnostics; publishing waits for a fix |
| also | `typeCheckDiagnostics` above `0` | The platform's build reported ERROR and WARNING diagnostics (count); `typeCheckErrors` lists up to 20 in the script's own sources, with `severity` | Treat them as real: read `references/type-check-diagnostics.md` |
| also | `buildFastForward.state: fast-forwarded` | The local `draft/` now holds the platform's build commit (`buildCommitSha`) | Say so: the build output in `draft/` came from the platform |
| also | `switchedToGit: true` | This push moved the script from WebDAV to git, one-way (the user said yes to it) | Say so in the report |
| also | files in `keptPlatformOnly` | Pushed; platform-only files kept | Report, then **Kept files**, below |
| also | `liveVerified: null` on a publish | Published; the read-back of the live branch could not run | Say so; confirm which build is live (Report) |
| `0` | `{"cancelled": true}` | Target-URL question cancelled | Nothing pushed; say so |
| `0` | `error: null` | Pushed and built (and published, on a publish) | Report, below |

On a draft-only push `publishedSha` and `liveVerified` are `null` — not a warning. No exit-`1` row is a CLI bug or a reason to switch tools.

**Stop and ask** (exit `1`, `declinedOverwrites` lists files). stderr ends with the files and the command that overwrites them. `Push stopped before pushing anything` (`Snapshot push stopped …` on a publish) means nothing was pushed:

```
ERROR: Push stopped before pushing anything: 2 file(s) were not overwritten, because each would overwrite a platform version nobody here has seen:

README.md (changed on the platform since this folder was last synced)
scripts/old-helper.ts (deleted on the platform since this folder was last synced; pushing would bring it back)

Pull or audit them to see the platform versions before overwriting them.
After checking them, overwrite them with your local files with:
  b6p --yes --json script push --file U######/<ComponentName>/draft/scripts/app.ts --overwrite README.md --overwrite scripts/old-helper.ts
```

1. This is the push doing its job, not a failure: do not retry, do not switch tools.
2. Show the user the files with the reason the CLI gives for each:
   - *changed on the platform* — the platform copy is not the one this machine last saw: usually someone edited it there. If the file has no local change (step 2's `git -C … status`), say so: overwriting it puts the old local copy back over the platform edit.
   - *deleted on the platform … pushing would bring it back* — someone removed it there. Say plainly that overwriting **restores a file someone deleted**.
3. Suggest `/b6p-audit` to see the differences, or `/b6p-pull` to take the platform copy. Do not run either unasked.
4. Ask one structured question, as in step 3 — **"These files changed on the platform since your last pull. What should happen?"**:
   - `Check them first (Recommended)` — "Nothing is pushed. Look at the differences first, then push again."
   - `Overwrite them with my local files` — "Replaces the platform copy of every file listed with yours. The platform's version stays in the history."
5. Only on *Overwrite*: run the printed command **exactly as printed** — same directory, nothing edited, added or removed; it repeats this push's arguments (publish choice and description included) plus one `--overwrite` per file. Read its result from the top of this step; if it stops on other files, the platform moved again — same flow. The CLI pushes all or nothing: if the user wants only some overwritten, the push waits until the rest are settled (pulled, merged or confirmed).

**Switch to git?** (exit `1`, the text says the script still publishes over WebDAV). Nothing changed. The script must move to git before b6p can push it, and the move cannot be undone. Ask one structured question — **"This script has not moved to the new git-based publishing yet. Move it now?"**:

- `Not now (Recommended)` — "Nothing changes. The script cannot take this push until it moves."
- `Move it to git and push` — "Moves the script to git publishing for good, then pushes. Its draft and live version then refuse the old upload route, so anyone still on an older b6p or the VS Code extension can no longer push it, and its history is the git history from here on."

Only on *Move it*: re-run the step-4 command with `--enable-git` added, nothing else changed, and read its result from the top of this step. Never add `--enable-git` without this yes for *this* script, never on an org the user only reads from, and an earlier yes for another script does not carry over.

**Draft moved** (`BUILD_REFUSED` with `DRAFT_MOVED`, `BUILD_NOT_REQUESTED`, or a `PUBLISH_REFUSED` whose reason is `DRAFT_MOVED`). Someone else pushed to the draft in between; the live version did not change. The CLI's `howTo` says to pull and push again. Run `/b6p-pull`, show the user what it brought in (`git -C … log` of the new commits, and any kept files), and only then re-run step 4 with the same choice: a publish after the pull also publishes the other person's change.

**Publish refused** (exit `1`, `PUBLISH_REFUSED`). The draft is pushed and the live version is unchanged. `error.howTo` says what to do.

1. `BUILD_MANIFEST_MISSING` — the platform writes the manifest only after a clean build. Show the build's ERROR diagnostics (`typeCheckErrors`, stderr); fix them, then publish again. If the user says a bundler outside b6p builds this script, that needs the script's `externallyBuilt` setting on the platform — the user's decision, set over `/gql` (the `b6p-propagate` skill's `references/config-matrix.md`); b6p has no flag for it.
2. `BUILD_STALE` or `BUILD_MANIFEST_INVALID` — run the step-4 publish once more, unchanged: the platform rebuilds on every push. If it is refused again with the same reason, stop and show the user `publishRefusal.withheld`; do not loop.
3. `DRAFT_MOVED` — **Draft moved**, above.
4. Never edit `.b6p-build.json` by hand to get past a refusal.

**Kept files** (exit `0`, `keptPlatformOnly` lists files). The push succeeded. b6p wrote the platform copy of each kept file into your local `draft/` and into this push's commit (`Their platform copies are included in this push`). stderr also prints a command to delete them — **do not run it**: the files are now in the local draft too, so that run finds nothing to delete.

```
WARNING: Kept 1 platform-only file(s): they are on the platform but not in your local draft folder, and deleting them was not confirmed.
…
To delete it from the platform, run the push again without --yes and answer Yes to the delete question:
```

1. Report the push as done, and list the kept files: files the platform added or changed since your last sync that were missing from the local `draft/`. They are now back in the local `draft/`.
2. Ask one structured question — **"These files were added or changed on the platform and were missing from your copy. They are now in your copy too. What should happen?"**:
   - `Keep them (Recommended)` — "They stay, on the platform and in your copy. Nothing else changes."
   - `Delete them from the platform` — "Removes them from your copy and from the platform with one more push. They stay in the history." On a publish, add: "This publishes once more, so the history gets a second entry."
3. Only on *Delete*: delete those files from the local `draft/` and run the step-4 push again with the same choice and description. With the platform unchanged since this push, b6p commits the deletions without a question. Read its result from the top of this step.

**Report.**

- **Published** → say it is live and give the published commit (`publishedSha`, first 7 characters is enough): it is the restore point in the script's history. Then confirm **which build is live** rather than assuming it: read `references/verify-live-build.md`. A `java.nio.file.NoSuchFileException: …/scripts/app` in a formula's ERR log means the script has no live build yet — publish it (step 3).
- **Saved a draft only** → say plainly it is **not live yet** and give the draft commit (`commitSha`); publishing makes it live.
- **A change does not show up** → check the push mode first, then `verify-live-build.md` — before theorising about caches, `config.json` or compilation.
- Remind the user to check the behaviour on the platform; if `draft/README.md` changed, the platform now has the updated docs.

## What this skill must NOT do

- Do NOT invoke `b6p` any way other than the bare `b6p` binary, and use `b6p script push`, not the deprecated top-level `b6p push`.
- Do NOT push with a `b6p` CLI below the minimum in `tool-versions.json` (step 0), and do NOT run the update yourself — hand it over.
- Do NOT push without showing the user the diff scope and getting an explicit selection for *this* push (step 3). Publish is recommended and pre-selected, never performed on its own — not on task completion, and `/spec-execute` offers no publish mid-task.
- Do NOT overwrite or delete anything on the platform without the user's yes for *this* push (step 5): no answer, or anything short of a clear yes, means no, and an earlier yes does not carry over.
- Do NOT pass `--enable-git`, or answer "Switch to git", without the user's yes for *this* script (step 5, **Switch to git?**). The switch is one-way.
- Do NOT edit the command the CLI printed or pipe answers into `b6p` yourself: run it exactly as printed, and never add an `--overwrite` for a file the user did not confirm.
- Do NOT commit, reset or change branches inside `draft/.git`, and do NOT hand-edit `.b6p-build.json`.
- Do NOT loop on CLI failures.

## If the CLI fails

- **`command not found`** — the b6p-cli binary is not installed or not on `PATH`. Do NOT retry; tell the user to install it (`/b6p-setup` hands over the command), then retry `/b6p-push <component>`.
- **Exit `1` from the push itself** (a stop at the overwrite question, a declined switch, no author, a refused build or publish, a live copy at another commit) — **not** a CLI failure and **not** a reason to change tools: handle it by the step-5 table.
- **Exit `1` naming a question it could not ask here** (`No input available for prompt: "…"`) — **not** a tool failure. Relay it. `Enter your access token` → tell the user to run `b6p auth set`, then retry. `Could not determine script URL`, or `Paste in the target formula URI` → the `--file` path is not inside a `U######/<ComponentName>/draft/` folder, or a `--root` push was run without its target URL: fix the path, or use the `--root` push from step 4's `Missing metadata` bullet with its URL. Any other question → show it to the user and ask; `b6p auth set` is only for the token.
- **`Could not switch the script to git publishing: HTTP <code>`** — b6p puts this prefix on any failed call about the script's git mode: the read it makes before every pull and push, and, with `--enable-git`, the switch itself. Without `--enable-git` nothing was switched. The cause is not in the message (the token's rights, or the server); tell the user, do not retry in a loop, and do not add `--enable-git`.
- **Any other error** (network, a real auth *rejection* by the platform) — stop and show it. The other supported way to change a script is the platform's own BSJS editor, which works on the same git repository: after anyone saves there, run `/b6p-pull` before the next push. The VS Code b6p extension is **not** a fallback: it has not been updated for git-only scripts.

**Never upload files by hand** (WebDAV PUT, a file manager, the platform's file browser) into a script's `draft/` or `snapshot/` folder: the platform refuses those writes with HTTP 403 since the git-only release (the `bluestep-reference` skill's `b6p-platform.md`, sync-failure fallbacks).
