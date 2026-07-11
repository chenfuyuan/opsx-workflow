---
name: opsx-apply
description: Implement tasks from an OpenSpec change (Experimental)
---

Implement tasks from an OpenSpec change.

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**语言**：所有面向用户的交流（进度说明、提示、状态汇报、下方所有 Output 模板）必须使用中文。保留命令、文件路径、change 名、schema 名、代码符号等技术标识的原文，但解释性文字与标题用中文。

**Input**: Optionally specify a change name (e.g., `/opsx-apply add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **Select the change**

   If a name is provided, use it. Otherwise:
   - Infer from conversation context if the user mentioned a change
   - Auto-select if only one active change exists
   - If ambiguous, run `openspec list --json` to get available changes and use the **AskUserQuestion tool** to let the user select

   Always announce: "Using change: <name>" and how to override (e.g., `/opsx-apply <other>`).

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
   - If `state: "blocked"` (missing artifacts): show message, suggest using `/opsx-continue`
   - If `state: "all_done"`: congratulate, suggest archive
   - Otherwise: proceed to implementation

4. **Read context files**

   Read the files listed in `contextFiles` from the apply instructions output.
   The files depend on the schema being used:
   - **spec-driven**: proposal, specs, design, tasks
   - Other schemas: follow the contextFiles from CLI output

   **Also read `openspec/standards.md` if it exists** — the persistent project-level
   standards (layering/dependency direction, naming vocabulary, module structure,
   forbidden patterns). Generated code MUST conform to it. If it does not exist, skip silently.

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
   - If all done: suggest archive
   - If paused: explain why and wait for guidance

**Output During Implementation**

```
## 正在实现：<change-name>（schema：<schema-name>）

正在处理任务 3/7：<任务描述>
[...实现过程...]
✓ 任务完成

正在处理任务 4/7：<任务描述>
[...实现过程...]
✓ 任务完成
```

**Output On Completion**

```
## 实现完成

**Change：** <change-name>
**Schema：** <schema-name>
**进度：** 7/7 任务完成 ✓

### 本次会话完成
- [x] 任务 1
- [x] 任务 2
...

所有任务已完成！可以用 `/opsx-archive` 归档此 change。
```

**Output On Pause (Issue Encountered)**

```
## 实现已暂停

**Change：** <change-name>
**Schema：** <schema-name>
**进度：** 4/7 任务完成

### 遇到的问题
<问题描述>

**可选方案：**
1. <方案一>
2. <方案二>
3. 其他方案

你希望如何处理？
```

**Guardrails**
- Keep going through tasks until done or blocked
- Always read context files before starting (from the apply instructions output)
- **Generated code MUST conform to `openspec/standards.md` if it exists** — respect layering/dependency direction, naming vocabulary, module boundaries, and forbidden patterns. If a task cannot be done without violating standards, pause and surface the conflict instead of silently breaking the boundary.
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
