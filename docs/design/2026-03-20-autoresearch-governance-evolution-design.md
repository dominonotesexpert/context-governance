# 治理链路自演化设计：根文档驱动 + Autoresearch 持续优化

**Date:** 2026-03-20
**Status:** Proposed
**Scope:** 为 Context Governance 框架引入根文档（PROJECT_BASELINE）作为一切真相的源头，并基于 Autoresearch 方法建立持续自优化能力

---

## 1. 背景

### 1.0 核心定位

**本框架的使用场景是：一个开发者 + agent 团队管理大型生产项目。**

未来开发者会越来越少，一个人需要驾驭原来需要一个团队才能维护的代码库。治理协议替代的是人类团队的协调机制——角色分工、合约审查、升级裁定、验收标准。用户通过 PROJECT_BASELINE 定义"要什么"，agent 团队负责"怎么做、怎么验、怎么改进"。

这个定位直接影响所有设计决策：
- **反馈收集**——不需要多人聚合，但需要一个人忙不过来时的自动化兜底（隐式反馈）
- **状态持久化**——不需要并发控制，但需要一个人跨天/跨周继续长任务的恢复能力
- **上下文预算**——更加关键，因为一个人频繁切换任务，每次 session 都要从零高效加载
- **PROJECT_BASELINE**——一个人写，不存在"谁说了算"。精确化协议更重要，因为只有一个人时，系统帮他想清楚比多人讨论更关键

### 1.1 现状

Context Governance 框架已经建立了完整的多代理治理链路：

1. 6 个专业代理角色（System Architect → Module Architect → Debug → Implementation → Verification → Frontend Specialist）
2. 40+ 个模板，覆盖系统级、模块级、调试、验证、实现各层
3. 路由协议，根据任务类型自动分发到正确的代理链路
4. 硬规则体系（无根因不修复、无合约不实现、无证据不验收）

### 1.2 问题

框架在**治理机械层**运转良好，但存在三个核心缺失：

1. **缺少统一基线。** 现有的 `SYSTEM_GOAL_PACK` 混合了用户业务目标和系统技术策略，没有一个纯粹的、用户拥有的根文档作为一切真相的源头。不同文档之间的推导关系不清晰，导致标准的权威性无法回溯到统一起点。
2. **没有反馈循环。** 代理执行完任务后，没有机制捕获"用户是否真的满意"。治理过程完美执行，但结果可能偏离用户意图。
3. **标准是静态的。** `ACCEPTANCE_RULES` 和 `VERIFICATION_ORACLE` 在 bootstrap 时一次性填写，之后几乎不更新。用户的真实标准会随着项目演化而变化，但文档没有跟上。
4. **代理技能 prompt 不进化。** 6 个 `SKILL.md` 自编写后未经实战验证和迭代。prompt 中可能有模糊指令、遗漏场景、或无效规则。

### 1.3 灵感来源

两个核心来源：

**Karpathy 的 Autoresearcher：** 让 Agent 自主修改训练脚本、跑实验、评估改进是否有效。核心机制：单文件搜索空间 + 固定时间预算 + 失败直接 revert。83 次实验中只有 15 次有效改进被保留，失败是常态，但单次失败成本极低。

**Agent 工程实践的行业共识：** Harness（围绕 Agent 的测试、验证与约束基础设施）比模型本身更决定系统能否收敛。这个判断在高可验证任务上最成立——OpenAI Codex 百万行代码、Anthropic 从零编译 Linux 的 C 编译器，都依赖的是工程约束而非模型升级。但在开放式推理任务中，模型上限仍然关键，两者不是替代关系。

这两个来源指向同一个结论：**约束越清晰、验证越自动化，Agent 越能稳定收敛。** 对应到我们的框架：
- PROJECT_BASELINE 提供清晰约束（推向"目标清晰"）
- 自动评分清单提供自动化验证（推向"可验证"）
- 两者合在一起，把任务推进到 Agent 最有效的工作区

### 1.4 行业经验中的关键洞察

以下判断直接影响本设计的架构选择：

1. **约束编码化而非文档化。** 写在文档中的规范容易被 Agent 忽略，编码进 HARD-GATE、hooks 或工具验证中的约束才具备可执行性。这验证了我们现有的 HARD-GATE 机制方向正确，但也意味着仅靠 SKILL.md 中的文字规则是不够的。
2. **先修评测再改 Agent。** 评测环境本身的问题，很多时候比 Agent 出问题更难发现。如果评分清单有误，优化循环会朝错误方向收敛。
3. **确定性检查 > 模型评分 > 人工评分。** 能用代码确定性判定的，不用 LLM 判断。我们的机械层评估全部使用确定性检查。判断性任务不假装定量，交给人类裁定。
4. **修复验证和回归保护必须同时进行。** 修了一个问题不能破坏已有功能。每次修改后，新修复项和全部已通过项都要重新验证。
5. **Skill 描述要写成路由条件。** 至少说明三件事：什么时候用、什么时候不要用、产出物是什么。很多路由失败不是模型能力问题，是边界写得不清楚。
6. **上下文压缩时必须有保留优先级。** 架构决策不可摘要，工具输出可删。没有显式优先级，压缩会丢掉关键决策上下文。
7. **跨 session 状态靠文件系统，不靠上下文窗口。** 长任务的进度、决策和未完成项必须持久化到文件，下次启动时从文件恢复，而非依赖对话历史。
8. **多 Agent 协作缺少真相仲裁是致命的。** 文件级隔离（worktree）解决不了语义级冲突。当两个 Agent 对同一件事有不同理解时，必须有权威层级来裁决。这是行业普遍缺失、我们的框架已经解决的问题。

---

## 2. 根文档设计：PROJECT_BASELINE

### 2.1 定位

`PROJECT_BASELINE` 是整个治理体系的根文档——**类似于计算机的指令集架构（ISA）**。

ISA 定义了"这个处理器能做什么、边界在哪"，不关心微架构、不关心操作系统、不关心应用程序。但编译器、OS、应用全部基于它构建。改了 ISA，整个生态跟着变。

`PROJECT_BASELINE` 同理：
- **它只包含用户的业务真相**——产品是什么、为谁服务、核心能力、不可妥协的业务规则、成功标准
- **它不包含任何技术术语**——没有"fail-closed"、没有"幂等性"、没有"回归矩阵"
- **它控制在 100 行以内**——短到用户能完整掌控、精确表达
- **它是用户唯一需要手写的文档**——所有其他文档从它推导

### 2.2 与现有 SYSTEM_GOAL_PACK 的关系

现有的 `SYSTEM_GOAL_PACK` 变为 `PROJECT_BASELINE` 的**第一层派生文档**：

```
PROJECT_BASELINE（用户写的，纯业务，≤100 行）
    │
    │  系统自动推导
    ↓
SYSTEM_GOAL_PACK（系统生成的，业务 + 技术翻译）
    │
    ├→ SYSTEM_INVARIANTS（从 BASELINE 的业务规则推导硬约束）
    ├→ SYSTEM_AUTHORITY_MAP（文档层级，自动生成）
    ├→ MODULE_CONTRACT（从 BASELINE 的核心能力推导模块职责）
    ├→ ACCEPTANCE_RULES（从 BASELINE 的成功标准推导验收条件）
    └→ 所有其他文档...
```

**SYSTEM_GOAL_PACK 不再是手写的，而是从 PROJECT_BASELINE 派生的。** 它把用户的业务语言翻译成系统的技术语言。如果 BASELINE 变了，GOAL_PACK 必须重新派生。

### 2.3 PROJECT_BASELINE 模板设计

```markdown
# PROJECT_BASELINE

## 1. 产品定义
<!-- 一段话：这个产品是什么？解决什么问题？ -->

## 2. 目标用户
<!-- 谁在用这个产品？他们最重要的需求是什么？ -->

## 3. 核心能力
<!-- 产品必须具备的能力，按优先级排列。每条一句话。 -->
<!-- 示例: -->
<!-- 1. 用户可以创建、编辑、删除任务 -->
<!-- 2. 多人可以在同一个工作区实时协作 -->
<!-- 3. 管理员可以分配角色和权限 -->

## 4. 业务规则（不可妥协）
<!-- 用日常语言描述绝对不能违反的规则。不要写技术术语。 -->
<!-- 示例: -->
<!-- - 用户的数据永远不能丢失，宁可服务暂停也不能丢数据 -->
<!-- - 没有权限的人绝对看不到别人的内容 -->
<!-- - 系统出错时告诉用户出了什么问题，不要假装没事 -->

## 5. 成功标准
<!-- 怎样算做得好？用可观察的结果描述，不要用模糊的形容词。 -->
<!-- 示例: -->
<!-- - 用户打开页面后 2 秒内能看到自己的任务列表 -->
<!-- - 一个人的修改在 1 秒内同步到其他协作者的屏幕上 -->
<!-- - 新用户不看说明书也能在 5 分钟内创建第一个任务 -->

## 6. 明确不做的事
<!-- 产品边界。什么是这个产品不负责的？ -->
<!-- 示例: -->
<!-- - 不做项目管理（甘特图、里程碑、资源分配） -->
<!-- - 不做即时通讯 -->
```

### 2.4 根文档精确化协议

用户第一次写 `PROJECT_BASELINE` 时，内容可能模糊或不完整。系统负责在这个文档的范围内帮用户精确化——**不扩大范围，不引入技术概念，只在用户的业务语言里追问**。

