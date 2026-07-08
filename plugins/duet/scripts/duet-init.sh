#!/usr/bin/env bash
# duet · init —— 给当前项目做一次性设置(幂等,可重复跑):
#   1) git 仓库(如需)
#   2) git 顶层 .gitignore 的 duet 块:默认忽略 __pycache__ 等运行时产物 + duet 自身运行时文件
#   3) <git 顶层>/.duet/.gitignore:duet 运行时文件自忽略
set -uo pipefail

# 1) git 仓库
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "duet:init  → 已是 git 仓库"
else
  git init -q && echo "duet:init  → git init 完成"
fi

# 定位 git 顶层(避免在子目录里写错 .gitignore)
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# 2) 顶层 .gitignore 的 duet 块(用 marker 保证幂等)
gi="$root/.gitignore"
if grep -q '>>> duet >>>' "$gi" 2>/dev/null; then
  echo "duet:init  → .gitignore 已有 duet 块,跳过"
else
  {
    printf '\n# >>> duet >>> (duet 默认忽略:运行时产物,勿手改此块)\n'
    printf '.duet/\n'
    printf '__pycache__/\n*.py[cod]\n.pytest_cache/\n.mypy_cache/\n.ruff_cache/\n'
    printf '.DS_Store\n'
    printf '# <<< duet <<<\n'
  } >> "$gi"
  echo "duet:init  → 写入 $gi 的 duet 块(含 __pycache__ / *.pyc / .pytest_cache 等)"
fi

# 3) <root>/.duet/.gitignore(duet 运行时文件自忽略)
# 统一写 "*":自动覆盖以后新增的运行时文件(如 journal.md);每次覆写,顺带升级旧版的逐文件列表
mkdir -p "$root/.duet" 2>/dev/null || true
printf '*\n' > "$root/.duet/.gitignore"
echo "duet:init  → 写 $root/.duet/.gitignore(*)"

# 4) codex YOLO 体检(只检查不改配置)——duet 的 rescue / 整段派活依赖无审批模式,否则卡在等审批干不动
cfg="$HOME/.codex/config.toml"
if [ -f "$cfg" ]; then
  if grep -qE '^[[:space:]]*approval_policy[[:space:]]*=[[:space:]]*"never"' "$cfg" && grep -qE '^[[:space:]]*sandbox_mode[[:space:]]*=[[:space:]]*"danger-full-access"' "$cfg"; then
    echo "duet:init  → codex YOLO 已配置(approval_policy=never + danger-full-access)"
  else
    echo "duet:init  ⚠ codex 未开 YOLO——rescue/整段派活会卡审批。到 ~/.codex/config.toml 设:"
    echo '             approval_policy = "never"'
    echo '             sandbox_mode = "danger-full-access"'
    echo "             (安全由 duet 护栏兜:干净分支/worktree + 亲眼看 diff + verifier 验收)"
  fi
else
  echo "duet:init  → 未检测到 codex(~/.codex/config.toml);双引擎能力需先装 Codex CLI"
fi

echo "duet:init  ✓ 完成。日常:/duet:clean-loop 开工,/duet:ship 收工。"
