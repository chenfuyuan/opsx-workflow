---
name: "OPSX: Design"
description: "在 pre_design 基础上交互式生成 design.md，章节遵循 OpenSpec spec-driven schema"
category: Workflow
tags: [workflow, artifacts, design, experimental]
---

# Design：交互式架构设计

`opsx:design` 是大需求路径上的核心交互节点：在 `pre_design` 拍板路线后、`tasks.md` 切片前，通过**决策驱动的对话**生成 `design.md`。

章节遵循 OpenSpec spec-driven schema：**Context / Goals & Non-Goals / Decisions / Risks & Trade-offs / Migration Plan / Open Questions**。

它做四件事：

1. **承接 pre_design 决策** — 不重做需求层判断
2. **展开关键决策** — 把 pre_design 路线落到具体技术决策（含模块切分、数据流、依赖关系等架构层判断，统一进 Decisions 节）
3. **维护决策面板** — 一边讨论决策，一边把节填起来，进度可见
4. **写出 design.md** — 经自查 + 用户确认后落盘

**它不做的事：**

- 不重做需求层判断（goals / non-goals / constraints 是 pre_design 的事）
- 不展开任务（tasks.md 的事）
- 不写实现代码（apply 阶段的事）
- 不自动调用下游命令

**Input**: `/opsx:design <change-name>`，change-name 可选。

省略时按以下顺序推断：

1. 从当前对话上下文推断（用户最近提到 / 正在工作的 change）
2. 仓库只有一个活跃 change 时自动选用
3. 多候选或无法推断 → 列出活跃 change 让用户选择

确定 change 后，目录下必须已有 `pre_design.md`、`proposal.md`、`specs/`。

<HARD-GATE>
在 `design.md` 写入并经用户确认之前：
- 不要生成 `tasks.md`
- 不要调用 `/opsx:ff`、`/opsx:ff-big`、`/opsx:apply`、`/opsx:continue`
- 不要编写实现代码
- 不要修改 `pre_design.md` 的 §1（Problem & Goals）和 §2（Constraints / Invariants）—— 硬绑定
- 不要 commit 文档
</HARD-GATE>

## 核心原则

- **决策驱动，节作进度面板** — 按关键架构决策推进，节是决策落定后的可视化产物
- **对话可充分展开，文档只记结果** — 方案对比、试错路径留对话；design.md 只记决策与设计
- **章节遵循 OpenSpec schema** — 不增不减默认 6 节；架构内容压进 Decisions 节
- **不重复 pre_design** — 引用一句话指针即可（"详见 pre_design §2"），不要复述
- **候选默认结构化展开** — 给决策候选时默认按"关键技术细节 + 主要权衡（按维度）+ 在本项目的具体后果"展开，让用户看清取舍后再选；伪代码、ASCII 图按需追加
- **用户表达观点时进入讨论模式** — 用户不只是选 A/B/C，而是给出自己的判断、补充、反对或新方案时，把它当**讨论**而不是**指令**：先客观评价（哪里对、哪里有保留），再决定是否调整推荐；坚持原推荐时给出依据，不为顺从而改口

## 流程（5 步）

1. **解析 change + 加载上游 + 完备性自检** — 解析 change name；读 pre_design/proposal/specs；缺失则暂停
2. **提议章节启用 + 用户确认** — 默认启用 Context / Goals-Non-Goals / Decisions / Risks-Trade-offs；提议 Migration Plan / Open Questions 是否有内容
3. **提取关键决策 + 启动对话** — 列出 5-8 条决策，按依赖顺序依次讨论
4. **决策驱动对话 + 节面板维护** — 决策落定即回填到节，用户随时可查节当前内容
5. **落盘自查 + 用户确认 + 写文件** — 通过标准判定后写 design.md，结束

## 流程详述

### 1. 解析 change + 加载上游 + 完备性自检

**解析 change name：**

- 若用户在命令后传了参数，直接使用
- 否则按顺序尝试：
  1. 从对话上下文推断（用户最近提到 / 正在工作的 change）
  2. 跑 `openspec list --json`；只有一个活跃 change 时自动选用
  3. 多候选或无法推断 → 调 `AskUserQuestion` 列出活跃 change 让用户选

确认后，明确告知："Using change: `<name>`"，并说明如何覆盖（`/opsx:design <other>`）。

**加载上游：**

- `openspec/changes/<change>/pre_design.md`（含同级分卷 `pre_design.*.md` 如有）
- `openspec/changes/<change>/proposal.md`
- `openspec/changes/<change>/specs/`

**自检（缺失任一项就暂停）：**

- pre_design 必须有 §1 Problem & Goals、§2 Constraints、§3 Direction & Key decisions、§4 Guardrails
- proposal.md 存在
- specs/ 目录存在（可空）

缺失即暂停并告知用户："本命令需要 pre_design + proposal + specs 都齐全。建议先跑 /opsx:pre-design 或 /opsx:ff。"

### 2. 提议章节启用 + 用户确认