```
Step 1: 系统读取用户初始版本
         ↓
Step 2: 逐节检查清晰度
        对每一节，检查:
         - 是否有模糊表述？（"高性能"、"好用"、"快速"）
         - 是否有遗漏？（有核心能力但没有对应的业务规则）
         - 是否有矛盾？（§3 说要实时协作，§6 说不做即时通讯——边界在哪？）
         ↓
Step 3: 生成精确化问题（仅在发现问题时触发）

        模糊表述:
          用户写: "系统要快"
          系统问: "你说的快是指？
            A) 用户点击后 1 秒内看到结果
            B) 用户点击后 3 秒内看到结果
            C) 具体场景具体说——哪个操作需要多快？"

        遗漏:
          用户写了核心能力"多人实时协作"但没有对应的业务规则
          系统问: "关于多人协作，有没有必须遵守的规则？比如：
            - 两个人同时改同一个东西时，谁的优先？
            - 离线时改的内容，上线后怎么处理？"

        矛盾:
          系统指出矛盾，请用户澄清

Step 4: 用户回答后，系统更新 PROJECT_BASELINE
        更新的仍然是纯业务语言，不引入技术术语
         ↓
Step 5: 重复 Step 2-4 直到所有节都清晰
        通常 1-2 轮即可完成
```

### 2.5 推导链：从 BASELINE 到所有文档

`PROJECT_BASELINE` 确定后，**由 System Architect 代理执行推导**（这是对其"真相仲裁"职责的自然延伸——他已经拥有这些文档的 ownership）。

**推导分两类，区别对待：**

**结构性推导（确定性，可自动完成）：**
```
PROJECT_BASELINE §1 产品定义
  → SYSTEM_GOAL_PACK §1 Product Vision（直接翻译）
  推导类型: structural，verified: auto

PROJECT_BASELINE §3 核心能力
  → MODULE_TAXONOMY（识别需要哪些模块）
  → 各 MODULE_CONTRACT（每个能力映射到模块职责）
  推导类型: structural，verified: auto

PROJECT_BASELINE §5 成功标准
  → VERIFICATION_ORACLE（成功标准翻译为可验证的检查项）
    例: "2 秒内看到任务列表" → Oracle: "首页加载 P95 < 2000ms"（数值转换）
  推导类型: structural，verified: auto

PROJECT_BASELINE §6 明确不做的事
  → MODULE_BOUNDARY（模块职责的排除项，直接搬运）
  → ROUTING_POLICY 的范围限定
  推导类型: structural，verified: auto
```

**翻译性推导（判断性，需用户确认）：**
```
PROJECT_BASELINE §4 业务规则
  → SYSTEM_INVARIANTS（业务规则翻译为技术不变量）
    例: "用户数据永远不能丢" → 可能的翻译:
      a) "所有写操作必须持久化后再返回成功"
      b) "数据必须有异地备份"
      c) "事务失败时必须回滚"
    具体选哪个取决于架构判断——必须展示给用户确认
  推导类型: interpretive，verified: user_confirmed

PROJECT_BASELINE §4 业务规则
  → ACCEPTANCE_RULES（验收标准的基线）
  推导类型: interpretive，verified: user_confirmed
```

**每个派生文档必须携带推导元数据：**

```yaml
# 派生文档 frontmatter 新增字段
derived_from_baseline_version: "v1.0"  # BASELINE 的版本号
derivation_type: structural | interpretive
verified: auto | user_confirmed
derived_sections:
  - baseline_section: "§4.1"
    target_section: "INV-001"
    derivation_type: interpretive
    verified: user_confirmed
    confirmation_date: 2026-03-20
```

**推导审查流程：**
```
System Architect 完成推导后:
  1. 结构性推导 → 标记 verified: auto，自动生效
  2. 翻译性推导 → 展示给用户：
     "BASELINE 说: [原文]
      我翻译为: [技术表述]
      因为: [推导理由]"
     用户确认 → 标记 verified: user_confirmed，生效
     用户不同意 → 用户给出正确翻译，System Architect 更新
```

### 2.6 推导的触发时机

**阶段一：Bootstrap 时（一次性）**
- `bootstrap-project.sh` 创建 PROJECT_BASELINE 空模板
- 用户填写并精确化后，bootstrap 触发 System Architect 执行首次推导
- 翻译性推导必须经用户确认后才能标记为 active

**阶段二：BASELINE 变更时（触发式）**
- 用户修改 PROJECT_BASELINE 后，下一次 session 启动时
- System Architect 在 HARD-GATE 阶段检测到 BASELINE 的版本号与派生文档的 `derived_from_baseline_version` 不一致
- 触发受影响部分的重新推导
- 变更差异展示给用户确认后更新

### 2.7 BASELINE 变更的级联效应

```
BASELINE §4 变更（业务规则变了）
    ↓
System Architect 检测到版本不一致
    ↓
识别受影响的下游文档（通过 derived_sections 元数据）:
  - SYSTEM_INVARIANTS: INV-001, INV-002 的 baseline_section 指向 §4
  - MODULE_CONTRACT api-service: §3.2 的 baseline_section 指向 §4
    ↓
重新推导受影响的部分
    ↓
结构性推导 → 自动更新
翻译性推导 → 展示差异给用户确认
    ↓
用户确认后更新，刷新 derived_from_baseline_version
```

---

## 3. 设计目标

1. 建立 `PROJECT_BASELINE` 作为一切真相的根——用户只需维护这一份 ≤100 行的文档，所有其他文档从它推导
2. 让系统自动从 BASELINE 派生 SYSTEM_GOAL_PACK、INVARIANTS、MODULE_CONTRACT 等全部下游文档
3. 让治理链路的内部质量能够自动评估和持续改进
4. 让用户反馈驱动 BASELINE 和下游文档的更新，标准自然随文档进化
5. 让代理 SKILL.md prompt 能基于实际表现数据进行微调
6. 让整个优化过程对用户透明、可审计、可回滚

---

## 4. 非目标

1. 不替代用户决策——系统推导标准，但 BASELINE 的内容由用户拥有
2. 不要求用户懂技术——BASELINE 使用纯业务语言，技术翻译由系统完成
3. 不修改核心架构——优化的是 prompt、模板内容和流程细节，不是代理角色体系本身
4. 不引入外部依赖——评估和优化在框架内部完成，不依赖第三方评分服务

---

## 5. 核心概念

### 5.1 两类任务，两种评估方式

**核心认知：不是所有任务都能定量评估。** 硬造数字去衡量定性问题，不是严谨，是自欺。

| 任务性质 | 评估方式 | 终止条件 | 举例 |
|---------|---------|---------|------|
| **确定性任务** | 通过/不通过，无灰度 | 全部通过，没有"大部分通过" | 路由正确、artifact 产出、测试全绿、功能实现、业务流程跑通 |
| **判断性任务** | 结构化判断 + 人类裁定 | 可自动检查的结构性问题清零 + 用户确认 | 合约是否清晰、架构决策是否合理、PRD 翻译质量、升级时机判断 |

**确定性任务不接受概率。** 生产系统中测试必须全绿、功能必须全部实现、业务流程必须跑通。不存在"跑 k 次通过几次"这种说法。

**判断性任务不假装定量。** 不给合约文档打 85 分，而是回答一组结构化问题，其中能自动检查的自动检查，不能的提交给用户裁定。

这两类任务的评估机制不同，优化循环不同，终止条件不同。不应该共享同一套评分体系。

### 5.2 文档优先推导原则

标准的生成遵循严格的推导链，**PROJECT_BASELINE 是根，文档是第一来源，用户追问是最后手段**：

```
推导优先级（从高到低）：

0. PROJECT_BASELINE（根文档）      → 一切真相的源头，用户的业务基线
1. SYSTEM_GOAL_PACK（从 BASELINE 派生）→ 业务目标的技术翻译
2. SYSTEM_INVARIANTS（从 BASELINE §4 推导）→ 不可违反的硬约束
3. MODULE_CONTRACT               → 职责边界、输入输出规格
4. MODULE_DATAFLOW / WORKFLOW    → 数据路径、执行流程
5. ACCEPTANCE_RULES              → 已有验收标准
6. BUG_CLASS_REGISTER            → 历史教训
7. RECURRENCE_PREVENTION_RULES   → 防复发规则
8. 工程最佳实践                    → 通用的、业界公认的技术标准
    ↓
以上全部推导完毕后，仍有无法确定的业务意图
    ↓
9. 问用户（只问业务选择，不问技术细节）
```

**关键规则：**
- **PRD 已经包含了大量业务标准。** 在问用户之前，必须先穷尽 SYSTEM_GOAL_PACK 中的信息。很多看似需要追问的问题，答案已经在 PRD 里了。
- **技术细节永远不问用户。** 系统从文档推导或用工程最佳实践填充。
- **只问用户他作为产品拥有者能回答好的问题。** 即业务选择和优先级取舍。
- **如果推导链走完仍没有答案，系统选最保守方案并记录决策依据。** 不因为"不确定"就把皮球踢给用户。

### 5.3 标准进化原则

评分标准不是一次性的。它通过三个渠道持续进化：

1. **文档变更驱动**——当 PRD、MODULE_CONTRACT、SYSTEM_INVARIANTS 等上游文档更新时，受影响的检查项自动重新推导
2. **用户反馈驱动**——每次任务完成后的满意度反馈，累积后转化为新检查项。但反馈的作用是**暴露文档的缺失**，而不是直接定义标准。如果反馈指出一个重复出现的问题，正确的做法是更新对应的合约或 PRD，然后标准自然随文档进化
3. **优化循环驱动**——autoresearch 过程中发现的 prompt 改进，沉淀为标准

