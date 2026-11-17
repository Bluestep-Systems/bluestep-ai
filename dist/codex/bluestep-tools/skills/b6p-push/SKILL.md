---
name: b6p-push
description: Publish a BlueStep (B6P) component's local changes to the platform with the b6p CLI — make it live, deploy it, upload it, ship a fix — or save them as a draft only. Use whenever the user wants local edits of a component on the platform, even without the word "push" ("publish this", "make it live", "deploy my changes", "upload the fix", "put it on the platform"). It shows what changed, asks whether to publish or save a draft, and stops to ask before anything on the platform is overwritten or deleted.
compatibility: Needs the b6p CLI 0.9.0 or later on PATH, a b6p access token stored with b6p auth set, and a commit author.
---

# /b6p-push — Publish a component to BlueStep

`b6p push --file <any file inside the component>` finds the destination from the sync metadata the CLI recorded when the component was pulled; it walks up from that file to the component root. `b6p` is a standalone binary on `PATH`, installed separately — invoke it as the bare `b6p`.

Since b6p 0.9.0 a script's draft is a git repository on the platform, and `draft/` is a clone of it (it holds its own `draft/.git`). A push is a git commit of `draft/` pushed to the `draft` branch; a publish also publishes that commit. The script's history is its git history. Once the web release that makes scripts git-only is live, the platform refuses every older (WebDAV) write to a script's source with HTTP 403, so older clients cannot push at all.

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

**CLI version.** Run `b6p --version`; it prints the bare version (e.g. `0.9.0`). The minimum is `tools.b6p.min` in `../b6p-setup/assets/tool-versions.json` (relative to this file) — read it there, never from memory.

- **At or above the minimum** → continue.
- **Older** → STOP. Do **not** run the push: the platform refuses every write from b6p 0.8.x with HTTP 403 ("This script is edited through git; use the BSJS editor or the b6p CLI."), on every script. Tell the user:
  > Your `b6p` CLI is <version>; this skill needs <minimum> or later. Update it — installed with npm: `npm i -g @bluestep-systems/b6p-cli@latest`; a downloaded binary: get the new one from https://github.com/Bluestep-Systems/b6p-cli/releases — then retry `/b6p-push <component>`.
