#!/usr/bin/env bash
# duet · session-start —— SessionStart 钩子(收工连续性 + 残留检测 + compact 自检)
# 注入三类接续上下文,各有触发条件,拼在一起一次输出:
#   1) 上次收尾的 .duet/next.md(前 15 行;>14 天未更新标"可能过时")
#   2) 新会话开场时工作区的残留未提交代码改动(上次没收干净,先核对再开新活)
#   3) compact 之后的自检提示(压缩可能丢任务状态)
# 有上限、可退化(无 jq 用 grep),全空则静默。
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

cwd="$(getf '.cwd')"
src="$(getf '.source')"
[ -n "${cwd:-}" ] && cd "$cwd" 2>/dev/null || true

# .duet 在 git 顶层(子目录开会话也要能接上);非 git 仓库退化到当前目录
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

ctx=""

# 1) 上次收尾的下一步(所有 source 都注入:compact/clear 后也要能接上)
f="$root/.duet/next.md"
if [ -f "$f" ]; then
  content="$(head -n 15 "$f" 2>/dev/null)"
  if [ "$(wc -l < "$f" 2>/dev/null || echo 0)" -gt 15 ]; then
    content="$content
…(更多见 .duet/next.md)"
  fi
  if [ -n "${content//[$'\n\t ']/}" ]; then
    # 过期标注:太久没更新的"下一步"可能已不成立,提示先核对
    stale=""
    now="$(date +%s 2>/dev/null || echo 0)"
    mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "$now")"
    age_days=$(( (now - mtime) / 86400 ))
    [ "$age_days" -gt 14 ] && stale="(注意:已 ${age_days} 天未更新,可能过时,先核对再照做)"
    ctx="duet · 上次收尾记录的下一步(.duet/next.md)${stale}:
$content"
  fi
fi

# 2) 残留检测:仅新会话开场(startup;source 取不到时也算),resume/compact 中途有未提交改动属正常,不打扰
if { [ "$src" = "startup" ] || [ -z "$src" ]; } && [ -d "$root/.duet" ] \
   && git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  leftover="$(git -C "$root" status --porcelain -uall 2>/dev/null \
    | grep -cE '\.(ts|tsx|js|jsx|mjs|cjs|py|rs|go|java|kt|rb|php|c|cc|cpp|h|hpp|cs|swift|scala)$' || true)"
  if [ "${leftover:-0}" -gt 0 ]; then
    [ -n "$ctx" ] && ctx="$ctx

"
    ctx="${ctx}duet · 工作区有 ${leftover} 个未提交的代码文件改动(上次可能没收尾干净)——动新活前先 git status / git diff 核对,别在残留上叠加。"
  fi
fi

# 3) compact 自检:压缩可能把任务状态/验证 handle 摘丢
if [ "$src" = "compact" ]; then
  [ -n "$ctx" ] && ctx="$ctx

"
  ctx="${ctx}duet · 刚发生上下文压缩:自检当前任务、验证 handle、执行清单是否还完整;丢了先读 .duet/next.md 和最近的 diff 找回,再继续。"
fi

[ -n "$ctx" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  jq -n --arg c "$ctx" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $c
    },
    systemMessage: "duet · 已载入接续上下文(next.md / 残留 / compact 自检)"
  }'
else
  printf '%s\n' "$ctx"
fi

exit 0
