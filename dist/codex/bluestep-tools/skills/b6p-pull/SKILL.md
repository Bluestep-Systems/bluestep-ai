---
name: b6p-pull
description: Pull a B6P component from the BlueStep platform into the local workspace using its DAV URL, and scaffold draft/README.md if missing. Use when the user wants to bring a component down for the first time or re-sync after platform edits.
compatibility: Needs the b6p CLI 1.0.0 or later on PATH and a b6p access token stored with b6p auth set.
---

# /b6p-pull — Pull a component from BlueStep

## How `b6p script pull` actually works

`b6p script pull` takes a **DAV URL** as its primary argument, NOT a display name (the old top-level `b6p pull` still works in 1.0.0 but prints a deprecation warning):

```
b6p script pull [options] <formula-url>
```

The user copies the DAV URL from the component's page in the BlueStep platform UI. You cannot discover or infer it. There is no fallback that takes a name.

A first pull creates the `U######/<ComponentName>/` folder (creating the U-folder if it does not exist), populates `declarations/`, and records the component's sync metadata. A script's draft is a git repository on the platform: the pull **clones** it into `draft/` (which gets its own `draft/.git`), or fetches and fast-forwards an existing clone. Only `declarations/` and the root `.gitignore` still come over WebDAV. The local `snapshot/` folder is no longer refreshed: the published code is the `master` branch inside `draft/.git`.

**A script that has not moved to git yet cannot be pulled without moving it.** If the script still publishes over WebDAV, the pull first asks to switch it to git. The switch is **one-way**: its draft and live version then refuse the old upload route, so anyone on b6p 0.8.x or the VS Code extension can no longer push it. `--yes` answers Cancel, and then the pull writes **nothing** (step 2). b6p has no read-only pull of such a script.

**Only on a namespace that has the git-only web release** (it reaches namespaces one at a time).

Three re-pull behaviors to know:

- **A re-pull never renames the local folder.** If the component was renamed on the platform, the CLI keeps pulling into the folder it first created — don't read the folder name as the component's current display name; the platform (or a legacy `draft/info/metadata.json`, when the component still ships one) is authoritative.
- **A re-pull keeps a file you edited locally rather than overwriting it.** A local edit to a file the platform also changed is left on disk untouched, and every kept file is listed in one warning at the end of the pull — read it (step 3).
- **A folder pulled before git** (files in `draft/`, no `draft/.git`) is bound to the platform's repository in place. A file that differs is replaced by the platform copy, unless its old sync record says it was edited here (then it is kept and listed). That record is **machine-local**: on a fresh clone of the project, a new machine, or after cleared state there is no record, so local edits in such a folder are replaced.

## How to invoke `b6p`

`b6p` is a standalone binary on the system `PATH` (the b6p-cli standalone artifact, installed separately from bspecs). Invoke it directly:

```
b6p <args>
```

If `b6p` is not found, the user has not installed the b6p-cli binary yet — point them at its release/install instructions.

## Steps

### 0. Auth preflight (do this first, before any `b6p` call)

With no access token stored in `~/.b6p/`, the pull asks for one — a question you cannot answer, and `--yes` does not — and exits `1` naming it. Check first; this never prompts:

```
b6p --json auth status
```

- If it prints `{"authenticated": false}` → STOP. Do **not** run the pull. Tell the user:
  > `b6p` has no BlueStep platform access token on this machine yet, so the pull would stop at a question I can't answer. Run `b6p auth set` once in your own terminal (it stores the token in `~/.b6p/`, once per machine), then retry `/b6p-pull <DAV URL>`.
- If it prints `{"authenticated": true}` → continue.

