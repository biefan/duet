#!/usr/bin/env bash
# duet · auto-tidy —— PostToolUse(Write|Edit) 钩子
# 收拾刚编辑的文件:按后缀跑内置已知格式化器(它们会读项目自己的配置,如 .prettierrc/ruff.toml);
# 没有就静默跳过。**只跑内置格式化器,绝不执行仓库内任意脚本**(防不可信仓库 RCE)。
# 永远 exit 0,绝不阻塞编辑;格式化本身失败也不报错。
set -uo pipefail

input="$(cat)"

# 从钩子 stdin 的 JSON 里取被编辑文件路径(优先 jq,退化到 grep/sed)
if command -v jq >/dev/null 2>&1; then
  file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
else
  file="$(printf '%s' "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
fi

# 路径为空或文件不存在(如删除/重命名)则直接跳过
[ -n "${file:-}" ] && [ -f "$file" ] || exit 0

# 按后缀自动检测项目自带的格式化器
case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.md|*.yaml|*.yml)
    command -v prettier >/dev/null 2>&1 && prettier --write "$file" >/dev/null 2>&1 || true
    ;;
  *.py)
    # 只做 format,不做 check --fix:--fix 会删“暂未使用”的 import,
    # 与小步实现打架(第一步加 import、第二步才用,中间就被删了)。fix 留给 /duet:ship 收拾阶段。
    if command -v ruff >/dev/null 2>&1; then
      ruff format "$file" >/dev/null 2>&1 || true
    elif command -v black >/dev/null 2>&1; then
      black -q "$file" >/dev/null 2>&1 || true
    fi
    ;;
  *.rs) command -v rustfmt >/dev/null 2>&1 && rustfmt "$file" >/dev/null 2>&1 || true ;;
  *.go) command -v gofmt >/dev/null 2>&1 && gofmt -w "$file" >/dev/null 2>&1 || true ;;
esac

exit 0
