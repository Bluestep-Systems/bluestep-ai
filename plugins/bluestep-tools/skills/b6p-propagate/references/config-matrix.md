# Config matrix — how to read, write and refresh each setting

Read by `/b6p-propagate` when it builds a target's plan (config step) and when it creates an object a
target lacks. Every route here was measured on both platform release lines; a route not listed has
not been proven, so the item is a "check by hand" line.

## Before you read the tables

**Which release line an org is on.** Read `list_org_tools(org)` once per org per move:

| Line | Tells it apart | Tool names |
|---|---|---|
| newer | `script_forms` is listed; `graphql_query` is not | merged tools: `script_forms`, `script_queries`, `script_record_types`, `script_field_access`; `set_permissions` with `mode` |
| older | `add_forms` and `graphql_query` are listed | `add_forms`, `add_queries`, `add_record_types`, `add_field_access`; `grant_permission`; gateway `graphql_query` |

An org can move from the older line to the newer one between two sessions, or during a move. A
`TOOL_NOT_FOUND` means: read `list_org_tools` again and use that line's names. Never guess a name.

**Labels used below.**
- **gateway** — an `invoke_org_tool` call. Writes follow the `bluestep-reference` skill's
  `conventions/mcp-platform-authoring.md` (target `org`, `expectedVersion` read in this move).
