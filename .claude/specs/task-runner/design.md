# Design — task-runner

**Status:** Approved

## What changes

- `skills/plan/SKILL.md` — Phase 3 step 3 becomes the marker rule (required, three values, a test
  each), plus a step for `after:` clauses, a step for the `**Gate:**` line, and a sentence that
  file lists must be complete. "After approval" gains one sentence pointing at `/task <feature>`,
  and its "fresh session per task" wording (lines 11 and 67 in 0.3.0) becomes "continue while the
  context fits; start fresh when it does not".
- `skills/plan/templates/tasks.template.md` — header gains a `**Gate:**` line; example rows show
  `[judgment]`, `[routine]`, `[mechanical]` and one `after:` clause.
- `skills/task/SKILL.md` — new section **Running a spec: `/task <feature>`** with the mode
  question, the flags, the run loop, the stop conditions, the parallel ready set, merge order, and
  the fallbacks. The description line gains a clause so the skill is picked for "run the remaining
  tasks". The single-task section keeps its behaviour, gains one cross-reference, and its "run it
  in a fresh session" fallback is reworded the same way as `/plan`.
- `lane/core.md` — rule 9 reworded with a *verify* clause; new section **Model tiers by marker
  (§ 7)** between Delegating and Sessions; rule numbering after 10 unchanged.
- `CHANGELOG.md` — 0.4.0 entry at the top.
- `README.md` — `/task` row mentions the run modes; `/plan` row mentions markers.
- `.claude-plugin/plugin.json` — version `0.4.0`.

Not touched: `skills/task/task.template.md` (spec-driven tasks no longer write a task file, and
the standalone path is unchanged), `skills/repo-setup/`, `docs/working-habits.md`, `tools/measure.py`, hooks (none).

## Approach

**Everything is markdown that a model follows; there is no runner script.** The "runner" is
`/task` reading `tasks.md` and looping. That keeps the plugin in its current shape (AGENTS.md:
"markdown and one Python script") and works on any tool that can read a skill.

**Task line grammar.** One line per task, parsed by eye and by model:

```
- [ ] **<n>. [<marker>]** <description> — files: `a`, `b` — after: <n>, <m>
```

`<marker>` is one of `mechanical`, `routine`, `judgment`, required. `after:` is optional; when it
is absent, the task's dependencies are the earlier tasks whose file lists share at least one path
with its own. `/plan` states this and states that file lists must be complete because the runner
reads them as the parallel-safety contract. The `**Gate:**` header line holds the exact command
the runner executes after every task. For a repo with no test command the line reads `none`; a
gate of `none` passes trivially and the done-when check carries the load.

**Marker tests (in `/plan`).** Written as questions the planner answers in order; the first yes
wins, and the list runs from strongest to cheapest so doubt rates up:

1. Is there a design choice left, UI behaviour, a new pattern, or anything the spec does not
   decide? → `[judgment]`.
2. Is the shape known (a typed contract, a template, an existing example in the repo) but the
   content new? → `[routine]`.
3. Does it repeat a pattern an earlier task *in this spec* already proved, with no new decision
   and nothing new added? → `[mechanical]`. A first instance is never mechanical.

**Model tiers (in `lane/core.md`).** A short table by role, not vendor: mechanical → cheapest
available model; routine → mid tier; judgment → strongest available model or the main session.
Claude Code's names appear once in parentheses (haiku / sonnet / the session's model), the same
way 0.3.0 names `Explore`. The section closes with the no-choice fallback: on a tool with one
model, the marker sets review depth instead. Mechanical: check the gate and that the diff touches
only listed files. Routine: also read the diff. Judgment: also re-read the task's done-when against
the design before ticking.

**Mode question (in `/task`).** `/task <feature>` with a spec name, no number, no flag:

> How should I run `<feature>`? (N tasks remain: a mechanical, b routine, c judgment)
> 1. One task — the next unticked, or name a number
> 2. Run the remaining tasks, stop at the first `[judgment]`
> 3. Run the remaining tasks in parallel (up to 3), stop at the first `[judgment]`
> 4. Run everything, judgment included (sequential)
> 5. Run everything in parallel, judgment included

On Claude Code the skill says to use the option-select tool when one is available (named by role,
"the tool that asks the user a multiple-choice question", with `AskUserQuestion` in passing).
Elsewhere the numbered list is printed and the skill waits for a reply. Flags map onto the same
five outcomes and skip the question. `/task <feature> <n>` never asks; it is the 0.3.0 path,
untouched.

**Run loop (sequential).** Precondition: `tasks.md` **Status** is Approved or In progress, the
working tree is clean, and every task line has a marker; otherwise stop and say what to fix (this
is also the re-tag nudge for 0.3.0 specs). Then, until nothing remains or a stop fires:

1. Pick the lowest-numbered unticked task whose dependencies are ticked.
2. If it is `[judgment]` and judgment is not included, stop.
3. No task file. The user chose run mode; that is the approval. The task line, the design
   section it needs and the gate are the whole brief.
4. Implement at the marker's tier: delegate to a general-purpose subagent at that tier when one
   exists, with the four things rule 10 requires; otherwise do it inline.
5. Check the diff touches only listed files. Run the gate. On failure, one fix attempt, then stop.
6. Verify done-when. If it cannot be verified, stop.
7. Tick the box in `tasks.md`, commit as `feat(<feature>): task <n> — <desc>` with
   `Marker: <marker>` and `Spec: .claude/specs/<feature>/tasks.md` in the body. Stage only the
   task's files and `tasks.md`.