**默认启用**：Context / Goals & Non-Goals / Decisions / Risks & Trade-offs
**条件启用**：
- `Migration Plan` — 仅当涉及部署 / 数据迁移 / 兼容性变更时
- `Open Questions` — 仅当存在未决项时

AI 扫描 pre_design / proposal / specs，输出形如：

```
基于上游文档，建议本次 design 包含：

【默认启用】Context / Goals & Non-Goals / Decisions / Risks & Trade-offs
【条件节】
  ✓ Migration Plan — pre_design Constraints 提到"用户画像需迁移到新存储"
  ✗ Open Questions — 上游所有决策都已明确

需要增减吗？
```

用户确认或调整后进入下一步。

### 3. 提取关键决策 + 启动对话

AI 列出 5-8 条本阶段需要拍板的架构/技术决策，来源：

- pre_design §3 推荐路线的展开（"用 SDK X" → 决策："SDK 哪个版本、怎么封装"）
- specs 中暗含但未具体的边界（"支持 X 协议" → 决策："协议层如何抽象"）
- 架构层判断（模块切分、依赖关系、数据流、接口契约——统一进 Decisions 节）

输出形如：

```
本次 design 需要做以下决策（按依赖顺序）：

  1. [ ] 模块顶层划分（影响：Decisions）
  2. [ ] 接口契约风格（影响：Decisions）
  3. [ ] 数据持久化方案（影响：Decisions, Migration Plan）
  4. [ ] 异步任务执行模型（影响：Decisions, Risks & Trade-offs）
  5. [ ] 错误传播策略（影响：Decisions, Risks & Trade-offs）

节进度面板：
  Context [ ]  Goals & Non-Goals [ ]  Decisions [ ]  Risks & Trade-offs [ ]
  Migration Plan [ ]

从决策 1 开始？
```

用户确认顺序后启动。

### 4. 决策驱动对话 + 节面板维护

每个决策的讨论：

- AI 提 2-3 条候选，**每条展开为结构化小节（约 15-20 行）**，固定包含：
  - **一句话定位** — 用户能凭一句话区分
  - **关键技术细节** — 具体技术选型 / 接口形态 / 关键实现要点（决策阶段需要这层）
  - **主要权衡（按维度，没代价的维度直接省略）**：
    - 性能 / 复杂度：具体代价
    - 维护成本：具体代价
    - 扩展性：具体代价
    - 风险：具体代价
  - **在本项目的具体后果**：
    - 短期（本次实现）：会发生什么
    - 中期（下一两个 change）：会撞上什么
    - 已知风险点：结合现有代码 / 约束 / 团队习惯
- **节奏**：先亮推荐 + 一句话理由，再依次展开候选；不要一次甩几屏长文。伪代码 / ASCII 图按需追加。
- **推荐策略**：
  - **有明显最优时** → 直接推荐 + 一句话理由（结合当前项目的具体约束）
  - **势均力敌时** → 显式说"两条都能走，差别在 X / Y，需要你拍板"；不要硬凑结论
- **用户表达观点时（不只是选 A/B/C）** → 客观评价后再决定：
  1. **哪里对** — 这条想法在哪些维度站得住、和现有约束如何契合（具体，不空泛）
  2. **哪里有保留** — 风险点、边界条件、被忽略的代价
  3. **要不要调整推荐** — 采纳 / 部分采纳 / 仍坚持原推荐；坚持时给出依据，不为顺从而改口
- 用户拍板或调整
- 决策落定 → AI 在面板更新对应节状态（如 `Decisions [▣]`）
- 节内容只记结果，不记对话路径

**反模式**：

- 用户提观点 → 直接采纳，没评估
- 用户提观点 → 只挑毛病，没承认对的部分
- 用户坚持 → 立场漂移翻盘——推荐变化必须有新信息支撑
- 候选只列定位和一句权衡——没让用户看清取舍就让选

**用户随时可查节状态**：

- "看下 Decisions 节现在长啥样" → AI 拼出当前已确认内容
- "节进度面板" → AI 重新输出面板

**与 pre_design 冲突时（分层绑定）**：

| 冲突所在 pre_design 章节 | 处理 |
|---|---|
| §1 Problem & Goals / Non-goals | 暂停 design，告知："此发现影响 §1，超出 design 范围。请用 /opsx:pre-design 修订后再回来。" |
| §2 Constraints / Invariants | 同上 |
| §3 Direction & Key decisions | 提示冲突点，给两个选项：(a) 修订 pre_design（AI 自动加修订标记），(b) 调整本次 design 适配 pre_design |
| §4 Guardrails for downstream | 暂停讨论，提示违反了哪条 guardrail，让用户决定放行或修订 |

**修订 pre_design.md 的格式**（写在被修订条目下方）：

```markdown
> [修订 YYYY-MM-DD] 原："<原内容>"
> 改为："<新内容>"
> 原因：design 阶段发现 <理由>
```

### 5. 落盘自查 + 用户确认 + 写文件

