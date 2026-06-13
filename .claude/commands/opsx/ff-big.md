---
name: "OPSX: Fast Forward Big"
description: "大需求路径：proposal + specs（机械） → opsx:design（交互） → tasks（机械），一条命令编排"
category: Workflow
tags: [workflow, artifacts, experimental]
---

# Fast Forward Big：大需求工作流编排

`opsx:ff-big` 是大需求路径的编排命令。它在已有 `pre_design.md` 的基础上，按以下顺序串联三个阶段：

```
ff --up-to specs   →   opsx:design   →   ff（续跑生成 tasks）
   (机械)              (交互式设计)        (机械)
```

它做四件事：

1. 解析 change，自检 `pre_design.md` 存在
2. 用 `ff --up-to specs` 机械生成 proposal + specs
3. 调 `opsx:design`，交互式生成 design.md
4. 续跑 `ff`，机械生成 tasks（自动跳过已 done 的 artifact）

**它不做的事：**

- 不生成 pre_design（前置依赖，必须已存在）
- 不实施 tasks（apply 阶段的事）
- 不跳过 opsx:design 的交互（要纯机械跑请用 `/opsx:ff`）

**Input**: `/opsx:ff-big <change-name>`，change-name 可选。

省略时按以下顺序推断：

1. 从对话上下文推断（用户最近提到 / 正在工作的 change）
2. 仓库只有一个活跃 change 时自动选用
3. 多候选或无法推断 → 列出活跃 change 让用户选

**前置条件**：change 目录下必须已有 `pre_design.md`。如缺失，命令终止并提示先跑 `/opsx:pre-design`。

<HARD-GATE>
本命令只编排，不直接生成 artifact。所有产物来自被调用的子命令（ff、opsx:design）。
- 不要绕过 opsx:design 直接生成 design.md
- 不要在 opsx:design 暂停时强行续跑
- 不要调用 `/opsx:apply`
- 不要 commit 文档
</HARD-GATE>

## 核心原则

- **薄编排** — ff-big 自身不做内容判断，只决定阶段顺序
- **子命令权威** — ff、opsx:design 各自的规则由各自的命令文件管，ff-big 不复制
- **可恢复** — 任一阶段暂停后用户可重新跑 ff-big，依靠 `openspec status` 自动续跑（已 done 的 artifact 会被跳过）

## 流程（5 步）

1. **解析 change + 自检 pre_design** — 解析 change name；确认 `pre_design.md` 存在
2. **阶段 A：proposal + specs** — 调 `ff --up-to specs`
3. **阶段 B：design.md** — 调 `opsx:design`
4. **阶段 C：tasks** — 调 `ff`（无 `--up-to`）
5. **输出最终状态** — 提示下一步 `/opsx:apply`

## 流程详述

### 1. 解析 change + 自检 pre_design

**解析 change name：**

- 若用户传了参数，直接使用
- 否则按顺序：
  1. 从对话上下文推断
  2. 跑 `openspec list --json`，只有一个活跃 change 时自动选用
  3. 多候选或无法推断 → 调 `AskUserQuestion` 让用户选

确认后告知："Using change: `<name>`"。

**自检 pre_design：**

- 检查 `openspec/changes/<name>/pre_design.md` 是否存在
- **缺失则终止 ff-big**，告知用户："ff-big 需要 pre_design.md。请先跑 /opsx:pre-design。"

不需要检查其他 artifact——ff 阶段会自己处理（已存在的 artifact 会被跳过）。

### 2. 阶段 A：proposal + specs

执行 `/opsx:ff <name> --up-to specs` 的逻辑：

- ff 读取 pre_design.md，作为 binding upstream
- ff 按依赖顺序机械生成 proposal、specs，停在 design 之前
- 已存在的 artifact 自动跳过

完成后简短汇报：`✓ Phase A: proposal + specs ready.`

### 3. 阶段 B：design.md

执行 `/opsx:design <name>` 的逻辑：

- opsx:design 进入交互模式
- 决策驱动对话，节作进度面板
- 完成后写入 `design.md`

**如果 opsx:design 中途暂停**（用户离开、冲突需返回 pre-design、用户主动放弃）：

- ff-big 干净退出，**不强行续跑**
- 告知用户："design 阶段暂停。重新跑 /opsx:ff-big 可从此处续。"
- 用户解决后重跑 ff-big，阶段 A 因 artifact 已 done 自动跳过，直接进入阶段 B

完成后汇报：`✓ Phase B: design.md ready.`

### 4. 阶段 C：tasks

执行 `/opsx:ff <name>` 的逻辑（无 `--up-to`）：

- ff 看到 proposal、specs、design 都已 done
- 只剩 tasks 是 ready，机械生成它
- tasks 同时受 pre_design.md 和 design.md 约束

**tasks 预览确认（硬门）**：tasks.md 生成后，向用户展示概要（任务列表，每条一行），询问：

```
tasks.md 已生成（N 个任务，预计粒度 30-90 分钟/个）：
  1. <任务 1>
  2. <任务 2>
  ...
确认按此执行？还是要调整？
```

- 用户要求**小调整**（措辞、顺序、粒度）→ 直接编辑 tasks.md 后再次确认
- 调整**涉及设计判断**（新决策、推翻已有决策）→ 回到 `/opsx:design` 处理，不在 tasks 层硬改
- 用户明确确认后，Phase C 才算完成

完成后汇报：`✓ Phase C: tasks ready.`

### 5. 输出最终状态

执行 `openspec status --change <name>` 显示完整状态。

最终汇报：

```
## ff-big 完成

Change: <name>
所有 artifact 已就绪：proposal / specs / design.md / tasks.md（tasks 已经用户确认）

下一步：
1. 建议先 commit 全部 artifacts（git 锚点；本命令不自动执行）
2. `/clear` 后在新会话运行 `/opsx:apply` —— artifacts 即完整交接物，干净上下文的实现质量更高
```

## 失败保护

| 场景 | 处理 |
|---|---|
| pre_design.md 缺失 | 终止，引导跑 `/opsx:pre-design` |
| 阶段 A 中 ff 失败 | 终止，报告错误，**不进入阶段 B** |
| 阶段 B 中 opsx:design 暂停或退出 | 干净退出，告知"重新跑 ff-big 可续"；不进入阶段 C |
| 阶段 B 中发现与 pre_design §1/§2 冲突 | 由 opsx:design 自己处理（提示用户跑 /opsx:pre-design 修订）；ff-big 等用户回来重跑 |
| 阶段 C 中 ff 失败 | 终止，报告错误 |

## 完成条件

- change name 已解析
- pre_design.md 存在
- proposal / specs / design.md / tasks.md 均已 done
- tasks.md 已经用户预览确认
- 已告知用户下一步走 `/opsx:apply`
- 在此结束，不调 `/opsx:apply`

## 明确不做的事

- 不生成 pre_design（前置依赖）
- 不调用 `/opsx:apply`
- 不 commit 文档
- 不修改 pre_design.md（修订由 opsx:design 负责）
