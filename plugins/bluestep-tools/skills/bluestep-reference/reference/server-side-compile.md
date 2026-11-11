---
description: "Since web 26.11.09 the platform compiles BsJs TypeScript itself: a GraphQL, MCP or editor save recompiles the draft behind a save gate, and a GraphQL publish compiles and can refuse. On 26.11.09.x, WebDAV writes (b6p 0.8.x) compile nothing, so a b6p 0.8.x publish goes live with the CLI's build."
---

# The platform's own TypeScript compile

Since web release 26.11.09 the platform compiles a BsJs script's TypeScript on the server. Which
write reaches that compile decides what you see:

| Write | What compiles | Status |
|---|---|---|
| `b6p push` without `--snapshot` (b6p 0.8.x, WebDAV) | Nothing. The source is saved; the draft's `.build/` stays as it was. | verified 2026-11 |
| `b6p push --snapshot` (b6p 0.8.x) | The CLI compiles locally and PUTs its own `.build/` and every other file into `draft/` and `snapshot/` over WebDAV. WebDAV writes compile nothing, so what goes live is the CLI's build (verified 2026-11: the live endpoint served the CLI's build). On 26.11.09.x a PUT into `snapshot/` also skips the publish gate below (as reported); a later web release may route these publishes through it. | verified / as reported |
| MCP `write_script_draft` of a source file | The whole draft, on the server, in the same write. The response carries a `compile` block (below); the draft's `.build/` holds the server's output. | verified 2026-11 |
| MCP `write_script_draft` of a file under `.build/` only | Nothing: a write into the output folder is not a compile trigger, and the response has no `compile` block. | verified 2026-11 |
| A save in the platform's script editor, or a GraphQL script write | The whole draft, as for an MCP write. | as reported |
| GraphQL `compileDraft: true` on a script update | The whole script, every source counted as the author's, so no output is held back for differing. A project is still held back for an existing output it cannot parse, a configuration the server cannot honour, or a build that would delete the output of a source still in the script. b6p 0.9 sends this after every push. | as reported |
| GraphQL `takeSnapshot` (publish) | The whole script, against the published (snapshot) copies of the scripts it imports, then publishes or refuses (below). b6p 0.9 publishes this way. | as reported |

Never compiled, on save or publish (as reported): a script with no `tsconfig.json` and one set
`externallyBuilt` (its output is built somewhere else, such as a Vite bundle) are copied as they
are; a git-managed script is not compiled on save, and its publish works as before.

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

## Publish refusals (GraphQL `takeSnapshot`)

A publish through GraphQL compiles first and publishes only when that compile is clean. Otherwise it
fails with the GraphQL error code `PUBLISH_REFUSED`, its reason in `extensions.reason`, and changes
nothing — snapshot and script row stay as they were. The reasons are the org's
`PublishRefusalReason` enum (read on an org 2026-11; when each one fires is as reported):

| Reason | Meaning |
|---|---|
| `GATE_TRIPPED` | the save gate holds back output of a project (see above) |
| `EMIT_WITHHELD` | `noEmitOnError` and errors in the project's own sources withheld its whole output (`compileDraft` reports the same status) |
| `ENTRYPOINT_MISSING` | the main entrypoint runs a compiled file today and the publish would leave none |
| `OUTPUT_SHADOWS` | new output would replace a file the script runs today (see the save gate) |
| `COMPILER_UNAVAILABLE`, `BUSY`, `INPUT_INCOMPLETE`, `WRITE_FAILED`, `NOT_PERMITTED` | the compile could not run through, or the user may not edit the script |

On 26.11.09.x a b6p 0.8.x publish does not go through `takeSnapshot`, so it meets none of these (first
table).
