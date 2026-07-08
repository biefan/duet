---
name: "duet-clean-loop"
description: "Use when implementing code changes (feature / fix / refactor / multi-file / unfamiliar module): the duet clean development loop — triage S/M/L first, then explore → plan structure → small verifiable steps → verify each step with real evidence → tidy → independent review. Skip for one-liner changes (typo, single log line, pure rename)."
---

# duet · 干净开发循环(Codex 镜像版)

目的:代码写出来就干净、每步可验,掐断"乱代码返工循环"和"事情没关上"。与 Claude Code 侧的 duet 插件共用 `.duet/` 约定,两个引擎接力不丢线。

**双记忆兼容**:duet 里 Claude 为主、你(Codex)为辅;你的私有记忆与 AGENTS.md / 项目 `.duet/` 等共享层冲突时,以共享层为准。

## 先分诊(流程按任务伸缩)
- **S** 一句话说清、单点低风险 → 直接改 + 顺手验证,不套循环。
- **M** 单文件 / 小范围、目标清晰 → 简版:快速探清 → 定验证 handle → 小步写 → 验证 → 收拾。
- **L** 跨多文件 / 不熟模块 / 高风险 → 完整循环(下)。
拿不准升一级;干着发现范围变大,当场升级。

## 循环(L 级)
1. **探清**:读清任务边界 + 相关代码 / 调用链,别拿孤立片段就改。
2. **规划**:动手前定下文件划分 / 关键命名 / 函数签名 + **验证 handle**(哪个测试 / 命令 / 输出能证明"做完");没有验证方式就先建一个。
3. **小步实现**:一次一小片、每片独立可验;跟现有风格一致;KISS / DRY / YAGNI,不加没用的抽象层。
4. **每步验证**:立即跑测试 / 真实流程,**贴原始输出当证据,不说"应该没问题"**;主动打边界 / 空态 / 异常 / off-by-one——测试过 ≠ 对。
5. **收拾**:命名、结构、拆 >~300 行文件、删与任务无关的改动;最终 diff 只留本次任务内容。

## 独立复审(双引擎,方向反转)
你(Codex/GPT)写的代码,盲区要靠**另一个引擎**看:收工前建议用户回 Claude Code 让 Claude 复审这份 diff(它的 `/duet:ship` 门禁会做),或至少开一个全新无偏见的会话按验证 handle 独立验收。自己审自己不算数。

## 长时间任务:next.md 当活状态文件
L 级 / 多小时任务,每完成一片就顺手覆写 git 顶层 `.duet/next.md`:"做到哪 / 下一片 / 验证 handle"(两三行)。断会话随时能接上,换到 Claude Code 侧也能接——两边共用这份状态。

## 收尾(乱不过夜)
- 把"下一步 / 明天第一件事"写进 git 顶层的 `.duet/next.md`(一两行,覆写);未完成的跨文件工作记进"未完成"区。Claude Code 侧开会话会自动顶出来。
- 往 `.duet/journal.md` 末尾**追加**一条(3-5 行):日期、做了什么、怎么验证的、踩的坑。
- `.duet/` 整目录是运行时状态,已由 `.duet/.gitignore`(`*`)自忽略,不进提交。
