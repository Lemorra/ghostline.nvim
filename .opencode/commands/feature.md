---
description: Implement a focused feature with tests, checks, and a human-review handoff
agent: developer
---

Implement this feature or task:

$ARGUMENTS

Workflow:
1. Inspect the relevant implementation, tests, docs, and current working-tree
   changes. Preserve unrelated user work.
2. Establish the smallest complete scope. For routine reversible details,
   state reasonable assumptions briefly and proceed. If the task requires a
   product, API, architecture, dependency, compatibility, or security decision
   with materially different options, ask the maintainer using the question
   tool and wait before choosing.
3. Implement in the existing project style. Add or update focused tests for
   behavior changes and documentation for user-visible behavior or setup.
4. Run `make check` when available; otherwise run the relevant checks. Resolve
   failures caused by the change and report unrelated or unavailable checks
   honestly.
5. Inspect the final diff for correctness, scope, readability, and accidental
   edits. Summarize the implementation, checks, assumptions, and any decisions
   still needed. Clearly hand the diff to a human maintainer for final review;
   do not claim the work is approved or ready to publish.
