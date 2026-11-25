---
description: "Reading multi-entry form entries in-session — form_entry READ (older release only) is broken for multi-entry (NEW_MULTI); the working paths are GraphQL (gateway tool or signed-in tab): formRows pages one record's entries (limit/offset, values through data(fields:)) and takes no filter, fieldData is one-field-one-entry (batch via aliases); prefer relateQuery, the only filterable, sortable path — a stored List query across records, a MEFR with record: for one record"
---

# Reading multi-entry form entries

The read-path decision tree for multi-entry form data. Without this map, discovering it costs a
fresh session ~15 calls. Paths 2–4 are GraphQL: run them by the route in
[gql-in-a-tab.md](gql-in-a-tab.md) (the gateway's `graphql_query` where the org serves it, a
signed-in tab otherwise).

## The paths, worst to best

1. **`form_entry` READ — older release only, and broken for multi-entry.** The newer release has no
   `form_entry` tool. Where it exists, on a multi-entry form it resolves to a `NEW_MULTI` empty
   template and cannot enumerate rows (a read of existing multi-entry rows throws server-side). Do not
   spend calls on it.
2. **GraphQL `formRows(id, recordId, limit, offset)` — one record's entries, paged.** It honors
   `limit` and `offset` and returns `totalSize`. Always pass a `limit`: a read of every row timed
   out on a form in the ~100k+ row range. Ask for values with
   `rows { ... on FormRow { topId data(fields: [<field topIds>]) { field { topId } valueAsString } } }`;
   the row's `xml` is a heavy XMLEncoder blob, so leave it out. It takes no filter and no sort.
3. **`fieldData(field, formEntry)` — one field of one entry per call.** For more than a couple of
   reads, **batch via GraphQL query aliases** (one request, many `fieldData` selections).
4. **`relateQuery` — PREFER THIS for anything filtered, sorted or across records.** It honors
   `start`/`count` and is the only path that accepts a runtime `filter`/`sort` (filters take
   **`fieldId`**, not `field`). Over a stored `List` query it reads entries across records; over
   a MEFR, the form's built-in all-entries view included, it reads one record's entries when
   called with `record:`. If no stored query covers a cross-record read, **create one** — for any
   form that needs recurring triage, a platform query pays for itself immediately. Creating and
   finding that view has four traps of its own (`maxRows: 0` as a zero-row cap, base-type
   `recordTypes`, `list_views` name-search misses, `record` for an EntityList view) — see
   [relate query over mefr](../gotchas/relate-query-over-mefr.md); this file deliberately does not
   restate them.

## Argument-name gotchas (cost real calls)

Sibling tools disagree on argument names — read the schema (`describe_tool`) instead of assuming:

- `get_option_list` takes **`listId`** (not `optionListId`).
