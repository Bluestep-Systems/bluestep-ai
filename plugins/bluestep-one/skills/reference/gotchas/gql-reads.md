# Gotchas — /gql reads

Prefix `G`.

---

### G-155 — A fresh CSRF `HEAD` before every `/gql` POST doubles every read's round trips

What looks right: mint a token with a `HEAD` for each call, "cheap and stateless". What happens:
each `HEAD` is a full round trip (about 200 ms), so every step of a load chain costs two. A load of
six steps run one after another pays six extra round trips. The server takes the same token again:
one token serves several POSTs in a row, all 200, and every answer carries a new token. A bad token
gets a 403 with the JSON body `{"error":"Invalid or missing CSRF token"}` and no `errors` array
(a bare 403 with no body before release 26.10.13.01).

What to do: keep the token per page (calls made together share one `HEAD`), replace it with the
one an answer carries, and on a 403 with no `errors` array (the server ran nothing) mint a fresh
one and send once more. A 403 with `errors` (`FORBIDDEN`) is a real refusal and is not retried.

**How to tell.** 1. On a test org, in a signed-in tab, time two `HEAD /gql` calls from the console:
each is a full round trip. 2. POST three reads with the first answer's `B6P-CSRF-TOKEN`: all three
answer 200. 3. POST with a made-up token: a 403 with the body above and no `errors` array.

**Applies to:** any BlueStep One component

### G-171 — A `formEntries` filter on a *Signature* field takes the `d`-prefixed operators; a plain `=` answers a bare INTERNAL

What looks right: read the entries still to sign with a `formEntries` filter "*Signature* is
empty", as Manage's list does, written with `=` and an empty value. What happens: `=` with no
value, `<>` with no value and `NOT_EQUALS ""` each answer a bare INTERNAL, with no message to act
on. A *Signature* field's search operators are the `d`-prefixed ones: `d=`, `d<>`, `d>`, `d<`,
`d>=`, `d<=`. A plain `>=` is refused by name, with that list in the message. With an empty value, `d=` means IS NULL (unsigned) and `d<>` means IS NOT NULL (signed). A plain `=`
builds an empty SQL segment on the server, which ends as INTERNAL. `QueryFilterInput.operation` is a
free `String!`, so the `d` operators pass the schema.

So "the unsigned entries" can be a server filter:
`{ fieldId: "<signature field id>", operation: "d=", value: "" }`. Always pass a `unitId` too: a
read of a large form with no `unitId` can time out. A PRECONDITION on `=` that names the right
operators, and their documentation, are still owed.

**Dates (changed in web 26.11.09).** With a value, `d>`, `d>=`, `d<` and `d<=` filter on the
signing instant. From web 26.11.09 the value is ISO 8601 with an offset
(`2026-10-01T00:00:00-06:00`) or in UTC (`2026-10-01T06:00:00.000Z`); both matched the same rows.
A bare date means midnight in the viewer's zone. Manage's own text (`MM/dd/yyyy h:mma`, a newline,
then a zone name), the only value taken before 26.11.09, is now refused: "Value '…' for field
'<label>' (Signature Field) is not a valid date and time; expected YYYY-MM-DDTHH:MM[:SS] with an
optional offset, or MM/DD/YYYY H:MMam …". Before 26.11.09, any other value answered "An unexpected
server error occurred." Send the offset of the zone the period belongs to (the unit's), never the
viewer's. Components that sent Manage's text broke when the release went out, and showed only
their generic load error. `d=` and `d<>` with an empty value are unchanged.

**How to tell.** On a test org, run `formEntries` on a form with a *Signature* field, with a
`unitId` and the filter `{ fieldId: "<signature field id>", operation: "=", value: "" }`, asking
`totalSize`: a bare INTERNAL. The same with `operation: "d="` gives the unsigned count, and `d<>`
the signed count. Since web 26.11.09, `d>=` with an ISO value with an offset gives the
entries signed from that instant; the same filter with Manage's text gives the refusal above.

**Applies to:** any BlueStep One component

### G-177 — `formEntries.get` without `{ fresh: true }` answers from what the tab already loaded, and a `/gql` write does not refresh it

What looks right: `host.formEntries.get(entryId, recordId)` reads the entry, so its `modifiedAt`
and `modifiedBy` are the last save's. What happens: the host's declarations say a plain `get` may
be answered from what the tab already loaded. A component that writes through `/gql` goes around
that cache, so a "Last modified" line read through the host keeps the first save's time after a
later save. A fresh read fails rather than answer stale, and fails only after 30 s with no answer,
so a fresh `get` inside a screen's load can hold the load that long.

**How to tell.** On a test entry, read `modifiedAt` with `host.formEntries.get`, save a change over
`/gql`, and read it again without `{ fresh: true }`: it may answer the old time (the declarations allow a
cached answer). With `{ fresh: true }`, or with
`formEntries(…) { modifyDate }` over `/gql`: the new time.

