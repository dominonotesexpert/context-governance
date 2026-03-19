# Context Governance Multi-Agent Design

**Date:** 2026-03-18  
**Status:** Active  
**Scope:** 面向当前仓库与相关代码库的长期多代理上下文治理体系；用于系统设计、模块设计、实现、验证与前端专业协作

---

## 1. 背景

当前 LLM coding 的主要瓶颈不是“不会写”，而是**上下文不足或上下文失真**。

在真实开发中，问题通常表现为：

1. 模型忘记系统最终目标
2. 模型忘记顶层架构边界
3. 模型把历史缓解文档误当成当前 baseline
4. 模型把当前代码现状误当成设计真理
5. 不同任务反复重新读取大上下文，导致噪声积累

因此，问题的核心不是“是否使用多 agent”，而是：

**如何让不同角色长期拥有不同层级的真相，并在每次任务时把这些真相压缩成最小、正确、可追溯的上下文包。**

---

## 2. 设计目标

本设计的目标是：

1. 让系统级、模块级、实现级、验证级真相分层持有
2. 让每个角色都只读取自己职责需要的最小权威工作集
3. 让下游 agent 只能消费上游批准过的 artifact，而不是自行重建真相
4. 让系统能够长期演化文档，而不是依赖一次性对话记忆
5. 让实现与验证始终回到最终目标、顶层架构和 active baseline

---

## 3. 非目标

本设计**不**追求：

1. 让每个 agent 长期保留大量隐式聊天记忆
2. 用更多 agent 数量代替更清晰的 artifact 体系
3. 让 coding agent 自己重写系统或模块真相
4. 用 prompt 技巧代替权威层级、contract 和 fail-closed 机制

---

## 4. 核心原则

### 4.1 持久的是角色 ownership，不是执行对话状态

角色应长期拥有：

1. 职责边界
2. 权威文档
3. 决策规则
4. 输出 artifact 类型

角色不应长期依赖：

1. 一长串隐式聊天历史
2. 模糊的“上次我记得大概是这样”

### 4.2 上下文优先级高于上下文总量

问题不在于让 agent 读取更多，而在于让 agent 明确知道：

1. 谁是权威
2. 哪些文档已废弃
3. 当前任务适用哪条 baseline
4. 哪些代码只是现状证据，不是真理

### 4.3 下游只能消费上游批准过的真相

1. `Implementation Agent` 不拥有系统真相
2. `Verification Agent` 不重写需求
3. `Frontend Specialist Agent` 不得以视觉理由突破语义 contract

如果发现上游文档有误，只能升级并回流修文档，不能静默在代码里“修正现实”。

### 4.4 代码是证据，不是设计真理

代码需要被读取，但它的角色是：

1. 证明当前实现态
2. 为文档裁决提供证据

而不是：

1. 自动推翻最终目标
2. 自动推翻 active baseline

### 4.5 真正持久化的对象是 artifact

多代理系统长期维护的核心不是 agent 自身，而是 artifact：

1. `System Goal Pack`
2. `Authority Map`
3. `Conflict Register`
4. `Module Contract Pack`
5. `Task Execution Pack`
6. `Verification Oracle`

---

## 5. 角色体系

本设计固定 5 个持久角色，加 1 个轻量编排器。

### 5.1 `System Architect Agent`

职责：

1. 维护最终目标
2. 维护系统级边界和全局不变量
3. 审计系统设计文档是否正确
4. 裁决文档冲突
5. 判断代码偏了还是文档偏了

### 5.2 `Module Architect Agent`

职责：

1. 把系统级目标落到模块级 contract
2. 定义模块输入输出、状态流、数据流、工作流
3. 定义模块边界与上下游接口

### 5.3 `Implementation Agent`

职责：

1. 消费上游 artifact 实现代码
2. 产出实施说明与必要测试
3. 报告设计缺口或冲突

### 5.4 `Verification Agent`

职责：

1. 按 contract 验证实现
2. 识别证据不足、回归风险与阻塞问题
3. 把问题回流到正确层级

### 5.5 `Frontend Specialist Agent`

职责：