**Stop report.** Always the same shape: which task stopped and why, also written as one indented
line under that task in `tasks.md` (`stopped 2026-09-17: <reason>`) so a later session sees it;
the tasks done this run with commit hashes; the tasks that
remain with their markers; then the copyable line to continue, `/task <feature> <n>` for the
stopped task.

**Parallel.** Only on top of run mode, only where the tool has subagents; otherwise it degrades to
sequential and says so once at the start. Loop:

1. Ready set = unticked tasks whose dependencies are all ticked *and* whose file lists overlap no
   task currently running. Exclude `[judgment]` unless included. Take up to N (default 3) in task
   order.
2. Start one subagent per task, each on its own copy of the tree where the tool offers one
   (in Claude Code, a worktree). The delegation states: objective (the task line plus the design
   section it needs), output format (a summary: files changed, done-when evidence, open
   questions), tools and sources (only `requirements.md`, `design.md`, the listed files), and
   boundaries (only these files, only this task, stop and report rather than guess, do not tick
   or commit).
3. As results return, hold them; merge in task order, lowest number first, never out of order
   even if a later task finished sooner. After each merge: file-list check, gate, done-when, tick,
   commit, as in sequential steps 5 to 7.
4. A stop condition in any task stops the whole run after the merges already in flight finish.
   Unmerged results are reported as "finished, not merged" with where their diff lives.
5. Refill the ready set and repeat.

Ticking and committing stay in the main session so `tasks.md` and git history have one writer.

**Judgment under inclusion.** Runs in the main session (the "or the main session itself" tier)
and never in parallel: when the next ready task is `[judgment]`, the runner drains the running
set, merges, then does the judgment task alone.

**No task file for spec tasks.** The 0.1.0 `/task` wrote `.claude/tasks/<feature>-<n>.md` for a
spec task too. Decided 2026-09-17 during task 1: that file duplicates what `tasks.md`, the design
and the commit already hold, and costs a write plus an approval round per task. Spec-driven tasks,
single or run mode, are done inline or handed to a subagent with the task line as the brief.
`tasks.md` is the record (ticks, stop notes), the commit is the review unit. The standalone
`/task <slug>` path, which has no spec to lean on, keeps its task file and template.

**Session wording.** The 0.1.0 skills turned `lane/core.md` rule 11 ("one task per session",
meaning do not carry two unrelated tasks) into "start a fresh session for every spec task". That
is stronger than the rule and wrong for a spec whose tasks share context, where a warm session is
cheaper than a cold re-read. Both skills now say: keep going in the current session while its
context still fits the next task; start fresh when it no longer does, or when switching to
unrelated work. The spec is what makes the cold start work.
The CHANGELOG names this as a correction.

## Data flow

Reads: `tasks.md` (status, gate, task lines), `requirements.md` and `design.md` scoped per task,
the tier table in `lane/core.md` through the rule set the repo names. Writes, per task, in this
order: the task's listed files, then `tasks.md` (tick), then the git commit. On stop: the note
under the task in `tasks.md`, then the report to the user. Nothing is
written outside the repo.

## Edge cases

- **Spec with no markers (0.3.0 vintage).** Run mode refuses and names the lines missing a marker.
  Single-task mode still works, so old specs are not broken.
- **`after:` pointing at a later or missing task.** `/plan` forbids it; the runner treats it as an
  ambiguity and stops.
- **File overlap between two tasks that `after:` does not mention.** Overlap alone makes a
  dependency, so they never run together. That is why file lists must be complete.
- **Gate is `none`.** Passes; done-when is the only check. The skill says so.
- **Dirty working tree at start.** Stop before the first task: per-task commits need a clean tree
  to stage only their files.
- **Subagent returns having touched an unlisted file.** Its result is not merged; the run stops
  with the diff location in the report.
- **`--parallel 1`.** Same as `--run`; accepted.
- **All remaining tasks are judgment and judgment is excluded.** Run mode stops at once with the
  report; the question path shows the counts so the user can pick option 4 instead.
- **The option-select tool is missing.** Numbered list in plain text, wait for a number.
- **No subagents and no model choice (Cursor, Codex today).** Sequential, inline, marker sets
  review depth. `tasks.md` ticks and per-task commits are the handoff if the session dies mid-run.

## Risks and rollback

- **The runner commits without a human in the loop.** Bounded by: opt-in, per-task commits, file
  list check, gate, stop on judgment by default. Rollback is `git revert` per commit; each commit
  body names its task and marker.
- **Cheap-model output on a mechanical task is wrong but passes the gate.** The marker test is
  strict on purpose and the CHANGELOG tells users to rate up when unsure. Revert per task.
- **Rule 9 loosening leaks into hand-driven fan-out.** The new wording contrasts "by hand" with
  "the runner may", and the clause is marked *verify* so it is measured, not trusted.
- **Skill text grows and the always-on cost rises.** Only the description lines are always loaded
  and they grow by one clause. Measure with `tools/measure.py` after a week.
- **Rollback of the feature itself.** Revert the 0.4.0 commit and ship 0.4.1 with a CHANGELOG
  line. Specs already tagged keep working with the 0.3.0 skill, which ignores every tag except
  `[mechanical]`.
