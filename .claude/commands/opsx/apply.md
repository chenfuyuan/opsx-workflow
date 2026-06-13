---
name: "OPSX: Apply"
description: Implement tasks from an OpenSpec change (Experimental)
category: Workflow
tags: [workflow, artifacts, experimental]
---

Implement tasks from an OpenSpec change.

**Input**: Optionally specify a change name (e.g., `/opsx:apply add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **Select the change**

   If a name is provided, use it. Otherwise:
   - Infer from conversation context if the user mentioned a change
   - Auto-select if only one active change exists
   - If ambiguous, run `openspec list --json` to get available changes and use the **AskUserQuestion tool** to let the user select

   Always announce: "Using change: <name>" and how to override (e.g., `/opsx:apply <other>`).

2. **Check status to understand the schema**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to understand:
   - `schemaName`: The workflow being used (e.g., "spec-driven")
   - Which artifact contains the tasks (typically "tasks" for spec-driven, check status for others)

3. **Get apply instructions**

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   This returns:
   - Context file paths (varies by schema)
   - Progress (total, complete, remaining)
   - Task list with status
   - Dynamic instruction based on current state

   **Handle states:**
   - If `state: "blocked"` (missing artifacts): show message, suggest using `/opsx:continue`
   - If `state: "all_done"`: congratulate, suggest archive
   - Otherwise: proceed to implementation

4. **Read context files**

   Read the files listed in `contextFiles` from the apply instructions output.
   The files depend on the schema being used:
   - **spec-driven**: proposal, specs, design, tasks
   - Other schemas: follow the contextFiles from CLI output

   **Additionally, check for `openspec/changes/<name>/pre_design.md`** (plus any sibling `pre_design.*.md` volumes). It is NOT part of `contextFiles`, but if it exists you MUST read it and treat it as implementation-time hard constraints:
   - **§2 Constraints / Invariants** — must hold in the code you write
   - **§4 Guardrails** — "Must follow" items must be honored in implementation; "Forbidden to invent" scope MUST NOT be implemented, even if a task seems to imply it. On conflict between a task and a guardrail: pause, surface the conflict, let the user decide — do not silently pick a side.

5. **Show current progress**

   Display:
   - Schema being used
   - Progress: "N/M tasks complete"
   - Remaining tasks overview
   - Dynamic instruction from CLI

6. **Implement tasks (loop until done or blocked)**

   For each pending task:
   - Show which task is being worked on
   - Choose execution mode by task type:
     - **Code tasks**: use the `test-driven-development` skill as the default path:
       1. Write or identify the next smallest failing test for the task
       2. Run it to confirm it fails for the expected reason
       3. Make the smallest code change required to pass it
       4. Run relevant regression checks
     - **Documentation tasks**: update the relevant docs directly without forcing TDD
   - Keep changes minimal and focused
   - If unexpected failures or unexplained behavior appear, switch to the `systematic-debugging` skill to find the root cause before proposing or making additional fixes
   - After root cause is understood, return to the appropriate path and complete the task
   - Mark task complete in the tasks file: `- [ ]` → `- [x]`
   - **Git anchor**: after every 1-3 completed tasks, suggest a commit with a one-line message (do NOT auto-commit)
   - Continue to next task

   **Pause if:**
   - Task is unclear → ask for clarification
   - Implementation reveals a design issue → suggest updating artifacts
   - User interrupts

   **Use systematic debugging if:**
   - A new test does not fail in the expected way
   - A test or regression fails and the cause is not yet understood
   - Implementation exposes unexpected runtime, integration, or environment behavior
   - A blocker appears and the root cause is unclear

7. **On completion or pause, show status**

   Display:
   - Tasks completed this session
   - Overall progress: "N/M tasks complete"
   - If all done, suggest in order: (1) final commit; (2) fresh-context diff review via the `code-reviewer` subagent; (3) `/opsx:verify` — it runs in the `spec-verifier` subagent; (4) archive once verification passes
   - If paused: explain why and wait for guidance

**Output During Implementation**

```
## Implementing: <change-name> (schema: <schema-name>)

Working on task 3/7: <task description>
[...implementation happening...]
✓ Task complete

Working on task 4/7: <task description>
[...implementation happening...]
✓ Task complete
```

**Output On Completion**

```
## Implementation Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 7/7 tasks complete ✓

### Completed This Session
- [x] Task 1
- [x] Task 2
...

All tasks complete! Next: commit your work, then run `/opsx:verify` (fresh-context audit via the spec-verifier subagent). Archive with `/opsx:archive` once verification passes.
```

**Output On Pause (Issue Encountered)**

```
## Implementation Paused

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 4/7 tasks complete

### Issue Encountered
<description of the issue>

**Options:**
1. <option 1>
2. <option 2>
3. Other approach

What would you like to do?
```

**Guardrails**
- Keep going through tasks until done or blocked
- Always read context files before starting (from the apply instructions output)
- If `pre_design.md` exists, treat its §2 / §4 as implementation-time hard constraints — never implement "Forbidden to invent" scope; pause and flag conflicts instead
- If this session just finished a long planning conversation, recommend `/clear` before implementing — the artifacts are the complete handoff
- Use the `test-driven-development` skill for code implementation tasks; do not force TDD for documentation-only tasks
- If unexpected failures or unexplained behavior appear, use the `systematic-debugging` skill before proposing additional fixes
- If task is ambiguous, pause and ask before implementing
- If implementation reveals issues, pause and suggest artifact updates
- Keep code and document changes minimal and scoped to each task
- Update task checkbox immediately after completing each task
- Pause on unclear requirements - don't guess
- Use contextFiles from CLI output, don't assume specific file names

**Fluid Workflow Integration**

This skill supports the "actions on a change" model:

- **Can be invoked anytime**: Before all artifacts are done (if tasks exist), after partial implementation, interleaved with other actions
- **Allows artifact updates**: If implementation reveals design issues, suggest updating artifacts - not phase-locked, work fluidly
