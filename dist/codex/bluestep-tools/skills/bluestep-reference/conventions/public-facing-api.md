---
description: "Design checklist for an API that outside consumers call — payload contract, errors and auth, images, storage and builds, changing the contract — and the BlueStep half: the /b/ endpoint settings the gateway cannot set (HttpLogin, HttpsRedirect, Run as Super User), /download/ URLs a consumer cannot use, and setting up the Basic Auth consumer account"
---

# Designing an API for outside consumers

Part 1 holds on any platform. Part 2 is how to serve it from a BlueStep `/b/` endpoint. The rules
come from a public read-only API built on BlueStep in 2026-09; a platform claim marked "as reported"
was seen there and not re-run here.

## 1. Contract rules

**Payload**

- **Never store assembled URLs in the payload.** Publish the id plus a `hasImage: boolean` and let
  the consumer build `<baseUrl>/image/<kind>/<id>` from its own config. A stored URL freezes your host
  and path into every saved document; changing either leaves dead links until a full rebuild. Keep
  the boolean so the consumer never asks for a photo that does not exist. Add a test that no payload
  contains your hostname.
- **Publish relationships in both directions.** If a parent lists its children's ids, give each
  child its parent's id and name too; otherwise a deep link to a child forces the consumer to walk
  every parent. Adding keys later is cheap; changing how the consumer resolves a relationship after
  they built on it is not.
- **Opt-in flags publish only on `=== true`.** An untouched boolean is `null`, and null must not
  publish.
- **Empty text is `null`, never `""`** (whitespace-only included). Empty collections are `[]`, never
  `null` or missing. Say both in the docs.
- **Ids are strings.** BlueStep ids can overflow 32-bit integers (as reported); tell consumers not to
  parse them.
- **Dates:** publish ISO `YYYY-MM-DD`, or document the format. Passing through what staff typed
  (`5/12/26`) pushes the guessing onto the consumer.
- **Key spelling is contract, typos included.** Once published, a misspelled key stays. Review key
  names before the first consumer builds on them.

**Errors and auth**

- GET only (405 otherwise). 401 with no or wrong credentials, 403 for a signed-in user who is not on
  the consumer allowlist, and **one 404** for every kind of miss: unknown id, unpublished record,
  missing photo, trailing slash, extra path segment, non-numeric id. A single 404 does not tell a
  prober which ids exist.
- Fail closed: an allowlist of consumer accounts in code keeps publishing an explicit act, not a side
  effect of someone's permissions.
- Errors return JSON (`{"error":"Not found."}`) with the JSON content type.
- Image routes: send the stored content type only when it starts with `image/`, otherwise
  `application/octet-stream`, and always add `X-Content-Type-Options: nosniff`. Watch file size: a
  multi-MB original read whole into memory on every request is the most expensive shape.

**Storage and builds**

- **Prebuilt documents** (a builder writes the JSON, the endpoint returns it as is) keep reads cheap
  and leave one place that decides what is published.
- **Withdrawing clears the content**, not just the flag. Keeping the last payload of an unpublished
  person (name, bio, photo) is a privacy problem with no consumer benefit, since a withdrawn row
  answers 404 anyway.
- **Concurrent builds with no dedup key duplicate a read-then-write upsert.** Make it heal itself
  (collapse duplicates, keep one). Throwing on the duplicate turns a routine race into a permanent
  outage for that record.
- **Prefer a stale document to a failed save.** A trigger that cannot schedule a rebuild must never
  fail the user's save that fired it.

**Changing the contract**

- Keep "decided, sent for information" apart from "question that needs an answer". Do not ask a
  stakeholder to confirm standard behavior.
- Put every change from the approved field table in writing, with its reason, before consumers
  build on it.
- Ship the consumer docs with the API: base URL, auth, every route with a sample body, a status-code
  table, payload quirks, and a request collection that chains ids.

## 2. BlueStep: serving it from a `/b/` endpoint

**Endpoint settings.** Set these on the endpoint's setup page. The gateway tools cannot read or set
any of them (verified 2026-11), so a component rebuilt through the gateway loses them without a word
(as reported); check them after every rebuild. The GraphQL input `UpdateScriptEndpointInput` carries all three: `basicPermissionOption`
(`Error` / `Login` / `HttpLogin`), `httpOption` (`HttpAllowed` / `HttpsNotAllowed` / `HttpsRedirect`)
and `runAsSuper` (fields and values verified 2026-11; setting them that way not tried — see
[../reference/gql-in-a-tab.md](../reference/gql-in-a-tab.md) for the route).

- `basicPermissionOption` = **`HttpLogin`** (likely the setup page's "Request HTTP authentication"
  choice, see [../reference/session-cookie-forwarding.md](../reference/session-cookie-forwarding.md);
  the label-to-value match is not checked). The platform answers 401 with a
  `WWW-Authenticate: Basic` challenge before the script runs. Set it **before** the first publish
  (both as reported).
- `httpOption` = **`HttpsRedirect`**.
- **Run as Super User** only if the script must read document bytes: without it, every content read
  on a document throws `!isSuperUser`, whatever the document's own permissions say (as reported; see
  [../reference/csv-parsing.md](../reference/csv-parsing.md)). It lifts platform filtering for the
  whole script, so every route must filter in code.
- Platform `/download/...` URLs need a signed-in session and ignore Basic Auth (they answer with the
  login page as `200 text/html`, as reported), so a consumer can never use them directly. Stream the
  bytes through your own route.
- The platform cannot emit WebP: `thumbnail().transformType("webp")` (any spelling) returns the same
  JPEG bytes, and `thumbnail()` always re-encodes to JPEG, with no alpha channel. A stored `.webp` is
  served as `image/webp` byte for byte (as reported). Serve the stored file when the format matters.

**Creating the consumer account**

1. Create a dedicated account for each consumer, never a person's account: a login plus an
   individual record in the top unit. The profile form may say "The username you have selected is
   already in use" right after creation; read the subject's `userName` over GraphQL before believing
   it (as reported).
2. Check the subject: **`relateLicensee: false`**, and no global user, global admin or super admin
   flag. A form that grants Relate Licensees the Relate Editor role would otherwise give the account
   **write** access to the stored documents (as reported).
3. Decide the account's email on purpose: a personal mailbox ties password resets to one person;
   none at all is also an option.
4. Grant the least read access the endpoint needs, since the caller's permissions apply: Relate
   Reader on the storage form, Reader on the source query. Objects secured by **category** roles
   accept only `NO_ACCESS` or `EDITOR` (as reported), so before granting there, measure what the
   account would see (`list_permissions` on every form of that record type, reading Everyone and
   Registered Users) and test the endpoint first; grant only if the query comes back empty.
5. Add the login to the endpoint's allowlist and compare it with **`user.userName()`**.
   `user.credential()` is the professional suffix (MD, RN; per its B.d.ts doc) and is usually empty.
   Renaming the login later breaks the allowlist; say so in the component README.
6. Hand the password over out of band — never in a spec, README, commit or chat.
7. Verify in this order: anonymous → 401 with the Basic challenge (a 200 here means `HttpLogin` is not
   set: stop and fix it); wrong password → 401; another valid user → 403; the consumer → 200 on every
   route; the negative cases → 404/405. Remove any temporary allowlist entry used for testing and
   check it now gets 403.

**Related traps.** A query's run unit is its GraphQL `unitKey`, not its `unit` — see
[../reference/staff-query-permission-gating.md](../reference/staff-query-permission-gating.md).
Script logs land only on the pod that ran the script — see
[../gotchas/merge-report-console-logs.md](../gotchas/merge-report-console-logs.md).
