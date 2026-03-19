# Debug Agent and Flow Map Design

**Date:** 2026-03-19  
**Status:** Approved  
**Scope:** 为当前多代理治理体系补充 `Debug Agent` 角色，以及跨模块场景图 / 模块 canonical workflow-dataflow 图的长期 truth 体系

---

## 1. 背景

当前体系已经有：

1. `System Architect Agent`
2. `Module Architect Agent`
3. `Implementation Agent`
4. `Verification Agent`
5. `Frontend Specialist Agent`
6. `Task Orchestrator`

但仍缺少一条稳定的 bug 主线。

现实问题是：

1. bug 经常从日志和截图开始，但没有固定角色先做 root-cause analysis
2. session 往往需要重新读代码和旧文档，重复重建系统如何工作的理解
3. 模块虽然有 contract / boundary / workflow / dataflow 文档，但还缺少一眼可定位的跨模块总图与可下钻 canonical 图
4. bug 很容易被当成单点事故修掉，而没有上升到“这类问题为什么会在系统里出现”

因此，需要补两件事：

1. 一个独立的 `Debug Agent`
2. 一组长期维护的 `Flow Map` artifact family

---

## 2. 设计目标

本设计的目标是：

1. 让每一个 bug 都必须先经过 root-cause analysis，再允许进入实现
2. 让任何 session 都能先看跨模块总图，再下钻到模块 canonical 图，而不是重新海量读代码
3. 让 `Debug Agent` 能从触发步骤、输入参数、日志、报错栈反推出模块链、workflow hop、dataflow hop、文件和函数
4. 让 bug 不仅能被修复，还能在必要时上升为系统级 bug class 与 recurrence prevention knowledge

---

## 3. 非目标

本设计不追求：

1. 新增一个负责写代码的 debug 角色
2. 新增一个独立常驻的 `Flow Trace Agent`
3. 让每个 bug 都被强行抽象为 bug class
4. 用自动生成的技术调用图代替系统级和模块级 truth

---

## 4. 核心原则

### 4.1 每个 bug 都必须先经过 `Debug Agent`

bug 主线固定为：

1. `System Architect`
2. `Module Architect`
3. `Debug Agent`
4. `Implementation`
5. `Verification`

没有 `DEBUG_CASE` 和 root cause，不得开始实现。

### 4.2 `Debug Agent` 负责根因定位，不负责直接实现

`Debug Agent` 的职责是：

1. 建立复现上下文
2. 沿场景图和模块图定位问题路径
3. 输出 root cause、证据链、修复范围、验证目标
4. 判断是否值得上升为 bug class

它不直接写代码，不改 system truth，不改 module contract。

### 4.3 `Flow Trace` 是能力层，不是常驻角色

本设计不新增独立的 `Flow Trace Agent`。

`Flow Trace` 由两部分组成：

1. 上游 truth artifact
   - `System Scenario Map`
   - `Module Canonical Workflow`
   - `Module Canonical Dataflow`
2. 下游动态 tracing
   - `Debug Agent` 在 debug 任务中读取这些图，并结合日志和代码执行动态 trace

### 4.4 不是每个 bug 都必须 promotion

所有 bug 都必须完成 `incident closure`：

1. `DEBUG_CASE`
2. root cause
3. 修复范围
4. 至少一条 recurrence prevention

但只有 `Debug Agent` 判断“值得系统长期记住”时，才 promotion 到：

1. `BUG_CLASS_REGISTER`
2. `RECURRENCE_PREVENTION_RULES`

promotion 不是规则表自动决定，而是 `Debug Agent` 判断并写明理由。

### 4.5 图必须是动态 truth，而不是静态说明材料

所有 `Flow Map` 都必须随真实代码变化更新。

如果图与代码不一致：

1. 不能继续作为默认 truth 使用
2. 必须记录并回流修订

---

## 5. `Debug Agent` 角色定义

### 5.1 使命

`Debug Agent` 是系统级故障治理角色。

它的核心目标不是“找到一个报错点”，而是：

1. 把一次故障定位到具体场景和模块链
2. 把一次故障下钻到具体 workflow/dataflow hop
3. 在必要时把一次 bug 上升为一类 bug
4. 推动 recurrence prevention，而不是只做一次性修补