### 5.4 问用户的分界线

| 场景 | 处理方式 |
|------|---------|
| 技术细节，文档有答案 | 系统自动推导，不问 |
| 技术细节，文档没有但有工程最佳实践 | 系统用最佳实践填充，不问 |
| 技术细节，文档没有且无通用最佳实践 | 系统选最保守方案，记录决策依据，不问 |
| 业务选择，PRD 已覆盖 | 从 PRD 推导，不问 |
| 业务选择，PRD 未覆盖，影响用户体验 | 问用户 |
| 业务选择，PRD 未覆盖，涉及优先级取舍 | 问用户 |
| 业务选择，用户描述存在矛盾 | 问用户澄清 |

**核心：用户只回答他作为产品拥有者能回答好的问题。绝大多数标准应该从文档推导，追问是最后手段而非默认行为。**

### 5.5 约束靠机制不靠期望

规则写在文档里让代理"注意遵守"，是期望。规则编码进 HARD-GATE、hooks 或工具验证，是机制。

| 层级 | 期望（弱） | 机制（强） |
|------|-----------|-----------|
| 路由 | "请先分类任务再执行" | CLAUDE.md 路由表 + SKILL.md 的 HARD-GATE 阻断 |
| 边界 | "下游不要修改上游合约" | 代码检查：Implementation 的文件修改列表中不得包含 MODULE_CONTRACT |
| 证据 | "验证要有运行时证据" | Verification 报告模板强制要求填写 evidence 字段，空值阻断 |
| 升级 | "合约不足时请升级" | 合约覆盖率检查：任务涉及的操作 vs MODULE_CONTRACT 的 owned_responsibilities |

本设计中，所有新增的检查项都应优先实现为机制（代码评分器、结构化模板的必填字段、HARD-GATE 阻断），而非期望（SKILL.md 中的文字提醒）。

### 5.6 上下文预算约束

每个路由步骤的 HARD-GATE 强制加载文档总量必须控制在上下文窗口的 10% 以内。

**HARD-GATE 文档（强制加载，静态或低增长）：**

| 路由步骤 | HARD-GATE 文档 | 估算 tokens |
|---------|---------------|------------|
| System Architect | PROJECT_BASELINE + GOAL_PACK + AUTHORITY_MAP + INVARIANTS + CONFLICT_REGISTER | ≈ 6K |
| Module Architect | baseline constraints + GOAL_PACK + INVARIANTS + MODULE_CONTRACT | ≈ 5K |
| Debug | baseline constraints + GOAL_PACK + SCENARIO_MAP + MODULE_CONTRACT + DEBUG_TEMPLATE | ≈ 6K |
| Implementation | baseline constraints + GOAL_PACK + MODULE_CONTRACT + task pack | ≈ 5K |
| Verification | baseline constraints + INVARIANTS + MODULE_CONTRACT + ACCEPTANCE_RULES + ORACLE | ≈ 7K |

对于 200K token 窗口，最大 7K ≈ 3.5%，安全。

**按需文档（不放入 HARD-GATE，仅在相关流程中加载）：**

| 文档 | 何时加载 | 为什么不是 HARD-GATE |
|------|---------|-------------------|
| FEEDBACK_LOG | 反馈收集和分析阶段 | 随时间增长，不适合每次强制加载 |
| CRITERIA_EVOLUTION | 标准审查阶段 | 历史记录，常规任务不需要 |
| OPTIMIZATION_LOG | autoresearch 优化循环 | 仅优化时需要 |
| REGRESSION_CASES | autoresearch 回归验证 | 仅优化时需要 |
| GOVERNANCE_PROGRESS-{task_id}.json | session 恢复时 | 仅跨 session 继续任务时需要 |
| BUG_CLASS_REGISTER | Debug 阶段 | 仅 bug 任务需要 |
| RECURRENCE_PREVENTION_RULES | Debug 阶段 | 仅 bug 任务需要 |

**新增 HARD-GATE 文档的前置条件：**
任何人提议将新文档加入某个角色的 HARD-GATE 时，必须：
1. 估算该文档的稳态 token 量
2. 计算加入后该角色的 HARD-GATE 总量
3. 确认总量不超过上下文窗口的 10%
4. 如果超过，必须将某个现有 HARD-GATE 文档降级为按需加载

### 5.7 上下文压缩保留优先级

当上下文接近容量时，按以下优先级保留信息：

```
1. PROJECT_BASELINE 引用          — 绝不摘要，原样保留
2. 架构决策和升级记录              — 决策的 "why" 必须留存
3. MODULE_CONTRACT 变更           — 什么变了、为什么变
4. 验证判定结果                   — 每个合约项的 pass/fail/insufficient
5. 未解决的升级和合约差距          — 开放问题必须跨压缩存活
6. 工具输出和中间执行过程          — 可删，只保留结论性摘要

标识符保护规则：
  commit hash、文件路径、PR 编号、行号、UUID、URL
  在压缩过程中必须原样保留，不得改写、简化或"修正"
```

### 5.8 Skill 路由的三要素

每个 SKILL.md 的 description 和正文必须包含三个要素，缺一不可：

1. **When to activate** — 什么情况下使用这个 Skill
2. **When NOT to activate** — 什么情况下不应使用（反例比正例更重要）
3. **Produces** — 这个 Skill 的产出物是什么

路由失败的主要原因不是模型能力不足，而是 Skill 之间的边界描述不够清晰。

### 5.9 跨 session 治理状态持久化

**设计前提：** 单开发者场景。不需要并发控制，但需要一个人中断任务后跨天/跨周回来继续的恢复能力。

当治理链路（System → Module → Debug → Implementation → Verification）跨 session 执行时，状态必须持久化到文件系统，而非依赖上下文窗口。

**状态文件：** `docs/agents/execution/GOVERNANCE_PROGRESS-{task_id}.json`

每个任务一个文件。文件名包含 task_id，不同任务互不干扰。

```json
{
  "task_id": "2026-03-20-api-rate-limit",
  "task_description": "给 API 模块加限流功能",
  "route": "System → Module → Implementation → Verification",
  "current_step": "implementation",
  "completed_steps": [
    {
      "role": "system-architect",
      "status": "done",
      "artifacts_produced": ["SYSTEM_INVARIANTS 确认无冲突"],
      "key_decisions": ["限流不影响现有不变量"]
    },
    {
      "role": "module-architect",
      "status": "done",
      "artifacts_produced": ["MODULE_CONTRACT api-service 更新"],
      "key_decisions": ["限流作为 api-service 的新职责，不新建模块"]
    }
  ],
  "pending_steps": ["implementation", "verification"],
  "context_snapshot": {
    "baseline_reference": "PROJECT_BASELINE §3.1, §4.2",
    "baseline_version": "v1.0",
    "unresolved_escalations": [],
    "evaluation_checklist_version": "v1"
  },
  "last_updated": "2026-03-20T14:30:00Z"
}
```

**Bootstrap 行为（写死，无实现自由度）：**
- Bootstrap 只拷贝 `GOVERNANCE_PROGRESS.template.md` 到 `docs/agents/execution/` 作为格式参考
- Bootstrap **不创建**任何 `GOVERNANCE_PROGRESS-{task_id}.json` 实例文件
- 实例文件由 System Architect 在首次路由任务时按 task_id 动态创建

**运行时规则：**
- 每个代理角色完成后，更新此文件
- 新 session 启动时，先检查 `docs/agents/execution/` 是否有未完成的 `GOVERNANCE_PROGRESS-*.json`，提示用户是继续还是开始新任务
- 使用 JSON 而非 Markdown（结构化格式对代理更友好）
- key_decisions 字段保留架构决策，确保跨 session 不丢失 "why"
- 任务完成后（所有步骤 done），文件归档到 `docs/agents/execution/completed/`
- 如果文件损坏或丢失，可从 git log 和已存在的 artifacts 重建状态

---

## 6. 架构设计

### 6.1 整体架构

