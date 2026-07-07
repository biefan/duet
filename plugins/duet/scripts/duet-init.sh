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

echo "duet:init  ✓ 完成。日常:/duet:clean-loop 开工,/duet:ship 收工。"
