---
description: "Reading multi-entry form data through a Relate query made with the MCP `view` tool has four traps — maxRows: 0 is a real zero-row cap (unlimited is -1), recordTypes must be the record's BASE type, only list_views(formId:) finds a form's views (the name search and the unfiltered listing miss List queries), and relateQuery reads an EntityList view (MEFR) only with `record`, a List view by unit"
---

# Relate query over a multi-entry form — four traps

Creating a Relate query (DB view) over a multi-entry form via the MCP `view` tool and reading it
with a GraphQL `relateQuery(...)` fails in ways that look like a platform limitation rather
than a config mistake — a healthy-looking view (columns come back correctly) that returns
`totalSize: 0` against a form holding hundreds of entries, or a bare server error. Together the
four traps produce the wrong conclusion "a Relate query cannot read MEFR entries."

1. **`maxRows: 0` is a real zero-row cap.** The view returns its columns and no data. Unlimited is
   **`maxRows: -1`**, which is also what a new view gets when `maxRows` is left out on create. On
   update, leaving it out keeps the existing cap; send `-1` to remove one.
2. **`recordTypes` is required, and it must be the record's BASE type — not the category the form
   reports.** `relateForm { recordTypes }` can return a *category*; the query needs the base record
   type of the records holding the entries. Wrong value or omitted → zero rows.
3. **Find a form's views with `list_views(formId:)`, not by name.** With the form's id it returns
   every view over the form: its `List` queries, its custom MEFRs, and the built-in all-entries
   view (`queryType: EntityList`, no `displayName` — see
   [../reference/current-record-bindings.md](../reference/current-record-bindings.md)). The name
   `search` and the listing with no `formId` find named MEFRs but **miss `List` queries that
   exist**, so neither proves a view is absent. In a search answer `total` is the count of all
   views and `hasMore` is `true` even when nothing matched. `list_views` returns at most 100 items
   and has no offset. When you hold an id, `get_view` is the check.
4. **A `List` view is read by unit, an `EntityList` view (a MEFR) by record.**
   `relateQuery(id: "<MEFR topId>", record: "<record topId>", start:, count:)` returns that
   record's entries, paged, each row with its `formEntry` and `data`. Called without `record`, or
   with `unit` in its place, it answers a bare "An unexpected server error occurred." (`INTERNAL`):
   read that as "this view needs `record`". For entries **across records**, use a `List` view,
   which yields one row per entry and honors `count`. The MEFR is also the vehicle for **wiring a
   script import** (the query-group recipe in `conventions/mcp-platform-authoring.md`).

## The working recipe

For one record's entries, the form's built-in all-entries view already works with `record:`;
nothing has to be created. For a read across records, create a view with the `view` tool:
`viewType: "List"`, `maxRows: -1`, `recordTypes: [<base record type topId>]`, plus display
columns. Read with this GraphQL query, by the route in
[../reference/gql-in-a-tab.md](../reference/gql-in-a-tab.md):

```graphql
{ relateQuery(id: "<view topId>", count: 50, start: 0,
              filter: { fieldId: "...", operation: EQUALS, value: "..." },
              sort:   { fieldId: "...", direction: ASCENDING }) {
    totalSize
    # plus the row/field selections your read needs
} }
```

`relateQuery` is the read path with a runtime `filter` and `sort`. `formRows(id, recordId, limit,
offset)` pages one record's entries too and returns `totalSize`; its rows carry values through
`... on FormRow { data(fields: [<field topIds>]) { field { topId } valueAsString } }`.