**Setup preflight.** Look at the working directory's rules file. Any of these means the folder is not ready: no `AGENTS.md` at all; an `AGENTS.md` with **no** `<!-- bluestep-tools rules-template N -->` marker (a file from before the marker — version 1); a marker **below** the one in `../b6p-setup/templates/AGENTS.md.template` (relative to this file); or a `CLAUDE.md` holding real rules with no `AGENTS.md` beside it. In that case **invoke the `/b6p-setup` skill** (through the Skill tool, so its own tool allowances apply — never re-implement it from memory; its file is `../b6p-setup/SKILL.md`) for its step 2, then continue with this request. It performs what has one correct answer and asks only what a file with the user's own lines raises — an old rules file with project rules, a populated `CLAUDE.md`, a folder with no BlueStep signal — and those questions are asked before this request goes on. If `b6p` is missing, or `$B6PT_TOKEN` is unset when a `[PLATFORM]` op needs it, run its step 1 first and hand over the commands only a person can run. Never drop the request: if the user would rather go on without setup, continue and say in the report that `/b6p-setup` is there when they want it. The one exception is the user answering "Not a BlueStep repo" or opting the plugin out — then this request ends with that answer, and say so.

### 1. Get the DAV URL

- If `$ARGUMENTS` looks like a URL (starts with `http://` or `https://`), use it.
- If `$ARGUMENTS` is empty or looks like a display name (no scheme), STOP and ask the user:
  > I need the **DAV URL** of the component, not its name. Copy it from the component's page in the BlueStep platform UI and paste it here.
- Do NOT guess the URL. Do NOT try to derive it from another component's recorded metadata.

### 2. Run the pull

```
b6p --yes script pull "<DAV URL>"
```

The `--yes` is **required** — without it, b6p may ask a question you cannot answer, and the call fails with exit `1` naming that question. Always include it. It prints each question it answered, with the answer, on stderr — those lines are not errors. **Never add `--enable-git` on the first run.**

Capture the output — it prints the local path where the component landed. A fresh pull also prints `[ERROR] Error reading .gitignore … creating a new one`: harmless, it creates the file.

**`Pull aborted: … switching it to git was not confirmed`** (exit `1`) means the script still publishes over WebDAV and `--yes` declined to move it. **Nothing was written.** Then:

1. If the user only wants to **read** the script (a reference, a template, another team's component, a source org you must not change, a production target), never switch it. Say that b6p cannot pull it without moving it, and offer the read-only route: the gateway's `read_script_draft` reads the draft without changing anything (the `bluestep-reference` skill's `conventions/mcp-platform-authoring.md`).
2. If the user owns the script and wants to work on it, ask one structured question — **"This script has not moved to the new git-based publishing yet. Move it now?"**:
   - `Not now (Recommended)` — "Nothing changes. The script cannot be pulled with this b6p until it moves."
   - `Move it to git and pull` — "Moves the script to git publishing for good, then pulls it. Anyone still on an older b6p (0.8) or the VS Code extension can no longer push it."
3. Only on *Move it*: re-run `b6p --yes script pull "<DAV URL>" --enable-git`. An earlier yes for another script does not carry over.

**`Could not switch the script to git publishing: HTTP <code>`** — b6p puts this prefix on any failed call about the script's git mode: the read it makes before a pull, and, with `--enable-git`, the switch itself. Without `--enable-git` nothing was switched. The cause is not in the message: the server may not have git publishing yet, or the token may lack a scope (`/b6p-setup`'s `references/platform-token.md`). Tell the user both; do not retry in a loop, and do not add `--enable-git`.

**Refusals that change nothing and exit `1`**: staged-only changes in `draft/` that the pull would discard, and a symbolic link that would let the pull write outside the draft folder. The message says how to fix it; show it to the user.

### 3. Locate the component folder, and read the kept-files warning

**First, check whether the pull kept any local file.** If it did, the CLI ends with a warning like:

```
Kept 2 file(s) that differ from what was last synced (local edits, or a previously
interrupted pull) — NOT synced:

<path>
<path>
```

The list is capped at 10 with a trailing `…and N more`; `b6p --json script pull …` reports the same set as `keptLocalPaths`. This is the divergence guard working as designed, so the pull still exits `0` — but **those files are NOT the platform version**, and a reader who assumes a clean pull will be working against stale content. Carry every kept path into the step-6 report.

To actually take the platform copy for a kept file, **delete the file and pull again**. The CLI's own message also suggests an audit pull, but `b6p script audit --pull` defaults to *Cancel*, so under `--yes` it declines — that route needs a person answering its question interactively.

Then parse the CLI output, or scan for the most recently modified `U######/<Name>/` directory under the project root. Confirm:

- `declarations/` is populated
- `draft/.git` exists (a clone), and `git -C "U######/<Name>/draft" status` says `On branch draft`
- `draft/scripts/app.ts` exists (or whatever `config.json:main` points at, on a component that still ships a legacy `draft/info/`)
- **Do not check for `draft/info/`.** It is **deprecated** platform behavior: newly-created formulas never get one, and that configuration now lives on the component's setup page. Only older components still serve it. Its absence is normal and is never a broken pull (see the `bluestep-reference` skill's `b6p-platform.md`).

