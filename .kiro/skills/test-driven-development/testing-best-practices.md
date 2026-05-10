# 测试最佳实践（行业标准）

**在以下情况加载此参考：** 编写新测试、设计测试结构、决定 mock 策略、判断"测多少够了"。

## 概述

本文件给出**正向规则**——什么是好的测试结构。配套阅读 `testing-anti-patterns.md`（什么不该做）。

所有规则都基于公开行业共识：

- Kent Beck *"TDD by Example"*
- Steve Freeman & Nat Pryce *"Growing OO Software, Guided by Tests"*
- Gerard Meszaros *"xUnit Test Patterns"*
- Martin Fowler *"Mocks Aren't Stubs"*
- pytest / JUnit / Jest 官方文档

## 核心 6 条

### 1. 单测试遵循 AAA 或 Given-When-Then 结构

每个测试三段：

```
Arrange (准备数据)   ↔   Given (前置条件)
Act     (执行被测)   ↔   When  (触发动作)
Assert  (验证结果)   ↔   Then  (验证结果)
```

**判定标准**：出现**第二个 Act**调用，就是测了两件事，应拆为独立测试。

**违反信号**：
- 一个测试里有多个 Act 段
- 测试中间需要"再 Arrange 一下"

### 2. Test Doubles 优先级（Gerard Meszaros）

从"最真实"到"最假"排序，**优先用左边**：

```
Real → Fake (真工作的简化版) → Stub (返回固定值) → Spy (记录调用) → Mock (预设期望)
```

**默认策略**：先问"能用真的吗"；不能再降到 Fake；再不能才用 Stub / Spy / Mock。

**违反信号**：
- "保险起见"先 mock
- 没确认真实代码会怎样就 mock 掉

### 3. 不 mock 你拥有的东西（Freeman & Pryce）

经典口号 "Don't mock what you don't own"：

| 类型 | 处理 |
|---|---|
| 外部依赖（第三方 API、数据库 driver、HTTP client） | 可以 mock |
| 你自己写的内部类（service、repository、domain model） | **不要 mock**——用真实对象 |

**为什么**：mock 内部类等于把测试和实现绑死，重构会大量破坏测试。

### 4. 覆盖以"行为"为单位，不以"代码行"为单位

- 行业指引：**70-80% 行覆盖率**是健康下限（Google / Meta 内部约定）
- 但**覆盖率不等于质量**——高覆盖率 + 弱断言毫无价值
- **关注**：spec 中每个 Scenario 是否有对应测试 + happy path + 主要错误路径
- **停止标准**：上述都覆盖了就停；不要为"完备性"主动加 spec 没要求的边界情况测试

### 5. 同一行为的多个输入变体用参数化

**违反**（写 N 个相似测试）：

```python
def test_email_validates_simple():
    assert validate("a@b.com")
def test_email_validates_with_subdomain():
    assert validate("a@b.c.com")
def test_email_validates_with_plus():
    assert validate("a+1@b.com")
```

**正确**（参数化）：

```python
@pytest.mark.parametrize("email", ["a@b.com", "a@b.c.com", "a+1@b.com"])
def test_email_validates_valid_formats(email):
    assert validate(email)
```

**适用条件**：相同断言，不同输入。

### 6. 测试文件镜像源代码结构

| 语言 | 约定 |
|---|---|
| Python | `tests/test_foo.py` ↔ `src/foo.py` |
| TypeScript | `foo.test.ts` ↔ `foo.ts` |
| Java/Kotlin | `FooTest.java` ↔ `Foo.java` |

**文件内组织**：
- 用 `describe` / `class TestX` / pytest class 给同一文件内的多个 function/class 分组
- **不为每个 function 单建文件**

**文件感觉太大时问**：
1. 源文件职责是否过宽 → 拆源文件，测试自然跟着拆
2. 测试是否有变体重复 → 参数化合并
3. **不要机械拆测试文件**

## F.I.R.S.T. 原则（Robert C. Martin）

辅助参考——所有测试应满足：

| 字母 | 含义 |
|---|---|
| **F**ast | 快——慢测试不会被频繁运行 |
| **I**ndependent | 独立——一个失败不影响其他 |
| **R**epeatable | 可重复——任何环境都能跑出相同结果 |
| **S**elf-validating | 自动判断 pass/fail |
| **T**imely | 及时——TDD 要求先于生产代码 |

## Test Pyramid（Mike Cohn）

测试层级建议比例：

```
         /\
        /e2e\        少量 - 关键链路
       /----\
      /集成 \      中量 - 边界、协议、外部
     /------\
    / 单元   \    大量 - 业务逻辑、核心算法
   /---------\
```

**反模式**：用大量 e2e 替代单元/集成测试。

## 学派选择

| | London (Mockist) | Chicago (Classicist) |
|---|---|---|
| 风格 | 重 mock，隔离每个单元 | 用真实协作对象，最少 mock |
| 关注 | 协作关系、调用顺序 | 输入输出、业务行为 |
| 现代趋势 | **多数项目向 Chicago 靠拢** |

本工作流默认 **Chicago 派**——这与"不 mock 你拥有的东西"一致。

## 快速参考

| 决策 | 默认选择 |
|---|---|
| Real vs Fake vs Stub vs Spy vs Mock？ | 从左往右，越左越好 |
| Mock 内部类？ | 不要 |
| 加新测试还是参数化？ | 同行为不同输入 → 参数化 |
| 何时停止加测试？ | spec Scenario 全覆盖 + 主要错误路径 = 够 |
| 拆测试文件？ | 先看源文件是否该拆 |
| 单测试多个 Act？ | 拆 |

## 与其他参考文件的关系

- `SKILL.md` — TDD 流程（红-绿-重构）
- `testing-anti-patterns.md` — 什么**不该**做（5 个反模式）
- 本文件（`testing-best-practices.md`） — 什么**该**做（6 条正向规则 + 行业框架）

## 底线

**测试质量来自结构，不来自数量。**

参数化合并相似变体；用真实对象代替 mock；spec 行为覆盖完毕即停。