What to do: pass `{ fresh: true }` whenever a component reads something its own `/gql` writes may
have changed, and read it again after each such write. Keep a fresh read off the critical path when
it only decorates the screen (treat a failed read as "no line").

**Applies to:** any BlueStep One component

### G-316 — `/gql` names one entry two ways, with and without the form's suffix, so `===` on ids misses a match

What looks right: an entry has one `/gql` id, so two ids are the same entry when they are equal.
What happens: the same entry reads as `<n>___<entry>` (the entry's own id) or
`<n>___<entry>_<form>` (with the form's suffix, as a relationship field's value reads back). A text
field that stores an entry id can hold yet another spelling, with the org's U-number inside:
`<n>_U<org>__<entry>_<form>` on older rows, `<n>___<entry>_<form>` on newer ones. An option id may
read `<n>__GID_<n>` or `<n>___<n>`. A plain `===` between an id the component holds and one a read
answered then says "not the same" for the same entry or option, and a check built on it ("is this
the entry I linked?", "is this option on the list?") fails quietly.

**How to tell.** On a test org, link two entries through a relationship field, read the field's
`valueAsString` (it carries the form's suffix) and compare it with the linked entry's id from
`formRows` on its own form (no suffix).

What to do: compare entry ids with a helper that drops the form's suffix and compares the numbers,
and option ids in their canonical spelling (the option list's), never with `===` on the strings as
read.

**Applies to:** any BlueStep One component

### G-328 — An option list's order over `/gql` is not its sort order: a list can come with sort orders 3, 1, 2

What looks right: `listOptions { items }` answers the options in the order Manage draws them, so a
picker lists them as they come. What happens: the items come in another order than their
`sortOrder`, while Manage's pickers and blocks follow `sortOrder`. A three-option list can come
back with sort orders 3, 1, 2, and in a long list the option with sort order 1 can come ninth.

**How to tell.** On a test org, read a select field's `listOptions { items }` with `sortOrder` on
each item, and compare the answer's order with the sort orders.

What to do: ask for `sortOrder` and sort every option list a screen draws by it (equal sort orders
kept in the answer's order).

**Applies to:** any BlueStep One component

### A `formEntries` read filtered on a text field costs about 2.5 s the first time per value; a "has a value" filter and a sort on a date-time field cut it to 0.6 s

What looks right: a `formEntries` read on one form across a unit, with one `=` filter on a text
field (one that holds a parent entry's id) and five fields on 100 rows, is a cheap read. What
happens: seen once, measured on one form, the first read of each filter value cost 1.5 to 2.6 s,
the server's time rather than the rows' (2 rows and 100 rows took the same), and the same read
again 0.22 s for minutes. A page that reads one parent after another waits for the slowest read:
several seconds before anything shows on a record with many parents. With a second filter
`{ fieldId: "<date-time field>", operation: "<>" }` and no value (the rows that have one; `=` with
no value is the rows without) and `sort: [{ fieldId: "<the same>", direction:
DESCENDING_NULLS_LAST }]`, the same read cost 0.6 s cold and 0.21 s warm, newest row first. In the
same probe a `<>` with a value answered INTERNAL; on a signature field, use the `d` operators
(G-171).

**How to tell.** From a signed-in tab on a test org, time the read twice on a filter value not read
for a while, then the same read with the `<>` filter and the sort on another such value, twice
(measured: about 2500/220 ms against 600/210 ms).

What to do: filter and sort on the date-time field the screen needs, ask for the rows that have it,
read one page, and show each read as it lands instead of waiting for the last one; never size a
loading state on one timing.

**Applies to:** any BlueStep One component

### A number field's `valueAsString` carries thousands separators

What looks right: match a stored list of ids (a text setting such as "12345,0,1") against a number
field's `valueAsString`. What happens: `valueAsString` is "12,345" while `value` is 12345, so a
string match never hits, and a split on commas breaks the number in two.

**How to tell.** On a test org, read a number field that holds 1000 or more:
`formEntries(formId: "<form id>", …) { rows { formEntry { data(fields: ["<field id>"]) { valueAsString value } } } }`.

What to do: read `value` for numbers, never `valueAsString`.

**Applies to:** any BlueStep One component

### `myAlerts` answers at most 100 rows, and the count past 100 is unknown

What looks right: `myAlerts` is the viewer's alert inbox, so its length is the number of alerts
the viewer has. What happens: the schema says the field is "Capped at 100 rows". A user who
receives many system alerts can pass 100, and a page or badge built on `myAlerts` then stops at
100 with no sign. Manage's own Alerts page stops at 100 too: it listed exactly 100 before and after
one was cleared, and the cleared one was replaced by the same next alert in both apps, while the
platform's header badge showed another number at the same minute. So no screen shows the true
count.

**How to tell.** On a test org, from a signed-in tab, run
`{ __type(name: "Query") { fields { name description } } }` over `/gql` and read `myAlerts`'
description.

What to do: when the answer has exactly 100 rows, show the count as "100+" and say the list may be
cut. `alertHistory` (an audit read, slow, not for polling) is not a replacement.

**Applies to:** any BlueStep One component