### 4. Identify the component type

**Start from the folder shape and the code** — that is all most components give you, since `draft/info/` is deprecated and usually absent:

- **`draft/static/` directory present** → **MergeReport** (it owns a frontend).
- **`app.ts` works through `B.net.request` / `B.net.response`** → **Endpoint** (it handles an HTTP request/response pair).
- **Neither** → it is a **formula**, but *which* kind is **not knowable from the code**. Post-Save vs Scheduled vs OnDemand vs a plain field formula is platform configuration, not source. Read it off the component's **setup page** via the gateway MCP (`bluestep-reference` → `conventions/mcp-platform-authoring.md`), or from a legacy `draft/info/` if the component still ships one. `app.ts` comment headers (`// Scheduler MR` etc.) are a weak hint, not proof.

**Shortcut when a legacy `draft/info/` *is* present** — `metadata.json` / `config.json` state the type outright, and these keys settle it. Do not go looking for these names in `app.ts`; they exist only in those JSON files:

- `httpOption` + `allowedMethods` + a `path` field → **Endpoint**
- `useAsHeaderInRelate` / `useForEditing` / `replaceRelateRecordSummary` → **MergeReport**
- `triggerType: "POST_SAVE"` (or comparable) → **Post-Save**
- `triggerType: "SCHEDULED"` → **Scheduled**
- `triggerType: "ON_DEMAND"` → **OnDemand**
- `language: "mjs"` + no triggers + presence of formula configuration → **Formula**

If you still cannot tell — which is normal for a formula with no `draft/info/` and no MCP access — **ask the user** rather than guessing. Do not report the missing `draft/info/` as the reason.

### 5. Handle `draft/README.md`

This is the per-module documentation that lives WITH the code (it ships to the platform on push, so anyone who pulls the module gets it).

a. **Check if it already exists and is substantive.** Read `<Component>/draft/README.md`.
   - If file does not exist → proceed to scaffold (step b).
   - If file exists with > 200 characters AND contains at least one `##` heading that is not literally `## Title` → it is substantive. **Leave it alone.** Tell the user: "draft/README.md already exists and looks substantive — leaving it. Read it before editing code."
   - Otherwise (empty, only `# Title`, only boilerplate) → proceed to scaffold (step b), overwriting.

