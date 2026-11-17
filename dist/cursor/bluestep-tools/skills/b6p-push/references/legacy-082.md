# `b6p-legacy` (b6p 0.8.2) — a push to an org without the git-only release (read by `/b6p-push` step 4 when step 0 picks `b6p-legacy`)

**Temporary.** While the git-only web release reaches namespaces one at a time, an org that does not have it yet (it serves a release before 26.11.17.00) has no git publishing for scripts: b6p 1.0 cannot push there. Its scripts still take b6p 0.8.2, installed beside b6p 1.0 under its own name, `b6p-legacy`. This file goes away with `b6p-legacy` once every namespace has the release.

Steps 1–3 of `/b6p-push` are the same. With 0.8.2 there is no commit author and no `draft/.git`: step 2's diff scope comes from the project's own `git status` for `U######/<ComponentName>/draft/`.

## Run the push

**Publish:**

```
b6p-legacy --yes --json push --file "U######/<ComponentName>/draft/scripts/app.ts" --snapshot --message "<description>"
```

**Save draft only:**

```
b6p-legacy --yes --json push --file "U######/<ComponentName>/draft/scripts/app.ts"
```

0.8.2 has no `script` namespace: the command is `b6p-legacy push`. `--yes` takes the safe answer of every question (**Cancel** to overwriting, **No** to deleting). The publish compiles in the CLI and uploads over WebDAV, which an org without the release still accepts.

**Every command b6p 0.8.2 prints starts with `b6p`.** Before running one (step "Stop and ask" or "Kept files" below), change that first word to `b6p-legacy` and nothing else: run as printed, it would start b6p 1.0 against this org.

- **`Missing metadata`** from `--file`: the `--root` push in `references/root-fallback.md`, with `b6p-legacy push` in place of `b6p script push`.
- **`Stale client bundle`** on a draft-only push: `draft/static/script.ts` is newer than its `.build/script.js`, and a plain push uploads the old client JS. Tell the user; a publish ships fresh client JS.

## Read the result

The exit code and the `--json` object are the success signal. The object has seven fields — `pushed`, `historyRecorded`, `typeCheckDiagnostics`, `liveVerified`, `liveMismatches`, `keptPlatformOnly`, `declinedOverwrites` — and no `error` field; after a cancelled target-URL question it is `{"cancelled": true}`. Act on every row that matches, top to bottom; the last row only when no other matched:

| Exit | `--json` | What happened | What to do |
|---|---|---|---|
| `1` | `pushed: false`, files in `declinedOverwrites` | Stopped before uploading: those files changed on the platform | **Stop and ask**, below |
| `1` | `pushed: false`, `declinedOverwrites: []` | Nothing uploaded: the compiled entrypoint is missing or has no code (`Snapshot not published: …`), a wrong `--root`, or an empty `draft/` | Fix the cause, re-run |
| `1` | `liveVerified: false`, files in `liveMismatches` | Uploaded, but those live copies are still missing or wrong after one re-send; no restore point | Say the live version may be broken; offer to re-run the publish |
| `1` | `historyRecorded: false` | Published without its restore point: no rollback | Say so; offer to re-run the publish |
| `1` | `typeCheckDiagnostics` above `0` | Live, but not type-clean (0.8.2 fails the push on type errors) | Treat them as real: `references/type-check-diagnostics.md` |
| `1` | `HTTP Error: 403` on stderr | The org has the git-only release after all, which refuses every WebDAV write | Run step 0's pick again; the org now takes `b6p` |
| `1` | stdout empty | A thrown failure (an upload refused, a question with no input); details on stderr | Read stderr; "If the CLI fails" in `/b6p-push` |
| `0` or `1` | files in `keptPlatformOnly` | Pushed; platform-only files kept | **Kept files**, below |
| `0` or `1` | `liveVerified: null` on a publish | Published; the live copy was not checked | Say so; confirm which build is live |
| `0` | `{"cancelled": true}` | Target-URL question cancelled | Nothing pushed; say so |
| `0` | anything else | Pushed | Report as `/b6p-push` step 5 says |

On a draft-only push `typeCheckDiagnostics` and `liveVerified` are `null` — not a warning — and `historyRecorded` is `true` although no restore point is made.

**Stop and ask** (exit `1`, `declinedOverwrites` lists files). stderr lists each file with its reason and ends with the command that overwrites them (`b6p --yes --json push … --overwrite <file>`). Show the user the files and reasons, suggest `/b6p-audit` or `/b6p-pull`, and ask as `/b6p-push` step 5 does. Only on *Overwrite*: run the printed command with its first word changed to `b6p-legacy`, nothing else.

**Kept files** (`keptPlatformOnly` lists files). With 0.8.2 the files stay on the platform only (they are not copied into the local draft). Ask: keep them (recommended), pull them (`/b6p-pull`), or delete them from the platform. Only on *Delete*: run the printed command (`printf 'Yes\n' | b6p --json push …`, or `'Yes' | b6p …` under PowerShell) with `b6p` changed to `b6p-legacy`. If that run stops at an overwrite question, run the publish or draft push again instead and follow what it prints.

**Report.** Published → live, with a restore point in the component's version history; then `references/verify-live-build.md`. Saved a draft only → not live yet.
