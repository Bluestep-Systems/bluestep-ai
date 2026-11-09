---
description: "A MergeReport's console.log / console.error output is written to the script's Out / Error log only on the server (pod) that rendered the page, so reading one pod's log can show nothing for code that ran; a pagelet-embedded report has been reported to write nothing at all — check every pod, and verify a MergeReport change by what it renders, not by log lines"
---

# A MergeReport's console output is per pod, and may not be there at all

## What happens

A BsJs MergeReport opened directly writes `console.log` to the script's **Out** log and
`console.error` to its **Error** log (the file name carries the date), but **only on the server (pod)
that rendered the page** (verified 2026-11 on a test org: the line was on the serving web pod; the
other web pod had no log file for the script that day).

So "no line in the log" can mean the code ran on another pod. Open the logs from the **Out Log** /
**Error Log** links on the script's editor or setup page: the log viewer lists the pods across the
top, one link each. Open every pod before concluding anything. (The links' `id` is not the plain
script id, so use the links rather than building the URL.)

As reported (2026-10, not re-run here): a MergeReport **embedded as a pagelet** wrote no Out log and
no new Error lines after a render that ran `console.log` and `console.error`. Whether that is the
same per-pod split or nothing being written for pagelet embeds is not settled.

The gateway's `read_log` describes itself as merging a SCRIPT log from every server, but it needs the
`ORG_LOGS` endorsement on the token's account, and the merge was not checked here.

## What to do

- Verify a MergeReport change by what it **renders**: a visible debug block, or a `data-` attribute
  on an element, read from the page.
- Read the logs as a hint only. When a line is missing, check every pod in the log viewer before
  saying the code did not run.
- `B.io` has no logging method to use instead (as reported 2026-10).