```
┌──────────────────────────────────────────────────────┐
│              根文档层（新增）                           │
│                                                      │
│  PROJECT_BASELINE（用户拥有，≤100行，纯业务语言）       │
│       │ 自动推导                                      │
│       ├→ SYSTEM_GOAL_PACK                            │
│       ├→ SYSTEM_INVARIANTS                           │
│       ├→ MODULE_CONTRACT                             │
│       └→ ACCEPTANCE_RULES / VERIFICATION_ORACLE      │
└──────────────────────┬───────────────────────────────┘
                       │ 派生文档作为上下文
                       ▼
┌──────────────────────────────────────────────────────┐
│              治理链路（现有，增强 HARD-GATE）           │
│  System → Module → Debug → Implementation → Verify   │
│                                                      │
│  SKILL.md 增强:                                       │
│  - System Architect: HARD-GATE 加载原始 BASELINE      │
│  - 下游角色: 消费上游提炼的 baseline constraints       │
│  - 全部角色增加 When NOT to activate + Produces       │
│                                                      │
│  跨 session 状态 → GOVERNANCE_PROGRESS-{task_id}.json  │
└──────────────────────┬───────────────────────────────┘
                       │ 执行结果
                       ▼
┌──────────────────────────────────────────────────────┐
│              评估层（新增）                             │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │ 评分清单自检（先修评测再改 Agent）              │    │
│  │ - 每项能否确定性判定 yes/no？                  │    │
│  │ - 两个评分器对同一结果是否给出相同判定？        │    │
│  └──────────────────────┬───────────────────────┘    │
│                         │ 清单验证通过                 │
│                         ▼                             │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  │
│  │ 机械层评估器  │  │ 业务层评估器  │  │ 反馈收集器  │  │
│  │ (确定性检查) │  │ (文档推导)    │  │ (用户触发)  │  │
│  └──────┬──────┘  └──────┬───────┘  └──────┬─────┘  │
│         │               │                  │         │
│         └───────┬───────┴──────────────────┘         │
│                 ▼                                     │
│  ┌──────────────────────────────────────────────┐    │
│  │ 汇总：确定性任务=全部通过 / 判断性任务=人类裁定 │    │
│  └───────────────────┬──────────────────────────┘    │
└──────────────────────┼───────────────────────────────┘
                       │ 评分 + 失败分析
                       ▼
┌──────────────────────────────────────────────────────┐
│              优化层（新增）                             │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │ 标准进化引擎  │  │ Prompt 微调器 │  │ 回滚守卫   │  │
│  └──────────────┘  └──────────────┘  └───────────┘  │
│                                                      │
│  输出: 改进后的 SKILL.md / 模板 / ACCEPTANCE_RULES    │
│  （原始版本保留备份，可随时回滚）                       │
│                                                      │
│  反馈驱动: 不直接改标准，而是更新上游文档              │
│  (BASELINE / GOAL_PACK / CONTRACT) → 标准自然进化     │
└──────────────────────────────────────────────────────┘
```

### 6.2 组件详细设计

#### 6.2.1 机械层评估器

**职责：** 自动检查治理链路的过程正确性。不需要用户参与。

**评估方式：** 全部使用确定性检查。每项检查只有通过/不通过两种结果，必须可通过日志、文件记录或结构化输出确定性地判定，不依赖 LLM 判断，不使用百分比。

**检查项自检（每次优化循环开始前执行）：**

```
对每个检查项验证：
1. 是否只有"通过/不通过"两种结果？（不接受"部分通过"、"大部分通过"）
2. 判定是否确定性的？（给定相同输入，是否必然得出相同结果？）
3. 不满足条件的项 → 要么重新定义为确定性检查，要么标记为"需人类裁定"并排除出自动优化
4. 记录清单版本号，清单变更后必须重新建立基线
```

**检查清单（内置，版本化管理）：**

```yaml
governance_mechanics_checklist:
  routing:
    - id: GM-R1
      question: "任务是否被分类到正确的路由链路？"
      verification: 对比任务描述的 TaskIntent 与实际激活的代理序列

    - id: GM-R2
      question: "任务类型变更时，是否重新路由？"
      verification: 检查会话中是否有未捕获的任务类型切换

  artifact_completeness:
    - id: GM-A1
      question: "代理是否读取了所有必需的上游文档？"
      verification: 对照 SKILL.md 的 HARD-GATE 列表，检查实际读取记录

    - id: GM-A2
      question: "该链路规定的所有输出 artifact 是否已产出？"
      verification: 对照路由类型的规定产出物清单

  boundary_respect:
    - id: GM-B1
      question: "下游代理是否避免了修改上游合约？"
      verification: 检查 Implementation 和 Verification 是否修改了 MODULE_CONTRACT 或 SYSTEM_INVARIANTS

    - id: GM-B2
      question: "当合约不覆盖任务时，是否升级而非静默修复？"
      verification: 检查是否存在合约覆盖范围外的代码修改

  evidence_quality:
    - id: GM-E1
      question: "验证报告是否包含具体的运行时证据？"
      verification: 检查验证输出中是否有文件路径、行号、日志片段等具体引用

    - id: GM-E2
      question: "验证是否检查了回归矩阵？"
      verification: 检查是否读取并引用了 REGRESSION_MATRIX.md
```

**评分规则：**
- 每项只有两种结果：**通过** 或 **不通过**，没有灰度
- 全部通过 = 治理过程合格；任一项不通过 = 治理过程不合格
- 不合格项自动标记为优化目标，记录具体失败原因

#### 6.2.2 业务层评估器

**职责：** 基于用户定义的标准检查任务结果的业务质量。

**标准生成流程（文档优先推导）：**

```
Phase 0: PROJECT_BASELINE 基线提取
───────────────────────────────────
输入: 用户任务描述 + 目标模块名
动作: 首先读取 PROJECT_BASELINE（根文档），确认：
  - 任务是否在 §3 核心能力范围内？
  - 任务是否违反 §4 业务规则？
  - 任务是否属于 §6 明确不做的事？
  - §5 成功标准中是否有与此任务直接相关的可观察指标？
输出: BASELINE 约束项（这些是最高权威，后续推导不得违反）

Phase 1: PRD 业务标准提取
─────────────────────────
输入: Phase 0 的约束项 + 用户任务描述 + 目标模块名
动作: 读取 SYSTEM_GOAL_PACK（从 BASELINE 派生的技术翻译），提取与当前任务相关的：
  - 产品方向和当前阶段     → 推导：任务是否符合当前方向
  - 非协商生产义务         → 推导：质量底线检查项
  - 失败哲学              → 推导：异常处理和降级行为的标准
  - 用户体验期望           → 推导：面向用户行为的验收标准
输出: PRD 推导检查项列表

示例:
  PRD 写了 "所有功能必须生产级质量，不接受 MVP 捷径"
  → 自动推导: "实现是否覆盖了错误处理、边界情况、日志？"
  → 不需要问用户

  PRD 写了 "系统过载时优雅降级，而非报错"
  → 自动推导: "限流触发后是否返回降级响应而非裸错误？"
  → 降级行为的选择已经由 PRD 决定了，不需要再问用户

Phase 2: 合约与约束标准推导
──────────────────────────
输入: Phase 1 的结果 + 目标模块文档
动作: 依次读取以下文档，逐层叠加检查项：
  - SYSTEM_INVARIANTS.md           → 不可违反的硬约束
  - MODULE_CONTRACT.md             → 职责边界内的义务
  - MODULE_DATAFLOW.md             → 数据路径正确性
  - MODULE_WORKFLOW.md             → 执行流程正确性
  - ACCEPTANCE_RULES.md            → 已有验收标准模式
  - BUG_CLASS_REGISTER.md          → 历史上此类任务容易犯的错
  - RECURRENCE_PREVENTION_RULES.md → 必须遵守的防复发规则
输出: 技术推导检查项列表（每项标注来源文档和具体条款）

示例:
  MODULE_CONTRACT 规定了 "API 模块必须返回标准错误格式 {code, message, detail}"
  → 自动推导: "错误响应是否符合标准格式？"

  BUG_CLASS_REGISTER 记录了 "BC-003: 空值穿透导致下游崩溃"
  → 自动推导: "输入参数是否进行了空值校验？"

Phase 3: 工程最佳实践填充
─────────────────────────
输入: Phase 1+2 的结果
动作: 对于文档未覆盖但属于工程常识的领域，用最佳实践填充：
  - 幂等性（写操作是否幂等？）
  - 并发安全（共享状态是否有竞态条件？）
  - 日志可观测性（关键路径是否有日志？）
  - 向后兼容（API 变更是否破坏现有调用方？）
规则: 只填充与当前任务类型相关的项，不无差别堆砌

Phase 4: 差距识别——是否有文档未覆盖的业务意图
──────────────────────────────────────────────
输入: 用户任务描述 + Phase 1-3 的全部推导结果
动作: 对比用户任务描述中表达的意图与已推导标准
判断:
  - 用户意图已被 Phase 1-3 完全覆盖 → 不需要追问，直接进入 Phase 6
  - 用户意图中有 Phase 1-3 无法推导的业务选择 → 进入 Phase 5

什么算"无法推导的业务选择":
  ✓ 涉及用户体验的取舍，PRD 未明确表态
  ✓ 涉及业务优先级，现有文档没有覆盖
  ✓ 用户描述中出现了矛盾，需要用户澄清意图
  ✗ 技术实现细节（永远不问，系统自行决定）
  ✗ 文档已有答案但需要组合推理（系统自行推理）

Phase 5: 业务意图追问（仅在 Phase 4 发现差距时触发）
───────────────────────────────────────────────────
前提: 这一步只有在 Phase 1-3 穷尽所有文档后仍无法确定时才触发
规则:
  - 只问用户作为产品拥有者能回答好的问题
  - 不问技术实现细节
  - 每个问题必须是选择题或填空题
  - 不接受模糊回答（"合理的"、"高性能的"、"尽量快"）
  - 最多 2 轮追问，每轮最多 2 个问题
  - 如果用户表示"你决定" → 系统选最保守方案并记录决策依据

问题示例:
  ✗ "限流器用令牌桶还是滑动窗口？"        ← 技术细节，不问
  ✗ "超时阈值设多少毫秒？"                ← 技术细节，不问
  ✗ "你对性能有什么要求？"                 ← 太开放，不问

  ✓ "系统过载时，用户看到什么？"            ← PRD 未指定时才问
     A) 排队等待提示，等系统恢复
     B) "稍后再试"的明确提示
     C) 降级版本的功能（部分可用）

  ✓ "这个新功能和现有的 X 功能有冲突，保留哪个？" ← 业务取舍

Phase 6: 清单合成
─────────────────
输入:
  - Phase 1 PRD 推导项（标记 source: prd）
  - Phase 2 合约推导项（标记 source: contract | invariant | bug_history）
  - Phase 3 工程实践项（标记 source: engineering_practice）
  - Phase 5 用户回答转化项（标记 source: user_input，仅在追问发生时存在）
  - 历史反馈沉淀项（标记 source: feedback_history）
动作: 合并、去重、排序
输出: 完整评分清单

清单格式:
  - id: BQ-001
    question: "限流逻辑的执行时间是否 < 10ms？"
    source: invariant
    derived_from: "SYSTEM_INVARIANTS INV-003: 所有 API 响应 < 200ms"

  - id: BQ-002
    question: "过载时是否返回降级响应而非裸错误？"
    source: prd
    derived_from: "SYSTEM_GOAL_PACK §4: 系统过载时优雅降级"

  - id: BQ-003
    question: "错误响应是否符合 {code, message, detail} 标准格式？"
    source: contract
    derived_from: "MODULE_CONTRACT api-service §3.2: 错误格式规范"

  - id: BQ-004
    question: "是否覆盖了空值和边界情况的处理？"
    source: feedback_history
    derived_from: "过去 3 次 feature 任务反馈中 2 次指出边界处理不足"

Phase 7: 用户确认
─────────────────
将完整清单展示给用户，标注每项的推导来源
用户可以:
  - 确认全部（大多数情况，因为标准都有据可查）
  - 删除不需要的项
  - 补充遗漏的项
不需要逐条讨论——来源透明，用户一眼能判断是否合理
```

