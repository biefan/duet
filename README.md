# duet

> Claude × Codex(GPT-5.5)双引擎、低疲劳的干净开发工作流 · Claude Code 插件

写代码累,大多不是活多,是**乱代码引发的返工 / 救火**,和**事情没关上**。duet 把这两点掐断:代码写出来就干净、卡住不硬扛、收工前有门禁不放漏、跨会话不丢线。

duet 本身不写代码——写代码的是 Claude Code + Codex,duet 是套在上面的**工作流 / 纪律层**。

## 安装

```
/plugin marketplace add biefan/duet
/plugin install duet@duet-marketplace
```

依赖:[Claude Code](https://claude.com/claude-code);独立复审 / 卡住救场需要 [codex 插件](https://github.com/openai/codex-plugin-cc)(GPT-5.x)。

**codex 必须开 YOLO**,否则 rescue / 整段派活会卡在等审批,干不了活。`~/.codex/config.toml`:

```toml
approval_policy = "never"
sandbox_mode = "danger-full-access"
```

安全不靠审批闸,靠 duet 的护栏:派活前切干净分支 / worktree、泡完亲眼看 diff、verifier 独立验收。`/duet:init` 会自动体检这项配置并给出改法(只检查,不代改)。

## 每个项目跑一次

```
/duet:init
```

建 git 仓库(如需)+ 写默认 `.gitignore`(`__pycache__/`、`*.py[cod]` 等运行时产物 + duet 自身运行时文件)。

## 用起来:平时只记 2 个命令

| 命令 | 什么时候 | 干嘛 |
|---|---|---|
| `/duet:clean-loop` | 开工 | 分诊 S/M/L/XL 动态伸缩:探清 → 规划 → 选引擎 → 小步实现 → 每步验证 → 收拾 → 独立复审 |
| `/duet:ship` | 收工 / 提交前 | 收拾 + 验证(要真证据)+ 确认看过 diff + 提示 Codex 复审 + 记下一步 |

卡住 / 想整段派活 → `/codex:rescue "具体任务"` 让 GPT-5.5 上;XL 级审计/探查 → `/duet:swarm`。

三个钩子全自动:改完文件**自动格式化**、开会话**顶出上次的下一步**、有未提交改动**轻提醒**去 ship。

> 详细用法见 [`plugins/duet/README.md`](plugins/duet/README.md)。

## 设计原则

- **双引擎独立复审**:同一个模型审自己有盲区,换个引擎(Codex / GPT-5.5)能兜住。
- **低疲劳**:卡住不硬扛(交给 Codex)、乱不过夜(自动收拾)、开放循环不过夜(收工续线)。
- **KISS / 安全**:只跑内置格式化器、**不执行仓库内任意脚本**;提醒非阻断,不烦人。

## 结构

```
.claude-plugin/marketplace.json   # marketplace 清单
plugins/duet/                     # 插件本体
├── skills/clean-loop/            # /duet:clean-loop —— 工作流大脑
├── commands/                     # /duet:ship  /duet:init
├── agents/                       # duet-planner(出方案) / duet-verifier(独立验收)
├── hooks/hooks.json              # PostToolUse / SessionStart / Stop
└── scripts/                      # auto-tidy / session-start / stop-remind / duet-init
codex-skills/                     # Codex CLI 侧镜像(duet-clean-loop / duet-ship)
tests/run.sh                      # 离线回归(stdin 模拟钩子输入,70+ 断言)
```

## 在 Codex CLI 里安装(可选)

duet 的核心工作流有一份 Codex 镜像(`codex-skills/`),装进 Codex CLI 的 skills 目录即可用。要求 Codex CLI 支持 `~/.codex/skills`(0.142+ 验证过)。

**方式 A · 不 clone,直接下载(推荐)**

```bash
mkdir -p ~/.codex/skills/duet-clean-loop ~/.codex/skills/duet-ship
curl -fsSL https://raw.githubusercontent.com/biefan/duet/master/codex-skills/duet-clean-loop/SKILL.md -o ~/.codex/skills/duet-clean-loop/SKILL.md
curl -fsSL https://raw.githubusercontent.com/biefan/duet/master/codex-skills/duet-ship/SKILL.md -o ~/.codex/skills/duet-ship/SKILL.md
```

**方式 B · 已 clone 本仓库**

```bash
mkdir -p ~/.codex/skills && cp -r codex-skills/duet-clean-loop codex-skills/duet-ship ~/.codex/skills/
```

**验证**:`ls ~/.codex/skills/` 应出现 `duet-clean-loop` 和 `duet-ship`;新开 Codex 会话生效。

**怎么用**:不用记命令——接到实现类任务(feature / fix / refactor)Codex 会按 description 自动匹配 `duet-clean-loop`;收工 / 提交前说"走 duet-ship 收工门禁"即可。也可在提示里直接点名 skill。

**更新 / 卸载**:更新 = 重跑安装命令覆盖;卸载 = 删掉 `~/.codex/skills/` 下这两个目录。

两边共用项目里的 `.duet/` 约定:Codex 收工写的 `next.md`,回到 Claude Code 开会话自动顶出来,跨引擎不丢线;复审方向反转(Codex 写的交 Claude 审)。Codex 侧没有 hooks,自动格式化 / 开会话顶线 / 收工提醒仍是 Claude Code 侧专属。

## 开发

```
bash tests/run.sh
```
改任何 hook 脚本后必跑;全部用 stdin JSON 模拟钩子输入,离线、无副作用(临时目录内)。

## 状态

v0.8.0 —— 长时间工作断点(`.duet/next.md` 作活状态文件,每片 checkpoint,断会话/compact 随时接上)+ 派活纪律(子代理简报五要素、结果含糊重派、主线程耐心等待不空转)。此前:动态工作流(分诊 S/M/L/XL 伸缩 + `/duet:swarm` 多智能体编排)+ 双引擎角色互换(Codex 可整段接实现)+ Codex CLI 侧镜像(共用 `.duet/` 跨引擎续线);更早:多轮 Codex(GPT-5.5)复审加固(RCE、路径引号、git 顶层定位等真问题)、planner / verifier 子代理、长时间工作与项目记忆(残留检测 / compact 自检 / journal / 过期标注)、回归测试固化于 `tests/run.sh`。
