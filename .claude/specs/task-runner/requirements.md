# Requirements — task-runner

**Status:** Approved

## Context

core-tools 0.3.0 runs one task per session. `/task <feature> <n>` has two hard stops (approve
before edit, propose a commit at the end), `/plan` has one optional `[mechanical]` tag that no
skill consumes, and `lane/core.md` rule 9 forbids fanning out coding work. So a spec with eight
mechanical tasks costs eight sessions of the strongest model, each waiting on a person twice.

This feature gives `/plan` a required complexity marker on every task and gives `/task` an opt-in
mode that runs a spec's remaining tasks without stopping, in parallel where file lists are
disjoint, routing cheap tasks to cheap models. Every word has to work on Claude Code, Codex and
Cursor, because `AGENTS.md` and the skills are read by all three. Asked for by Fernando
Chazarreta; ships as core-tools 0.4.0.

## User stories

- As a planner using `/plan`, I want every task line to carry `[mechanical]`, `[routine]` or
  `[judgment]` with a test I can apply, so that a runner and a reader both know how much
  attention each task needs.
- As a planner, I want an optional `after: <n>, <m>` clause on a task line, so that a dependency
  that is not visible from file lists is still respected.
- As a developer, I want `/task <feature>` with no task number to ask me how to run the spec, with
  the modes as selectable options, so that I do not have to remember flags.
- As a developer, I want the continuous mode to finish the safe remaining tasks of an approved
  spec without asking me between tasks, so that a mechanical tail costs one answer instead of
  one session each.
- As a developer, I want `--parallel` to run tasks with disjoint file lists at the same time, so
  that independent work finishes sooner.
- As a developer, I want the runner to route mechanical work to the cheapest model and judgment
  work to the strongest, so that cost tracks difficulty.
- As a reviewer, I want one commit per task in run mode, so that I can review the work per task
  afterwards.
- As a Codex or Cursor user, I want every mode to state what it does where there are no subagents
  and no model choice, so that the same skill text still works.

## Acceptance criteria

Markers and dependencies (`/plan`)
- [ ] `skills/plan/SKILL.md` requires one of `[mechanical]`, `[routine]`, `[judgment]` on every
      task line and defines each with a test. Mechanical keeps today's strict rule (repeats a
      pattern an earlier task in the same spec already proved, no new decisions; a first instance
      is never mechanical). Routine is a known shape with new content. Judgment is anything with a
      design choice left, UI behavior, or a new pattern. When in doubt, rate up.
- [ ] `skills/plan/SKILL.md` documents the optional `after: <n>, <m>` clause and states the
      default: with no clause, a task depends only on earlier tasks whose file lists overlap its own.
- [ ] `skills/plan/SKILL.md` says file lists must be complete because the runner uses them to
      decide what may run in parallel.
- [ ] `skills/plan/templates/tasks.template.md` example rows show all three markers and one
      `after:` clause.

