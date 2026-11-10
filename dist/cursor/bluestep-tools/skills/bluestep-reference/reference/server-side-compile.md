---
description: "Since web 26.11.09 the platform compiles BsJs TypeScript itself: a GraphQL, MCP or editor save recompiles the draft behind a save gate, and a GraphQL publish compiles and can refuse. WebDAV writes (b6p 0.8.x) still compile nothing, and a b6p 0.8.x publish is neither recompiled nor gated."
---

# The platform's own TypeScript compile

Since web release 26.11.09 the platform compiles a BsJs script's TypeScript on the server. Which
write reaches that compile decides what you see:

| Write | What compiles | Status |
|---|---|---|
| `b6p push` without `--snapshot` (b6p 0.8.x, WebDAV) | Nothing. The source is saved; the draft's `.build/` stays as it was. | verified 2026-11 |
| `b6p push --snapshot` (b6p 0.8.x) | The CLI compiles locally and uploads its own `.build/`, then copies every file into `snapshot/` over WebDAV. The platform does not recompile or check it: the publish went live with the draft's save gate tripped. | verified 2026-11 |
| MCP `write_script_draft` of a source file | The whole draft, on the server, in the same write. The response carries a `compile` block (below); the draft's `.build/` holds the server's output. | verified 2026-11 |
| MCP `write_script_draft` of a file under `.build/` only | Nothing: a write into the output folder is not a compile trigger, and the response has no `compile` block. | verified 2026-11 |
| A save in the platform's script editor, or a GraphQL script write | The whole draft, as for an MCP write. | as reported |
| GraphQL `compileDraft: true` on a script update | The whole script, with every source counted as changed, so no output is held back for differing. | as reported |
| GraphQL `takeSnapshot` (publish) | The whole script, against the published (snapshot) copies of the scripts it imports, then publishes or refuses (below). This is how b6p 0.9 publishes (not released as of 2026-11-10). | as reported |

A script with no `tsconfig.json`, or one set `externallyBuilt` (its output is built somewhere else,
such as a Vite bundle), is never compiled: saves and publishes copy it as it is (as reported).

Never run `tsc` locally either way: it has no declarations wired up and leaves stray `.js` files.

## The save gate

A server compile writes new output only when it would not change what an **untouched** source runs.
For every source the write did not change (nor anything it imports), the new output must be the same
program as the `.build/` file it replaces. If not, the gate **trips**: the source is still saved,
**nothing** from that `tsconfig.json` project is written, and the script keeps running its previous
build (verified 2026-11 through `write_script_draft`). Outputs that are the same program keep their
old bytes.

Typical causes: a `.build/` file written by hand, a bundled or minified build, or one an older
compiler produced. A configuration the server's compiler no longer honours (for example `target`
ES5 or `module` AMD) trips too, and accepting never overrides that (as reported).

Clearing a trip is the author's decision, not a retry: **accept the new output** (GraphQL
`acceptNewOutput: true` on the script update, or the editor's accept action), set the script
`externallyBuilt` when its output really is built elsewhere, or fix the configuration. From web
26.11.09.01 a trip over output that looks bundled carries a warning that suggests `externallyBuilt`
(as reported). Rewriting the same source again trips again.

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
- `status: GATE_TRIPPED` — the write itself succeeded (`filesWritten` lists the source) but no output
  was written. Tell the user which file and why (`gate.problems`); do not loop on the write.
- TypeScript errors in your own source show up in `diagnostics` with `status: COMPILED`; they do not
  stop the output unless the project sets `noEmitOnError` (then `EMIT_WITHHELD`).
- `BUSY`, `COMPILER_UNAVAILABLE`, `INPUT_INCOMPLETE`, `WRITE_FAILED`, `NOT_PERMITTED` — the compile
  did not run through; the source is saved, the old build kept (as reported).

A draft write is still a draft: nothing is live until the script is published.

## Publish refusals (GraphQL `takeSnapshot`)

A publish through GraphQL compiles first and publishes only when that compile is clean. Otherwise it
fails with the GraphQL error code `PUBLISH_REFUSED`, its reason in `extensions.reason`, and changes
nothing — snapshot and script row stay as they were. The reasons are the org's
`PublishRefusalReason` enum (read on an org 2026-11; when each one fires is as reported):

| Reason | Meaning |
|---|---|
| `GATE_TRIPPED` | the save gate holds back output of a project (see above) |
| `EMIT_WITHHELD` | `noEmitOnError` and errors in the project's own sources |
| `ENTRYPOINT_MISSING` | the main entrypoint runs a compiled file today and the publish would leave none |
| `OUTPUT_SHADOWS` | new output would replace a file the script runs today, such as a compiled empty `scripts/app.ts` in front of a hand-written `scripts/app.js` |
| `COMPILER_UNAVAILABLE`, `BUSY`, `INPUT_INCOMPLETE`, `WRITE_FAILED`, `NOT_PERMITTED` | the compile could not run through, or the user may not edit the script |

A b6p 0.8.x publish never meets these: it copies over WebDAV (first table).
