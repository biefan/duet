#!/usr/bin/env bash
# duet · session-start —— SessionStart 钩子(A:收工连续性)
# 若项目里有上次收尾写的 .duet/next.md,把“下一步”注入本次会话上下文并提示用户。
# 有上限:最多注入前 15 行,避免撑大上下文。
set -uo pipefail

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
else
  cwd="$(printf '%s' "$input" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
fi
[ -n "${cwd:-}" ] && cd "$cwd" 2>/dev/null || true

# .duet 在 git 顶层(子目录开会话也要能接上);非 git 仓库退化到当前目录
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
f="$root/.duet/next.md"
[ -f "$f" ] || exit 0

# 上限:最多前 15 行;超出则加省略提示,避免上下文膨胀
content="$(head -n 15 "$f" 2>/dev/null)"
if [ "$(wc -l < "$f" 2>/dev/null || echo 0)" -gt 15 ]; then
  content="$content
…(更多见 .duet/next.md)"
fi

# 全空白则不打扰
[ -n "${content//[$'\n\t ']/}" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  jq -n --arg c "$content" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: ("duet · 上次收尾记录的下一步(.duet/next.md):\n" + $c)
    },
    systemMessage: "duet · 已载入上次的下一步(见 .duet/next.md)"
  }'
else
  printf 'duet · 上次收尾记录的下一步(.duet/next.md):\n%s\n' "$content"
fi

exit 0