### 5.2 标准输入

每次 debug 任务至少要有：

1. 触发步骤
2. 输入参数或用户动作
3. 实际现象
4. 期望现象
5. 日志、截图、报错栈、请求样本之一

### 5.3 标准输出

`Debug Agent` 每次必须交付：

1. `Bug Reproduction Summary`
2. `Scenario Path`
3. `Suspect Module Chain`
4. `Workflow/Dataflow Trace`
5. `Root Cause`
6. `Evidence`
7. `Recommended Fix Scope`
8. `Verification Targets`
9. `Promotion Decision`
10. `Promotion Reason`

### 5.4 与现有角色的关系

1. `System Architect`
   - 提供 authority、invariants、冲突裁决
2. `Module Architect`
   - 提供模块级静态 truth 与 canonical 图
3. `Debug Agent`
   - 用真实输入和日志把静态 truth 映射到故障路径
4. `Implementation Agent`
   - 只在 root cause 明确后修复
5. `Verification Agent`
   - 修复后验证 contract 是否恢复

---

## 6. Flow Map Artifact Family

本设计采用双层结构。

### 6.1 `System Scenario Map`

这是跨模块端到端总图。

每个 scenario map 至少包含：

1. `Scenario Name`
2. `Entry Trigger`
3. `Module Chain`
4. `Cross-Module Hops`
5. `Failure Points`
6. `Drilldown Links`

它回答的是：

1. 一个关键场景从哪里开始
2. 经过哪些模块
3. 哪些模块之间有关键 handoff
4. 出问题时应先看哪条路径

### 6.2 `Module Canonical Workflow`

这是模块内部步骤真图。

每张图至少包含：

1. `Entry Points`
2. `Ordered Steps`
3. `Decision Gates`
4. `Failure Semantics`
5. `Code Links`

它回答的是：

1. 模块内部按什么顺序工作
2. 在哪些节点会分叉、fallback、retry 或 fail
3. 关键步骤对应哪些文件和函数

### 6.3 `Module Canonical Dataflow`

这是模块内部数据真图。

每张图至少包含：

1. `Inputs`
2. `Transforms`
3. `Intermediate Artifacts`
4. `Outputs`
5. `Code Links`

它回答的是：

1. 输入从哪里进入
2. 在哪里发生转换
3. 中间 artifact 有哪些
4. 输出交给谁

### 6.4 必须支持图到代码的回链

每个关键节点都必须至少带：

1. `ownerModule`
2. `filePath`
3. `functionName` 或 `entryName`
4. `artifactName`（如果是数据节点）
5. `relatedTests`（可选但推荐）

没有代码回链的图只能算说明图，不能算 debug truth。

---

## 7. Artifact Ownership

### 7.1 `docs/agents/system/`

由 `System Architect Agent` 拥有：

1. `SYSTEM_SCENARIO_MAP_INDEX.md`
2. `scenarios/<scenario>.md`

### 7.2 `docs/agents/modules/<module>/`

由 `Module Architect Agent` 拥有：

1. `MODULE_CONTRACT.md`
2. `MODULE_BOUNDARY.md`
3. `MODULE_DATAFLOW.md`
4. `MODULE_WORKFLOW.md`
5. `MODULE_CANONICAL_WORKFLOW.md`
6. `MODULE_CANONICAL_DATAFLOW.md`

### 7.3 `docs/agents/debug/`

由 `Debug Agent` 拥有：

1. `AGENT_SPEC.md`
2. `DEBUG_BOOTSTRAP_PACK.md`
3. `DEBUG_CASE_TEMPLATE.md`
4. `BUG_CLASS_REGISTER.md`
5. `RECURRENCE_PREVENTION_RULES.md`
6. `cases/YYYY-MM-DD-<topic>.md`

Debug 目录不拥有系统总图和模块 canonical 图；它只消费这些图。

---

## 8. `Debug Agent` 标准流程

### Step 0. 接收触发信息

先固定：

1. 触发步骤
2. 输入 / 动作 / 环境
3. 实际现象
4. 期望现象
5. 证据

### Step 1. 建立 `DEBUG_CASE`

