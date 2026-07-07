#!/usr/bin/env bash
# duet · stop-remind —— Stop 钩子(B:轻量收工提醒,非阻断)
# 有未提交代码改动时,收工前温和提醒。去重:有 session_id 按会话一次,否则按时间节流(30 分钟一次)。
# 不调模型、不 block;jq 缺失也能工作(退化到 grep 取字段)。
set -uo pipefail

input="$(cat)"

# 取字段:优先 jq,退化到 grep/sed(无 jq 也能用)
getf() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$key // empty"
  else
    local name="${key#.}"
    printf '%s' "$input" | grep -o "\"$name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*"\([^"]*\)"$/\1/'
  fi
}

sid="$(getf '.session_id')"
cwd="$(getf '.cwd')"
[ -n "${cwd:-}" ] && cd "$cwd" 2>/dev/null || true

# 仅在 git 仓库里生效;定位到仓库顶层——/duet:init 的 .duet 建在顶层,子目录会话也要能找到
root="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$root" ] || exit 0
cd "$root" 2>/dev/null || exit 0

# 仅在用过 duet 的项目里生效(跑过 /duet:init 或 ship 写过 next.md)——不向别的仓库写任何文件
[ -d .duet ] || exit 0

# 有未提交的“代码类”改动才提醒(-uall:未跟踪目录也逐文件列出,否则整个新目录只显示 “?? dir/” 而漏检)
changes="$(git status --porcelain -uall 2>/dev/null \
  | grep -cE '\.(ts|tsx|js|jsx|mjs|cjs|py|rs|go|java|kt|rb|php|c|cc|cpp|h|hpp|cs|swift|scala)$' || true)"
[ "${changes:-0}" -gt 0 ] || exit 0

# duet 自身运行时文件不入库(即使项目没配根 .gitignore);"*" 自动覆盖以后新增的运行时文件(如 journal.md)
# 缺失或还是旧版逐文件列表(无 "*" 行)都写成 "*",顺带升级 0.5 初始化过的项目
grep -qxF '*' .duet/.gitignore 2>/dev/null || printf '*\n' > .duet/.gitignore 2>/dev/null || true

# 去重
if [ -n "${sid:-}" ]; then
  marker=.duet/.reminded-sessions
  grep -qxF "$sid" "$marker" 2>/dev/null && exit 0
  printf '%s\n' "$sid" >> "$marker" 2>/dev/null || true
else
  # 没有 session_id:按时间节流,30 分钟内不重复提醒
  stamp=.duet/.last-remind
  now="$(date +%s 2>/dev/null || echo 0)"
  if [ -f "$stamp" ]; then
    last="$(cat "$stamp" 2>/dev/null || echo 0)"
    [ "$((now - last))" -lt 1800 ] 2>/dev/null && exit 0
  fi
  printf '%s\n' "$now" > "$stamp" 2>/dev/null || true
fi

printf '%s\n' '{"systemMessage":"duet · 本次工作区有未提交的代码改动。收工前可跑 /duet:ship(收拾+验证+Codex 复审)再走。"}'
exit 0