1. 在 UI/交互任务中提供专业约束与实现支持
2. 保证视觉层不突破系统与模块语义边界

### 5.6 `Task Orchestrator`

职责：

1. 不拥有长期真相
2. 只负责把上游 artifact 裁剪成当前任务的最小上下文包
3. 决定当前任务需要拉入哪些持久角色

### 5.7 当前落地模式说明

本设计兼容两种运行模式：

1. `Multi-Agent Runtime`
   - 主 agent 充当 `Task Orchestrator`
   - 并行拉起多个 sub-agent 执行不同角色
   - 角色之间通过 artifact 而不是隐式共享记忆协作
2. `Single-Agent Compatibility Mode`
   - 在当前不适合或不需要并行 agent 的环境中，由同一个 agent 顺序扮演多个角色
   - 用户或主 agent 充当 orchestrator
   - 每次角色切换时，强制重新加载对应的 `docs/agents/...` artifact

因此，`Task Orchestrator` 是一个逻辑角色，不要求一定对应独立运行时进程。

---

## 6. 权威层级

`System Architect Agent` 必须长期维护文档权威层级。

默认优先级如下：

1. 最终目标 / PRD
2. 顶层架构文档
3. 系统级 active baseline / active correction
4. 模块级 active design / implementation plan
5. 历史缓解 / historical note / deprecated 文档
6. 当前代码实现状态

关键规则：

1. newer 文档不自动胜过 older 文档
2. active correction 可以推翻旧 baseline
3. historical mitigation 不能因为“代码还在用”就升格为 baseline
4. 任何削弱 fail-closed、runtime ownership、shared contract 的局部方案都必须高警惕

---

## 7. 核心 artifact 体系

### 7.1 系统级 artifact

由 `System Architect Agent` 维护：

1. `SYSTEM_GOAL_PACK.md`
2. `SYSTEM_AUTHORITY_MAP.md`
3. `SYSTEM_CONFLICT_REGISTER.md`
4. `SYSTEM_INVARIANTS.md`

### 7.2 模块级 artifact

由 `Module Architect Agent` 维护：

1. `MODULE_CONTRACT_<module>.md`
2. `MODULE_BOUNDARY_<module>.md`
3. `MODULE_DATAFLOW_<module>.md`
4. `MODULE_WORKFLOW_<module>.md`

### 7.3 任务级 artifact

由 `Task Orchestrator` 生成：

1. `TASK_EXECUTION_PACK_<task>.md`
2. `AFFECTED_FILES_MAP_<task>.md`
3. `TASK_RISK_CHECKLIST_<task>.md`

### 7.4 验证级 artifact

由 `Verification Agent` 维护：

1. `VERIFICATION_ORACLE_<module>.md`
2. `REGRESSION_MATRIX_<module>.md`
3. `ACCEPTANCE_RULES.md`

### 7.5 前端专业 artifact

由 `Frontend Specialist Agent` 维护：

1. `FRONTEND_CONSTRAINTS.md`
2. `UI_A11Y_PERF_RULES.md`
3. `THEME_SYSTEM_RULES.md`

### 7.6 Artifact 生命周期规则

每个 artifact 都必须显式携带状态，至少使用以下集合：

1. `active`
2. `superseded`
3. `historical`

默认规则：

1. 新 artifact 创建后默认为 `proposed` 或等价待批准状态，不得自动升格为 `active`
2. 只有 `System Architect Agent` 可以批准系统级 artifact 升格为 `active`
3. 只有对应的 `Module Architect Agent` 可以提议模块级 artifact 升格；最终仍需与 `System Architect Agent` 的 `Authority Map` 对齐
4. 当新 artifact 替代旧 artifact 时，旧 artifact 必须显式降级为 `superseded` 或 `historical`
5. 任何 `historical` artifact 不得被下游角色当作默认 baseline 消费

治理要求：

1. `System Architect Agent` 必须定期或在每个大型 session 结束时审计 `Authority Map`
2. 发现文档冲突时，必须同步更新 `Conflict Register`
3. 发现已废弃 artifact 仍被 active 文档引用时，必须修复引用

---

## 8. 初始化协议（Bootstrap Protocol）

