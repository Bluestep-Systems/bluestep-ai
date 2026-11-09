---
description: "Client JS that works with platform-rendered form fields (merge reports and form pages): find a field's row by its <className>Label class (needs a CSS class set on the field), not the field's own class, which is absent when the field is read-only; a SIMPLE signature is a checkbox, so 'signed' = saved value OR checkbox.checked; a relationship <select> option value is 1000201___<entry short id>_<form id>, match /___(\\d+)/"
---

# Client JS on platform-rendered form fields

Rules for client code (a merge report's `static/script.ts`, a form page script) that reads or
changes fields the platform draws. As reported 2026-10 from a live org, checked over several days;
not re-run here.

## 1. Find a field's row by its label class

This needs a **CSS class set on the field** in its settings; it can differ from the field's formula
id. That class goes on the field's **editable input** only. Where that input sits varies, and when
the field is **read-only** for the viewer the class is not drawn at all. The platform also puts
**`<className>Label`** on the field's label, which is drawn whether or not the field is editable,
always in the same place. Selectors on the input itself, such as `[data-fid="…"]`, likely fail the
same way for a read-only viewer (not checked).

```typescript
// The field's CSS class is "notesField". Hide or show its row: start from the label.
document.querySelector('.notesFieldLabel')?.closest('tr')?.style.setProperty('display', 'none');

// Reach the input itself only for a field you know is editable for this viewer.
const input = document.querySelector<HTMLTextAreaElement>('textarea.notesField');
```

## 2. A SIMPLE signature is a checkbox

An editable SIMPLE signature field is a checkbox carrying the field's class. Signing on the page
ticks it, so "signed on this page" is a `change` listener plus `.checked` on `input.<fieldClass>`.

Once it is saved, a regular user gets no checkbox, but supers and org admins still get one, ticked.
So:

- "signed" = the server's saved value **or** `checkbox.checked`;
- a checkbox being there never means "unsigned";
- don't build MutationObserver or value-diff tricks to detect signing.

`justSigned` is server-side only (RelateScript calculations and save formulas).

## 3. A relationship option's value carries two ids

A RELATIONSHIP field's `<select>` option value is `1000201___<entry short id>_<related form id>`,
for example `1000201___12345678_1000001`:

- the number after `___` is the related entry's short id (the same as
  `selected()[0].id().shortId()` on the server);
- the part after the last `_` is the related form's id.

Read the entry id with `/___(\d+)/`, never "the part after the last `_`".

For an option field's value in general, see [option-field-dom-value.md](../gotchas/option-field-dom-value.md).