#### 6.2.3 反馈收集器

**职责：** 收集任务结果反馈，追溯到上游文档缺失，驱动文档进化。

**设计前提：** 单开发者场景。不需要多人聚合、权限控制或冲突裁定。但开发者不可能每个任务都手动反馈，因此需要隐式反馈作为兜底。

**三种反馈模式：**

```
1. 同步反馈 — 用户在场时直接询问
2. 隐式反馈 — 从执行结果自动推断（用户不在场时的兜底）
3. 延迟反馈 — 跨 session 长任务，记录到文件，下次 session 聚合
```

**同步反馈协议（用户在场时）：**

```
触发时机: 验证代理完成报告后

Step 1: 简要反馈
───────────────
问: "结果满意吗？"
选项:
  A) 满意
  B) 部分满意
  C) 不满意

如果 A → 记录正面反馈 + 当前推导链路标记为"已验证有效"→ 流程结束

Step 2: 问题定位（B 或 C 时触发）
────────────────────────────────
问: "哪些方面不符合预期？"
选项（多选）:
  A) 功能行为不正确
  B) 边界/异常情况未处理
  C) 性能不达标
  D) 代码风格/结构不符合项目惯例
  E) 与现有功能产生冲突
  F) 其他（请简要描述）

Step 3: 标准差距分析
──────────────────
系统对比:
  - 用户反馈的问题点
  - 当前检查清单的推导来源

识别:
  - 清单中有但未检出的项 → 评估器执行问题（prompt 需优化）
  - 清单中没有的项 → 上游文档缺失（需追溯到 BASELINE/GOAL_PACK/CONTRACT）
```

**隐式反馈协议（自动推断，无需用户在场）：**

```
触发时机: 任务执行结束后自动检查

- 测试全绿 → 隐式正面反馈（仅对确定性检查项有效）
- 测试失败 → 隐式负面反馈 + 自动记录失败的检查项
- CI/CD 流水线通过 → 隐式正面反馈
- 用户在 git 中 revert 了代理的修改 → 强隐式负面反馈（标记为高优先级待分析）

隐式反馈只记录事实，不自动触发文档更新建议。
累积后由同步反馈或延迟反馈阶段统一分析。
```

**延迟反馈协议（跨 session 长任务）：**

```
- 反馈记录在 FEEDBACK_LOG 中，不要求实时
- 下次 session 启动时，如有未处理的反馈，提醒用户审阅
- 用户可以一次性处理多条积累的反馈
```

Step 4: 回流上游文档（而非直接改派生文档）
──────────────────────────────────────────
如果发现标准缺失:
  追溯到应该由哪个上游文档覆盖:
    - 业务层面的缺失 → 建议用户更新 PROJECT_BASELINE
    - 技术翻译缺失 → SYSTEM_GOAL_PACK 需要重新从 BASELINE 推导
    - 合约覆盖缺失 → MODULE_CONTRACT 需要补充
  上游文档更新后，标准在下次推导时自然产生
  记录到 CRITERIA_EVOLUTION.md（作为变更历史，不作为标准来源）

  ⚠ 绝不直接向 ACCEPTANCE_RULES 写入新标准。
  ACCEPTANCE_RULES 是派生文档，它的内容只能来自上游推导。
  直接写入会让派生文档重新变成手写真相，破坏权威链。

如果是评估器执行问题:
  标记为 prompt 优化候选项
```

**反馈沉淀规则（反馈驱动文档更新，而非直接改标准）：**

```
核心原则: 反馈暴露的是文档的缺失，而非标准的缺失。
         正确的响应是更新上游文档，标准自然随之进化。

- 单次反馈: 记录到 FEEDBACK_LOG，不触发任何更新
- 同类反馈 ≥ 2 次: 分析根因，回流到正确的上游文档
    - 如果是业务规则/能力定义缺失 → 建议用户更新 PROJECT_BASELINE
    - 如果是技术翻译缺失 → 触发 System Architect 重新从 BASELINE 推导 SYSTEM_GOAL_PACK
    - 如果是模块职责缺失 → 建议更新 MODULE_CONTRACT
    - 如果是工程实践遗漏 → 系统自行在 Phase 3 补充，不需用户参与
    - ⚠ 不直接修改 ACCEPTANCE_RULES 或其他派生文档
    - 上游文档更新后，标准在下次推导时自然产生
- 同类反馈 ≥ 3 次且用户未响应上游文档更新建议:
    升级提醒优先级，但仍不直接写入派生文档
    记录为 CRITERIA_EVOLUTION 中的"待上游文档化"条目
- 正面反馈: 标记对应推导链路为"已验证有效"，强化该推导路径的可信度
```

#### 6.2.4 标准进化引擎

**职责：** 管理评分标准的全生命周期——创建、更新、废弃、回滚。

**标准来源分类：**

| 来源类型 | 说明 | 更新方式 | 权威级别 |
|---------|------|---------|---------|
| `baseline` | 直接从 PROJECT_BASELINE 提取 | 随 BASELINE 变更自动更新 | 最高 |
| `prd` | 从 SYSTEM_GOAL_PACK 推导 | 随 GOAL_PACK 变更自动更新 | 高 |
| `system_invariant` | 从 SYSTEM_INVARIANTS 推导 | 随 invariant 变更自动更新 | 高 |
| `contract` | 从 MODULE_CONTRACT 推导 | 随合约变更自动更新 | 中 |
| `engineering_practice` | 工程最佳实践填充 | 系统自行管理 | 中 |
| `user_input` | 用户在追问阶段明确提供 | 用户手动更新 | 中 |
| `feedback_history` | 从反馈累积中沉淀 | 达到阈值后半自动更新 | 低（待文档化） |
| `autoresearch` | 优化循环中发现的改进 | 优化器提议，用户确认 | 低（待验证） |

**权威冲突规则：** 当不同来源的检查项矛盾时，高权威级别的标准胜出。`feedback_history` 和 `autoresearch` 来源的标准如果与 `baseline` 或 `invariant` 冲突，必须被废弃或升级为对应的上游文档更新。

**标准废弃规则：**

```
- 来源文档被删除或标记为 superseded → 对应检查项标记为 deprecated
- 连续 5 次评估中该项未被触发（始终通过） → 建议用户审查是否仍需保留
- 用户明确要求移除 → 标记为 removed，保留历史记录
```

#### 6.2.5 Prompt 微调器

**职责：** 基于评估结果，对代理 SKILL.md 进行小幅增量修改。

**微调协议：**

```
Step 1: 失败模式分析
───────────────────
输入: 最近 N 次评估的评分数据
动作:
  - 识别失败率最高的检查项
  - 追溯到对应的代理角色（哪个代理负责这个环节）
  - 分析失败原因模式

Step 2: 变更生成
───────────────
规则:
  - 每轮只改一处，改动尽可能小
  - 优先在已有规则基础上增加精确性，而非添加新规则
  - 修改方向:
    a) 将模糊指令精确化（"注意边界" → "必须处理 null、空数组、超长字符串三种情况"）
    b) 增加失败案例的 worked example
    c) 增加明确的禁止项（"NEVER: ..."）
    d) 调整执行顺序（如果顺序导致信息遗漏）

Step 3: 验证
───────────
  - 用修改后的 SKILL.md 重新跑相同测试场景
  - 之前不通过的项是否通过了？（修复验证）
  - 之前通过的项是否仍然通过？（回归保护）
  - 标准：全部通过 → 保留；任一退化 → 回滚

Step 4: 记录
──────────
  - 记录修改内容、原因、各项通过/不通过状态变化
  - 写入 OPTIMIZATION_LOG.md
  - 保留原始 SKILL.md 备份
```

#### 6.2.6 回滚守卫

**职责：** 确保任何优化都可逆，防止优化过程引入退化。

**回滚规则：**

```
自动回滚条件:
  - 优化后任一之前通过的检查项变为不通过（零容忍退化）
  - 优化后 SYSTEM_INVARIANTS 相关检查项不通过
  - 优化后修复目标仍然不通过（修改无效）

