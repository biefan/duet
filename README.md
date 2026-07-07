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

## 每个项目跑一次

```
/duet:init
```

建 git 仓库(如需)+ 写默认 `.gitignore`(`__pycache__/`、`*.py[cod]` 等运行时产物 + duet 自身运行时文件)。

## 用起来:平时只记 2 个命令

| 命令 | 什么时候 | 干嘛 |
|---|---|---|
| `/duet:clean-loop` | 开工 | 探清 → 规划 → 小步实现 → 每步验证 → 收拾 → 交 Codex 独立复审 的完整循环 |
| `/duet:ship` | 收工 / 提交前 | 收拾 + 验证(要真证据)+ 确认看过 diff + 提示 Codex 复审 + 记下一步 |

卡住 → `/codex:rescue "具体任务"` 让 GPT-5.5 救场。

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
tests/run.sh                      # 离线回归(stdin 模拟钩子输入,57+ 断言)
```

## 开发

```
bash tests/run.sh
```
改任何 hook 脚本后必跑;全部用 stdin JSON 模拟钩子输入,离线、无副作用(临时目录内)。

## 状态

v0.6.1 —— 经真项目 demo、深度对抗测试、多轮 Codex(GPT-5.5)只读独立复审加固(修掉不可信仓库 RCE、路径引号、init/门禁的 git 顶层定位等真问题);含 planner / verifier 子代理、长时间工作与项目记忆支持(残留检测 / compact 自检 / journal / 过期标注),回归测试已固化进 `tests/run.sh`。
