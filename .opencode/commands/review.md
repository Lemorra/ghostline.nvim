---
description: Run an independent, read-only review of changes for maintainer follow-up
agent: reviewer
subagent: true
---

Independently review the requested scope: $ARGUMENTS

If no specific scope was supplied, review the current uncommitted changes. Use
the diff and surrounding code, not just the patch in isolation. Do not edit
files. Report only actionable findings, with severity and file/line references,
then note any important validation gaps. If there are no findings, say so and
state what was reviewed. This review informs the human maintainer and is not an
approval or merge decision.