初始化是本系统的第零步，不是附加步骤。

每个持久角色初始化后都必须建立：

1. `Role Memory`
2. `Authority Map`
3. `Boundary Statement`
4. `Escalation Rules`

### 8.0 Progressive Disclosure 规则

初始化必须遵守 progressive disclosure，而不是一次性读取全部相关文档。

每个角色初始化都分为两层：

1. `Mandatory Bootstrap Set`
   - 绝对必读
   - 默认不超过 5 份核心文档或 artifact
   - 目标是建立权威视图，而不是获得全部细节
2. `On-Demand Evidence Set`
   - 只在当前任务确实涉及某个争议点、模块或代码路径时才加载
   - 用于验证、反证或补充，而不是替代 bootstrap set

禁止行为：

1. 初始化时无差别扫完整个仓库文档
2. 把历史文档与 active baseline 混在同一层读取
3. 在没有建立 `Authority Map` 前直接读取大量实现代码

### 8.1 `System Architect Agent` 初始化

`Mandatory Bootstrap Set`：

1. `docs/DEV_STATUS.md` 索引区
2. `docs/product/current/PRD_V2_1_CN.md`
3. `docs/architecture/SYSTEM_ARCHITECTURE.md`
4. `docs/architecture/STYLE_SYSTEM_ARCHITECTURE_CN.md`
5. `docs/context/CLAUDE.md` 中仍然有效的产品/协议约束

`On-Demand Evidence Set`：

1. 当前 active baseline 文档
2. 与争议点相关的少量关键代码证据
3. 与当前任务直接冲突的历史文档

产出：

1. `System Goal Pack`
2. `Authority Map`
3. `Conflict Register`
4. `System Invariants`

### 8.2 `Module Architect Agent` 初始化

`Mandatory Bootstrap Set`：

1. `System Goal Pack`
2. `System Invariants`
3. 当前模块 active docs
4. 当前模块相关 `DEV_STATUS`
5. 目标模块的主要接口或 schema 文档

`On-Demand Evidence Set`：

1. 关键接口代码
2. 关键测试
3. 上下游模块的相关 contract 摘要

产出：

1. `Module Contract Pack`
2. `Module Boundary Map`
3. `Module Dataflow Summary`
4. `Module Workflow Summary`

### 8.3 `Implementation Agent` 初始化

`Mandatory Bootstrap Set`：

1. `System Goal Pack`
2. `Module Contract Pack`
3. `Task Execution Pack`
4. 指定 skills

`On-Demand Evidence Set`：

1. 当前任务相关代码
2. 当前任务相关测试
3. 受影响文件的相邻实现与调用链

产出：

1. `Implementation Scope`
2. `Affected Files Map`
3. `Risk Checklist`
4. `Verification Checklist`

### 8.4 `Verification Agent` 初始化

`Mandatory Bootstrap Set`：

1. `System Goal Pack`
2. `System Invariants`
3. `Module Contract Pack`
4. `Task Execution Pack`
5. 相关验证规则文档

`On-Demand Evidence Set`：

1. 当前代码改动
2. 当前测试改动
3. 关键 validator / gate / protocol 代码路径

产出：

1. `Verification Oracle`
2. `Blocking Conditions`
3. `Regression Scope`
4. `Evidence Checklist`

### 8.5 `Frontend Specialist Agent` 初始化

只在 UI 任务激活时读取。

`Mandatory Bootstrap Set`：

1. `System Goal Pack` 中与 UI/交互相关部分
2. `Module Contract Pack` 中与 UI/交互相关部分
3. 前端规范
4. theme / a11y / perf 规则

`On-Demand Evidence Set`：

1. 当前页面/组件/样式代码
2. 相关 runtime visual contract 代码
3. 相关 UI 测试与快照

产出：

1. `Frontend Constraint Pack`
2. `UI Contract Summary`
3. `A11y/Perf Checklist`
4. `Frontend Risk Notes`

---

## 9. 角色级判断能力

### 9.1 `System Architect Agent` 的核心判断

它不是文档读取器，而是系统级真相裁判者。

它必须判断：