手动回滚:
  - 用户随时可以回滚到任意历史版本
  - 回滚操作记录在 OPTIMIZATION_LOG.md

备份策略:
  - 每次微调前，原始文件复制到 docs/agents/optimization/backups/
  - 备份文件名格式: {原文件名}.{轮次号}.backup.md
  - 保留最近 10 个版本
```

---

## 7. 新增 Artifact 设计

### 7.1 FEEDBACK_LOG.template.md

**位置：** `docs/templates/verification/FEEDBACK_LOG.template.md`
**实例化位置：** `docs/agents/verification/FEEDBACK_LOG.md`

```yaml
artifact_type: feedback-log
status: proposed
owner_role: verification
scope: verification
downstream_consumers: [system-architect, module-architect]
```

**内容结构：**

```markdown
# FEEDBACK_LOG

## 反馈记录

### FB-001
- **Date:** YYYY-MM-DD
- **Task Type:** feature | bug | design | audit
- **Task Description:** [简要描述]
- **Satisfaction:** satisfied | partial | unsatisfied
- **Issues:** [问题分类列表]
- **Detail:** [用户的具体反馈]
- **Checklist Gap:** [清单中缺失的检查项，如有]
- **Action Taken:** none | upstream_update_suggested | prompt_optimized | escalated

## 统计摘要

- 总反馈数: N
- 满意 / 部分满意 / 不满意: 各多少次
- 最常见问题类型: [类型]
- 待处理的标准更新建议: N 条
```

### 7.2 CRITERIA_EVOLUTION.template.md

**位置：** `docs/templates/verification/CRITERIA_EVOLUTION.template.md`
**实例化位置：** `docs/agents/verification/CRITERIA_EVOLUTION.md`

```yaml
artifact_type: criteria-evolution
status: proposed
owner_role: verification
scope: verification
downstream_consumers: [implementation, debug]
```

**内容结构：**

```markdown
# CRITERIA_EVOLUTION

## 检查项变更历史

### CE-001: [检查项名称]
- **Date Added:** YYYY-MM-DD
- **Source:** system_invariant | contract | user_input | feedback_history | autoresearch
- **Derived From:** [来源文档或反馈编号]
- **Current Status:** active | deprecated | removed
- **Question:** [yes/no 检查问题]
- **Changelog:**
  - YYYY-MM-DD: 初始创建，来源: [说明]
  - YYYY-MM-DD: 措辞精确化，原因: [用户反馈 FB-XXX]
  - YYYY-MM-DD: 废弃，原因: [来源合约已更新]
```

### 7.3 OPTIMIZATION_LOG.template.md

**位置：** `docs/templates/optimization/OPTIMIZATION_LOG.template.md`
**实例化位置：** `docs/agents/optimization/OPTIMIZATION_LOG.md`

```yaml
artifact_type: optimization-log
status: proposed
owner_role: autoresearch
scope: system
downstream_consumers: [system-architect]
```

**内容结构：**

```markdown
# OPTIMIZATION_LOG

## 优化轮次记录

### Round 001
- **Date:** YYYY-MM-DD
- **Target:** [被修改的文件，如 .claude/skills/verification/SKILL.md]
- **Trigger:** [触发优化的原因，如"GM-E1 连续 3 轮失败"]
- **Change Description:** [具体修改内容]
- **Rationale:** [为什么认为这个修改会改善评分]
- **Before:** [列出修改前不通过的检查项]
- **After:** [列出修改后每个检查项的通过/不通过状态]
- **Regressions:** [列出修改后新出现的不通过项，如有]
- **Decision:** kept | reverted
- **Backup:** [备份文件路径]
```

### 7.4 治理测试场景集

**位置：** `docs/templates/optimization/test-scenarios/`
**实例化位置：** `docs/agents/optimization/test-scenarios/`

没有测试场景集，autoresearch 优化循环就没有输入数据。

**场景来源（三类）：**

1. **种子场景**——bootstrap 时由框架提供，覆盖每种路由类型：
   - 一个 bug 类任务（测试 System → Module → Debug → Implementation → Verification）
   - 一个 feature 类任务（测试 System → Module → Implementation → Verification）
   - 一个 design 类任务（测试 System → Module → Verification）
   - 一个 audit 类任务（测试 System Architect only）

2. **真实任务回放**——每次真实任务完成且用户确认满意后，该任务的描述+路由+检查结果自动保存为测试场景

3. **回归场景**——每次 autoresearch 修复一个失败后，对应的失败场景自动加入回归集

**场景格式：**

```json
{
  "scenario_id": "TS-001",
  "type": "feature",
  "description": "给 API 模块加限流功能",
  "expected_route": "System → Module → Implementation → Verification",
  "target_module": "api-service",
  "expected_checks": {
    "GM-R1": "pass",
    "GM-A1": "pass",
    "GM-A2": "pass",
    "GM-B1": "pass",
    "GM-B2": "pass",
    "GM-E1": "pass",
    "GM-E2": "pass"
  },
  "source": "seed | replay | regression",
  "date_added": "2026-03-20"
}
```

**维护规则：**
- 种子场景在 bootstrap 时生成，可手动编辑
- 回放场景和回归场景自动生成，只增不减（除非对应的检查项被废弃）
- 场景数量超过 50 个时，建议用户审查是否有冗余

---

## 8. 优化循环完整流程

### 8.1 治理机械层自优化（全自动）

```
┌─ 启动条件: 用户运行 /autoresearch-governance 或累积 N 次任务后自动触发
│
├─ Step 0: 检查项自检（先修评测再改 Agent）
│  ├─ 对每个检查项验证：是否只有"通过/不通过"两种结果？
│  ├─ 对每个检查项验证：判定是否确定性的（不依赖 LLM 主观判断）？
│  ├─ 不满足条件的项 → 要么重新定义为确定性检查，要么标记为"需人类裁定"
│  └─ 记录清单版本号，清单变更后必须重新建立基线
│
├─ Step 1: 基线评估
│  ├─ 用内置机械层清单（GM-R1..GM-E2）评估最近的治理过程
│  ├─ 每项只有通过/不通过，没有百分比
│  └─ 输出: 哪些项通过，哪些项不通过，不通过的具体原因
│
├─ Step 2: 失败分析
│  ├─ 找出不通过的检查项
│  ├─ 追溯到对应的代理 SKILL.md
│  ├─ 分析失败原因（模糊指令？遗漏场景？执行顺序？）
│  └─ 区分：是 SKILL.md 的问题，还是检查项定义的问题？
│         如果同一项在不同场景下判定不一致 → 检查项问题，修检查项而非 SKILL
│
├─ Step 3: 微调
│  ├─ 对目标 SKILL.md 做一处小修改
│  ├─ 备份原始版本
│  └─ 记录修改原因
│
├─ Step 4: 重新评估（双重检查）
│  ├─ 当前场景: 之前不通过的项是否现在通过了？
│  ├─ 回归保护: 之前通过的项是否仍然通过？（已修复的历史失败场景也要重新跑）
│  └─ 标准很简单：全部通过 = 改进有效，任一退化 = 回滚
│
├─ Step 5: 决策
│  ├─ 新修复的项通过 且 无退化 → 保留修改
│  ├─ 新修复的项通过 但 有退化 → 回滚（回归保护优先于新修复）
│  ├─ 新修复的项仍不通过 → 回滚
│  └─ 保留的修改对应的失败场景 → 自动加入回归用例集，后续轮次必须持续通过
│
├─ Step 6: 终止条件
│  ├─ 所有检查项全部通过 → 停止（这是唯一的正常终止）
│  ├─ 连续 3 轮无法修复任何不通过项 → 停止，输出剩余问题清单供人工处理
│  └─ 达到最大轮次（默认 10 轮） → 停止，输出剩余问题清单
│
└─ Step 7: 输出报告
   ├─ 优化后的 SKILL.md（已就位）
   ├─ OPTIMIZATION_LOG.md（每轮的修改、原因、结果）
   ├─ 回归用例集（只增不减）
   ├─ 剩余不通过项清单（如有）
   └─ 原始备份（可随时回滚）
