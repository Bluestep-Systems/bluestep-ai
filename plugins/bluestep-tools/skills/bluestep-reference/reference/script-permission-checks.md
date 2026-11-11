---
description: "Since web 26.11.09 a BsJs script that runs as its caller enforces that caller's View/Create/Edit/Delete — hidden fields, hidden entries, refused queries. Scripts that existed at the deploy carry legacyPermissions: true and keep the old behaviour; new scripts are checked. How to read and set the flag, and how to test."
---

# Scripts check their caller's permissions (`legacyPermissions`)

Since web release 26.11.09 a BsJs script that runs **as its caller** applies that caller's
permissions to what it reads and writes. That covers endpoints and merge or detail reports without
**Run as Super User**, formulas, and anonymous pages (as reported). A super user caller is not
checked.

What the caller now meets inside the script:

- **A query, sort, grouping or lookup that depends on a field the caller may not view** is refused
  before it runs, with
  `RemoteSecurityException: You may not run this Relate Query: it depends on a field you may not view.`
  Seen 2026-11 on an anonymous endpoint, running a query the Everyone group may read, over a form
  where Everyone is Relate Author. Which grant would have let it run was not found. A grant scoped
  to a unit, a record or a dynamic group counts as not viewable everywhere and refuses for now (as
  reported), so a grant that looks right can still be refused.
- **A field the caller may not view** reads empty or `[No Access]`; **entries the caller may not
  read** are left out of lists, counts and children; **an id the caller may not see** fails exactly
  like an unknown id (as reported).
- **Writes** — creating or deleting an entry, setting a field, moving a record's unit, editing
  categories, documents and alerts — need the caller's own permission, as in the platform's forms
  (as reported).
- **Secrets** (`verifySecret()` included), `RecordScript.selectValue` and advanced WHERE/HAVING are
  for super callers only (as reported).

## The `legacyPermissions` flag

- Every formula, endpoint and merge report that existed at the deploy was set
  `legacyPermissions: true`: its runs skip the new checks and behave as before. A script created
  after the deploy has it `false` and is checked (verified 2026-11 with `create_script` for an
  endpoint and a merge report). A script created by schema apply, or by `create_script` in another
  org during a move, is new, so it is checked even when its source is not (as reported for schema
  apply). A save on the script's config page during the deploy could drop the flag (as reported):
  read it rather than assume it from the script's age.
- Read it with the gateway's `get_script` or `lookup_script_by_name` (`legacyPermissions`). Set it
  with `update_script` `legacyPermissions`, or the **Legacy Permissions** checkbox on the script's
  config page. Turning it **on** is refused `FORBIDDEN` unless the caller is a super administrator;
  anyone who may edit the script may turn it **off** (as reported; turning it on with a super
  administrator's token works, verified 2026-11).
- The flag is read when a run starts: a change applies to the next run with no publish (verified
  2026-11: the same published endpoint answered with data under `true` and with the refusal above
  under `false`). Changing it on a live script changes what its callers get at once, so it is the
  user's call, never a side effect of another change.

## Building and testing a new script

- **Test as a non-super caller** — the anonymous visitor for a public endpoint, or a real user
  without super rights; for a formula, a user whose save fires it. A super test proves nothing here.
- When the script needs data its caller may not see, the choice is the user's, because each option
  changes who can see what: grant the caller (or their group) View on the forms and fields, turn
  **Run as Super User** on for an endpoint or report meant to act for everyone, or query only
  fields the caller may view. That a View grant lets a refused query run is as reported — test it.
  Never widen a form's permissions on your own so a script can read it.
- Do not turn `legacyPermissions` on to make a new script work: that brings back the reads and
  writes the checks close. It is for scripts that ran before the checks existed.
- A refused query or an empty field in an older script whose flag someone turned off is the same
  check, not a bug in the code.
