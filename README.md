# OpenSpec 优化工作流（可移植包）

把 OpenSpec spec-driven 流程 + brainstorming + TDD + 行业测试最佳实践串成一套**适合 AI 协作的轻量工作流**。

同时支持 **Claude Code** 和 **Kiro CLI** 两种 harness。

## 目录结构

```
opsx-workflow/
├── README.md                    本文档
├── .claude/                     Claude Code 版本
│   ├── commands/opsx/           13 个 opsx slash 命令（/opsx:xxx）
│   └── skills/
│       ├── brainstorming/       pre-design 用
│       ├── systematic-debugging/ apply 遇到意外时用
│       └── test-driven-development/  apply 走 TDD 时用
├── .kiro/                       Kiro CLI 版本（slash 命令 = skill）
│   └── skills/
│       ├── opsx-<name>/         13 个 opsx skill（/opsx-xxx）
│       ├── brainstorming/
│       ├── systematic-debugging/
│       └── test-driven-development/
└── openspec/
    └── config.yaml              context + per-artifact rules（与 harness 无关）
```

> **Claude Code vs Kiro CLI 命名差异**：Kiro skill 名只允许 `[a-z0-9-]`，所以
> 命令前缀从 `/opsx:pre-design` 变成 `/opsx-pre-design`。两套文件内部已分别
> 用对应写法，互不影响。

---

## 安装到新项目

### 0. 前置条件（两个 harness 通用）

```bash
node --version          # 需 18+
npm install -g @fission-ai/openspec
openspec --version      # 应为 1.3.x
```

---

### A. Claude Code 路径

#### 1. 初始化 OpenSpec

```bash
cd <new-project>
openspec init --tools claude
```

会创建 `openspec/` 目录与默认 `config.yaml`、以及 `.claude/` 基础结构。

#### 2. 复制 .claude 内容

```bash
# <package> 是本目录的路径
cp -r <package>/.claude/commands/opsx/*.md .claude/commands/opsx/
cp -r <package>/.claude/skills/* .claude/skills/
```

#### 3. 合并 openspec/config.yaml

把本包 `openspec/config.yaml` 的 `context:` / `rules:` 段整体替换新项目同名文件，或一键覆盖：

```bash
cp <package>/openspec/config.yaml openspec/config.yaml
```

#### 4. 验证

```bash
openspec list                   # 应显示 "No active changes found."
ls .claude/commands/opsx/       # 应看到 13 个命令文件
ls .claude/skills/              # 应看到 3 个 skill 目录
```

打开 Claude Code，输入 `/opsx:` 应能补全到所有 opsx 命令。

---

### B. Kiro CLI 路径

Kiro CLI 把 slash 命令统一放进 `.kiro/skills/`（每个 skill 自动注册成同名 slash 命令）。本包 `.kiro/` 已经把 13 个 opsx 命令转换成 `opsx-<name>` skill。

#### 1. 初始化 OpenSpec

```bash
cd <new-project>
openspec init           # 选默认或不带 --tools
mkdir -p .kiro/skills .kiro/steering
```

> 当前 `openspec init --tools` 不一定有 `kiro` 选项；先正常 init，再手动建 `.kiro/`。

#### 2. 复制 .kiro 内容

```bash
cp -r <package>/.kiro/skills/* .kiro/skills/
```

会得到 16 个 skill：13 个 `opsx-*` + `brainstorming`、`test-driven-development`、`systematic-debugging`。

#### 3. 合并 openspec/config.yaml（与 Claude 路径相同）

```bash
cp <package>/openspec/config.yaml openspec/config.yaml
```

#### 4. （可选）AGENTS.md / steering

如果项目有需要 Kiro 自动加载的全局指令，放到 `AGENTS.md`（仓库根）或 `.kiro/steering/*.md`。本包不强制要求。

#### 5. 验证

```bash
openspec list           # 应显示 "No active changes found."
ls .kiro/skills/        # 应看到 16 个 skill 目录
```

启动 `kiro`，输入 `/opsx-` 应能补全到所有 opsx 命令；输入 `/context show` 可以查看当前会话已加载的 skill 列表。

---

## 工作流总览

> 下面命令以 Claude Code（`/opsx:xxx`）写法举例。Kiro CLI 把所有 `:` 换成 `-`
> 即可（`/opsx-pre-design`、`/opsx-ff` …）。

### 轻量档（小需求）