```

### 8.2 用户业务层标准进化（文档优先推导）

```
┌─ 触发条件: 新任务开始时
│
├─ Step 0: PROJECT_BASELINE 基线确认
│  ├─ 读取 PROJECT_BASELINE，确认任务在核心能力范围内
│  ├─ 确认任务不违反业务规则，不属于"明确不做的事"
│  ├─ 提取直接相关的成功标准
│  └─ 输出: BASELINE 约束项（最高权威，后续推导不得违反）
│
├─ Step 1: PRD 优先提取
│  ├─ 读取 SYSTEM_GOAL_PACK（从 BASELINE 派生），提取与当前任务相关的业务标准
│  ├─ 产品方向 → 任务方向性检查
│  ├─ 非协商义务 → 质量底线检查
│  ├─ 失败哲学 → 异常和降级行为标准
│  └─ 输出: PRD 推导检查项（大多数业务标准在这一步就已确定）
│
├─ Step 2: 合约与约束逐层叠加
│  ├─ SYSTEM_INVARIANTS → 硬约束检查项
│  ├─ MODULE_CONTRACT → 职责和输入输出检查项
│  ├─ DATAFLOW / WORKFLOW → 路径和流程检查项
│  ├─ BUG_CLASS_REGISTER → 历史教训检查项
│  └─ 输出: 技术推导检查项
│
├─ Step 3: 工程最佳实践填充
│  ├─ 文档未覆盖但属于工程常识的领域
│  └─ 输出: 工程实践检查项（只填充相关项，不堆砌）
│
├─ Step 4: 差距识别
│  ├─ 对比用户任务描述 vs Step 1-3 全部推导结果
│  ├─ 如果全部覆盖 → 跳过 Step 5，直接合成清单
│  └─ 如果有 PRD 未覆盖的业务意图 → 进入 Step 5
│
├─ Step 5: 业务意图追问（仅在 Step 4 发现差距时触发）
│  ├─ 只问用户作为产品拥有者能回答好的问题
│  ├─ 不问技术实现细节
│  ├─ 最多 2 轮，每轮最多 2 个问题
│  └─ 用户说"你决定" → 系统选最保守方案，记录依据
│
├─ Step 6: 清单合成 + 分类
│  ├─ 合并全部推导项，每项标注来源文档
│  ├─ 分类每个检查项：
│  │   - 确定性检查（测试通过、功能实现、流程跑通）→ 自动验证，必须全部通过
│  │   - 判断性检查（合约清晰度、决策合理性）→ 标记为"需人类裁定"
│  └─ 展示给用户确认（来源透明，用户一眼能判断合理性）
│
├─ Step 7: 执行任务（走正常治理链路）
│
├─ Step 8: 验收
│  ├─ 确定性检查项：全部通过 = 合格，任一不通过 = 不合格
│  ├─ 判断性检查项：提交给用户裁定，不硬造分数
│  └─ 终止条件：确定性项全部通过 + 判断性项用户确认
│
├─ Step 9: 反馈收集
│  ├─ 任务完成后询问满意度
│  ├─ 如不满意，定位具体问题
│  └─ 识别是标准缺失还是执行偏差
│
└─ Step 10: 反馈回流上游文档（绝不直接改派生文档）
   ├─ 单次反馈 → 记录到 FEEDBACK_LOG
   ├─ 同类 ≥ 2 次 → 追溯到应由哪个上游文档覆盖：
   │   ├─ 业务规则/能力缺失 → 建议用户更新 PROJECT_BASELINE
   │   ├─ 技术翻译缺失 → 触发 System Architect 重新推导 SYSTEM_GOAL_PACK
   │   └─ 模块职责缺失 → 建议更新 MODULE_CONTRACT
   │   ⚠ 不直接写入 ACCEPTANCE_RULES 或 VERIFICATION_ORACLE
   └─ 上游文档更新后 → 触发推导链，标准自然随之进化
