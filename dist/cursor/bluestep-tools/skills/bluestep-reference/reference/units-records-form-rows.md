---
description: "Creating units, records and form rows (seed or test data) over GraphQL — no gateway tool writes them. createUnit needs organizationEmail; deleteUnit moves the unit's records, sub-units and users to its parent, so dry-run it and confirm on its own; createRecord needs parents and fills the base-form entry from fieldValues; createFormRow refuses a bad value by field label and saves nothing. On the older platform release units and records stay a UI hand-back."
---

# Units, records and form rows

No gateway tool creates a unit, a record or a form row. They go through GraphQL mutations, run by
the route in [gql-in-a-tab.md](gql-in-a-tab.md). Each one is a platform write: echo it and get the
user's yes first, as for any other op in
[conventions/mcp-platform-authoring.md](../conventions/mcp-platform-authoring.md) (step 5).

## Check the org's platform release first

What follows holds on the **newer** platform release (verified 2026-11). `list_org_tools(org)` shows
which release an org is on: the newer one serves `batch_fields`, `option_list` and `read_log`.

On an org on the **older** release, treat units and records as a **UI hand-back**. There, in 2026-08,
`createUnit` made units that could not hold records and could not be deleted except in the UI, and
`createRecord` failed with an opaque `INTERNAL`. Create them in the platform UI.

## Units

```graphql
mutation($i: [CreateUnitInput!]!) { createUnit(inputs: $i) { id displayName } }
# $i = [{ name, displayName, organizationEmail, parents: [{ topId: "<parent unit id>" }] }]
```

`organizationEmail` is required. Records can be created in the new unit.

**Deleting a unit is destructive.** `deleteUnit(unitId, dryRun, moveContentsTo, expectedVersion)`
moves the unit's records, sub-units and users to the parent unit (or to `moveContentsTo`), which
changes who can reach them. Run it with `dryRun: true` first, show the user the counts it returns
(`recordCount`, `subUnitCount`, `userCount`, `movedContentsTo`), and run the real delete only on a
separate, explicit yes.

## Records

```graphql
mutation($i: [CreateRecordInput!]!) { createRecord(inputs: $i) { id displayName } }
# $i = [{ entityType: "<record type id>", parents: [{ topId: "<unit id>" }],
#         displayName: "...", fieldValues: { "<fieldId>": "<value>" } }]
```

- `parents` is required. A unit's id works: the record is placed in that unit's Entities container.
- `fieldValues` fills the record's base-form entry, so a record is never created empty.
- A new base record type also needs its Display and Summary fields set — see the record-type bullet
  under Schema authoring in the authoring page.

## Form rows

```graphql
mutation($r: String!, $v: JSON) {
  createFormRow(formId: "<form id>", recordId: $r, fieldValues: $v) { id }
}
```

Pass `fieldValues` as a variable (a JSON literal in the query text is a syntax error). A value a field
cannot take is refused with the field's label and the formats it accepts (code `PRECONDITION`), and
no row is saved, so a corrected retry does not leave a duplicate.

## Deleting rows and records

The newer release's schema has no mutation that deletes a single form row or record. Before relying
on one (`deleteFormRow` exists on some orgs), check that the org's `Mutation` type has it:
`{ __type(name: "Mutation") { fields { name } } }`. Otherwise removing test data is a UI step: tell
the user what to delete.