在读代码前，先把本次事件落盘成 case。

### Step 2. 选中 `System Scenario Map`

根据触发路径选场景总图，产出：

1. `Scenario Path`
2. `Suspect Module Chain`

### Step 3. 下钻 `Module Canonical Workflow/Dataflow`

对 suspect module chain 中的模块逐个下钻，标出：

1. 输入进入点
2. 关键转换点
3. decision gate
4. 下游 handoff 点
5. failure 点

### Step 4. 回链到文件 / 函数 / 代码路径

只读命中节点的相关代码和测试，而不是海量扫代码。

### Step 5. 建立 `Workflow/Dataflow Trace`

沿图模拟一次真实输入路径，标出偏离点。

### Step 6. 输出 root cause

root cause 必须说明：

1. 哪个 hop 失败
2. 为什么失败
3. 违反了哪个 contract / invariant / flow assumption
4. 是单点 defect，还是 pattern defect

### Step 7. 做 promotion decision

`Debug Agent` 必须输出：

1. `promoted` / `not_promoted`
2. 理由
3. 影响范围
4. 是否需要更新图、contract、invariant 或 guardrail

### Step 8. 交给实现与验证

只有这时才允许：

1. `Implementation Agent` 修复
2. `Verification Agent` 验证
3. 必要时回写 flow map 和 debug knowledge

---

## 9. Debug Closure Rules

### 9.1 `Incident Closure`

所有 bug 都必须达到：

1. `DEBUG_CASE`
2. root cause
3. 修复范围
4. 至少一条 recurrence prevention

### 9.2 `Class Promotion`

是否 promotion，由 `Debug Agent` 判断并给出理由。

不是每个 bug 都必须进入 `BUG_CLASS_REGISTER`。

例如：

1. 单点参数错误、局部 wiring、单 route 配置错误
   - 可以只做 `incident closure`
2. 暴露系统性 failure pattern、跨模块 drift、guardrail 缺失
   - 应 promotion

### 9.3 阻塞关闭权

`Debug Agent` 拥有以下阻塞关闭权：

1. 没有 `DEBUG_CASE`，bug 不得开始实现
2. 没有 root cause，bug 不得宣称修复完成
3. 如果 `Debug Agent` 判定需要 flow map / contract / guardrail 更新，而这些更新未完成，bug 不得宣称完全关闭

---

## 10. 对现有治理体系的影响

### 10.1 角色体系更新

现有体系更新为：

1. `System Architect Agent`
2. `Module Architect Agent`
3. `Debug Agent`
4. `Implementation Agent`
5. `Verification Agent`
6. `Frontend Specialist Agent`
7. `Task Orchestrator`

### 10.2 bug 主线更新

bug 任务的强制顺序变为：

1. `System`
2. `Module`
3. `Debug`
4. `Implementation`
5. `Verification`

### 10.3 动态维护要求

1. 关键模块改动后，必须同步更新模块 canonical 图
2. 关键跨模块场景变化后，必须同步更新 `System Scenario Map`
3. 如果 debug 发现图和代码不一致，这本身就是需要回流修复的问题
4. verification 不仅验证代码，也验证必要的 truth artifact 是否同步

---

## 11. 推荐的首批落地范围

优先落地以下内容：

1. `docs/agents/debug/` 最小 bootstrap
2. `docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md`
3. 至少一张跨模块场景图
   - 推荐先覆盖 `Step2 -> Step3 style generation and deploy`
4. 至少一个模块的 canonical 图
   - 推荐先覆盖 `style-generation` 相关模块
5. `SKILLS.md` 的 bug 启动顺序更新为 `System -> Module -> Debug -> Implementation -> Verification`

---

## 12. 结论

本设计把 bug 治理从：

1. 看到报错
2. 猜一个地方
3. 改一下
4. 再试

升级为：

1. 先建 case
2. 先定场景
3. 再定模块链
4. 再定 workflow/dataflow hop
5. 再定位文件和函数
6. 再判断是单点事故还是系统性 defect
7. 再进入实现与验证

它新增的不是一个“会修 bug 的 coding agent”，而是一条面向系统级根因治理的 bug 主线，以及一组可长期维护的 flow truth artifact。