```

---

## 9. 对现有框架的影响

### 9.1 需要修改的文件

**权威链一致性（所有定义路由或 artifact loading 的文件必须同步更新）：**

| 文件 | 修改内容 |
|------|---------|
| `docs/templates/system/ROUTING_POLICY.template.md` | **最关键：** §4 Artifact Loading 增加 PROJECT_BASELINE（仅 System Architect 加载原始文档）；§1 声明 BASELINE 为最高权威输入；下游角色改为消费"上游已提炼的 baseline constraints" |
| `docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md` | 新增 Tier 0 = PROJECT_BASELINE，现有 Tier 1-6 顺延为 Tier 1-7 |
| `CLAUDE.md` | 增加 PROJECT_BASELINE 入口（路由第一步）、上下文压缩保留优先级、"约束靠机制不靠期望"原则 |
| `AGENTS.md` | Role Activation 的 System Architect 部分增加 PROJECT_BASELINE；与 ROUTING_POLICY 保持一致 |
| `GEMINI.md` | 如有独立路由定义，同步更新 |
| `docs/templates/BOOTSTRAP_READINESS.template.md` | 增加 PROJECT_BASELINE 存在性检查为 bootstrap 第一项 |

**SKILL.md 修改（BASELINE 加载策略：只有 System Architect 加载原始文档，下游消费提炼结果）：**

| 文件 | 修改内容 |
|------|---------|
| `.claude/skills/system-architect/SKILL.md` | HARD-GATE 增加 PROJECT_BASELINE 为最高权威（原始文档）；增加"推导派生文档"职责；增加 When NOT to Activate + Produces |
| `.claude/skills/module-architect/SKILL.md` | HARD-GATE **不**直接加载 BASELINE，而是消费上游 System Architect 传递的 baseline constraints；增加 When NOT to Activate + Produces |
| `.claude/skills/debug/SKILL.md` | 同上——消费上游传递的 baseline constraints；增加 When NOT to Activate + Produces |
| `.claude/skills/implementation/SKILL.md` | 同上；增加 When NOT to Activate + Produces |
| `.claude/skills/verification/SKILL.md` | 同上；增加反馈收集协议、检查项自检、When NOT to Activate + Produces |
| `.claude/skills/frontend-specialist/SKILL.md` | 增加 When NOT to Activate + Produces |

**派生文档模板修改（所有从 BASELINE 派生的文档统一增加推导元数据）：**

| 文件 | 修改内容 |
|------|---------|
| `docs/templates/system/SYSTEM_GOAL_PACK.template.md` | 改为派生文档模板，增加 `derived_from_baseline_version`、`derivation_type`、`verified`、`derived_sections` 元数据 |
| `docs/templates/system/SYSTEM_INVARIANTS.template.md` | 增加 `derived_from_baseline_version`、`derivation_type`、`verified`、`derived_sections` 元数据 |
| `docs/templates/modules/MODULE_CONTRACT.template.md` | 增加 `derived_from_baseline_version`、`derivation_type`、`verified`、`derived_sections` 元数据 |
| `docs/templates/verification/ACCEPTANCE_RULES.template.md` | 增加 `derived_from_baseline_version`、`derivation_type`、`verified`、`derived_sections`、`source`、`authority_level` 元数据 |
| `docs/templates/verification/VERIFICATION_ORACLE.template.md` | 增加 `derived_from_baseline_version`、`derivation_type`、`verified`、`derived_sections` 元数据 |

### 9.2 需要新增的文件

| 文件 | 用途 |
|------|------|
| `docs/templates/PROJECT_BASELINE.template.md` | **根文档模板——用户唯一需要手写的文档** |
| `docs/templates/execution/GOVERNANCE_PROGRESS.template.md` | 跨 session 治理状态（JSON 格式，per task_id） |
| `docs/templates/verification/FEEDBACK_LOG.template.md` | 反馈记录模板 |
| `docs/templates/verification/CRITERIA_EVOLUTION.template.md` | 标准进化历史模板 |
| `docs/templates/optimization/OPTIMIZATION_LOG.template.md` | 优化轮次记录模板 |
| `docs/templates/optimization/test-scenarios/seed-*.json` | 种子测试场景（每种路由类型一个） |
| `.claude/skills/autoresearch/SKILL.md` | autoresearch 技能定义 |
| `.claude/commands/autoresearch.md` | /autoresearch 命令入口 |

### 9.3 需要新增的目录

| 目录 | 用途 |
|------|------|
| `docs/templates/optimization/` | 优化相关模板 |
| `docs/templates/optimization/test-scenarios/` | 种子测试场景 |
| `docs/templates/execution/` | 执行状态模板 |
| 目标项目 `docs/agents/optimization/` | 优化日志和备份 |
| 目标项目 `docs/agents/optimization/backups/` | SKILL.md 微调备份 |
| 目标项目 `docs/agents/optimization/test-scenarios/` | 测试场景集（种子+回放+回归） |
| 目标项目 `docs/agents/execution/completed/` | 已完成任务的 GOVERNANCE_PROGRESS 归档 |

### 9.4 Bootstrap 脚本影响

Bootstrap 是两阶段过程，不是一次性操作：

**阶段 A：脚本执行（`bootstrap-project.sh`）**

脚本负责创建目录结构和拷贝模板。它是纯 bash，不调用 LLM：
- 第一步拷贝 `PROJECT_BASELINE.md` 模板（空模板，等用户填写）
- 拷贝所有系统/模块/调试/验证/优化模板到目标仓库
- 创建 `docs/agents/optimization/`、`backups/`、`test-scenarios/` 目录
- 创建 `docs/agents/execution/` 和 `completed/` 目录
- 拷贝 4 个种子测试场景 `seed-*.json`
- 拷贝 `GOVERNANCE_PROGRESS.template.md` 作为参考（不创建实例文件）
- 所有派生文档此时的 `derived_from_baseline_version` 为 `v0.0`（表示尚未推导）

**阶段 B：首次推导（用户 + System Architect，在 AI 编码工具中执行）**

脚本完成后，用户在 AI 编码工具中手动触发推导：
1. 用户填写 `PROJECT_BASELINE.md`
2. 用户告诉 AI："PROJECT_BASELINE is ready. Derive SYSTEM_GOAL_PACK and SYSTEM_INVARIANTS from it."
3. System Architect 的 HARD-GATE 加载 BASELINE，执行推导协议（§2.5-2.6）
4. 结构性推导自动完成，翻译性推导展示给用户确认
5. 推导完成后，每个派生文档的 `derived_from_baseline_version` 更新为实际版本

**阶段 B 未完成之前，治理链路无法正常工作。** 脚本的输出明确告知用户这一点。

**`--validate` 模式的检查范围：**
- PROJECT_BASELINE 是否存在且已填写
- 所有派生文档（SYSTEM_GOAL_PACK、SYSTEM_INVARIANTS、MODULE_CONTRACT、ACCEPTANCE_RULES、VERIFICATION_ORACLE）是否有 `derived_from_baseline_version` 元数据
- `derived_from_baseline_version` 是否仍为 `v0.0`（表示推导未执行）
- 优化基础设施（OPTIMIZATION_LOG、test-scenarios、REGRESSION_CASES 等）是否就位

---

## 10. 约束与风险

### 10.1 约束

1. **PROJECT_BASELINE 是唯一的根。** 所有标准最终必须可追溯到 BASELINE。如果一个标准无法追溯，它要么来自工程最佳实践（需标注），要么不应该存在。
2. **派生文档不可手写化。** SYSTEM_GOAL_PACK、SYSTEM_INVARIANTS、ACCEPTANCE_RULES、VERIFICATION_ORACLE 等派生文档，只能通过推导链从上游生成。任何需要修改派生文档内容的需求，必须追溯到对应的上游文档（最终追溯到 BASELINE），更新上游后重新推导。直接写入派生文档会破坏权威链的完整性。
3. **BASELINE 由用户拥有。** 系统可以帮助精确化，但不能单方面修改 BASELINE 内容。用户确认是唯一的写入路径。
4. **技术翻译由系统负责。** BASELINE 使用纯业务语言。从业务语言到技术标准的翻译是 System Architect 的职责，不是用户的职责。翻译性推导需用户确认后才能生效。
5. **只有 System Architect 加载原始 BASELINE。** 下游角色（Module Architect、Implementation、Verification 等）消费上游已提炼的 baseline constraints，不必每个角色都重读整份根文档。
6. **Prompt 微调不改变角色职责。** 优化器只能调整 SKILL.md 中的指令细节，不能修改代理的核心职责边界或上下游关系。
7. **回滚必须可用。** 任何时候都能回到优化前的状态。如果备份丢失，优化流程必须停止。

### 10.2 风险

| 风险 | 缓解措施 |
|------|---------|
| 评分清单本身有误，优化循环朝错误方向收敛 | Step 0 评分清单自检；定期人工抽查清单质量；清单版本化管理 |
| 优化清单过度拟合，代理开始"应试"而非真正改进 | 回归用例持续累积；定期人工审查检查项是否仍然有意义 |
| 判断性任务被硬塞进定量评估 | 明确区分确定性任务和判断性任务，后者用结构化判断 + 人类裁定 |
| 用户反馈偏斜（只在不满意时反馈） | 主动收集正面反馈；满意时也记录 |
| 累积修改导致 SKILL.md 膨胀 | 每 5 轮检查 SKILL.md 长度，超过阈值时触发精简 |
| 跨 session 状态文件过期或与实际进度不符 | 每个代理角色完成后强制更新 GOVERNANCE_PROGRESS-{task_id}.json |
| 上下文压缩丢失关键决策 | 压缩保留优先级写入 CLAUDE.md，架构决策和标识符不可摘要 |
| Skill 路由错误（选错代理角色） | 所有 SKILL.md 增加 When NOT to Activate 反例条件 |

---

## 11. 实施计划

### Phase 0: 根文档 + 权威链一致性 + 治理链路增强（最高优先级）

**根文档体系：**
- 创建 `PROJECT_BASELINE.template.md` 模板
- 实现根文档精确化协议（系统帮用户在 1-2 轮追问内完善 BASELINE）
- 实现推导链（含元数据：`derived_from_baseline_version`、`derivation_type`、`verified`）
- 实现结构性推导（自动）和翻译性推导（需用户确认）的区分
- 修改 `SYSTEM_GOAL_PACK.template.md` 为派生文档模板

**权威链一致性（所有定义路由或 artifact loading 的文件必须同步更新）：**
- 修改 `SYSTEM_AUTHORITY_MAP.template.md`：新增 Tier 0 = PROJECT_BASELINE
- 修改 `ROUTING_POLICY.template.md`：§4 System Architect 增加 BASELINE，下游角色消费上游 baseline constraints
- 修改 `CLAUDE.md`：增加 BASELINE 入口、压缩保留优先级、"约束靠机制不靠期望"原则
- 修改 `AGENTS.md`：Role Activation 与 ROUTING_POLICY 保持一致
- 修改 `BOOTSTRAP_READINESS.template.md`：BASELINE 存在性检查为第一项

**SKILL.md 修改（只有 System Architect 加载原始 BASELINE）：**
- System Architect：HARD-GATE 增加 BASELINE 为最高权威 + 增加"推导派生文档"职责
- 其余 5 个 SKILL.md：消费上游 baseline constraints，不直接加载 BASELINE
- 全部 6 个增加 When NOT to Activate + Produces

**跨 session 状态：**
- 创建 `GOVERNANCE_PROGRESS.template.md`（per task_id，单开发者长期恢复用）

### Phase 1: 推导链完善 + 评估基础设施
- 实现从 BASELINE → MODULE_CONTRACT、ACCEPTANCE_RULES、VERIFICATION_ORACLE 的完整推导链
- 实现 BASELINE 变更的级联影响检测（通过 `derived_sections` 元数据追踪）
- 实现机械层评估清单（全部使用确定性检查，不使用模型评分器）
- 实现检查项自检机制（可执行性、无歧义性、版本化管理）
- 创建 FEEDBACK_LOG、CRITERIA_EVOLUTION、OPTIMIZATION_LOG 三个模板
- 创建种子测试场景集（4 个种子场景，覆盖每种路由类型）

### Phase 2: 文档优先的标准生成
- 实现业务层评估器的 8 步标准生成流程（BASELINE 基线 → PRD 提取 → 合约推导 → 工程实践 → 差距识别 → 追问 → 合成 → 确认）
- 实现"只问业务意图，不问技术细节"的追问过滤器
- 在 verification skill 中加入反馈收集协议

### Phase 3: 优化循环
- 实现 Prompt 微调器
- 实现回滚守卫（零容忍退化：任一已通过项变为不通过即回滚）
- 实现回归用例自动累积机制（修复的失败场景自动加入回归集）
- 创建 autoresearch skill 和 command
- 实现修复验证 + 回归保护的双重检查逻辑

### Phase 4: 反馈驱动文档进化
- 实现反馈累积统计和模式识别
- 实现反馈到文档更新建议的转化（反馈 → 识别 BASELINE/PRD/合约缺失 → 建议更新上游文档）
- 实现标准废弃检测
- 实现标准权威冲突检测和解决

---

## 12. 验收标准

本设计的实现验收需要满足：

**根文档与推导链：**
1. **根文档可用：** 用户可以写一份 ≤100 行的 PROJECT_BASELINE，系统能帮助精确化，并从中派生 SYSTEM_GOAL_PACK 和 SYSTEM_INVARIANTS
2. **推导链可追溯：** 每个派生文档携带 `derived_from_baseline_version`、`derivation_type`、`verified` 元数据，每条规则能标注从 BASELINE 哪一节推导而来
3. **结构性与翻译性推导区分：** 结构性推导自动完成并标记 `verified: auto`；翻译性推导必须展示"X → Y because Z"并经用户确认后标记 `verified: user_confirmed`
4. **BASELINE 变更可级联：** 修改 BASELINE 后，System Architect 通过 `derived_sections` 元数据识别受影响的下游文档并触发重新推导
5. **派生文档不可手写化：** 反馈流程中任何标准变更需求都回流到上游文档，不直接写入 ACCEPTANCE_RULES 等派生文档

**权威链一致性：**
6. **Tier 0 权威确立：** SYSTEM_AUTHORITY_MAP 包含 Tier 0 = PROJECT_BASELINE
7. **ROUTING_POLICY 同步：** ROUTING_POLICY §4 的 System Architect artifact loading 包含 BASELINE；下游角色消费上游 baseline constraints
8. **所有入口文件一致：** CLAUDE.md、AGENTS.md、ROUTING_POLICY、各 SKILL.md 对 artifact loading 顺序无矛盾

**治理链路增强：**
9. **Skill 路由三要素完整：** 所有 6 个 SKILL.md 都包含 When to Activate、When NOT to Activate、Produces
10. **BASELINE 加载策略正确：** 只有 System Architect 直接加载 PROJECT_BASELINE 原始文档，下游角色消费提炼后的 baseline constraints
11. **跨 session 可恢复：** 单开发者中断任务后，从 GOVERNANCE_PROGRESS-{task_id}.json 恢复
12. **压缩保留优先级生效：** 上下文压缩后，BASELINE 引用和架构决策完整保留

**评估与优化：**
13. **检查项全部为确定性判定：** 所有机械层检查项只有通过/不通过，不依赖 LLM 主观判断
14. **测试场景集存在：** 至少有 4 个种子场景覆盖每种路由类型，回归场景自动累积
15. **三种反馈模式可用：** 同步反馈（用户在场）、隐式反馈（测试/CI 结果）、延迟反馈（跨 session）
16. **反馈只回流上游：** 累积反馈后追溯到 BASELINE/GOAL_PACK/CONTRACT 缺失，不直接写入派生文档
17. **优化循环可执行：** 能完成至少一轮"检查项自检 → 基线评估 → 微调 → 修复验证+回归保护 → 保留/回滚"的完整循环
18. **零容忍退化：** 优化过程中任一已通过项变为不通过，自动回滚，无例外
19. **回滚可用：** 任意优化都能回滚到修改前状态
