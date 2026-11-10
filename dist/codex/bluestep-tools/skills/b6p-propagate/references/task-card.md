# The task card — "Propagation list" and "Propagation" (read by `/b6p-propagate` and the close-out page whenever they read or write the task card)

The task card is the shared record of a change: what it touched and which targets have it. It
works on a machine that never had the change log. Two custom fields on the task's list hold it:

- **"Propagation list"** — a long-text field with the record, in the text format below.
- **"Propagation"** — a dropdown with the state: Not needed / Pending / Partial / Done.

No comments (a task can have many) and no checklists (the ClickUp connector cannot write them).
The list comes from `tracker.listId` in `.bluestep/project.json` (`project-config.md`).

## Where the text lives

1. **The "Propagation list" field**, when the task's list has a long-text field by that exact
   name. The field keeps the text byte for byte up to at least about 41,000 characters (20 targets
   of 40 lines). ClickUp refuses much longer text with `FIELD_012 "Value is too many characters"`.
   Never cut lines to fit: tell the user and stop.
2. **Fallback: the task description**, when the list has no such field. The same text goes in a
   fenced code block tagged `propagation-list`:

   ````
   ```propagation-list
   Propagation list v1
   ...
   ```
   ````

   The block starts at a line that is exactly ```` ```propagation-list ```` and ends at the next
   line that is exactly ```` ``` ````. Rewrite only the lines inside it. Everything above and below
   is the user's text and goes back unchanged. With no block yet, add one at the end of the
   description, after a blank line. Use the fence, not plain marker lines: ClickUp escapes plain
   markdown on the way back (`\---`, `\[ \]`), and a fence comes back exactly.

When the field exists but is empty and the description has a block (the field was added later),
start from the block's text and write it to the field. Leave the description as it is.

## The text format (v1)

```
Propagation list v1
Source: <source name> (U######)
To <target name> (U######) | last run <YYYY-MM-DD or ->
[x] field | <Form> > <Field> | FID <fid> | created
[ ] script | <name> | FID <fid> | code + schedule
    check by hand: <setting>, <setting>
To <target name> (U######) | last run -
[ ] field | <Form> > <Field> | FID <fid> | created
```

- Line 1 is the version. Line 2 is the source org. The org names and U-numbers are the ones in
  `.bluestep/project.json`.
- One section per target, in the config's rollout order. Each starts with a `To` line. `last run`
  is the date of that target's last run, or `-` if it never ran.
- One line per artifact, not per log entry. `[x]` means the artifact reached that target.
  - The type is the log's `type` (`script`, `form`, `field`, `option_list`, `view`,
    `record_type`, `mefr`, `folder`, `permission`, `unknown`).
  - The name is the artifact's name. For a field it is `<Form> > <Field>`.
  - The FID is the match key. Write `FID -` when the artifact has none; then the name is the key.
  - The last column says what was done, in plain words joined by ` + ` (`created`, `changed`,
    `wired`, `deleted`, `published`, `code + schedule`).
- `check by hand:` lines are indented four spaces. They belong to the artifact line above them and
  list, comma-separated, the settings a person must check in that target.
- Separators and fixed words are plain ASCII, so the text parses back the same on every route.
  Names are written as the platform shows them.
- A target's own `doNotMove` items get no line in its section.

### Parsing it back

One regex per line kind, tried in this order. Anything that matches none (a note a person
typed) is kept in place and ignored.

```
version        ^Propagation list v(\d+)$
source         ^Source: (.+) \((U\d+)\)$
target         ^To (.+) \((U\d+)\) \| last run (\d{4}-\d{2}-\d{2}|-)$
artifact       ^\[( |x)\] (\S+) \| (.+) \| FID (\S+) \| ([^|]+)$
check by hand  ^ {4}check by hand: (.+)$
```

- Split the check-by-hand group on `, `.
- The artifact name group is greedy, so a name that holds `|` still parses. The FID and the last
  column never hold one.
- A version above 1: stop, say the plugin is older than the card, and write nothing.
- A `Source` U-number that is not the config's source: stop and ask. Same for a `To` U-number that
  is not one of the config's targets.

### Changing the text

- **Tick a line:** in that target's section, find the line by type and FID (by type and name when
  the FID is `-`) and change its leading `[ ]` to `[x]`. Tick only after the read-back shows the
  artifact landed, or when it was already identical in the target.
- **Add check-by-hand lines:** right below the artifact line, one `    check by hand: …` line.
- **Record a run:** set that target's `last run` to the run's date.
- **Add a target section:** append a `To <name> (U######) | last run -` line, then one `[ ]` line
  for every artifact in the list except that target's `doNotMove` items. Keep sections in the
  config's target order.
- **Add a later change to an existing list:** add its artifacts to every section as `[ ]` lines.
  An artifact already in a section is not added twice: set its line back to `[ ]` and add the new
  words to its last column.

