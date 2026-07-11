---
name: opsx-continue
description: Continue working on a change - create the next artifact (Experimental)
---

Continue working on a change by creating the next artifact.

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**: Optionally specify a change name after `/opsx-continue` (e.g., `/opsx-continue add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes sorted by most recently modified. Then use the **AskUserQuestion tool** to let the user select which change to work on.

   Present the top 3-4 most recently modified changes as options, showing:
   - Change name
   - Schema (from `schema` field if present, otherwise "spec-driven")
   - Status (e.g., "0/5 tasks", "complete", "no tasks")
   - How recently it was modified (from `lastModified` field)

   Mark the most recently modified change as "(Recommended)" since it's likely what the user wants to continue.

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Check current status**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to understand current state. The response includes:
   - `schemaName`: The workflow schema being used (e.g., "spec-driven")
   - `artifacts`: Array of artifacts with their status ("done", "ready", "blocked")
   - `isComplete`: Boolean indicating if all artifacts are complete

3. **Act based on status**:

   ---

   **If all artifacts are complete (`isComplete: true`)**:
   - Congratulate the user
   - Show final status including the schema used
   - Suggest: "All artifacts created! You can now implement this change with `/opsx-apply` using the default TDD workflow, or archive it with `/opsx-archive`."
   - STOP

   ---

   **If artifacts are ready to create** (status shows artifacts with `status: "ready"`):
   - **Check for pre_design**: Read `pre_design.md` from the change's `changeRoot` (from the status JSON) if it exists — `<changeRoot>/pre_design.md`, plus any sibling `pre_design.*.md` volume files. This is the **binding upstream constraint** for artifact generation.
   - Pick the FIRST artifact with `status: "ready"` from the status output
   - Get its instructions:
     ```bash
     openspec instructions <artifact-id> --change "<name>" --json
     ```
   - Parse the JSON. The key fields are:
     - `context`: Project background (constraints for you - do NOT include in output)
     - `rules`: Artifact-specific rules (constraints for you - do NOT include in output)
     - `template`: The structure to use for your output file
     - `instruction`: Schema-specific guidance
     - `resolvedOutputPath`: **absolute, store-aware path to write the artifact — use this** (`outputPath` is only the bare filename like `proposal.md` and would land in the repo root)
     - `dependencies`: Completed artifacts to read for context
   - **Create the artifact file**:
     - Read any completed dependency files for context
     - **If pre_design exists**: apply pre_design constraints (see "Pre-Design Constraint Rules" section below)
     - Use `template` as the structure - fill in its sections
     - Apply `context` and `rules` as constraints when writing - but do NOT copy them into the file
     - Write to `resolvedOutputPath` (absolute, store-aware) from the instructions JSON
   - Show what was created and what's now unlocked
   - If pre_design was used, note: "Generated under pre_design constraints."
   - STOP after creating ONE artifact

   ---

   **If no artifacts are ready (all blocked)**:
   - This shouldn't happen with a valid schema
   - Show status and suggest checking for issues

4. **After creating an artifact, show progress**
   ```bash
   openspec status --change "<name>"
   ```

**Output**

After each invocation, show:
- Which artifact was created
- Schema workflow being used
- Current progress (N/M complete)
- What artifacts are now unlocked
- Prompt: "Run `/opsx-continue` to create the next artifact"

**Artifact Creation Guidelines**

The artifact types and their purpose depend on the schema. Use the `instruction` field from the instructions output to understand what to create.

Common artifact patterns:

**spec-driven schema** (proposal → specs → design → tasks):
- **proposal.md**: Ask user about the change if not clear. Fill in Why, What Changes, Capabilities, Impact.
  - The Capabilities section is critical - each capability listed will need a spec file.
- **specs/<capability>/spec.md**: Create one spec per capability listed in the proposal's Capabilities section (use the capability name, not the change name).
- **design.md**: Document technical decisions, architecture, and implementation approach.
- **tasks.md**: Break down implementation into checkboxed tasks.

For other schemas, follow the `instruction` field from the CLI output.

**Pre-Design Constraint Rules**

When `pre_design.md` exists, treat it as the **primary upstream constraint** — above the `context` and `rules` from `openspec instructions`. Apply these rules to the ONE artifact you are creating this invocation. The current pre_design structure has 4 sections + 1 informational appendix:

| pre_design 章节 | Constraint on downstream artifacts |
|---|---|
| §1 Problem & Goals (含 Non-goals) | Goals 限定 specs / tasks 范围；Non-goals 范围内的工作**禁止生成** |
| §2 Constraints / Invariants | 所有 artifact 不得违反硬约束 / 不变量 |
| §3 Direction & Key decisions | design.md 必须遵守 Direction 路线选择与已定决策；不引入与放弃路线/取舍矛盾的方向 |
| §4 Guardrails for downstream | "Must follow" 项必须体现；"Forbidden to invent" 内容**禁止生成** |
| (附) Next step | 仅是给用户的下一步建议，本命令不依赖此节 |

**Per-artifact application** (apply the block matching the artifact you're creating):

- `proposal.md`: 章节遵循 OpenSpec schema（Why / What Changes / Capabilities / Impact），以 §1 (Problem & Goals) 为中心展开 "why"。**不扩展** §1 边界。
  - `What Changes`: 3-5 条一行 bullet，只表达变化轮廓（"新增/修改/移除 X"），不展开实现细节
  - `Capabilities`: 形式化声明（capability 名 + 一句话定位），不复述 What Changes
  - Non-goals 不在 proposal 独立成节，由 pre_design §1 + 下游 design.md 的 Goals/Non-Goals 承担
  - 详细实现细节归属 pre_design / specs / design，不在 proposal 重复
- `specs/`: 在 §1 (Goals / Non-goals) 边界内定义需求场景。**不引入** §1 未声明的能力。
  - **可测性约束**：每个 Scenario 必须可被测试代码验证；架构违规、命名约定、代码组织等不可测内容**不入 spec**。
  - **不可测内容的分流**：
    - Change 特定的架构判断 → `design.md` "设计决策"节
    - 项目级架构规则 → 标记"建议抽到项目级文档"，不主动归档
    - 评审/自检类 → `tasks.md` 末尾"验证与收尾"区
  - **结构信号**：每个 Requirement 推荐 1-3 个 Scenario；每个 Requirement 表达单一能力；单个 capability 的 `spec.md` ≤ 200 行
- `design.md`: 章节遵循 OpenSpec schema（Context / Goals-Non-Goals / Decisions / Risks-Trade-offs / Migration Plan / Open Questions）。在 §3 (Direction) 选定路线内展开架构；尊重已定决策；不与放弃路线矛盾；遵守 §4 Guardrails。
  - 架构层判断（模块切分、依赖关系、数据流）作为决策记录在 `Decisions` 节，必要时配 ASCII 图
  - 接收从 spec 移出的 change 特定架构判断（边界、依赖、命名约定等）写入 `Decisions` 节
  - `Migration Plan` / `Open Questions` 节按需，无内容时可省略
- `tasks.md`: 在 §1 + §3 范围内拆分；**禁止**为 §1 (Non-goals) 或 §4 (Forbidden to invent) 的内容产生 task。
  - **任务一行原则**：动作 + 对象 + 简短约束；细节引用 spec / design，不复述
  - **测试不单独成节**：TDD 节奏让单元/集成测试随实施任务自然产出；跨切面测试（架构边界、E2E 基础设施）可作为独立任务，不重复罗列单元测试
  - **末尾"验证与收尾"区分两块**：
    - (a) 整体测试基线运行 / 回归确认
    - (b) 从 spec 移出的不可测约束自检（如"自检未引入业务 schema"、"自检 API key 未泄露到日志"）
  - **单任务粒度**：一次会话内可完成（约 30-90 分钟工作量）
  - **长度信号**：tasks.md ≤ 100 行

**Out-of-date references to remove on read**: the old pre_design had "OpenSpec mapping"、"Allowed to elaborate"、"Contract drafts" 等章节，新版本不再包含。如果遇到旧版 pre_design.md 仍有这些章节，可作为附加约束读取，但不要因为缺失而报错。

**Guardrails**
- Create ONE artifact per invocation
- Always read dependency artifacts before creating a new one
- If pre_design exists, read it first and treat it as the highest-priority constraint
- Never skip artifacts or create out of order
- If context is unclear, ask the user before creating
- Verify the artifact file exists after writing before marking progress
- Use the schema's artifact sequence, don't assume specific artifact names
- **IMPORTANT**: `context` and `rules` are constraints for YOU, not content for the file
  - Do NOT copy `<context>`, `<rules>`, `<project_context>` blocks into the artifact
  - These guide what you write, but should never appear in the output
