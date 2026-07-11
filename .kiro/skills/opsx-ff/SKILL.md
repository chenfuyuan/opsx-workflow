---
name: opsx-ff
description: Create a change and generate all artifacts needed for implementation in one go
---

Fast-forward through artifact creation - generate everything needed to start implementation.

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**:

- `<change-name>` (positional) — change name in kebab-case, OR a description of what to build. If omitted, ask via `AskUserQuestion`.
- `--up-to <artifact-id>` (optional) — stop after the specified artifact is `done` (inclusive). Useful for partial generation, e.g. `/opsx-ff add-auth --up-to specs` generates only `proposal` + `specs`. If omitted, generate all `applyRequires` artifacts (default behavior).

**Steps**

1. **If no input provided, ask what they want to build**

   Use the **AskUserQuestion tool** (open-ended, no preset options) to ask:
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" → `add-user-auth`).

   **IMPORTANT**: Do NOT proceed without understanding what the user wants to build.

2. **Create or reuse the change directory**

   Check whether the change already exists (e.g., created by `/opsx-pre-design`) by running `openspec status --change "<name>" --json` (add `--store <id>` if a store is in play).
   - If it resolves, reuse it and note its `changeRoot` from the status JSON — do NOT run `openspec new change` again
   - If it does not exist yet, create it:
     ```bash
     openspec new change "<name>"
     ```

3. **Check for pre_design**

   Check whether `pre_design.md` exists under the change's `changeRoot` (from the status JSON), i.e. `<changeRoot>/pre_design.md`. If it does:
   - Read it (and any sibling `pre_design.*.md` volume files)
   - This is the **binding upstream input** for all subsequent artifact generation
   - Announce to user: "Found pre_design.md — all artifacts will be generated under its constraints."

   If `pre_design.md` does not exist, proceed without it (the classic flow).

4. **Get the artifact build order**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to get:
   - `applyRequires`: array of artifact IDs needed before implementation (e.g., `["tasks"]`)
   - `artifacts`: list of all artifacts with their status and dependencies

5. **Create artifacts in sequence until apply-ready**

   Use the **TodoWrite tool** to track progress through the artifacts.

   Loop through artifacts in dependency order (artifacts with no pending dependencies first):

   a. **For each artifact that is `ready` (dependencies satisfied)**:
      - Get instructions:
        ```bash
        openspec instructions <artifact-id> --change "<name>" --json
        ```
      - The instructions JSON includes:
        - `context`: Project background (constraints for you - do NOT include in output)
        - `rules`: Artifact-specific rules (constraints for you - do NOT include in output)
        - `template`: The structure to use for your output file
        - `instruction`: Schema-specific guidance for this artifact type
        - `resolvedOutputPath`: **absolute, store-aware path to write the artifact — use this** (`outputPath` is only the bare filename like `proposal.md` and would land in the repo root)
        - `dependencies`: Completed artifacts to read for context
      - Read any completed dependency files for context
      - **If pre_design exists**: apply `pre_design` constraints (see section below)
      - Create the artifact file using `template` as the structure, writing it to `resolvedOutputPath`
      - Apply `context` and `rules` as constraints - but do NOT copy them into the file
      - Show brief progress: "✓ Created <artifact-id>"

   b. **Continue until done or `--up-to` boundary reached**
      - After creating each artifact, re-run `openspec status --change "<name>" --json`
      - **If `--up-to <artifact-id>` was provided**: stop as soon as that artifact's `status` is `done`. Do NOT generate later artifacts even if `ready`.
      - **Otherwise (default)**: stop when every artifact ID in `applyRequires` has `status: "done"`

   c. **If an artifact requires user input** (unclear context):
      - Use **AskUserQuestion tool** to clarify
      - Then continue with creation

6. **Show final status**
   ```bash
   openspec status --change "<name>"
   ```

**Output**

After completing the run, summarize:

- Change name and location
- Whether `pre_design` was used as upstream constraint
- List of artifacts created with brief descriptions

**If `--up-to` was used (partial run)**:
- Note "Stopped at `<artifact-id>` per `--up-to` flag"
- Do NOT prompt for `/opsx-apply` (not yet ready)

**Otherwise (full run)**:
- "All artifacts created! Ready for implementation."
- Prompt: "Run `/opsx-apply` to start implementing with the default TDD workflow."

**Artifact Creation Guidelines**

- Follow the `instruction` field from `openspec instructions` for each artifact type
- The schema defines what each artifact should contain - follow it
- Read dependency artifacts for context before creating new ones
- Use the `template` as a starting point, filling in based on context

**Pre-Design Constraint Rules**

When `pre_design.md` exists, treat it as the **primary upstream constraint** — above the `context` and `rules` from `openspec instructions`. The current pre_design structure has 4 sections + 1 informational appendix:

| pre_design 章节 | Constraint on downstream artifacts |
|---|---|
| §1 Problem & Goals (含 Non-goals) | Goals 限定 specs / tasks 范围；Non-goals 范围内的工作**禁止生成** |
| §2 Constraints / Invariants | 所有 artifact 不得违反硬约束 / 不变量 |
| §3 Direction & Key decisions | design.md 必须遵守 Direction 路线选择与已定决策；不引入与放弃路线/取舍矛盾的方向 |
| §4 Guardrails for downstream | "Must follow" 项必须体现；"Forbidden to invent" 内容**禁止生成** |
| (附) Next step | 仅是给用户的下一步建议，ff 不依赖此节 |

**Per-artifact application**:

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
- Create ALL artifacts needed for implementation (as defined by schema's `apply.requires`)
- Always read dependency artifacts before creating a new one
- If pre_design exists, treat it as the highest-priority constraint — above `openspec instructions` context
- If context is critically unclear, ask the user - but prefer making reasonable decisions to keep momentum
- If a change with that name already exists, ask if user wants to continue it or create a new one
- Verify each artifact file exists after writing before proceeding to next