## The "Propagation" dropdown

| Value | When |
|---|---|
| Not needed | Close-out answer "not needed" |
| Pending | The list is written and no target section is fully ticked |
| Partial | At least one target section is fully ticked, not all |
| Done | Every target section is fully ticked |

- Set it **by option id**, never by name or position. The connector's `clickup_get_custom_fields`
  returns the options with their ids. The REST task read lists them under the field's
  `type_config.options`.
- Reading it back: the connector returns the option as `{id, name, orderindex}`. The REST task
  read returns only the option's **orderindex**; map it to the name through
  `type_config.options`.
- No "Propagation" field on the list, or no option with that name: skip it silently.
- Set it in the same write as the list, shown in the same preview.

## When the card changes

Only at these points, never on each platform write:

- **Close-out, "later":** write the list (every target unticked), dropdown → Pending.
- **Close-out, "now":** write the list before the first target starts, so a stop leaves a record.
- **Close-out, "not needed":** dropdown → Not needed.
- **After each target's run:** ticks, check-by-hand lines, `last run`, dropdown.
- **When the user asks.**

Every write is shown first and made on the user's yes. Show the dropdown value and the text that
changes: the whole list when it is new, the changed target sections otherwise. Read the card again
right before writing. If someone changed it since your read, merge your change into the fresh text
and show it again.

## Three routes, in order

None is required. Use the first one that works for this user. Each acts as the user, so the user
needs access to the task's list. A user without access can still use route 3 and hand the text to
someone who has.

### 1. The ClickUp MCP connector

ClickUp's official connector, which the user connects in their agent tool and signs in to with
OAuth (no token). The tool names below are the connector's own; the agent tool may add a prefix.

- **Read:** `clickup_get_task` with `include: ["custom_fields"]` (add `"description"` for the
  fallback). The long text comes back as is, the dropdown as `{id, name, orderindex}`. The field
  names are `tracker.listField` and `tracker.statusField` in `project-config.md`, with the defaults
  "Propagation list" and "Propagation".
- **Field and option ids:** `clickup_get_custom_fields` for the task's list.
- **Write the field and the dropdown:** `clickup_update_task` with
  `custom_fields: [{ id: <field id>, value: <text> }, { id: <dropdown id>, value: <option id> }]`.
- **Write the fallback:** `clickup_update_task` with `markdown_description` (the whole
  description, changed only inside the fence).
- **New task** (close-out, on the user's yes): `clickup_create_task` in the config's list.
- The connector cannot create custom fields; the list admin adds them (below).
- Calls per workspace per day are capped by the ClickUp plan. On `RATE_LIMIT_EXCEEDED`, use the
  next route.

### 2. The REST API, only with the user's own token

Only when the user has set their own ClickUp personal token in `CLICKUP_API_TOKEN`. Never look for
another variable or anyone else's token. Base `https://api.clickup.com`, header
`Authorization: <token>`.

- **Read:** `GET /api/v2/task/{taskId}?include_markdown_description=true`. `custom_fields` holds
  both fields with their `id`, `type`, `value` and, for the dropdown, `type_config.options`.
- **Write a field:** `POST /api/v2/task/{taskId}/field/{fieldId}` with `{"value": "<text>"}`, or
  `{"value": "<option id>"}` for the dropdown.
- **Write the fallback:** `PUT /api/v2/task/{taskId}` with `{"markdown_content": "<whole
  description>"}`.
- **New task:** `POST /api/v2/list/{listId}/task` with `{"name": "<title>"}`.
- **From Windows PowerShell 5.1, send the body as UTF-8 bytes.** A string `-Body` mangles non-ASCII
  characters, which would damage the user's text in the description:

  ```powershell
  Invoke-RestMethod -Method Post -Uri $uri -Headers @{ Authorization = $env:CLICKUP_API_TOKEN } `
    -ContentType 'application/json; charset=utf-8' `
    -Body ([Text.Encoding]::UTF8.GetBytes($json))
  ```

  Node's `fetch` sends UTF-8 as is.

### 3. Paste

With no connector and no token, print the text for the user:

- The whole new "Propagation list" text in one code block, with: "Open the task, replace all the
  text in the Propagation list field with this, and set Propagation to `<value>`."
- For the fallback, the whole fenced block, with: "Replace the `propagation-list` block in the
  description with this."
- To read the card, ask the user to paste the field's text (or the description block).

## Setup text for the list admin

Print this for whoever administers the list. The flow works on a card without the fields too (the
description fallback, no dropdown). No task template or automation is needed: fields on a list
exist on every task in it.

```
Custom fields to add to this list:
- "Propagation list" - type Text area (Long Text). Holds what the change touched
  and which target orgs have it. Written by the agent; do not reformat it.
- "Propagation" - type Dropdown, options in this order:
  Not needed, Pending, Partial, Done
```
