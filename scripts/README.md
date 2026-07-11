# scripts

本目录存放仓库维护脚本。

## sync-kiro-from-claude.sh — 从 Claude 迁移生成 Kiro skills

以 **`.claude/` 为唯一事实源（source of truth）**，机械地把 Claude 的
commands / skills 迁移生成为 Kiro 的 `.kiro/skills/`。Kiro 侧是**派生产物**：
不要手改 `.kiro/skills/**`，改动请落到 `.claude/**`，再跑本脚本重新生成。

### 背景

同一套 OpenSpec 工作流在两个平台各有一份载体：

- Claude：斜杠命令，位于 `.claude/commands/`，opsx 命令用 `/opsx:<x>` 命名空间
- Kiro：skill，位于 `.kiro/skills/`，opsx skill 用 `opsx-<x>` id

两份内容除「载体格式」外应保持一致。手动同步易漂移（曾出现 Kiro 落后于
Claude、以及两者内部不一致的情况），故用脚本单向生成，保证可复现。

### 映射规则

| Claude 源 | Kiro 目标 | 生成的 `name` |
|---|---|---|
| `.claude/commands/opsx/<x>.md` | `.kiro/skills/opsx-<x>/SKILL.md` | `opsx-<x>` |
| `.claude/commands/<x>.md` | `.kiro/skills/<x>/SKILL.md` | `<x>` |
| `.claude/skills/<x>/` | `.kiro/skills/<x>/` | `<x>` |

slug 规则：命令路径去掉 `.md` 后，`/` 替换为 `-`
（`opsx/archive` → `opsx-archive`，`critical-review` → `critical-review`）。

当前会生成 17 个 skill：13 个 opsx + `critical-review` + `brainstorming` +
`systematic-debugging` + `test-driven-development`。

### 转换规则

对每个生成的 `SKILL.md`：

1. **Frontmatter 精简**为两行：
   - `name`：由目标 slug 生成（见上表）
   - `description`：从 Claude 源**逐行照搬**（丢弃 `category` / `tags` 等
     Claude 专属字段）
2. **命令命名空间改写**：正文与描述中的 `opsx:` → `opsx-`
   （Claude 用 `/opsx:` 命令命名空间，Kiro 用 `opsx-` skill id）
3. **支撑文件原样拷贝**：skill 目录内非 `SKILL.md` 的文件（如 `.sh` / `.ts` /
   附属 `.md`）按原样复制，保留文件权限（含可执行位）

### 用法

```bash
# 进入仓库（脚本会根据自身位置定位仓库根，实际在哪跑都行）
cd /path/to/opsx-workflow

# 1. 预览将改动哪些文件（不写任何东西）
scripts/sync-kiro-from-claude.sh --dry-run

# 2. 确认无误后正式执行
scripts/sync-kiro-from-claude.sh

# 查看帮助
scripts/sync-kiro-from-claude.sh --help
```

若报 `permission denied`，补执行权限或显式用 bash：

```bash
chmod +x scripts/sync-kiro-from-claude.sh
# 或
bash scripts/sync-kiro-from-claude.sh
```

### 行为特性

- **幂等**：源不变时，重复运行不产生任何改动。
- **孤儿检测**：`.kiro/skills/` 下没有对应 Claude 源的 skill 会被**报告但不删除**
  （避免误删）。若确为陈旧内容，请手动删除。
- **单向**：只从 Claude 生成 Kiro，绝不反向写回 Claude。

### 验证

脚本改动全部落在 git 工作区，跑完用 diff 检查：

```bash
git diff .kiro/skills
```

如需确认「Kiro 正文 == 规范化后的 Claude 正文」，可对任一 opsx 逐对比对
（规范化 = 去 frontmatter + `opsx:`→`opsx-`）：

```bash
name=archive
diff \
  <(awk 'BEGIN{n=0}/^---$/{n++;next}n>=2' .claude/commands/opsx/$name.md | sed 's/opsx:/opsx-/g') \
  <(awk 'BEGIN{n=0}/^---$/{n++;next}n>=2' .kiro/skills/opsx-$name/SKILL.md)
```

### 已知假设 / 限制

- `description` 按**单行**处理，不支持 YAML 多行块标量（`|` / `>`）。当前所有
  描述均为单行。
- `description` 照搬 Claude 原样，因此**引号风格跟随 Claude**（Claude 有的加引号、
  有的没加）。引号在 YAML 中语义等价、不影响功能；若想让 Kiro 描述引号风格统一，
  请规范化 **Claude 源**的 frontmatter，而非在本脚本中加规整逻辑。
- 兼容 macOS 自带 bash 3.2（未使用 `mapfile` / 关联数组）。