- **`/gql` only** — no gateway tool reads or writes it on the newer line. On an org that still
  serves `graphql_query` (older line), the read goes through it (`remoteObject(id)` on
  `ScriptFormula`, `ScriptEndpoint`, `ScriptMergeReport`). Otherwise it **needs a browser the agent
  drives, signed in to that org — check by hand on the CLI, Cursor, Codex.** How to pick the route
  (the gateway's GraphQL tools where the org serves them, else a tab) and run the call: the
  `bluestep-reference` skill's `reference/gql-in-a-tab.md`. Look up the
  input type with `get_schema` before a write. Only one GraphQL write was run in the prove-out
  (`updateScriptFormula` with `runImmediate`); the other write routes come from the input types.
- **check by hand** — no tool route at all. It is always a line in the plan and the report for a
  person, never assumed equal.

An item this surface cannot read on an org is a "check by hand" line for that org. Never skip it
and never treat it as equal.

**Refresh default.** A refresh copies a target's config onto the source. Four items are **held**:
`schedule` (with its time zone), `disabled`, `runImmediate` and `formulaType` are not copied onto
the source without a separate yes to a question that names the risk (for example: "This turns the
nightly schedule off in the source."). Every other item follows the plan.

**`legacyPermissions` is held both ways.** A change applies to the script's next run with no
publish, so never copy it onto a source or a target as part of a move or refresh. When source and
target differ, list it in the plan and ask a separate question that names the risk (for example:
"This makes the live <script> check its callers' permissions from its next run."). Never plan
turning it on in a target just to match the source: that is for a super administrator to decide,
and a script created in a target always starts `false`.

## Part 1 — script config, per type

### All scripts (formulas, endpoints, merge reports)

| Item | Read | Write (newer / older) | Refresh |
|---|---|---|---|
| form imports | newer: `inspector` (`uses[]`); older: `graphql_query` (`formulaDependencyGroups`) | `script_forms` / `add_forms` | plan |
| query imports | newer: `inspector`; older: `graphql_query` | `script_queries` / `add_queries` | plan |
| field access and writable | `list_field_access` | `script_field_access` / `add_field_access` | plan |
| scope (categories) | `list_script_scope` | `set_category_requirement` | plan |
| permissions | `list_permissions` | `set_permissions` with `mode: MERGE` / `grant_permission` (the older `set_permissions` replaces the whole list) | plan |
| alt id in the FID namespace | only inside the `topId` (`…__FID_<name>`) | `update_script` `altIds` | plan |
| other alt-id namespaces | `/gql` only | `/gql` only | plan |
| Fixed ID | `/gql` only | `/gql` only | plan |
| `configJson` | `/gql` only | `/gql` only | plan |
| description | `/gql` only | `update_script` `description` (run on the newer line) | plan |
| name | `get_script`, `lookup_script_by_name` | check by hand: `update_script` `name` does not rename | plan |
| `legacyPermissions` | `get_script`, `lookup_script_by_name` (since web 26.11.09; measured on the newer line only) | `update_script` `legacyPermissions`; turning it on needs a super administrator. A script created in the target reads `false` (the bluestep-reference skill's `reference/script-permission-checks.md`) | **held**, both ways (see above) |
| `externallyBuilt` | `/gql` only (as reported, not measured) | `/gql` only (as reported, not measured). A script created in the target lacks it, so a bundled build there trips the save gate on its next server save | plan |

### Formulas

| Item | Read | Write (both lines) | Refresh |
|---|---|---|---|
| `formulaType` | `get_script`, `lookup_script_by_name` | `update_script` (send what the new type needs in the same call; see the authoring page) | **held** |
| primary form | `get_script`, `lookup_script_by_name` | `update_script` | plan |
| schedule and time zone | `get_script` (`schedule{kind, dailyTimes, timeZoneId}`), `lookup_script_by_name` | `update_script` `schedule` | **held** |
| On-Demand Identifier | `lookup_script_by_name` only (`onDemandIdentifier`) | `update_script` `onDemandIdentifier` | plan |
| record types | `list_script_scope` (`recordTypes`) | `script_record_types` / `add_record_types`, or `update_script` `recordTypes` | plan |
| unit, `includeSubUnits` | `/gql` only | `update_script` `unitId`, `includeSubUnits` | plan |
| `disabled` | `/gql` only | `/gql` only | **held** |
| `runImmediate` | `/gql` only | `/gql` only (`updateScriptFormula`); the save runs the formula, see Part 2 | **held** |

### Endpoints

| Item | Read | Write (both lines) | Refresh |
|---|---|---|---|
| path | `get_script` (`endpointPath`, `endpointUrl`) | at create only: `create_script` `path`; a change after create is `/gql` only | plan |
| methods, `httpOption`, `runAsSuper`, basic permission, IP filter | `/gql` only | `/gql` only | plan |
| `disabled` | `/gql` only | `/gql` only | **held** |
| `requireHTTPS`, `hasIPAccessControl` | `/gql` only | check by hand (not in the update input) | plan |

`get_script` on an endpoint returns only `endpointPath` and `endpointUrl`; every other endpoint
setting is `/gql` only.

### Merge reports

| Item | Read | Write (both lines) | Refresh |
|---|---|---|---|
| settings flags | `/gql` only | `/gql` only | plan |
| `expiresBy`, `pageKind`, `webView` | `/gql` only | check by hand (not in the update input) | plan |

**On the newer line, without a driven browser**, these are always "check by hand" lines: every
endpoint and merge report setting except the endpoint path, a formula's `disabled`,
`runImmediate`, unit and `includeSubUnits`, Fixed ID, `configJson` and the description.

## Part 2 — scheduled formulas and `runImmediate`

Measured on a playground formula with a schedule far in the future, so no run came from the
schedule:

| `runImmediate` | What was saved | Ran? |
|---|---|---|
| off | publish with a code change | no |
| off | publish with no change | no |
| off → on | the `/gql` save that turns the flag on | yes, with the published code |
| on | publish with a code change | yes, the new code |
| on | publish with no change | yes |
| on | config-only `update_script` (description) | yes |

- With `runImmediate` **on**, every save of the formula runs it: a publish with or without a code
  change, a config-only `update_script`, and the save that turns the flag on.
- With it **off**, a publish does not run it.
- The flag stays on after a run. It is not one-shot.
- A run executes the formula once per record that matches its unit, record types and categories.
- The `trigger_formula` description ("runs nothing unless the save changes the formula") does not
  match: a save with no change ran it.
- The flag is readable only through `/gql` (`ScriptFormula.runImmediate`).

**Rule.**
1. Before any write to a scheduled formula in a target (code or config), read its `runImmediate`
   in that org. This covers the source too, when a refresh writes to it.
2. Mark each write to it in the plan. When the flag is on: **"runs the formula once per matching
   record"**. When it cannot be read (no driven browser, or the user did not sign in): **"may run
   the formula"**. Each write is its own save, so each one is its own run.
3. Never turn `runImmediate` on or off unless that is itself a difference the user approved.
   Turning it on is a save, so it runs the formula too.

## Part 3 — recreating objects a target lacks

The gateway reads (`describe_form`, `get_form`, `describe_field_type`, `get_option_list`,
`get_view`, `get_record_type`) do not return every setting the create tool takes, on either line.
Create each object with every setting this surface can read from the source. The settings below
become that object's **"check by hand" list** in the plan and the report, unless a `/gql` read
returns them.

| Object | The gateway read does not return | `/gql` read |
|---|---|---|
| form | `folderId`, `tableName`, `publicLabel`, `tableDescription`, `tableHint`, `userUpdateable`, `useFor*RecNav`, `copyOption`, `tags`, `altIds`, `summaryFieldLabels` | `RelateForm` returns nearly all |
| field | about 25 members, among them `defaultValue`, `helpText`, `width`, `styleClass`, `userUpdateable`, `frozen`, `prefix`, `altIds` | `RelateFieldWrapper` returns nearly all |
| option list | `folderId` only (items read back with `value`, `sortOrder`, `status` and css) | not needed |
| view / query | `objectType`, `formId` (list queries), `destination`, `unit`, categories, `showTotalsOnly`, the display columns' form, field and sort, filter, break and subtotal columns, `altIds` | `RelateQuery` returns nearly all |
| record type | `parentId` (implied for a base type), `formPublicLabel`, `formDescription`, `recordIcon` | not checked: check by hand |
| MEFR | `folderId`, `altIds` | not checked: check by hand |

What the field read does give: id, label, column, type, format, required, control type, option
labels, and `formulaId` (through `inspector`). Only the single option list field type was checked
with `describe_field_type`; for any other type, compare its read with the create tool's schema
before trusting the list above.

**A query is created complete.** Criteria and display columns cannot be changed afterwards through
any tool (the `bluestep-reference` skill's `conventions/mcp-platform-authoring.md`, "Create-time
rules and completeness read-back"). The gateway reads the criteria but not the display columns'
form, field and sort. Without a `/gql` read of the source query, the plan says before approval that
the query's columns must be finished by hand in the target.

**An MEFR seeds one display column** from the base form's first field. More columns need a `view`
update after create, which the same page says the platform blocks for column edits; plan them as a
step for a person.

**Units have no tool.** A unit the target lacks is a step for a person, and whatever depends on it
waits.
