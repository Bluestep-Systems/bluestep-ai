# Rules

Prefix `R`.

---

### R-13 — Never put private entry data in a component's placement props, or a secret in a component repo: every signed-in user of the tenant can read both

Since server release 26.09.22.00, custom components, their placements and the placements' anchors
are readable by everyone signed in to the tenant, and the server refuses per-component grants. The
change made components render for staff users. So placement props, their history and the
component's git repo are open to every staff user. What to do: keep private data in form entries,
which keep their own rights, and keep keys in a Secret field or a server store, never in props or
source.
**How to tell.** On a test org, sign in as a plain staff user (not Super) and read a placement over `/gql` with `remoteObjects(ids: ["<placement id>"])`: the `CustomComponentPlacement` answers with its props. So anything put in props or in a component repo is open to every staff user.
**Applies to:** any BlueStep One component

### R-16 — Pick one data path per piece of data, the host or raw `/gql`, and never pass a key from one to the other

Host keys (`ApiRecordId` and the entry keys) are opaque `SystemKey` objects with `toString()` and `equals()`. A component cannot build one from a raw id: a hand-made key is refused at runtime ("expected a key obtained from this host, got a foreign object"). A raw `/gql` id cannot be handed to the host either. The two meet only through `toString()`: a host key's string is the `/gql` id. A component may read units, sites and counts through the host and do every form-row read and write over `/gql` (CSRF token from a `HEAD`, then a same-origin `POST`), because the host cannot name what it needs. A converted screen decides per data path: the host when its contract covers the read or write (it brings the offline queue, `expectedVersion` and the conflict pill), `/gql` when it does not (fields outside the summary fields, which a read returns only when they are named by id; signatures; option values, which are the option's id, not its export value or label). A `/gql` write gives up the queue and the pill, so it passes `expectedVersion` itself where the mutation takes one, and re-reads after.
**How to tell.** Read the host contract in the downloaded `component-host.d.ts`: host keys are opaque `ApiRecordId` / entry keys, the header says you never construct one, and no constructor from a `/gql` id exists.
**Applies to:** any BlueStep One component

### R-18 — Branch on a refusal's `extensions.code`, never on its text: server refusals carry no ids

No GraphQL refusal names an id. A field is named by its label, an object by its kind ("this Relate Form Entry"), and a batch item by its position; the ids go only to the server log. On release 26.10.13.00, a `PRECONDITION` refusal named the field by its label and gave no id. The texts also change wording between releases. BlueStep One's own host already broke on this: its save matched an id inside the refusal text (G-91). So converted code decides by `extensions.code` (`FORBIDDEN`, `PRECONDITION`, `CONCURRENT_MODIFICATION`, `NOT_FOUND`, `INTERNAL`) and its typed extras (`currentVersion`, `maxLength`, `reason`), and shows `message` to the user as it comes (a failed `/gql` call can answer an HTTP error or even 200 with a JSON `errors` body; its kind is in the error's extensions, not in the status). Never parse the message for an id or a field name; to know which field was refused, send fewer fields or check them before the write.
**How to tell.** On a test org, over `/gql`, send a write refused for each reason (a stale `expectedVersion`, an unknown field key, a form the user may not edit) and read each error: `extensions.code` is `CONCURRENT_MODIFICATION`, `PRECONDITION` or `FORBIDDEN`, and no `message` names an id.
**Applies to:** any BlueStep One component

### R-54 — A read or save refused for rights gets words saying what to do instead, never a generic *Try again*

A component's error state offers *Try again* for a read or a write that failed, but a `FORBIDDEN` (missing rights) or a signed-out answer (G-265) fails the same way every time, so *Try again* is a button that only fails again. On a rights refusal, show words that say what the viewer can do instead ("You can't add a new contact. Pick one already in the list."), keep only *Close* or *Cancel*, and keep *Try again* for timeouts, network failures and version conflicts. Test the error mapping: each refusal kind maps to its words and its buttons.
**Applies to:** any BlueStep One component

### R-55 — The design check lists every control that starts slow work and checks, live, what it shows while it waits and when it fails

The canvas draws still states, and the design check writes one row per thing the canvas draws (`build/design-check.md` step 5), so a pending or failure state is checked only where someone thought to list it. Step 4's fetch wrapper reaches loading and error states *of a screen*, not of each control. This lets a control ship with no sign that a click took. Two examples: a *Try again* with no running state (a click looked lost), and an icon in a table row that opened another entry after a few seconds of lookups with nothing drawn, while the other links in the same row had P-34's opening mark. The audit had a row for the icon's look, one for what the rows open (naming the links but not the icon), and one for pending states (buttons only).
The rule: before the design check's verdicts, list in `design-audit.md` every control that starts slow work: opens another screen (`openEntry`, `openNewEntry`, a lookup before it), reads (a tab, a dialog that loads, a *Try again*, a reread), saves or deletes. Give each one row with two checks, both live: (1) **while it waits**, with the operation held by the fetch wrapper: a visible sign on or beside the control itself (P-34's mark, a loader in the icon's place, the button's working words), clicks held without losing focus (P-70), and a polite status for a screen reader; (2) **when it fails**, with the operation failed: words near the control saying what failed and whether the work in hand is blocked (P-71), and no generic *Try again* on a refusal (R-54). Build the list from the code (every `onClick` that awaits or navigates), not from the canvas, since the canvas does not draw these states. A control with no sign in (1) is a **Fix**, never a **Keep**.
**Applies to:** any BlueStep One component

### R-56 — Put what a component lets an org change in its settings, so Build's AI can change it; write a tool of its own only for what no setting can hold

