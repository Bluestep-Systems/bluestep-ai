---
description: "A MergeReport shown in a form field sits in a host table that grows to the report's widest natural width, so its wrapping layout never wraps on a narrow screen and the page scrolls sideways; give the report's root element width: 0; min-width: 100%"
---

# A MergeReport in a form field never wraps

A MergeReport shown in a form field is placed in `tr.mergeReportRow > td`, inside a host `<table>`
within `.table-responsive`. A table sizes itself to its content's widest natural (max-content)
width, so the report's own layout never sees the narrow screen:

- a flex layout with `flex-wrap: wrap` stays side by side;
- the host table grows wider than the screen, and `.table-responsive` scrolls sideways instead.

## The fix

Give the report's root element:

```css
.myReportRoot { width: 0; min-width: 100%; }
```

`width: 0` takes the report out of the table's width calculation; `min-width: 100%` makes it fill
the cell width the rest of the form sets. As reported (2026-10, not re-run here): the layout is
unchanged at desktop width, and at phone width every section stacked with nothing overflowing the
report.

The host form's own native rows can still be wider than a phone. That is outside the report's
control.

For fields drawn by `mergeTag("F")` that ignore `width: 100%`, see "Sizing platform-rendered fields"
in [design-system.md](../reference/design-system.md).
