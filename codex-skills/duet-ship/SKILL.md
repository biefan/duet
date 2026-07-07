---
name: "duet-ship"
description: "Use before declaring a coding task done, committing, or wrapping up a session: the duet ship gate — tidy the diff, verify with real evidence (not claims), make sure a human eyeballed the diff, get an independent cross-engine review, then record next steps in .duet/. Triggered by 收工 / ship / 提交前 / done."
---

# duet · 收工门禁(Codex 镜像版)

目标:这段改动做到"干净 + 真验证过 + 人看过 diff + 被独立复审过"才算完。按顺序走,别跳步、别提前宣布完成。

## 1 · 收拾(乱不过夜)
自审当前 diff:命名、结构、拆 >~300 行文件、去过度设计、删与本次任务无关的改动。最终 diff 只留本次任务内容。

## 2 · 验证(要真证据,不是剧场)
- 跑测试 / 真实流程,**关键输出原样贴出来**——不是"跑起来了""应该没问题"。
- 别只走 happy path:主动打边界 / 空态 / 异常 / off-by-one / 罕见分支。AI 生成的测试常只验证了它自己的实现,测试过 ≠ 对。
- 不能被验证的改动 = 没做完;缺验证手段就先建一个。

## 3 · 人看过 diff(不能跳)
明确问用户:**这份 diff 你亲眼看过了吗?** 没看过就把 `git diff` 摆出来,等确认再往下。没人看过的 diff 不算 ship。

## 4 · 跨引擎独立复审(方向反转)
这份 diff 是你(Codex/GPT)写的,自己审自己有盲区。建议用户:
- 回 Claude Code 让 Claude 独立复审(其 duet 插件的 `/duet:ship` / `/code-review` 会做);
- 或至少开一个全新 Codex 会话,只给 diff 和验证 handle,无偏见地独立验收。
复审结果按严重度列给用户,修不修用户定;"另一个引擎说没问题"也只是第一遍,不是证明。

## 5 · 收尾(与 Claude 侧共用 .duet/ 约定)
- git 顶层 `.duet/next.md`:覆写"下一步 / 明天第一件事"(一两行)+ 未完成的跨文件工作。Claude Code 侧开会话会自动顶出来。
- `.duet/journal.md`:末尾追加一条工作日志(日期 / 做了什么 / 怎么验证 / 踩的坑)。
- 抓到"可复发类"真问题别只修一处——把教训固化进 AGENTS.md / 项目规则,以后自动受益。
- 然后收工,别把开放循环带过夜。
