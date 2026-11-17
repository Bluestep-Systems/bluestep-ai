---
description: BlueStep Platform overview — architecture (Relate/Connect/Manage/BsJs), the b6p CLI, sync, and component lifecycle. Read when orienting on the platform, working with the b6p CLI, or troubleshooting pull/push sync.
---

# B6P Platform Workflow

Platform orientation plus the workflow reference for sync, lifecycle, and the b6p CLI. Critical rules live in `AGENTS.md`; on-demand detail lives in the skill index (`SKILL.md`).

## Contents

- [Platform architecture](#platform-architecture)
- [Workspace model](#workspace-model)
- [Data hierarchy](#data-hierarchy)
- [Script types](#script-types)
- [Anonymous access — two independent grants](#anonymous-access--two-independent-grants)
- [b6p CLI workflow](#b6p-cli-workflow)
- [Sync metadata](#sync-metadata)
- [Files Claude must never edit](#files-claude-must-never-edit)
- [Imports — verification flow](#imports--verification-flow)
- [When the CLI fails](#when-the-cli-fails)
- [When `B.commit()` is required](#when-bcommit-is-required)

## Platform architecture

The BlueStep Platform is three web applications over one shared data layer:

- **Relate** — the database and configuration layer. Defines the data model (**Type → Category → Form → Field**) and holds all structured records.
- **Connect** — end-user web pages that view or enter Relate data. Connect pages embed MergeReports.
- **Manage** — the administrative counterpart to Connect; also hosts MergeReports.
- **BlueStep.js (BsJs)** — the TypeScript library used to build the three component types: MergeReports, Endpoints, and Formulas. Patterns and APIs: `bsjs-development.md`.

**Relate data model (configuration view).** A **Type** is a high-level entity (Individual, Organization, Event); a **Category** sub-classifies it (Staff, Volunteer, Client) — a record has one Type and zero or more Categories; a **Form** is a named group of fields; a **Field** is one data element. This is the *configuration* model; the runtime/storage nesting is in "Data hierarchy" below.

### MergeReports are embedded, not standalone

A MergeReport does not render a whole page. Connect (or Manage) supplies the page shell — `<html>`/`<head>`/`<body>`, site navigation, and branding — and the MergeReport's `pageContent()` output and `static/index.html` are injected into it. Write MergeReport frontend assuming the host page already exists; do not emit a full HTML document. Detail: `reference/merge-report-static-index.md`, `reference/component-library.md`.

- `B.siteNavigation()` — the host site's navigation tree.
- `B.isLayout("MANAGE")` — branch on whether the page is a Manage or Connect layout.
- `B.optUser` / `B.user` — the logged-in user (`B.user` is null in scheduled scripts; see "Script types").

## Workspace model

The workspace is a **local copy** of components that live on the BlueStep platform. The platform is the source of truth.

- New B6P components (MergeReport, Endpoint, Formula) are created **on the platform**, never locally.
- Inside an existing component, creating new `.ts` files locally is fine — they ship to the platform on `push`.
- A script's draft is a **git repository** on the platform (b6p 1.0 and the web release that makes scripts git-only). `draft/` is a clone of it with its own `draft/.git`; a push is a commit, a publish moves the live branch (`master`) to that commit, and the script's history is its git history. The platform refuses every older WebDAV write into `draft/` or `snapshot/` (HTTP 403), so b6p 0.8.x and hand uploads no longer work.
- The **platform** builds every b6p push (b6p 1.0 bundles no compiler): it adds a "Build draft" commit with the output, plus a build manifest when the build is clean, and b6p moves the local `draft/` to it. A publish push (`b6p script push --snapshot`) publishes that build; a plain push leaves the live version alone. The platform also compiles when a script is saved through the gateway MCP, GraphQL or its editor — see `reference/server-side-compile.md`. Never run `tsc` by hand.

## Data hierarchy

```
Organization
└── Unit (folder: U######)
    └── BaseRecord
        └── Form
            └── Entry
                └── Field
```

Queries, scripts, and permissions are scoped per Unit by default. A local project may pull components from multiple Units; each lives under its own `U######/` folder created by `b6p script pull` on first pull.

<!-- CONFLICT: U###### identity — this overview treats U###### as the Unit folder created by `b6p script pull` (nested under an Organization). Another platform-overview source labels U###### as the Organization's own ID. Needs human resolution. -->

## Script types

| Type           | `B.user` available | Notes                                              |
|----------------|--------------------|----------------------------------------------------|
| Post-Save      | Yes                | Runs after a record is saved                       |
| MergeReport    | Yes                | Page renderer; frontend in `static/`               |
| Endpoint       | Yes                | HTTP-style request handler                         |
| OnDemand       | Yes                | User-triggered formula — runs on the task pod; ~5 s scheduler-queue delay before start |
| Field Formula  | Yes                | Computes a field's value                           |
| Scheduled      | **No (null)**      | Runs on cron; guard `B.user` accordingly           |
| Section Script | Yes                | Page section logic                                 |

### OnDemand — async/background use cases

OnDemand formulas execute on the **task pod**, making them appropriate for heavy or long-running work that should not run on a production pod. They are a good fit for async, background, or batch tasks.

**Do not use OnDemand on a user's synchronous wait path.** The platform's scheduler queues the formula and starts it "as soon as possible," but that incurs a ~5 second delay before execution begins. For user-facing create or update flows where latency matters, use a synchronous task-pod **Endpoint** instead. See `bsjs-development.md` → "OnDemand / Field Formula" for code patterns.

## Anonymous access — two independent grants

Serving anything to an **unauthenticated visitor** needs **two independent grants**, and they are
easy to miss because failing either produces a different symptom:

- **"Everyone: Reader" on the ENDPOINT** — grants execute.
- **"Everyone: Relate Author" on the FORM** — grants create.

Both are required for an anonymous write. **Anonymous writes need NO elevated script authority**
(verified live, before web 26.11.09 — on a script with `legacyPermissions: true` it still holds) —
the natural assumption is the opposite, and an elevated-authority fallback is expensive to build for
nothing.

**A new script checks the visitor's reads as well.** An endpoint created since web 26.11.09 has
`legacyPermissions: false` and applies the anonymous visitor's permissions to what it reads and
writes: a query over the form where Everyone is Relate Author was refused as depending on a field
the visitor may not view (seen 2026-11; the grant that would let it run was not found). Read the
script's flag, test as the visitor, and see `reference/script-permission-checks.md`.

The diagnostic cleanly separates the two failure modes:

| Response | Meaning |
| --- | --- |
| `403` | existing alias, no permission — fix the grants above |
| `500` Error | unknown alias — wrong path, the endpoint was never reached |

For the unauthenticated-fallback *behavior* on an endpoint (clean `401` vs a JSON-breaking `302`
login redirect via "Request HTTP authentication"), see `reference/session-cookie-forwarding.md` —
that setting is adjacent to, but distinct from, the grants themselves.

## b6p CLI workflow

`b6p` is a standalone binary on the system `PATH` (the b6p-cli standalone artifact, installed separately from this tooling). Invoke it directly — no `npx`, no devDependency, no `npm install`. The shape is:

```
b6p <subcommand> ...
```

### Pull a component

```
b6p script pull "<DAV URL>"
```

**`b6p script pull` takes a DAV URL, not a display name.** The URL is copied from the component's page in the BlueStep platform UI. There is no name-based lookup; the CLI has no way to find a component by its label.

`b6p script pull --help` reference:

```
Usage: b6p script pull [options] [formula-url]

Pull a script from a WebDAV location

Options:
  --file <path>       Derive source from local file metadata
  --workspace <path>  Target workspace folder (default: cwd)
```

A successful first pull:

- Creates the `U######/` folder (if not present) and the `<ComponentName>/` subfolder under it
- Clones the script's git draft into `draft/` (with `draft/.git`): `draft/scripts/` and (in older modules) `draft/objects/`; `draft/info/` is **legacy and usually absent** — see below. Its absence is normal, not a broken pull. A script still on WebDAV must be moved to git first (one-way); the pull asks, and `--yes` declines and writes nothing (the `b6p-pull` skill, step 2)
- Populates `declarations/` with the platform-generated `.d.ts` files, including `declarations/index.d.ts` (field/query/form declarations)
- Records the component's sync metadata (WebDAV id, file hashes, script key) so future pulls/pushes can resolve it

Subsequent pulls fetch and fast-forward the clone. A local edit to a file the platform also changed is **kept**, and every kept file is listed in one warning at the end (`keptLocalPaths`). The local `snapshot/` folder is no longer refreshed: the published code is the `master` branch in `draft/.git`. A folder pulled before git (files, no `draft/.git`) is bound to the repository in place; a file that differs is replaced unless its old, machine-local sync record says it was edited here.

### `draft/info/` is deprecated — read it, never expect it

`draft/info/` (`metadata.json`, `config.json`, `permissions.json`) is **deprecated platform behavior**, not a pull that went wrong. Newly-created formulas never get it — that configuration now lives on the component's **setup page**, readable through the gateway MCP inspector (see `conventions/mcp-platform-authoring.md`). Components created years ago still serve it, so treat it as **legacy, read-only when present**:

- Never make a step conditional on `draft/info/` existing, and never report its absence as a problem.
- Need the component type, display name, paths/methods or permissions? Read `draft/info/metadata.json` **if it happens to be there**; otherwise go to the setup page via the gateway MCP, or infer the type from `draft/scripts/app.ts` and the folder shape.
- Do not write or recreate `draft/info/` locally to "fix" its absence.

Tracked as ClickUp 86bb91km5 (platform-side; the CLI is faithfully mirroring what WebDAV serves).

### Push a component

The cleanest way to push an already-pulled component is `--file`, which lets the CLI derive the destination DAV URL from the recorded sync metadata:

```
b6p script push --file "U######/<Component>/draft/scripts/app.ts"
```

Any file inside the component works as the `--file` argument; the CLI walks up to find the component root and looks up its recorded sync metadata. A push commits the working tree of `draft/` and pushes the `draft` branch; it needs a commit author (`b6p config set author "Name <email>"`, or `git config user.name`/`user.email`). A plain push commits the draft source **as-is** — it does **not** compile and does **not** change the live version. Only a **publish/snapshot** (`b6p script push --snapshot --message "…"`) runs the TypeScript build — in the CLI, covering `scripts/` and any `static/` bundle — commits the emitted JS and the build manifest `.b6p-build.json` with the source, and publishes that commit. Type errors are warnings since 0.9.0; the `/b6p-push` skill reads the result.

### No VS Code fallback

The VS Code b6p extension has **not** been updated for git-only scripts: do not use it to pull or push. The other supported way to change a script is the platform's own BSJS editor, which commits to the same repository; pull before the next push after anyone saves there.

## Sync metadata

Auto-managed by the CLI and stored internally (no longer a `.b6p_metadata.json` file in the workspace; legacy files are migrated on first run). Tracks WebDAV IDs, last-pull / last-push timestamps, file hashes, and script keys, so pull/push/audit can resolve each component. The history of the files themselves is in `draft/.git`. Not something you edit, and neither is anything under `draft/.git/` or a `.b6p-build.json`.

## Files Claude must never edit

Enforced by the `block-generated-files` hook:

- Anything under `declarations/`
- `B.d.ts`, `scriptlibrary.d.ts`, `Globals.d.ts`
- `.b6p-build.json` (the build manifest the platform writes after a clean build) and anything under `draft/.git/`
- (Treat `declarations/index.d.ts` as platform-generated — it regenerates on pull. `draft/objects/imports.ts` is a legacy artifact in older modules; do not edit it either.)

If declarations are wrong, fix it on the platform and pull, not by editing locally.

## Imports — verification flow

Form-field imports are **per-component**. Each component independently declares which fields of a form it imports. A field present in component A's `declarations/index.d.ts` is not visible to component B unless B's import config was updated on the platform and B was pulled separately.

Before referencing a query/form/field in code:

1. Open **the component you are editing**'s `declarations/index.d.ts` and confirm the name exists. Another component's declarations file tells you nothing.
2. In older modules, `draft/objects/imports.ts` may also exist as a legacy artifact — ignore it for verification; new declarations land in `declarations/index.d.ts`.
3. If missing:
   - Add the field to **this component's** form-import config on the platform.
   - `b6p script pull "<DAV URL>"` to regenerate this component's declarations.
   - Then write the TypeScript reference.

If N components all need the same new field, each one needs its own import-config update on the platform and a separate pull.

Hallucinated names are caught at publish only after they ship: the publish type-check runs with the component's `declarations/`, so a fabricated name shows up as a `Cannot find name` diagnostic from the platform's build — a warning, so the push exits `0` and the code is live (see the `/b6p-push` skill's `references/type-check-diagnostics.md`). The only gate before that is checking `declarations/index.d.ts` before writing the reference.

## When the CLI fails

Common causes:

- `b6p` cannot be found — the b6p-cli standalone binary isn't installed or isn't on `PATH`. Install it from its release.
- Network/auth issue with the platform. Re-authenticate with `b6p auth set`.
- Local file lock. Close the editor that holds the file, retry.
- No commit author. `b6p config set author "Name <email>"`, once.

Fallbacks:

1. The platform's BSJS editor works on the same git repository; after a save there, pull before the next push.
2. Manual uploads (WebDAV, the platform's file screens) into `draft/` or `snapshot/` are refused with HTTP 403 since the git-only release. The VS Code b6p extension is not a fallback: it has not been updated for git-only scripts.

## When `B.commit()` is required

The platform commits automatically when a script finishes. Call `B.commit()` manually only when:

- A new entry's `id` is needed before the script ends.
- A subsequent read in the same script must see writes that haven't fired post-saves yet.

In most scripts, manual `B.commit()` is unnecessary.