- **Not a version number** (no output, an error, a wrapper's own text) → say so and ask the user which version they have before pushing; do not guess. `command not found` → see "If the CLI fails".

**Login.** With no access token stored in `~/.b6p/`, the push asks for one — a question you cannot answer, and `--yes` does not — and exits `1`. Check first: `test -f ~/.b6p/secrets.enc && echo OK`.

- Nothing printed → STOP, no push. Tell the user:
  > `b6p` has no BlueStep platform access token on this machine yet. Run `b6p auth set` once in your own terminal, then retry `/b6p-push <component>`.
- `OK` → continue. The file can exist without a token in it; then the push stops at `Enter your access token` (exit `1`) — relay it with the same `b6p auth set` instruction; do not retry.

**Commit author.** Every push is a git commit, and b6p never commits as nobody: with no author it exits `1` before touching the platform. It takes the first of `--author "Name <email>"`, the stored default (`b6p config set author "Name <email>"`), `git config user.name` and `user.email` for the component folder, then `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL`. Check: `git -C "U######/<ComponentName>/draft" config user.name` and `git -C "U######/<ComponentName>/draft" config user.email` (they fall back to the global values).

- Both print something → continue; the push carries that name and e-mail.
- Either is empty → the author may still be stored with `b6p config set author` (b6p has no command that prints it). Run the push; if it stops with `No commit author found`, step 5 says what to hand over. Never invent a name or e-mail, and never pass `--author` with a value the user did not give.

**Setup preflight.** Look at the working directory's rules file. Any of these means the folder is not ready: no `AGENTS.md` at all; an `AGENTS.md` with **no** `<!-- bluestep-tools rules-template N -->` marker (a file from before the marker — version 1); a marker **below** the one in `../b6p-setup/templates/AGENTS.md.template`; or a `CLAUDE.md` holding real rules with no `AGENTS.md` beside it. In that case **invoke the `/b6p-setup` skill** (through the Skill tool, so its own tool allowances apply — never re-implement it from memory; its file is `../b6p-setup/SKILL.md`) for its step 2, then continue with this request. It performs what has one correct answer and asks only what a file with the user's own lines raises — an old rules file with project rules, a populated `CLAUDE.md`, a folder with no BlueStep signal — and those questions are asked before this request goes on. If `b6p` is missing or below the step-0 minimum, or `$B6PT_TOKEN` is unset when a `[PLATFORM]` op needs it, run its step 1 first and hand over the commands only a person can run. Never drop the request: if the user would rather go on without setup, continue and say in the report that `/b6p-setup` is there when they want it. The one exception is the user answering "Not a BlueStep repo" or opting the plugin out — then this request ends with that answer, and say so.

### 1. Identify the component

If `$ARGUMENTS` contains a component path (relative to the project root), use it. Otherwise ask the user which component to push.

### 2. Pre-flight checks

- Run `git -C "U######/<ComponentName>/draft" status` to surface what changed and flag anything unexpected. `draft/` is its own git repository, so a `git status` from the project root may not show what the push will commit. Its first line must say `On branch draft`: on any other branch the push refuses (step 5).
- Never edit, commit, reset or switch branches inside `draft/.git` yourself, and never hand-edit `.b6p-build.json` (the build manifest b6p writes into the build folder): the push makes the commit, and the platform checks that manifest before it publishes.
- Summarise the diff scope in one line: "X files changed in `U######/<Component>/draft/`".
- Do not look for the sync metadata yourself: the CLI keeps it outside the component folder. Always run the step-4 `--file` command first — it finds the destination on its own — and use the `--root` fallback only when it answers `Missing metadata`.
- Know what the CLI checks, by content, never by date. Before pushing anything it asks **one question** listing every file whose platform copy changed since the last sync from here, or was never synced from this machine, or that the platform deleted while it still exists here; new files and files equal to the platform copy never ask. A confirmed overwrite is a merge commit, so the platform's version stays in the history. It asks **one more** when a file the platform added or changed since your last sync is missing locally. `--yes` (step 4) answers **Cancel** and **No**, so the push stops or keeps the files, and step 5 says what to do.
- **A file deleted locally is deleted on the platform, with no question,** when the platform did not change it since your last sync: the push commits the working tree as it is. If `git -C … status` lists a `deleted:` file, name it to the user in the diff scope and get their yes for it as part of step 3 — or restore it with `git -C "U######/<ComponentName>/draft" checkout -- <file>` if the delete was not meant. When the platform may have moved since the pull (a days-old pull, a component others edit), suggest `/b6p-audit` first.

### 3. Choose how the change goes out (this also confirms the push)

**Publish** (`--snapshot --message`) compiles `scripts/` and any `static/` bundle in the CLI, commits the source and the build together, and publishes that commit: it updates the **live version**, and the commit is the restore point in the script's history. **Save draft only** (plain push) commits the source as-is to the `draft` branch: nothing compiles, the live version does not change — rarely what the user wants. Publish is the recommended default: pre-selected, never run without an explicit selection.

A publish writes a build manifest (`.b6p-build.json` in the build folder) only when the build is fully clean, and the platform refuses to publish a draft whose sources changed since its manifest (`publishRefusal`, step 5). Type errors in the script's own sources are **warnings** since 0.9.0: they are printed and counted, and the push still goes out with exit `0`. Syntax and emit errors still stop it. Errors in `.d.ts` files never count. How the platform's own compile fits in: the `bluestep-reference` skill's `reference/server-side-compile.md`.

Most users are non-technical, so present the choice in **plain language — avoid the words "snapshot" and "push" in what they see.** Show the one-line diff scope from step 2, then ask **two** structured questions with clickable options (`AskUserQuestion` in Claude Code) — one at a time, never as a numbered list to answer by hand:

1. **"How should this change go out?"** — two options, plus an "Other" escape (`AskUserQuestion` adds "Other" automatically in Claude Code, so don't author a third option there; where the tool doesn't auto-add one, add it yourself):
   - `Publish — make it live (Recommended)` — "Compiles your code and updates the live version everyone sees. The change is kept in the history, so an earlier version can be put back." → `--snapshot --message`.
   - `Save draft only — not live yet` — "Saves your work on the platform without compiling or making it live. Use only if you're not ready for it to go live." → plain push.

   Selecting an option is the confirmation to push; if the user cancels, do not push. "Other" is a free-text instruction: follow it rather than forcing it into the two options.
2. On **Publish**, a second question — **"Describe this change"** (it becomes the commit message in the history):
   - `Use suggested description (Recommended)` — a concise plain-language summary you draft from the diff, put in the option label so the user sees what they're accepting.
   - `Let me write my own` — the user types it through the "Other" escape.

### 4. Run the push

**Publish:**

```
b6p --yes --json push --file "U######/<ComponentName>/draft/scripts/app.ts" --snapshot --message "<description>"
```

**Save draft only:**

```
b6p --yes --json push --file "U######/<ComponentName>/draft/scripts/app.ts"
```

Any existing file inside the component works for `--file`; `app.ts` is the usual one.

`--yes` is **required**: without it b6p may ask a question you cannot answer and exit `1`. It takes the **safe answer of every question** — **Cancel** to overwriting, **No** to deleting, **Cancel** to switching a script to git — and prints each one on stderr (`[Cancel] / Overwrite all: Cancel  (answered by --yes: …)`); those lines are not errors. An overwrite, a delete or a switch to git happens only on the user's yes (step 5). `--json` puts the result on stdout as one object — step 5's success test.

- **Never add `--enable-git` on the first run.** A script that still publishes over WebDAV must be switched to git before it can take a push, and the switch is **one-way**. Under `--yes` the push declines it and exits `1`; step 5 says how to ask.
- **Do not add `--externally-built` by default.** All it does is stop b6p from writing the build manifest. The platform skips its manifest check only for a script whose own `externallyBuilt` setting is on (a platform setting, set over `/gql` — the `b6p-propagate` skill's `references/config-matrix.md`). On a script without that setting, a publish with the flag carries no fresh manifest and is refused (`BUILD_MANIFEST_MISSING`, or `BUILD_STALE` against an older one). A plain publish works either way.
- Do not add `--fail-on-type-errors` unless the user asks for it; step 5 reads the type errors either way.
- **`Missing metadata`** from `--file` means the component was never pulled with the CLI: read `references/root-fallback.md` for the `--root` push. The step-3 choice still applies.
- **`Stale client bundle`** on a draft-only push: `draft/static/script.ts` is newer than its `.build/script.js`, and a plain push commits the old client JS. Tell the user; a publish ships fresh client JS (the `bluestep-reference` skill's `conventions/single-script.md`).

### 5. Read the result and report

**The exit code and the `--json` object are the success signal, not the prose.** Exit `1` means it did not do everything asked; `0` means it did — normally a push, but a cancelled target-URL question also exits `0`. A plain push is judged by `pushed` alone; a publish succeeded only when the exit is `0` **and** `publishedSha` is set. The object has these fields — `pushed`, `commitSha`, `publishedSha`, `publishError`, `publishRefusal`, `switchedToGit`, `typeCheckDiagnostics`, `typeCheckErrors`, `liveVerified`, `liveMismatches`, `keptPlatformOnly`, `declinedOverwrites` — except after a cancelled target-URL question: `{"cancelled": true}`, no `pushed` key. There is no `historyRecorded` any more: `commitSha` and `publishedSha` replace it. Questions, warnings and next steps are on stderr. Act on **every** row that matches, top to bottom — more than one can (a publish can go live with type errors *and* keep platform-only files); the last row only when no other matched:

| Exit | `--json` / stderr | What happened | What to do |
|---|---|---|---|
| `1` | `pushed: false`, files in `declinedOverwrites` | Stopped before pushing: those files changed on the platform | **Stop and ask**, below |
| `1` | stderr: `To switch it, run the same command with --enable-git` | The script still publishes over WebDAV; `--yes` declined the switch. Nothing changed | **Switch to git?**, below |
| `1` | stderr: `No commit author found` | No author; nothing was pushed or touched | Hand over `b6p config set author "Your Name <you@example.com>"` for the user to run with their own name and e-mail, then re-run step 4 |
| `1` | stderr: `git -C <script>/draft checkout draft` | `draft/` has another branch checked out | Tell the user. Do not switch branches yourself: commits on the other branch are not lost, and they may want them merged into `draft` first |
| `1` | stderr names a symbolic link outside the draft folder | Refused, nothing changed; the message says how to fix it | Show the message; let the user decide |
| `1` | `pushed: false`, `declinedOverwrites: []`, none of the above | Nothing pushed: the compiled entrypoint is missing or has no code (`Snapshot not published: …`), a syntax or emit error, a wrong `--root`, or an empty `draft/` | Fix the cause, re-run |
| `1` | `pushed: true`, `publishRefusal.reason` is `BUILD_STALE`, `BUILD_MANIFEST_MISSING` or `BUILD_MANIFEST_INVALID` | The draft was pushed, but the platform refused to publish it: the build is missing, unreadable or older than its sources (`withheld` lists the files or the manifest). The live version did not change | **Publish refused**, below |
| `1` | `DRAFT_MOVED` in `publishRefusal` or `publishError` | Someone pushed to the draft between this commit and its publish. The live version did not change | Run step 4 again, unchanged; it may stop at the overwrite question, which is then the right flow |
| `1` | `pushed: true`, `publishError` set (any other reason) | The draft was pushed; the publish failed. The live version did not change | Show `publishError`; offer to re-run the publish once |
| `1` | publish, `publishedSha: null`, no `publishError` | Nothing was published | Say so plainly: not live. Offer to re-run the publish once |
| `1` | `liveVerified: false`, files in `liveMismatches` | Published, but the live branch reads back at another commit | Say the live version may not be this push; offer to re-run the publish |
| `1` | stdout empty | A thrown failure (a question with no input, a network or git error); details on stderr | Read stderr; "If the CLI fails" |
| `0` or `1` | `typeCheckDiagnostics` above `0` | Type errors in the script's own sources, listed in `typeCheckErrors`. They are warnings: on exit `0` the code went out anyway | Treat them as real: read `references/type-check-diagnostics.md` |
| `0` or `1` | `switchedToGit: true` | This push moved the script from WebDAV to git, one-way (the user said yes to it) | Say so in the report |
| `0` or `1` | files in `keptPlatformOnly` | Pushed; platform-only files kept | Report, then **Kept files**, below |
| `0` or `1` | `liveVerified: null` on a publish | Published; the read-back of the live branch could not run, so the live copy was not checked | Say so; confirm which build is live (Report) |
| `0` | `{"cancelled": true}` | Target-URL question cancelled | Nothing pushed; say so |
| `0` | anything else | Pushed (and published, on a publish) | Report, below |

On a draft-only push `publishedSha` and `liveVerified` are `null` and nothing compiles — not a warning. No exit-`1` row is a CLI bug or a reason to switch tools.

**Stop and ask** (exit `1`, `declinedOverwrites` lists files). stderr ends with the files and the command that overwrites them. `Push stopped before pushing anything` (`Snapshot push stopped …` on a publish) means nothing was pushed:

```
ERROR: Push stopped before pushing anything: 2 file(s) were not overwritten, because each would overwrite a platform version nobody here has seen:

README.md (changed on the platform since this folder was last synced)
scripts/old-helper.ts (deleted on the platform since this folder was last synced; pushing would bring it back)

Pull or audit them to see the platform versions before overwriting them.
After checking them, overwrite them with your local files with:
  b6p --yes --json push --file U######/<ComponentName>/draft/scripts/app.ts --overwrite README.md --overwrite scripts/old-helper.ts
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

**Switch to git?** (exit `1`, stderr says the script still publishes over WebDAV). Nothing changed. The script must move to git before b6p 0.9 can push it, and the move cannot be undone. Ask one structured question — **"This script has not moved to the new git-based publishing yet. Move it now?"**:

- `Not now (Recommended)` — "Nothing changes. The script cannot take this push until it moves."
- `Move it to git and push` — "Moves the script to git publishing for good, then pushes. Its draft and live version then refuse the old upload route, so anyone still on an older b6p (0.8) or the VS Code extension can no longer push it, and its history is the git history from here on."

Only on *Move it*: re-run the step-4 command with `--enable-git` added, nothing else changed, and read its result from the top of this step. Never add `--enable-git` without this yes for *this* script, never on an org the user only reads from, and an earlier yes for another script does not carry over.

**Publish refused** (exit `1`, `publishRefusal` set). The draft is pushed and the live version is unchanged. stderr says why and to rebuild and push.

1. A publish writes a fresh manifest only when the build is fully clean. If stderr says `No build manifest was written, because the build was not fully clean:`, fix the reasons it lists first, then publish again.
2. Otherwise run the step-4 publish once more, unchanged. If it is refused again with the same reason, stop and show the user `publishRefusal.withheld`; do not loop.
3. A refusal after a push with `--externally-built`: the flag stopped b6p from writing the manifest, and the script's platform `externallyBuilt` setting is off. Publish again without the flag. The CLI's own hint to add `--externally-built` does not get past this refusal: only the platform setting does, and turning it on is the user's decision (step 4).
4. Never edit `.b6p-build.json` by hand to get past a refusal.

**Kept files** (exit `0`, `keptPlatformOnly` lists files). The push succeeded. b6p wrote the platform copy of each kept file into your local `draft/` and into this push's commit (`Their platform copies are included in this push`). stderr also prints a command to delete them — **do not run it**: the files are now in the local draft too, so that run finds nothing to delete.

```
WARNING: Kept 1 platform-only file(s): they are on the platform but not in your local draft folder, and deleting them was not confirmed.
…
To delete it from the platform, run the push again without --yes and answer Yes to the delete question:
  printf 'Yes\n' | b6p --json push --file U######/<ComponentName>/draft/scripts/app.ts
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

- Do NOT invoke `b6p` any way other than the bare `b6p` binary.
- Do NOT push with a `b6p` CLI below the minimum in `tool-versions.json` (step 0), and do NOT run the update yourself — hand it over.
- Do NOT push without showing the user the diff scope and getting an explicit selection for *this* push (step 3). Publish is recommended and pre-selected, never performed on its own — not on task completion, and `/spec-execute` offers no publish mid-task.
- Do NOT overwrite or delete anything on the platform without the user's yes for *this* push (step 5): no answer, or anything short of a clear yes, means no, and an earlier yes does not carry over.
- Do NOT pass `--enable-git`, or answer "Switch to git", without the user's yes for *this* script (step 5, **Switch to git?**). The switch is one-way.
- Do NOT edit the command the CLI printed or pipe answers into `b6p` yourself: run it exactly as printed, and never add an `--overwrite` for a file the user did not confirm.
- Do NOT commit, reset or change branches inside `draft/.git`, and do NOT hand-edit `.b6p-build.json`.
- Do NOT loop on CLI failures.

## If the CLI fails

- **`command not found`** — the b6p-cli binary is not installed or not on `PATH`. Do NOT retry; tell the user to install it (`/b6p-setup` hands over the command), then retry `/b6p-push <component>`.
- **Exit `1` from the push itself** (a stop at the overwrite question, a declined switch, no author, a refused publish, a live copy at another commit) — **not** a CLI failure and **not** a reason to change tools: handle it by the step-5 table.
- **Exit `1` naming a question it could not ask here** (`No input available for prompt: "…"`) — **not** a tool failure. Relay it. `Enter your access token` (possible even when the step-0 check printed `OK`) → tell the user to run `b6p auth set`, then retry. `Could not determine script URL` → the `--file` path is not inside a `U######/<ComponentName>/draft/` folder: fix the path, or use the `--root` push from step 4's `Missing metadata` bullet. Any other question → show it to the user and ask; `b6p auth set` is only for the token.
- **`Could not switch the script to git publishing: HTTP <code>`** — b6p puts this prefix on any failed call about the script's git mode: the read it makes before every pull and push, and, with `--enable-git`, the switch itself. Without `--enable-git` nothing was switched. The cause is not in the message: the server may not have git publishing yet, or the token may lack a scope (`/b6p-setup`'s `references/platform-token.md`). Tell the user both; do not retry in a loop, and do not add `--enable-git`.
- **`outDir not specified`** (after `Build folder doesn't exist (this is fine)`) — a pulled `static/` sub-project with `"outDir": ""` in `draft/static/tsconfig.json`. Set it to `"."` (any non-empty value) and push again; it only satisfies the local build and does not change what deploys.
- **Any other error** (network, a real auth *rejection* by the platform) — stop and show it. The other supported way to change a script is the platform's own BSJS editor, which works on the same git repository: after anyone saves there, run `/b6p-pull` before the next push. The VS Code b6p extension is **not** a fallback: it has not been updated for git-only scripts.

**Never upload files by hand** (WebDAV PUT, a file manager, the platform's file browser) into a script's `draft/` or `snapshot/` folder: the platform refuses those writes with HTTP 403 since the git-only release (the `bluestep-reference` skill's `b6p-platform.md`, sync-failure fallbacks).
