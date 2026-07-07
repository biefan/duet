---
description: XL 级任务的多智能体编排火力档——并行探查 / 多维度审计+对抗验证 / 多方案评审。重、耗 token,只给单上下文吃不下的活用;日常任务走 /duet:clean-loop。
argument-hint: "<任务:探清 X / 审计 Y / 评审 Z 的方案>"
allowed-tools: Read, Grep, Glob, Agent, Workflow, TaskCreate, TaskUpdate
---

你在执行 **duet swarm**:用多智能体编排啃 XL 级任务。任务:`$ARGUMENTS`

## 第 0 步 · 值不值得上 swarm(先拦一道)
- 单上下文能吃下的活(≤ 几个文件、一个模块)→ **别用**,直接说"这个规模走 /duet:clean-loop 更省",然后停。
- 值得上的:大范围审计 / 全库排查 / 跨模块理解 / 多方案权衡 / 迁移清单。
- 开跑前用一两句话告知用户大致规模(几个阶段、约几个子代理),不用等确认——命令本身就是授权。

## 第 1 步 · 先侦察,再编排
主线程先花少量动作探清"工作清单"(哪些目录 / 文件 / 维度 / 候选方案),编排步骤要在已知形状上跑,不要盲目撒代理。

## 第 2 步 · 选模式并执行(用 Workflow 工具;不可用时退化为并行 Agent 子代理)
按任务形状选一种,脚本骨架照抄后按需改:

**explore(并行探查→汇总地图)**:按目录/子系统分片,每片一个只读读者,最后一个综合者拼"结构地图 + 关键调用链 + 风险点"。
```
phase('Explore')
const maps = await parallel(chunks.map(c => () =>
  agent(`只读探清 ${c}:结构/关键调用链/坑,返回要点`, {phase: 'Explore'})))
phase('Synthesize')
return agent(`综合成一张地图:${JSON.stringify(maps.filter(Boolean))}`)
```

**review(多维度找→逐条对抗验证)**:维度 = 正确性/边界/并发/安全/性能…;每条发现派独立怀疑者去**推翻**,多数推翻则丢弃。用 pipeline,别加不必要的 barrier。
```
const results = await pipeline(DIMENSIONS,
  d => agent(`审计维度 ${d}:只报确凿问题+复现`, {phase: 'Find', schema: FINDINGS}),
  r => parallel(r.findings.map(f => () =>
    agent(`对抗验证,默认不成立:${f.title}`, {phase: 'Verify', schema: VERDICT})
      .then(v => ({...f, real: v.isReal})))))
```

**design(N 方案→评审团→综合)**:3 个不同切入角(MVP 优先 / 风险优先 / 一致性优先)独立出方案,评审团打分,综合胜者并嫁接其余亮点。

## 红线
- **swarm 全程只读**:产出是报告 / 地图 / 方案,不改代码。要落地改动 → 回 clean-loop 走正常循环。
- 结果按严重度 / 优先级列给用户,修不修用户定。
- 有截断就说明(扫了哪些、没扫哪些),别让"跑完了"读成"覆盖全了"。
- 汇报进度用 log(),别让用户对着转圈猜。