```
/opsx:pre-design <需求描述>     想清楚 / 选路线 / 立护栏
/opsx:ff <change-name>           机械生成 4 类 artifact
/opsx:apply <change-name>        按 tasks 走 TDD 实施
/opsx:archive <change-name>      归档 + sync 主 specs
```

### 重量档（大需求 / 复杂架构）

```
/opsx:pre-design                决策卡片 + 推荐 ff-big
/opsx:ff-big <change-name>      自动编排：proposal+specs → 交互式 design → tasks
/opsx:apply <change-name>       同上
/opsx:archive <change-name>     同上
```

`pre_design.md` 的 `## Next step` 节会告诉你这次该走哪一档。

---

## 产物长度信号速查

| 产物 | 信号 |
|---|---|
| `pre_design.md` | 4 节 + 1 附属（Problem & Goals / Constraints / Direction & Decisions / Guardrails / Next step） |
| `proposal.md` | What Changes 3-5 条一行；不复述 Capabilities |
| `specs/<cap>/spec.md` | ≤ 200 行；每 Requirement 1-3 个 Scenario；可测性强约束 |
| `design.md` | ≤ 200 行；OpenSpec 6 节（Context / Goals & Non-Goals / Decisions / Risks & Trade-offs / Migration Plan / Open Questions） |
| `tasks.md` | ≤ 100 行；每任务一行；TDD 节奏让测试自然产出 |

超出信号会触发 AI 自检"是否塞了不该塞的"，或提示"该拆 change"。

---

## 关键约束（已写入命令 / config.yaml）

- **可测性约束**：specs 中每个 Scenario 必须可测试；架构违规 / 命名约定移到 design.md `Decisions` 节或 tasks.md `验证与收尾` 区
- **章节遵循 OpenSpec schema**：design.md 用 OpenSpec 6 节，proposal 用 4 节，不增不减
- **不重复 pre_design**：下游 artifact 引用一句话指针即可
- **TDD 行业最佳实践**：AAA / Test Doubles 优先级 / 不 mock 你拥有的东西 / 行为覆盖 / 参数化 / 镜像源结构

---

## 命令清单

> Claude Code 用 `/opsx:<name>`，Kiro CLI 用 `/opsx-<name>`。下表以 Claude
> 写法列出，Kiro 用户把 `:` 换成 `-` 即可。

| 命令 | 用途 |
|---|---|
| `/opsx:pre-design` | 想清楚 / 选路线 / 立护栏 / 推荐下一步（轻量 vs 重量） |
| `/opsx:design` | 交互式架构设计（仅大需求 / ff-big 内部调用） |
| `/opsx:ff` | 机械生成 OpenSpec artifact，支持 `--up-to <id>` 部分生成 |
| `/opsx:ff-big` | 大需求编排（pre-design 之后用） |
| `/opsx:apply` | 按 tasks 实施（默认走 TDD） |
| `/opsx:archive` | 归档 + sync 主 specs |
| `/opsx:bulk-archive` | 批量归档多个 change |
| `/opsx:continue` | 生成下一个待生成的 artifact |
| `/opsx:new` | 创建空 change |
| `/opsx:verify` | 验证 change 是否完成 |
| `/opsx:sync` | 同步 delta specs 到主 specs |
| `/opsx:explore` | 探索模式（自由对话） |
| `/opsx:onboard` | 新人引导式走完整工作流 |

---

## 故障排查

| 问题 | 处理 |
|---|---|
| Claude Code 提示 `Unknown command: /opsx:pre-design` | 命令文件未在 `.claude/commands/opsx/`；重新复制 |
| Kiro CLI 输入 `/opsx-` 没补全 | skill 没在 `.kiro/skills/opsx-<name>/SKILL.md`；重新复制；用 `/context show` 确认 |
| `openspec instructions` 报 schema 错误 | 检查 `openspec/config.yaml` 的 `schema:` 是否为 `spec-driven` |
| design.md 章节是 4 必选 + 5 条件 | 你用的是旧版 design.md；使用本包的版本 |
| ff 一口气把 design.md 也生成了 | 你想要交互式 design，应该用 `/opsx:ff-big`（Kiro: `/opsx-ff-big`） |
| 测试还是太长太多 | 检查 `skills/test-driven-development/testing-best-practices.md` 是否存在 |

---

## 参考资料

- OpenSpec：https://github.com/Fission-AI/OpenSpec
- TDD 最佳实践参考文献：见 `.claude/skills/test-driven-development/testing-best-practices.md` 末尾
