#!/bin/bash
# Compaction reminder (SessionStart, matcher "compact"). Claude Code only.
#
# Why: after a compaction the rules file loads again, but which bluestep-reference files and B.d.ts
# docs had been read is lost, and the summary mixes checked facts with the agent's own conclusions.
# One session treated a summarised conclusion (a misread query unit) as verified and shipped a bug.
# The stdout of a SessionStart hook is added to the model's context, so this prints one reminder.
#
# Only in a B6P project: a U######/ unit folder, or an AGENTS.md carrying the bluestep-tools
# rules-template marker. Silent anywhere else. It reads no input and always exits 0 — a reminder
# must never block or report an error. Checks run from the project root (CLAUDE_PROJECT_DIR), not
# the hook's working folder, which can be a unit or component folder inside the project.

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

if ls -d U[0-9][0-9][0-9][0-9][0-9][0-9]/ >/dev/null 2>&1 \
  || grep -qs 'bluestep-tools rules-template' AGENTS.md; then
  echo "bluestep-tools: this session was just compacted, so the summary above stands in for files you no longer have open. Before the next change: re-open the spec or quick-task document being followed (.claude/specs/ or .claude/quick-tasks/); before editing anything under draft/, re-open the bluestep-reference skill's SKILL.md and the topic files and B.d.ts docs the task relies on; and treat a technical fact in the summary as unverified unless it names its source (a file, a doc comment, a live check)."
fi

exit 0