b. **Scaffold from the template.** Read `component-readme-template.md` (the module README skeleton bundled alongside this skill, in the same directory as this `SKILL.md`). Fill it in using inference from the code:

   - **Title (`# [Component displayName]`):** use `displayName` from a legacy `draft/info/metadata.json` if the component ships one. Otherwise take the name from the DAV URL / the folder the pull created, or read it off the component's setup page via the gateway MCP — do not invent one, and do not treat the missing `draft/info/` as an error.
   - **Type section:** use what you identified in step 4, plus the type-specific details listed in the template's commented hints (paths/methods for Endpoint, etc.).
   - **Overview:** read `draft/scripts/app.ts` (and for MergeReports, also `draft/static/index.html`). Write ONE paragraph describing what the component does at runtime, based on what you actually see in the code. Do NOT speculate beyond what is visible.
   - **Fields used:** scan `draft/scripts/**/*.ts` for patterns like `entry.<name>.val()`, `entry.<name>.set(...)`, `entry.<name>.selectedExportValue()`. List each unique `<name>` with access type (read = `.val()` / `.selectedExportValue()`; write = `.set(...)`). Leave FID and Form columns as `?` — those are only knowable from the platform.
   - **Behavior:** translate the structure of `app.ts` into 2-5 bullets ("Receives an HTTP GET at /audits, reads the activeAudits query, returns JSON list", etc.).
   - **External dependencies:** scan for `B.net.fetch(...)` URLs, library imports beyond the platform globals, and any cross-component calls (e.g., `B.exports.something` or imports from `../OtherComponent/`).
   - **Edge cases / known gotchas:** leave empty with the literal text `_(no inferred gotchas — fill in if you find any)_`. These can only be known by humans.

c. **If you cannot infer the Overview with reasonable confidence** (e.g., `app.ts` only imports things and has no body, or the logic is too sparse to summarize) — STOP and ask the user:
   > I pulled `<ComponentName>` but cannot infer its purpose from the code alone. In one or two sentences, what does this component do? I will use your answer to scaffold `draft/README.md`.
   Then fill the Overview with the user's answer and continue.

d. **Write** the rendered README to `<Component>/draft/README.md`.

e. **Recommend pushing the scaffolded README.** A later pull keeps the local README if the platform changes its copy too (it is listed in the kept-files warning, step 3). But **only a push puts the docs where others get them.** `draft/` ships to the platform, so until the README is pushed, nobody who pulls the component sees it. Recommend pushing it in the step-6 report. (The do-not-overwrite rule further down binds *this skill's* own writes; it is unrelated to the CLI's guard.)

### 6. Report

Print a summary:

```
Pulled: U######/<ComponentName>/
Type:   <Endpoint|MergeReport|...>
README: <created from scaffold — push it so others who pull the component get the docs | preserved (already substantive)>
Kept:   <local files the pull did NOT overwrite, one per line — omit this line if none>

Next: read draft/README.md, then start editing. For a new feature use /spec-create.
```

## What this skill must NOT do

- Do NOT invoke `b6p` any way other than the bare `b6p` binary, and use `b6p script pull`, not the deprecated top-level `b6p pull`.
- Do NOT accept a display name as a substitute for the DAV URL.
- Do NOT pass `--enable-git` without the user's yes for *this* script (step 2), and never on a pull that is only for reading. The switch is one-way.
- Do NOT commit, reset or change branches inside `draft/.git`, and do NOT hand-edit `.b6p-build.json`.
- Do NOT overwrite a substantive `draft/README.md`.
- Do NOT speculate beyond what the code shows when filling Overview/Behavior — if uncertain, ask.
- Do NOT scaffold a SPEC.md anywhere — the SPEC concept lives only under `.claude/specs/<feature>/` for new work, never per component.

## If the CLI fails

Three distinct failure modes — handle them differently (a declined switch to git is not one of them: step 2):

- **`command not found` / `b6p` cannot be resolved** — the b6p-cli standalone binary is not installed (or not on `PATH`). Do NOT retry, do NOT try alternative invocations. Tell the user:
  > `b6p` could not be resolved. Install the b6p-cli standalone binary and make sure it is on your `PATH` (see its release/install instructions), then retry `/b6p-pull <DAV URL>`.
- **Exit `1` naming a question it could not answer** (`Enter your access token`, or any other) — **not** a tool failure and **not** a reason to switch tools. The CLI ran correctly and is telling you it needed an answer nobody could give. For the token: relay the CLI's message and tell the user to run `b6p auth set`, then retry. Any other question: relay it and ask the user — `b6p auth set` is only for the token.
- **Any other error** (network, lock, a real auth *rejection* by the platform, etc.) — `b6p` ran but the call failed. Show it to the user; do not retry the CLI in a loop. The VS Code b6p extension is **not** a fallback: it has not been updated for git-only scripts.
