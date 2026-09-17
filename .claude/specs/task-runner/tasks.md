# Tasks — task-runner

**Status:** Complete
**Gate:** none — markdown only; each task's done-when is the check.

Each task names every file it touches and is small enough to finish in one session. Tasks are
ordered so none depends on a later one. Markers follow the rule this spec introduces; this spec is
the first tagged one, so the version bump is `[routine]`, not `[mechanical]`, because nothing
earlier in it proves the pattern.

## Tasks

- [x] **1. [judgment]** Rewrite `/plan` Phase 3: required marker with the three ordered tests,
      the `after:` clause and its default, the `**Gate:**` line, "file lists must be complete", a
      ban on `after:` pointing forward; add one sentence to "After approval" that `/task <feature>`
      alone offers the run modes; reword "fresh session per task" (intro and "After approval") to
      "continue while the context fits, start fresh when it does not". Keep every other step as it is.
      — files: `skills/plan/SKILL.md`
- [x] **2. [routine]** Update the tasks template: `**Gate:**` header line, example rows showing
      `[judgment]`, `[routine]`, `[mechanical]` and one `after:` clause, intro sentence about
      complete file lists. — files: `skills/plan/templates/tasks.template.md` — after: 1
- [x] **3. [judgment]** `lane/core.md`: reword rule 9 to "do not fan out coding work by hand; the
      runner may, only across tasks with disjoint file lists", keep the § 7 citation, mark the new
      clause *verify*; add section **Model tiers by marker (§ 7)** between Delegating and Sessions
      with the role-based table, Claude Code names in passing, and the no-model-choice fallback
      (marker sets review depth: mechanical gate+file check, routine also read the diff, judgment
      also re-check done-when against design). Rule numbers after 10 unchanged.
      — files: `lane/core.md`
- [x] **4. [judgment]** `/task`: add section **Running a spec: `/task <feature>`** with the mode
      question (five options, option-select tool by role with `AskUserQuestion` in passing,
      numbered list elsewhere), the flags `--run` / `all` / `--parallel [N]` /
      `--include-judgment`, preconditions, the sequential loop, the five stop conditions, the stop
      report shape (plus the stop note under the task in `tasks.md`), the commit shape, the
      parallel ready set and in-order merge, judgment drains the running set, and the fallbacks for
      no subagents / no model choice. Extend the description line by one clause. In the
      single-task spec section: drop the task file (the task is done inline or by a subagent, the
      approval stop is stated in chat, `tasks.md` is the record), keep both stops, reword the
      "fresh session" fallback as in task 1. The standalone `/task <slug>` path is untouched.
      — files: `skills/task/SKILL.md` — after: 1, 3
- ~~**5.** Task template: Marker and Mode lines~~ — dropped 2026-09-17: spec-driven tasks write no
      task file, so the template is unchanged. Number kept so `after:` references stay valid.
- [x] **6. [routine]** Docs: 0.4.0 CHANGELOG entry in the 0.3.0 voice (what changed, why, what a
      0.3.0 user does: re-tag specs, add a Gate line; no task file for spec tasks; the
      session-wording correction); README `/task` row gains the run modes and
      `/plan` row gains markers. — files: `CHANGELOG.md`, `README.md` — after: 4
- [x] **7. [routine]** Bump plugin version to `0.4.0`. — files: `.claude-plugin/plugin.json`
      — after: 6

## Verification

1. Grep check: no vendor model id in `skills/`:
   `grep -rniE "claude-|gpt-|opus-|sonnet-4|haiku-4" skills/ lane/` returns nothing (bare
   "haiku", "sonnet" as tier names are allowed in `lane/core.md`).
2. `grep -n "\[mechanical\]" skills/plan/SKILL.md` shows the marker only alongside `[routine]`
   and `[judgment]`; `grep -c "after:" skills/plan/templates/tasks.template.md` is at least 1.
3. Install the checkout as a local marketplace:
   `claude plugin marketplace add <checkout>` then `claude plugin install core-tools@bluestep-ai`.
4. In a scratch git repo, write `.claude/specs/demo/` with Status Approved, `**Gate:** none`, and
   three tasks: 1 `[mechanical]` touching `a.md`, 2 `[routine]` touching `b.md`, 3 `[judgment]`
   touching `a.md`, `b.md`. Then in fresh sessions:
   - `/task demo 1` stops for approval before editing, as in 0.3.0.
   - `/task demo` asks the mode question with five options; picking "run the remaining tasks"
     finishes 1 and 2 with one commit each, writes no `.claude/tasks/` file, and stops before 3
     with the report and a stop note under task 3.
   - Reset the scratch repo. `/task demo --run --parallel` runs 1 and 2 at the same time, commits
     them in order 1 then 2, stops before 3.
   - Reset. `/task demo --run --include-judgment` finishes all three, task 3 in the main session.
   - Remove the markers from the demo spec; `/task demo --run` refuses and names the lines.
5. Re-run this spec's own tasks 1 and 3 mentally against the ready set: disjoint files, no
   `after:`, so they would be the first parallel pair.
