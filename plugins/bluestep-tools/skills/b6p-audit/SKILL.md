---
name: b6p-audit
description: Compare a local component's state against what lives on the BlueStep platform, listing files that differ. Use when the user wants to know if they (or someone else) changed something on the platform side, or before a push, to see what changed there before the push stops to ask about it.
allowed-tools: Bash(b6p:*) Bash(git:*)
compatibility: Needs the b6p CLI 1.0.0 or later on PATH and a b6p access token stored with b6p auth set.
---

# /b6p-audit — Compare local vs. platform

## What this does

Runs `b6p script audit`, which fetches the component's current state from the BlueStep platform and lists files where local content differs from platform content. It compares the local `draft/` with the platform's `draft` branch (the draft, not the live version). **Read-only** — it does not modify anything.

Use this **on demand**, not as a pre-flight before every push. The user decides when to run it; typical triggers are:

- "I want to push but I'm not sure if someone else changed this module"
- "I haven't touched this in a week, what's different on the platform?"
- "I want to verify my local state matches platform before starting work"

For a push that immediately follows, the user can ask you to chain `/b6p-audit` then `/b6p-push`; do not auto-chain it yourself.

## How to invoke `b6p`

`b6p` is a standalone binary on the system `PATH` (the b6p-cli standalone artifact, installed separately from bspecs). Invoke it directly as `b6p`. If `b6p` is not found, the user has not installed the b6p-cli binary yet — point them at its release/install instructions.

Always pass `--yes` so b6p does not stop at a question you cannot answer; it prints each question it answered, with the answer, on stderr — those lines are not errors.

## Steps

### 0. Auth preflight (do this first, before any `b6p` call)

With no access token stored in `~/.b6p/`, the audit asks for one — a question you cannot answer, and `--yes` does not — and exits `1` naming it. Check first; this never prompts:

```
b6p --json auth status
```

- If it prints `{"authenticated": false}` → STOP. Do **not** run the audit. Tell the user:
  > `b6p` has no BlueStep platform access token on this machine yet, so the audit would stop at a question I can't answer. Run `b6p auth set` once in your own terminal (it stores the token in `~/.b6p/`, once per machine), then retry `/b6p-audit <component>`.
- If it prints `{"authenticated": true}` → continue.

### 1. Identify the component

If `$ARGUMENTS` contains a component path (e.g. `U######/Combined Scheduler`), use it. If empty, ask the user which component to audit.

Confirm the component was pulled as a git clone: `U######/<ComponentName>/draft/.git` must exist. Without it the audit prints `The draft of "<name>" is not a git working copy yet, so there is nothing to compare it against. Pull the script first.`, compares nothing and exits `1`. Then suggest `/b6p-pull` — which may have to ask about moving the script to git first — and do not run it unasked.

### 2. Run the audit

Pass `--json` so the result is parseable, and `--file` to specify a file inside the component:

```
b6p --yes --json script audit --file "U######/<ComponentName>/draft/scripts/app.ts"
```

The CLI walks up from `--file` to find the component root, then compares each file against the platform.

### 3. Parse and summarise

Read the JSON output. The shape (each path starts with the component's folder name, e.g. `<ComponentName>/draft/scripts/app.ts`):

```json
{
  "changedFiles": ["<ComponentName>/draft/scripts/app.ts", "<ComponentName>/draft/static/script.ts (new)", ...],
  "baseUrl": "<DAV URL>"
}
```

- If `changedFiles` is empty: tell the user "Local is in sync with the platform."
- If non-empty: list each path and note which side has the newer version when you can tell (a `(new)` suffix means the file exists on the platform but not locally; otherwise the file exists on both sides with different content). `git -C "U######/<ComponentName>/draft" status` shows which of them you changed locally.
- Say what `/b6p-push` would do with each. A file that **changed on the platform** since the last push or pull from here (or was never synced from this machine) makes the push **stop before pushing anything** and ask whether to overwrite it. A file changed **only locally** is pushed without a question. A `(new)` file is on the platform but not here: if the platform added or changed it since your last sync, the push asks before deleting it and, with `--yes`, keeps it and copies it into your local `draft/`. **A file you deleted locally that the platform did not change is deleted on the platform by the push, with no question.**

### 4. Suggest a next step (do not auto-execute)

Based on the result, suggest:

- **In sync** → "Local is in sync. You can `/b6p-push <component>` safely if you have local changes."
- **Platform has changes you don't** → "Platform has changes not present locally. Consider `/b6p-pull` to sync before continuing work, especially if you're about to push."
- **You have local changes the platform doesn't** → "These changes exist only locally. They'll be pushed when you run `/b6p-push`."
- **Both sides changed** → "Both sides have diverged. `/b6p-push` will stop and ask before overwriting the platform copies, and a pull keeps the files you edited here instead of taking the platform copy (when this machine has a sync record for them) — neither merges. Decide file by file: open each one and merge by hand before pushing."

Never auto-pull or auto-push from inside this skill. The user drives the next step.

## What this skill must NOT do

- Do NOT pass `--pull` to `b6p script audit` (that flag would auto-sync; we want read-only).
- Do NOT chain into `/b6p-pull` or `/b6p-push` without the user asking.
- Do NOT invoke `b6p` any way other than the bare `b6p` binary, and never without `--yes`; use `b6p script audit`, not the deprecated top-level `b6p audit`.

## If the CLI fails

Three distinct failure modes — handle them differently:

- **`command not found` / `b6p` cannot be resolved** — the b6p-cli standalone binary is not installed (or not on `PATH`). Tell the user:
  > `b6p` could not be resolved. Install the b6p-cli standalone binary and make sure it is on your `PATH` (see its release/install instructions).
- **Exit `1` naming a question it could not answer** (`Enter your access token`) — not a tool failure: relay the message and tell the user to run `b6p auth set`, then retry.
- **Any other error** (network, a real auth rejection by the platform, etc.) — the audit is read-only, so failures are usually transient. Surface the raw error to the user and suggest retrying.