Model routing (`lane/core.md`)
- [ ] `lane/core.md` has a section mapping markers to model tiers by role: mechanical to the
      cheapest available model, routine to the mid tier, judgment to the strongest available model
      or the main session itself. The Claude Code mapping (haiku / sonnet / the session's model) is
      named in passing, the way 0.3.0 names `Explore` and `general-purpose`.
- [ ] The same section says that on a tool with no model choice the marker still sets how much
      review the result gets.
- [ ] `lane/core.md` rule 9 reads "do not fan out coding work by hand; the runner may, only across
      tasks with disjoint file lists", keeps its § 7 citation, and marks the new clause *verify*.
- [ ] No vendor model id appears in any skill file.

Mode selection (`/task`)
- [ ] `/task <feature>` with no task number and no flag asks one question with these options, and
      waits for the pick: **one task** (then asks which, or takes the next unticked), **run the
      remaining tasks** (continuous), **run the remaining tasks in parallel** (continuous plus
      parallel, cap 3), and for each run option whether to **include `[judgment]` tasks**. On Claude
      Code the question uses the option-select tool if one is available; otherwise a numbered list
      in plain text.
- [ ] Flags are shortcuts that skip the question: `--run` (also `all`), `--parallel [N]`,
      `--include-judgment`. `/task <feature> <n>` behaves exactly as in 0.3.0, including both stops,
      and never asks the mode question.
- [ ] `/plan`'s after-approval handoff tells the user the runner exists: the copyable line stays
      `/task <feature> 1`, followed by one sentence that `/task <feature>` alone offers the run modes.

Run mode (`/task`)
- [ ] In run mode `/task` loops: take the next unticked task, implement it inline or hand it to a
      subagent, run the spec's gate command, tick the box in `tasks.md`, commit with a conventional
      message, continue. No approval prompt between tasks.
- [ ] `/task` reads the task's marker and picks the tier from `lane/core.md` when it delegates.
- [ ] Run mode stops and reports on any of: a gate that still fails after one fix attempt; a
      done-when it cannot verify; a diff touching a file outside the task's list; a `[judgment]`
      task, unless `--include-judgment` was passed; an ambiguity that would need a decision the
      spec did not make.
- [ ] On stop, a one-line note (date, reason) goes under the stopped task in `tasks.md` and the
      report lists what remains.
- [ ] Each task in run mode gets its own commit.

Parallel mode (`/task`)
- [ ] `--parallel` (and `--parallel N`, default 3) is accepted only with `--run` or `all`, or picked
      from the mode question.
- [ ] The ready set is: unticked tasks whose dependencies (file-overlap plus `after:`) are all
      ticked and whose file lists overlap no task currently running.
- [ ] Each ready task goes to one subagent, with the four things rule 10 requires: objective,
      output format, tools and sources, boundaries (only these files, only this task, stop and
      report rather than guess).
- [ ] Results merge one at a time in task order; the gate runs after each merge; each task is
      ticked and committed separately.
- [ ] Where the tool has no subagents, `--parallel` degrades to `--run` and says so once.

Tool-agnostic fallbacks
- [ ] Every mode states its fallback for a tool with no subagents and no model choice: run
      sequentially in the main session, use the marker to set review depth, and rely on the task
      spec for handoff.

No task file for spec tasks
- [ ] `/task <feature> <n>` and the run modes write no `.claude/tasks/<feature>-<n>.md`. The task
      is done inline or handed to a subagent; `tasks.md` is the record (tick, stop notes), the
      commit is the review unit. The standalone `/task <slug>` path keeps its task file.
- [ ] `/task <feature> <n>` keeps its approval stop before editing, stated in chat, not in a file.

Session wording
- [ ] `/plan` and `/task` no longer tell the user to start a fresh session for every task. They
      say: continue in the current session while its context still fits the next task; start fresh
      when it no longer does, and the spec is what makes that handoff work. This matches
      `lane/core.md` rule 11, which is about unrelated tasks, not about one session per spec task.

Docs and packaging
- [ ] `CHANGELOG.md` has a 0.4.0 entry in the 0.3.0 voice: what changed, why, and what a 0.3.0
      user must do (re-tag existing specs, since `[mechanical]`-or-nothing is gone).
- [ ] `README.md` `/task` row mentions the run and parallel modes.
- [ ] `.claude-plugin/plugin.json` version is `0.4.0`.
- [ ] `skills/task/task.template.md` is unchanged.
- [ ] No hooks added (AGENTS.md rule 6). `skills/repo-setup/` untouched.

End to end
- [ ] With the checkout installed as a local marketplace and a scratch repo holding a three-task
      spec (mechanical, routine, judgment; tasks 1 and 2 with disjoint files): `/task <feature> 1`
      stops for approval; `/task <feature>` asks the mode question and picking "run the remaining
      tasks" finishes 1 and 2 and stops before 3 with a report; `--run --parallel` runs 1 and 2 at
      once, commits them in order, stops before 3; `--run --include-judgment` finishes all three.

## Out of scope

- Hooks of any kind.
- Changes to `skills/repo-setup/`.
- Vendor model ids in skills; a runner script or any code (this stays markdown).
- Retrying a task on a different model after failure.
- Re-tagging existing specs automatically; the CHANGELOG tells users to do it by hand.
- Cross-spec runs (`--run` works on one feature).
- Changing the 0.3.0 single-task flow or its two stops.
- Removing the task file from the standalone `/task <slug>` path; only spec-driven tasks drop it.

## Open questions

- Gate command source: the spec's **Verification** section is prose today. Proposed: `/plan`
  writes a `**Gate:**` line in `tasks.md` with the exact command, and run mode refuses to start
  without one. Confirm at design.
- Commit message shape: proposed `feat(<feature>): task <n> — <short description>` with the
  marker in the body. Confirm at design.
- Whether a `[judgment]` task under `--include-judgment` runs in the main session or is delegated
  to the strongest model. Proposed: main session, since that is the "or the main session itself"
  tier. Confirm at design.