1. 哪部分文档正确
2. 哪部分错误
3. 哪部分与 active baseline 冲突
4. 哪部分虽然代码实现了，但不应升格为设计真理

它的标准输出应包含：

1. `Verdict`
2. `Why`
3. `Impact`
4. `Required Action`

### 9.2 `Module Architect Agent` 的核心判断

它必须判断：

1. 模块输入输出是否完整
2. 模块边界是否清晰
3. 工作流和数据流是否自洽
4. 当前实现偏离了哪些模块 contract

### 9.3 `Implementation Agent` 的核心判断

它必须判断：

1. 当前任务是否有足够上游信息可以实施
2. 当前改动是否越界
3. 当前实现是否需要升级回上游角色

### 9.4 `Verification Agent` 的核心判断

它必须判断：

1. 测试通过是否真的代表 contract 满足
2. 哪些关键路径缺少证据
3. 哪些问题是阻塞性的
4. 哪些问题需要回流到系统/模块层

### 9.5 `Frontend Specialist Agent` 的核心判断

它必须判断：

1. 哪些是 UI 自由度
2. 哪些是语义 contract，绝不能碰
3. 当前 UI 改动是否破坏 runtime / validator / binding 规则

---

## 10. 技能体系映射

### 10.1 `System Architect Agent`

建议主模式：

1. `Inversion`
2. `Reviewer`
3. `Pipeline` 仅作为可选固定审计顺序，不是核心模式

### 10.2 `Module Architect Agent`

建议主模式：

1. `Generator`
2. `Pipeline`
3. `Reviewer`

### 10.3 `Implementation Agent`

建议主模式：

1. `Tool Wrapper`
2. `Pipeline`
3. `Reviewer`
4. `Generator`

### 10.4 `Verification Agent`

建议主模式：

1. `Reviewer`
2. `Tool Wrapper`
3. `Pipeline` 仅作为可选固定检查顺序，不是核心模式

### 10.5 `Frontend Specialist Agent`

建议主模式：

1. `Tool Wrapper`
2. `Reviewer`
3. `Pipeline`
4. `frontend` 作为项目特定的 domain skill，不属于通用的 5 种模式之一

---

## 11. 任务生命周期

### 11.1 标准流程

1. 用户提出任务
2. `Task Orchestrator` 判断是否需要系统层裁决
3. 如果需要，调用 `System Architect Agent`
4. 获取相关 `System Goal Pack` / `Authority Map` / `System Invariants`
5. 调用 `Module Architect Agent`
6. 生成 `Module Contract Pack`
7. `Task Orchestrator` 组装 `Task Execution Pack`
8. 分发给 `Implementation Agent`
9. 如涉及 UI，再叠加 `Frontend Constraint Pack`
10. 实现完成后交给 `Verification Agent`
11. 如果验证失败：
   - 回到实现层修复，或
   - 回流到模块层修文档，或
   - 回流到系统层裁决冲突
12. 如果验证通过：
   - 更新实现
   - 必要时同步回写模块/系统文档

### 11.2 回流规则

1. **实现问题** → 回到 `Implementation Agent`
2. **模块 contract 缺口** → 回到 `Module Architect Agent`
3. **系统级冲突或 baseline 冲突** → 回到 `System Architect Agent`

### 11.3 明确升级触发条件

以下情况必须升级，不能由下游角色自行吞掉：

1. `Implementation Agent` 发现当前代码与 active baseline 或 `Module Contract Pack` 冲突
2. 任意文档变更会影响 `Authority Map` 或 `System Goal Pack` 的结论
3. `Verification Agent` 发现测试通过但 contract 不满足
4. `Verification Agent` 发现关键 failure path 缺证据
5. `Frontend Specialist Agent` 发现视觉方案需要突破模块或系统语义边界
6. 当前任务需要新增系统级 invariant、模块级 contract family、或更改权威层级

### 11.4 升级目标选择

1. 与代码实现范围有关、但不改变 contract 的问题 → 升级到 `Implementation Agent`
2. 输入输出、状态流、工作流、模块边界不清楚 → 升级到 `Module Architect Agent`
3. active baseline 冲突、历史文档误用、系统 invariant 被挑战 → 升级到 `System Architect Agent`

