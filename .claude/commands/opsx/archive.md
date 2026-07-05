---
name: "OPSX: Archive"
description: Archive a completed change in the experimental workflow
category: Workflow
tags: [workflow, archive, experimental]
---

Archive a completed change in the experimental workflow.

**语言**：所有面向用户的交流（提示、警告、汇总、下方所有 Output 模板）必须使用中文。保留命令、文件路径、change 名、schema 名、归档目录名等技术标识的原文，但解释性文字与标题用中文。

**Input**: Optionally specify a change name after `/opsx:archive` (e.g., `/opsx:archive add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes. Use the **AskUserQuestion tool** to let the user select.

   Show only active changes (not already archived).
   Include the schema used for each change if available.

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Check artifact completion status**

   Run `openspec status --change "<name>" --json` to check artifact completion.

   Parse the JSON to understand:
   - `schemaName`: The workflow being used
   - `artifacts`: List of artifacts with their status (`done` or other)

   **If any artifacts are not `done`:**
   - Display warning listing incomplete artifacts
   - Prompt user for confirmation to continue
   - Proceed if user confirms

3. **Check task completion status**

   Read the tasks file (typically `tasks.md`) to check for incomplete tasks.

   Count tasks marked with `- [ ]` (incomplete) vs `- [x]` (complete).

   **If incomplete tasks found:**
   - Display warning showing count of incomplete tasks
   - Prompt user for confirmation to continue
   - Proceed if user confirms

   **If no tasks file exists:** Proceed without task-related warning.

4. **Assess delta spec sync state**

   Check for delta specs at `openspec/changes/<name>/specs/`. If none exist, proceed without sync prompt.

   **If delta specs exist:**
   - Compare each delta spec with its corresponding main spec at `openspec/specs/<capability>/spec.md`
   - Determine what changes would be applied (adds, modifications, removals, renames)
   - Show a combined summary before prompting

   **Prompt options:**
   - If changes needed: "Sync now (recommended)", "Archive without syncing"
   - If already synced: "Archive now", "Sync anyway", "Cancel"

   If user chooses sync, execute `/opsx:sync` logic. Proceed to archive regardless of choice.

5. **Perform the archive**

   Create the archive directory if it doesn't exist:
   ```bash
   mkdir -p openspec/changes/archive
   ```

   Generate target name using current date: `YYYY-MM-DD-<change-name>`

   **Check if target already exists:**
   - If yes: Fail with error, suggest renaming existing archive or using different date
   - If no: Move the change directory to archive

   ```bash
   mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
   ```

6. **Update implementation status**

   Read `openspec/实现状态.md`.

   Determine what capability the archived change implements:
   - Read the change's proposal or design artifacts to identify the capability
   - Match against existing rows in the status tables

   **If a matching row is found:**
   - Update: 状态 → "已实现", 归档 change → the archived change name, 更新日期 → today's date
   - Update the "最后更新" line at the top of the document

   **If the capability is new (no matching row):**
   - Append a new row to the appropriate capability layer section (基础设施 / AI 能力 / 业务功能)
   - Fill in all columns including 来源 (link to requirement card if one exists)

   **If cannot determine the capability** (e.g., pure docs, renaming, or infrastructure-only changes):
   - Do not modify the status table
   - Note in the summary that no status update was made

   **If `openspec/实现状态.md` does not exist:** Skip this step silently.

7. **Display summary**

   Show archive completion summary including:
   - Change name
   - Schema that was used
   - Archive location
   - Spec sync status (synced / sync skipped / no delta specs)
   - Implementation status update (which capability was updated, or "no matching capability")
   - Note about any warnings (incomplete artifacts/tasks)

**Output On Success**

```
## 归档完成

**Change：** <change-name>
**Schema：** <schema-name>
**归档至：** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs：** ✓ 已同步到主 specs
**Status：** ✓ 已更新 openspec/实现状态.md（<capability-name> → 已实现）

所有产物已完成。所有任务已完成。
```

**Output On Success (No Delta Specs)**

```
## 归档完成

**Change：** <change-name>
**Schema：** <schema-name>
**归档至：** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs：** 无 delta specs
**Status：** ✓ 已更新 openspec/实现状态.md（<capability-name> → 已实现）

所有产物已完成。所有任务已完成。
```

**Output On Success With Warnings**

```
## 归档完成（含警告）

**Change：** <change-name>
**Schema：** <schema-name>
**归档至：** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs：** 已跳过同步（用户选择跳过）
**Status：** ✓ 已更新 openspec/实现状态.md（<capability-name> → 已实现）

**警告：**
- 归档时有 2 个未完成的产物
- 归档时有 3 个未完成的任务
- delta spec 同步已被跳过（用户选择跳过）

若非有意为之，请检查此归档。
```

**Output On Error (Archive Exists)**

```
## 归档失败

**Change：** <change-name>
**目标：** openspec/changes/archive/YYYY-MM-DD-<name>/

目标归档目录已存在。

**可选方案：**
1. 重命名已有的归档
2. 若为重复归档，删除已有的归档
3. 等到其他日期再归档
```

**Guardrails**
- Always prompt for change selection if not provided
- Use artifact graph (openspec status --json) for completion checking
- Don't block archive on warnings - just inform and confirm
- Preserve .openspec.yaml when moving to archive (it moves with the directory)
- Show clear summary of what happened
- If sync is requested, use /opsx:sync approach (agent-driven)
- If delta specs exist, always run the sync assessment and show the combined summary before prompting