用户提示要落盘（"行了"、"写文件吧"等）时，AI 触发**标准判定**——**先内容预览，再机械自查**：

```
落盘前请确认整体方案：

【Context 关键点】
  - <2-3 条 bullet，把背景 / 关键约束 / 利益相关者点出>

【Decisions（每条一句话：选了什么 + 关键理由）】
  - <决策 1>：<选了什么，为什么>
  - <决策 2>：<选了什么，为什么>
  - ...

【Risks & Trade-offs（每条一行：风险 → 缓解）】
  - <风险 1> → <缓解>
  - ...

【Migration Plan】<如启用，一句话；否则写"未启用"〉
【Open Questions】<如启用，列要点；否则写"未启用"〉

—— 自查 ——
✓ 默认节：Context / Goals & Non-Goals / Decisions / Risks & Trade-offs（均有内容）
✓ 条件节：Migration Plan（已包含 / 未启用）；Open Questions（已包含 / 未启用）
✓ 决策列表：N/N 已决
✓ 与 pre_design：无未处理冲突

OK 落盘？还是要调整哪一块？
```

- 用户回复"调整 X"/"不对"/"再想想" → 回到对话定位到对应决策或节，**不写文件**
- 任何 ✗ 项 → 列出并请用户处理或显式放行
- 全 ✓ 且用户明确"OK / 落盘吧 / 写吧" → 写 `openspec/changes/<change>/design.md`，结束

## design.md 内容结构

章节遵循 OpenSpec spec-driven schema。**总长度信号 ≤ 200 行**。

```markdown
# Design: <change-name>

## Context
- 背景与现状
- 关键约束 / 利益相关者
- 上游引用（pre_design / proposal / specs 关键引用）
- 长度信号：≤ 30 行

## Goals / Non-Goals
- Goals：本次设计要达成什么（与 pre_design §1 对齐，简明引用即可）
- Non-Goals：本次设计明确不做什么（继承 pre_design §1）
- 长度信号：≤ 20 行

## Decisions
- 关键技术选择 + 理由（为什么 X 而不是 Y）+ 考虑过的替代
- **架构层判断**（模块切分、依赖关系、数据流、接口契约）作为决策记录在此
  - 必要时配 1 张 ASCII 架构图
  - 关键流程用简易序列描述（不超过 1-2 张图）
- 接收从 spec 移出的 change 特定架构判断
- 长度信号：≤ 100 行（design.md 主体）

## Risks / Trade-offs
- 已知限制、可能出问题的地方
- 格式：`[Risk] → Mitigation`
- 长度信号：≤ 30 行

## Migration Plan (条件)
- 涉及部署 / 数据迁移 / 兼容性时填写
- 部署步骤、回滚策略
- 长度信号：≤ 30 行

## Open Questions (条件)
- 仍未决定的事项（标"待外部澄清"或"待 apply 阶段验证"）
- 长度信号：≤ 20 行
```

## 写作约束

- **不重复 pre_design 内容** — 引用一句话指针即可
- **不写实现代码** — 接口签名、数据类型 OK；函数实现 NOT；伪代码只在算法不写就说不清时用
- **对话 vs 文档分离** — 方案对比留对话，design.md 只记结果
- **ASCII 图按需** — Decisions 节里的架构图/序列图按需；不强制
- **长度信号不是硬上限** — 超出请自检"是不是塞了不该塞的"；确实必要的内容应坦诚保留
- **接收从 spec 移出的架构判断** — 当 ff/spec 生成识别到不可测的架构 scenario 时，按性质分流到 design.md：
  - **change 特定**的架构判断（如"AI 网关 facade 必须中性"、"profile 命名禁含业务语义"）→ 进 `Decisions` 节
  - **项目级**架构规则（如"capability 不依赖 business"——所有 capability 都该如此）→ AI 在对话中提示用户："这是项目级规则，建议抽到项目级文档；本工作流不主动创建该文件"，**不写入 design.md**

## 失败保护

以下情况暂停而非硬写：

- 上游缺失（pre_design / proposal / specs 不全）
- 与 pre_design §1 / §2 冲突 → 让用户先修订 pre_design
- 决策列表里存在用户无法决定的项 → 标"待外部澄清"放进 Open Questions 节
- design.md 总长度超过 200 行 → 提示自检或拆 change

## 完成条件

- 上游文档读取成功
- 章节启用集合已确认（Migration Plan / Open Questions 是否有内容）
- 决策列表全部决出
- 默认节内容齐全，启用的条件节内容齐全
- 与 pre_design 无未处理冲突
- 用户确认落盘
- 已写 `openspec/changes/<change>/design.md`
- 在此结束，不调下游命令

## 明确不做的事

- 不修改 pre_design.md 的 §1 / §2（硬绑定）
- 不生成 tasks.md
- 不调用 `/opsx:ff` / `/opsx:ff-big` / `/opsx:apply` / `/opsx:continue`
- 不写实现代码
- 不 commit 文档
