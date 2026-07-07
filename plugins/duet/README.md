# duet

Claude × Codex(GPT-5.5)双引擎、低疲劳的干净开发工作流。

**一句话用途**:让每天写代码不那么累 —— 代码写出来就干净(auto-tidy + clean-loop)、卡住不硬扛(codex rescue)、收工前有门禁不放漏(ship + codex review)、跨会话不丢线(next.md)。

## 装一次
```
/plugin marketplace add /root/duet
/plugin install duet@duet-marketplace
```
更新:`/plugin marketplace update duet-marketplace`(或改源后 `/reload-plugins`)。
装一次即全局可用,**所有项目自动生效,不用每个项目再装**。

## 触发速查(只有 2 个要手动,其余全自动)
| 能力 | 怎么触发 | 用途 |
|---|---|---|
| `/duet:clean-loop` | 手动打,或接任务时自动匹配 | 先分诊 S/M/L/XL 动态伸缩:探清→规划→选引擎(Claude 或整段派 Codex)→小步写→每步验证→收拾→复审 |
| `/duet:ship` | 手动打(做完/收工/提交前) | 收工门禁:收拾+验证+确认看过 diff+提示 Codex 复审+记下一步 |
| `/duet:swarm` | 手动打(XL 级任务) | 多智能体编排:并行探查 / 多维审计+对抗验证 / 多方案评审(只读、重火力) |
| auto-tidy | 全自动(改完文件即触发) | 自动格式化,乱不过夜 |
| 收工连续性 | 全自动(每次开会话) | 顶出上次的 `.duet/next.md`(>14 天标"可能过时");新会话开场检测上次残留的未提交改动;compact 后提示自检任务状态 |
| 轻提醒 | 全自动(该收工还没 ship 时) | 有未提交代码改动就戳一下(每会话仅一次;仅在用过 duet 的项目,即 `.duet/` 存在) |

配合 codex:
- 卡住 / 第二实现 / 深挖根因 → `/codex:rescue "具体任务"`(GPT-5.5,YOLO)
- 收工前独立查缺陷 → `/codex:review`
- 质疑设计对不对 → `/codex:adversarial-review "关注点"`

## 一天怎么用
1. **开会话** → duet 自动顶出上次的"下一步",立刻知道从哪接。
2. **接任务** → `/duet:clean-loop`(或直接描述,自动上)→ 一步步干,改文件时 auto-tidy 自动收拾。
3. **卡住** → `/codex:rescue "..."` 让另一个引擎救场(在干净分支/worktree)。
4. **做完 / 收工前** → `/duet:ship`:逼你收拾干净、真验证、亲眼看过 diff、跑 `/codex:review`、把下一步写进 `.duet/next.md`。
5. **忘了 ship 就想走** → Stop 轻提醒戳一下(不烦)。
6. 下次开会话 → 回到第 1 步,无缝接上。

## 在一个项目里用(一条命令搞定)
duet 全局生效,但下列能力**依赖 git**(看 diff、YOLO worktree 隔离),且 **Stop 轻提醒只在跑过 init 的项目里生效**(以 `.duet/` 存在为准,不向别的仓库写文件)。每个项目跑一次即可:

```
/duet:init
```
它幂等地:建 git 仓库(如需)+ 写入 duet 默认 `.gitignore`(`__pycache__/`、`*.py[cod]`、`.pytest_cache/` 等运行时产物 + duet 自身运行时文件)+ 建 `.duet/.gitignore`。
格式化交给内置检测:auto-tidy 按后缀自动跑项目自带的 prettier / ruff / rustfmt / gofmt(它们会读你项目的 `.prettierrc` / `ruff.toml` 等配置),没有就静默跳过。出于安全,auto-tidy **不执行仓库内任意脚本**。

**例:加一个新功能**
```
/duet:clean-loop 给用户模块加登录限流
  → 探清相关代码 → 规划结构 → 小步实现(auto-tidy 自动收拾)→ 每步验证
  → 卡住就 /codex:rescue "..."
/duet:ship 重点看限流边界
  → 收拾 + 验证边界 + 看 diff + /codex:review + 记下一步到 .duet/next.md
```

## 组件
| 文件 | 触发点 | 说明 |
|---|---|---|
| `skills/clean-loop/SKILL.md` | `/duet:clean-loop` | 工作流大脑 |
| `agents/planner.md` | 大任务动手前(可自动委派) | 独立上下文出结构方案 + 验证 handle(只读) |
| `agents/verifier.md` | 声称完成后 | 全新上下文独立验收:跑测试、打边界、PASS/FAIL |
| `commands/ship.md` | `/duet:ship` | 收工门禁 |
| `commands/swarm.md` | `/duet:swarm` | XL 级多智能体编排(explore / review / design 三模式,只读) |
| `commands/init.md` | `/duet:init` | 项目一次性设置:git + 默认 gitignore(含 `__pycache__`)+ 运行时忽略 |
| `scripts/auto-tidy.sh` | PostToolUse(Write\|Edit) | 按后缀自动检测 prettier/ruff/rustfmt/gofmt(不执行仓库内脚本) |
| `scripts/session-start.sh` | SessionStart | 顶出 `.duet/next.md`(过期标注)+ 开场残留改动检测 + compact 后自检提示 |
| `scripts/stop-remind.sh` | Stop | 未提交代码改动时提醒一次(非阻断;仅 `.duet/` 存在的项目) |

## `.duet/` 目录约定(在你的项目里,不在插件里)
整个目录都是运行时状态,由 `.duet/.gitignore`(内容 `*`)整体自忽略,不进 diff / 提交:
- `next.md` —— "下一步",每次 ship 收尾覆写,开会话自动顶出(>14 天标"可能过时")
- `journal.md` —— 追加式工作日志(日期 / 做了什么 / 怎么验证 / 踩的坑),项目记忆,不注入上下文、需要时自己查
- `.reminded-sessions` / `.last-remind` —— 提醒去重 / 节流记录

## 最省心的记法
平时只管 **`/duet:clean-loop` 开工、`/duet:ship` 收工**,中间卡住 `/codex:rescue`,剩下的 duet 自动兜着。
