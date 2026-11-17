---
description: "Since web 26.11.09 the platform compiles BsJs TypeScript itself, and since the release that makes scripts git-only every script write is a git commit. A gateway write_script_draft moves a WebDAV script to git (one-way) and commits the source with the server's build; a b6p 0.9 publish commits the CLI's build with a build manifest, and the platform refuses a stale or missing one (BUILD_STALE, BUILD_MANIFEST_MISSING, BUILD_MANIFEST_INVALID) or a moved draft (DRAFT_MOVED). The save gate and the compile block still apply to server compiles."
---

# The platform's own TypeScript compile

Since web release 26.11.09 the platform compiles a BsJs script's TypeScript on the server. Since
the web release that makes scripts git-only, a script's draft is a git repository: every write is a
commit to its `draft` branch, a publish moves `master` to a draft commit, and the platform refuses
every WebDAV write into `draft/` or `snapshot/` (HTTP 403). Which write reaches which compile
decides what you see:

| Write | What compiles | Status |
|---|---|---|
| `b6p push` without `--snapshot` (b6p 0.9) | Nothing. The working tree is committed to `draft` as it is; `.build/` holds whatever was in it. | release notes and b6p source |
| `b6p push --snapshot` (b6p 0.9) | The CLI compiles locally and commits the sources, its `.build/` and — only when the build is fully clean — the build manifest `.build/.b6p-build.json` in one commit, then publishes that commit (`takeSnapshot` with `expectedDraftSha`). The platform checks the manifest instead of recompiling (below). | release notes and b6p source; not yet run live |
| `b6p push` of any kind with b6p 0.8.x | Refused: its WebDAV PUTs get HTTP 403 ("This script is edited through git; use the BSJS editor or the b6p CLI.") on every script. | as reported (web #2000) |
| MCP `write_script_draft` of a source file | First a script still on WebDAV is **moved to git — one-way**. Then one commit to `draft` holds the source and the server's compiled `.build/` output, with a manifest when the compile vouches for it. The response carries `draftCommit` and a `compile` block (below). | compile verified 2026-11 on 26.11.09; the git part as reported (web #1994) |
| MCP `write_script_draft` of a file under `.build/` only | Nothing: a write into the output folder is not a compile trigger, and the response has no `compile` block. | verified 2026-11 on 26.11.09 |
| A save in the platform's BSJS editor | The git-only editor commits to `draft` through the platform's git proxy, under the user's own name and e-mail. | as reported (web #1992, #2000) |
| GraphQL `contents` or `applyCompileFix` (both discouraged) | Moves a WebDAV script to git first (one-way), then one commit to `draft`, compiled. | as reported (web #1994) |
| GraphQL `compileDraft: true` on a git script | The server builds the `draft` branch: a "Build draft" commit authored by the caller, with the manifest only when the build vouches for it. Optional `expectedDraftSha`; refusals `DRAFT_MOVED`, `BUILD_OUTCOME_UNKNOWN`, `DRAFT_TOO_LARGE`, `REPO_MISSING`, `DRAFT_BRANCH_MISSING`. b6p 0.9 does not call it; a later b6p (core 1.0) is planned to push sources only and let the server build. | as reported (web #2022) |
| GraphQL `takeSnapshot` (publish) of a git script | Checks the draft commit's build manifest, then moves `master` to it (below). | as reported (web #1994, #1992) |

Exempt from the manifest check, and never compiled on save or publish (as reported): a script with
no `tsconfig.json`, a draft with no TypeScript source (a `.d.ts` does not count), and a script set
`externallyBuilt` (its output is built somewhere else, such as a Vite bundle). That setting is the
script's own, on the platform. b6p's `--externally-built` flag only stops b6p writing a manifest; it
does not set the platform setting, so on a script without it the publish is refused.

Type errors without `noEmitOnError` are warnings for both the server and b6p 0.9: the build still
gets a manifest and publishes. An error in a `.d.ts` file never counts.

**A server write is a commit you do not have locally.** After a `write_script_draft`, an editor save
or a server build, run `b6p pull` before the next `b6p push`, or the push stops at its overwrite
question.

Never run `tsc` locally either way: it has no declarations wired up and leaves stray `.js` files.

## The save gate

A server compile writes new output only when it would not change what an **untouched** source runs.
For every source the write did not change (nor anything it imports), the new output must be the same
program as the `.build/` file it replaces. If not, the gate **trips**: the source is still saved,
nothing from that `tsconfig.json` project is written, and the script keeps running its previous
build (verified 2026-11 through `write_script_draft`, problem `OUTPUT_DIFFERS`). Outputs that are
the same program keep their old bytes.

What trips it (as reported, except `OUTPUT_DIFFERS`):

- **The new output differs** from the existing one (`OUTPUT_DIFFERS`): a `.build/` file written by
  hand, a bundled or minified build, or one an older compiler produced.
- **An existing output cannot be parsed**, so it cannot be compared.
- **The build would delete the output of a source still in the script.**
- **A configuration the server's compiler no longer honours** (for example `target` ES5 or `module`
  AMD). Accepting never overrides this one.
- **New output would replace a file the script runs today** (`OUTPUT_SHADOWS`), such as an empty
  `scripts/app.ts` compiling in front of a hand-written `scripts/app.js`. Here only that output is
  withheld — the project's other outputs are written — and accepting never overrides it. Removing or
  renaming the hand-written file through a non-WebDAV save releases it.

Clearing a trip is the author's decision, not a retry: **accept the new output** (GraphQL
`acceptNewOutput: true` on the script update, or the editor's accept action), set the script
`externallyBuilt` when its output really is built elsewhere, or fix the configuration. Ask the user
before any of them: accepting changes what an untouched source runs. From web 26.11.09.01 a trip
over output that looks bundled carries a warning that suggests `externallyBuilt` (as reported).
Rewriting the same source again trips again.

## Reading the `compile` block of an MCP write

```json
"compile": [{
  "status": "GATE_TRIPPED", "errors": 2, "written": 0, "deleted": 0,
  "diagnostics": [{ "origin": "ENGINE", "severity": "ERROR", "file": ".build/scripts/app.js",
    "message": "the new build of scripts/app.ts would change the program .build/scripts/app.js runs. …" }],
  "gate": { "tripped": true, "withheld": ["tsconfig.json"],
    "problems": [{ "kind": "OUTPUT_DIFFERS", "file": ".build/scripts/app.js", "accepted": false }] }
}]
```

- `status: COMPILED` with `gate.tripped: false` — the draft's `.build/` now holds the new output.
- `status: GATE_TRIPPED` — the write itself succeeded (`filesWritten` lists the source) but output
  was held back. Tell the user which file and why (`gate.problems`); do not loop on the write.
- TypeScript errors in your own source show up in `diagnostics` with `status: COMPILED`; they do not
  stop the output unless the project sets `noEmitOnError`.
- `NOTHING_TO_COMPILE` — the script has no `tsconfig.json` (as reported).
- `BUSY`, `COMPILER_UNAVAILABLE`, `INPUT_INCOMPLETE`, `WRITE_FAILED`, `NOT_PERMITTED` — the compile
  did not run through; the source is saved, the old build kept (as reported).

A draft write is still a draft: nothing is live until the script is published.

## Publish refusals

A publish that is refused fails with the GraphQL error code `PUBLISH_REFUSED`, its reason in
`extensions.reason`, and changes nothing: `master`, `snapshot/` and the live version stay as they
were. b6p 0.9 shows the reason in `publishRefusal` or `publishError` (the `b6p-push` skill, step 5).

**A git script** (every script, once the git-only release is live) publishes the draft commit it is
given (as reported, web #1994 and #1992):

| Reason | Meaning | What to do |
|---|---|---|
| `BUILD_STALE` | a source changed after the build in the manifest; `extensions.publish.withheld` lists the stale files | rebuild and push again (a b6p publish rebuilds) |
| `BUILD_MANIFEST_MISSING` | the draft has TypeScript sources but no `.b6p-build.json`, or the build was not clean enough to get one | fix the build errors and publish again without `--externally-built` |
| `BUILD_MANIFEST_INVALID` | the manifest cannot be read | rebuild and push again; never edit it by hand |
| `DRAFT_MOVED` | someone pushed to `draft` between the commit and the publish (`expectedDraftSha`) | run the same b6p publish again: it stops at its overwrite question if the other commit touched your files |

**A WebDAV script** (only on a server without the git-only release) compiles first, against the
published copies of the scripts it imports, and publishes only when that compile is clean. The
reasons are the org's `PublishRefusalReason` enum (read on an org 2026-11; when each one fires is as
reported):

| Reason | Meaning |
|---|---|
| `GATE_TRIPPED` | the save gate holds back output of a project (see above) |
| `EMIT_WITHHELD` | `noEmitOnError` and errors in the project's own sources withheld its whole output (`compileDraft` reports the same status) |
| `ENTRYPOINT_MISSING` | the main entrypoint runs a compiled file today and the publish would leave none |
| `OUTPUT_SHADOWS` | new output would replace a file the script runs today (see the save gate) |
| `COMPILER_UNAVAILABLE`, `BUSY`, `INPUT_INCOMPLETE`, `WRITE_FAILED`, `NOT_PERMITTED` | the compile could not run through, or the user may not edit the script |