A BlueStep One component can be changed from Build in Edit mode in two ways. Its **settings** (the props an admin sets on a placed component) are picked up by Build's default AI tool with no code: an admin or the agent can change them in words. A **tool of its own**, registered by the component, covers behavior a setting cannot hold (for example, drag and drop of tiles in a grid). A component converted from Manage only has to reproduce Manage's behavior, so the build tends to give it neither, and then the org cannot change it except in code. So when building a component, put in settings what an org would sensibly change (labels, defaults, which parts show, thresholds, filters), and add a tool of its own only for what does not fit a setting. Aim for both, settings and tools, as the standard. It is a short ask in the build prompt, not a separate piece of work; on a converted component it does not hold up a release. Not yet tried live: Build's default tool changing a setting.
**Applies to:** any BlueStep One component

### A component that writes a Manage form reads the required fields from the form definition and decides each one in writing; it never keeps its own list

A write over `/gql` (`createFormRow`, `updateFormRow`) skips the form's required fields, and the platform then refuses every later save of that entry until each one is filled. The mechanical gate is in `build/typecheck.md` (*Required-fields check*: read each field's `required` from `host.forms.get` on every load, and check every write, either with the host's `validate` (or the form kit's `useFormValidation` with `validateAll()`) or with a policy with `own` and `exempt` and a coverage test); this is the rule behind it, for what the gate does not read.

- A load that cannot read `required` fails with *Try again*; a save never guesses.
- A required field with no rule that the screen does not draw still refuses the save, and the footer names it ("This form also requires: ..."), so it never slips through.
- `required: true` alone does not say what Manage refuses: fields hidden by default and conditional ones are not asked, and rows made in Manage can hold a required field empty. So each exception is written in the screen's policy and not inferred from the flag or from a walk on one record. A list made from one record where Manage let a field go empty (because the page had nothing to pick there) lets that field, and others marked required, be saved empty on every record.
- The test for each field: does the Manage page that saves this form draw it, visible and editable, in this state? `own` carries that page's condition (read from its grouping and its required rules, not from another org's copy of the page); `exempt` says why the page never asks it (not drawn, read only, filled by a formula or the server).
- A required Yes/No is answered by No: port it as "not null", never as "must be Yes".
- A screen drawn with the form kit gets the plain check from `host.formEntries.validate(def, values, { hidden })`, or from the form kit's `useFormValidation(host.formEntries, …)` with `validateAll()` before the save (`FormRenderer` checks nothing by itself); its policy is the `hidden` list and its own rules.

**How to tell.** Run `node "${CLAUDE_PLUGIN_ROOT}/tools/required.mjs" <repo>` from the folder that holds the repos (from inside a repo it cannot find the sources of the copies): a repo that writes forms and checks no required field fails. On a test org, save an entry from a component with a required field left empty: the screen refuses it and names the field; then create one over `/gql` with the field empty (it saves) and try to save it in Manage (refused).
**Applies to:** any BlueStep One component that writes a Manage form

### Each Manage field type is drawn by one control, with Manage's own words; keep a map of them and give a new type a row before it is built

What looks wrong: the same field type drawn several ways across the components of one workspace (a signature as a checkbox in one, a *Sign* button in another, a bordered button in a third), and one hand-built control copied into several repos. A look change to a control then never reaches every screen at once.
The rule:

- One control per Manage field type: the kit's where the kit has one; a shared file where it has none yet, copied unchanged to every repo (the copies check) and swapped for the kit's when it arrives. Never a second hand-drawn version of a type.
- The words are Manage's own control's, never a screen's invention and never the field's label. For a signature they are the field's `rightLabel`, which Manage prints inside its bordered button: read it from the form definition (`host.forms.get`, `rightLabel` on a signature field) or over `/gql` (`... on RelateSignatureSimpleField { formulaId rightLabel }`), and fall back to a plain default only when the field names none. Where two controls of one type meet with the same words, the field's label goes beside the control.
- Before a screen draws a field type that is not in the map, add its row to the map and build from it. A type the kit does not draw yet is a finding for the kit's owner, sent with the row.

A starting map (change it to what the workspace uses):

| Manage field type | BlueStep One control | words |
|---|---|---|
| Signature, simple | a toggle button (`B6pButton` outline, a box inside; signs on save) | the field's `rightLabel` |
| Signature, secure | no button: the signed text, or "Not signed" (a row write cannot sign it; it needs the signer's passphrase) | none |
| Checkbox | `B6pCheckbox` (whole box and words clickable) | the field's label |
| Multi-select | one checkbox per option, written as an array of ids | the options' labels |
| Single-select, radio | `B6pRadioGroup` | the options' labels |
| Single-select, dropdown | `B6pSelect` | the options' labels |
| Text, number | `B6pInput` | none |
| Memo | `B6pTextarea` | none |
| Date, date and time | `B6pInput type="date"` / `type="datetime-local"`, as the form kit's own date field does: no text box typed as a date, no hidden picker, no calendar button of its own | none |

`B6pCheckbox` draws no refused state and cuts a long label: see "`B6pCheckbox` takes no invalid, required or id, and its label is one truncated line" in `gotchas/host-components-kit.md`. A request for Manage's look on a control is a change to the kit's component, for every form at once, not a hand-built field in one component.
**How to tell.** On a test org, list a form's field types over `/gql` (`__typename`, and `rightLabel` on signature fields), then open two components that draw the same type and compare the control and its words with that read and with Manage's input.
**Applies to:** any BlueStep One component