---

## 12. 强制治理规则

### 12.1 下游不可静默改写真相

1. `Implementation Agent` 不能自己重写系统/模块 contract
2. `Verification Agent` 不能因为测试绿了就放弃 contract
3. `Frontend Specialist Agent` 不能用视觉理由突破语义边界

### 12.2 没有 artifact，不允许下游开工

必须至少具备：

1. `System Goal Pack`
2. `Module Contract Pack`
3. `Task Execution Pack`

否则任务应停止并升级。

### 12.3 必须优先传递 artifact，而不是自然语言理解

向下游传递的优先形式应是：

1. 文档摘要
2. contract 列表
3. schema
4. checklist
5. file map

而不是：

1. “我理解大概是这样”
2. “应该差不多”

### 12.4 没有验证证据，不得宣称完成

验证必须能回答：

1. 验证了哪些 contract
2. 用了哪些证据
3. 哪些风险仍然存在

---

## 13. 推荐目录与落地方式

本设计本身先以一份总文档存在。

后续若落地为长期治理体系，建议在 `docs/` 下建立一套**与现有历史文档明确隔离**的 agent 专属目录。

推荐结构如下：

1. `docs/agents/system/`
   - `SYSTEM_GOAL_PACK.md`
   - `SYSTEM_AUTHORITY_MAP.md`
   - `SYSTEM_CONFLICT_REGISTER.md`
   - `SYSTEM_INVARIANTS.md`
2. `docs/agents/modules/`
   - 每个模块一个子目录，维护自己的 contract / boundary / dataflow / workflow
3. `docs/agents/implementation/`
   - implementation patterns、task pack 模板、repo-level coding conventions
4. `docs/agents/verification/`
   - verification oracle、regression matrix、acceptance rules
5. `docs/agents/frontend/`
   - frontend constraints、theme rules、a11y/perf rules
6. `docs/plans/`
   - 保留临时设计稿、审计记录、迁移过程中的工作文档
7. 历史/废弃文档继续留在既有历史位置或明确标注为 historical / deprecated

### 13.0 目录隔离原则

1. agent 专属 artifact 不应与旧计划文档混放
2. `docs/agents/` 存放的是**长期维护、角色拥有、默认可消费**的 artifact
3. `docs/plans/` 存放的是**提案、迁移记录、审计记录、过渡文档**
4. 任何 agent 在初始化时，默认应优先读取 `docs/agents/`，而不是先扫 `docs/plans/`
5. 历史文档必须通过 `Authority Map` 显式降级，且目录结构也应帮助读者一眼区分“长期真相”和“历史过程”

如果暂时无法一次性完成目录迁移，也至少应先建立 `docs/agents/`，让新 artifact 从第一天开始和老文档分区。

### 13.1 初始试点顺序

为避免一次性创建全部 artifact 而重新制造噪声，建议先从当前仓库已有治理基础出发试点：

1. 把 `DEV_STATUS` §0 / 索引区正式收敛为 `System Goal Pack` 与 `Authority Map`
2. 把当前最易出错的核心模块先写成一份 `Module Contract Pack`
3. 把当前人工评审中反复出现的验收规则沉淀成第一版 `Verification Oracle`

这样可以先验证体系有效，再逐步扩展到其他模块与角色。

---

## 14. 成功标准

这套多代理上下文治理体系成功的标志不是“agent 变多”，而是：

1. 每个角色都知道自己该信谁
2. 每个任务都能拿到最小、正确、可追溯的上下文包
3. 历史错误文档不会重新污染 active baseline
4. 下游执行不会静默改写上游真相
5. 代码、文档、验证三者能持续对齐系统最终目标

---

## 15. 最终结论

对当前项目而言，最值得长期建设的不是“更多会说话的 agent”，而是：

**一套由持久角色维护、由权威 artifact 承载、由任务编排器裁剪上下文、并由验证层强制闭环的上下文治理系统。**

这个系统的本质不是 agent orchestration，而是：

**truth ownership + artifact governance + contract-preserving execution**
