#!/usr/bin/env bash
# duet · 离线回归测试 —— 全部用 stdin JSON 模拟钩子输入,不依赖 Claude Code 运行时。
# 用法:bash tests/run.sh
# 约定:任一断言失败以非零退出;依赖可选工具(ruff/prettier)的用例在工具缺失时 skip。
set -uo pipefail

SCRIPTS="$(cd "$(dirname "$0")/../plugins/duet/scripts" && pwd)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0; skip=0
ok()    { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad()   { fail=$((fail+1)); printf 'FAIL %s\n     %s\n' "$1" "${2:-}"; }
skipt() { skip=$((skip+1)); printf 'skip %s(%s 未安装)\n' "$1" "$2"; }

eq()      { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "期望[$2] 实际[$3]"; fi; }
has()     { if printf '%s' "$3" | grep -qF -- "$2"; then ok "$1"; else bad "$1" "应含[$2] 实际[$3]"; fi; }
not_has() { if printf '%s' "$3" | grep -qF -- "$2"; then bad "$1" "不应含[$2]"; else ok "$1"; fi; }

newrepo() { mkdir -p "$WORK/$1" && git -C "$WORK/$1" init -q; }
gcommit() { git -C "$1" add -A >/dev/null && git -C "$1" -c user.email=t@t -c user.name=t commit -qm "${2:-c}"; }

tidy()   { printf '{"tool_input":{"file_path":"%s"}}' "$1" | bash "$SCRIPTS/auto-tidy.sh" 2>"$WORK/tidy.stderr"; }
remind() { printf '{"session_id":"%s","cwd":"%s"}' "$1" "$2" | bash "$SCRIPTS/stop-remind.sh"; }
sstart() { printf '{"cwd":"%s","source":"%s"}' "$1" "$2" | bash "$SCRIPTS/session-start.sh"; }
sctx()   { sstart "$1" "$2" | jq -r '.hookSpecificOutput.additionalContext // ""'; }

# ---------- 元检查:语法 / JSON / 版本一致 ----------
echo "# 元检查"
for f in auto-tidy.sh stop-remind.sh session-start.sh duet-init.sh; do
  if bash -n "$SCRIPTS/$f" 2>/dev/null; then ok "bash -n $f"; else bad "bash -n $f"; fi
done
for f in "$ROOT/plugins/duet/.claude-plugin/plugin.json" "$ROOT/.claude-plugin/marketplace.json" "$ROOT/plugins/duet/hooks/hooks.json"; do
  if jq -e . "$f" >/dev/null 2>&1; then ok "json 合法 $(basename "$f")"; else bad "json 合法 $(basename "$f")"; fi
done
pv="$(jq -r .version "$ROOT/plugins/duet/.claude-plugin/plugin.json")"
mv_="$(jq -r .metadata.version "$ROOT/.claude-plugin/marketplace.json")"
eq "plugin.json 与 marketplace.json 版本一致" "$pv" "$mv_"

# ---------- auto-tidy ----------
echo "# auto-tidy"
mkdir -p "$WORK/at"
if command -v ruff >/dev/null 2>&1; then
  printf 'import os\nx=1\n' > "$WORK/at/a.py"
  tidy "$WORK/at/a.py"
  has "py 仍做 format" "x = 1" "$(cat "$WORK/at/a.py")"
  has "py 保留未使用 import(不跑 check --fix)" "import os" "$(cat "$WORK/at/a.py")"
else
  skipt "py format/保留 import" "ruff"
fi
printf 'hello  \n' > "$WORK/at/b.txt"
tidy "$WORK/at/b.txt"
eq "无关后缀不动内容" "hello  " "$(head -1 "$WORK/at/b.txt")"
tidy "/nonexistent/x.py";              eq "文件不存在 exit 0" "0" "$?"
printf '{"tool_input":{}}' | bash "$SCRIPTS/auto-tidy.sh" 2>"$WORK/tidy.stderr"; eq "file_path 缺失 exit 0" "0" "$?"
printf 'garbage' | bash "$SCRIPTS/auto-tidy.sh" 2>"$WORK/tidy.stderr";           eq "非 JSON stdin exit 0" "0" "$?"
eq "非 JSON stdin 无 stderr 噪音" "" "$(cat "$WORK/tidy.stderr")"

# ---------- stop-remind ----------
echo "# stop-remind"
mkdir -p "$WORK/nogit"
eq "非 git 目录静默" "" "$(remind s1 "$WORK/nogit")"

newrepo r1 && echo x=1 > "$WORK/r1/a.py"
eq "无 .duet 门禁:静默" "" "$(remind s1 "$WORK/r1")"
[ -d "$WORK/r1/.duet" ] && bad "无 .duet 门禁:零写入" ".duet 被创建了" || ok "无 .duet 门禁:零写入"

mkdir "$WORK/r1/.duet"
has "有 .duet + 代码改动:提醒" "duet:ship" "$(remind s1 "$WORK/r1")"
eq  ".duet/.gitignore 自动建为 *" "*" "$(cat "$WORK/r1/.duet/.gitignore")"
eq  "同 session 去重" "" "$(remind s1 "$WORK/r1")"
has "新 session 再提醒" "duet:ship" "$(remind s2 "$WORK/r1")"

newrepo r2 && mkdir -p "$WORK/r2/src" "$WORK/r2/.duet" && echo x=1 > "$WORK/r2/src/a.py"
has "子目录会话 + 未跟踪目录(-uall):提醒" "duet:ship" "$(remind s1 "$WORK/r2/src")"
[ -d "$WORK/r2/src/.duet" ] && bad "标记写在 git 顶层" "src 下出现 .duet" || ok "标记写在 git 顶层"

newrepo r3 && mkdir "$WORK/r3/.duet" && echo x=1 > "$WORK/r3/a.py" && gcommit "$WORK/r3"
echo y=2 >> "$WORK/r3/a.py"
has "已跟踪文件修改:提醒" "duet:ship" "$(remind s1 "$WORK/r3")"
gcommit "$WORK/r3"
eq "工作区干净:静默" "" "$(remind s3 "$WORK/r3")"
( cd "$WORK/r3" && echo note > doc.md )
eq "只有非代码改动:静默" "" "$(remind s4 "$WORK/r3")"

newrepo r4 && mkdir "$WORK/r4/.duet" && echo x=1 > "$WORK/r4/a.py"
printf 'next.md\n.reminded-sessions\n.last-remind\n' > "$WORK/r4/.duet/.gitignore"
remind s1 "$WORK/r4" >/dev/null
eq "旧版逐文件列表升级为 *" "*" "$(cat "$WORK/r4/.duet/.gitignore")"
echo j > "$WORK/r4/.duet/journal.md"
eq "升级后 journal.md 被忽略" "0" "$(git -C "$WORK/r4" status --porcelain -uall | grep -c journal || true)"

newrepo r5 && mkdir "$WORK/r5/.duet" && echo x=1 > "$WORK/r5/a.py"
out="$(remind "" "$WORK/r5")"
has "无 session_id 首次:提醒(节流路径)" "duet:ship" "$out"
eq  "无 session_id 30 分钟内:静默" "" "$(remind "" "$WORK/r5")"
( cd "$WORK/nogit" && printf '{"session_id":"s9"}' | bash "$SCRIPTS/stop-remind.sh" >/dev/null 2>&1 )
eq "cwd 缺失不 crash(在临时目录执行,不碰调用者项目)" "0" "$?"

# ---------- session-start ----------
echo "# session-start"
newrepo s1 && mkdir -p "$WORK/s1/src" "$WORK/s1/.duet"
printf -- '- 接 CLI 入口\n' > "$WORK/s1/.duet/next.md"
echo x=1 > "$WORK/s1/src/a.py"

c="$(sctx "$WORK/s1/src" startup)"
has "startup:注入 next.md(子目录会话)" "接 CLI 入口" "$c"
has "startup:残留检测提示" "未提交的代码文件改动" "$c"
c="$(sctx "$WORK/s1" resume)"
has     "resume:仍注入 next.md" "接 CLI 入口" "$c"
not_has "resume:不报残留" "未提交的代码文件改动" "$c"
c="$(sctx "$WORK/s1" compact)"
has "compact:自检提示" "上下文压缩" "$c"
has "compact:仍注入 next.md" "接 CLI 入口" "$c"
c="$(sctx "$WORK/s1" clear)"
not_has "clear:不报残留" "未提交的代码文件改动" "$c"
c="$(printf '{"cwd":"%s"}' "$WORK/s1" | bash "$SCRIPTS/session-start.sh" | jq -r '.hookSpecificOutput.additionalContext')"
has "source 缺失按 startup 处理(报残留)" "未提交的代码文件改动" "$c"

eq "输出 hookEventName 正确" "SessionStart" "$(sstart "$WORK/s1" startup | jq -r '.hookSpecificOutput.hookEventName')"

not_has "新鲜 next.md 无过期标注" "可能过时" "$(sctx "$WORK/s1" startup)"
touch -d "20 days ago" "$WORK/s1/.duet/next.md" 2>/dev/null || touch -t "$(date -v-20d +%Y%m%d%H%M 2>/dev/null || echo 202501010000)" "$WORK/s1/.duet/next.md"
c="$(sctx "$WORK/s1" startup)"
has "过期 next.md 标注" "可能过时" "$c"

gcommit "$WORK/s1"
c="$(sctx "$WORK/s1" startup)"
not_has "干净工作区:无残留段" "未提交的代码文件改动" "$c"

seq 1 20 | sed 's/^/- 行/' > "$WORK/s1/.duet/next.md"
c="$(sctx "$WORK/s1" startup)"
has     "超 15 行截断并提示" "更多见 .duet/next.md" "$c"
not_has "第 16 行不注入" "行16" "$c"

printf '   \n\n' > "$WORK/s1/.duet/next.md"
eq "全空白 next.md + 干净工作区:整体静默" "" "$(sstart "$WORK/s1" startup)"

newrepo s2 && echo x=1 > "$WORK/s2/a.py"
eq "无 .duet 的仓库:静默(即使有改动)" "" "$(sstart "$WORK/s2" startup)"
mkdir -p "$WORK/nogit2"
eq "非 git 且无 next.md:静默" "" "$(sstart "$WORK/nogit2" startup)"

# ---------- duet-init ----------
echo "# duet-init"
mkdir -p "$WORK/i1" && ( cd "$WORK/i1" && bash "$SCRIPTS/duet-init.sh" >/dev/null )
git -C "$WORK/i1" rev-parse --is-inside-work-tree >/dev/null 2>&1 && ok "空目录:git init" || bad "空目录:git init"
has "顶层 .gitignore 含 .duet/" ".duet/" "$(cat "$WORK/i1/.gitignore")"
has "顶层 .gitignore 含 __pycache__" "__pycache__/" "$(cat "$WORK/i1/.gitignore")"
eq  ".duet/.gitignore 为 *" "*" "$(cat "$WORK/i1/.duet/.gitignore")"
( cd "$WORK/i1" && bash "$SCRIPTS/duet-init.sh" >/dev/null )
eq "重跑幂等:duet 块只有一份" "1" "$(grep -c '>>> duet >>>' "$WORK/i1/.gitignore")"
printf 'next.md\n' > "$WORK/i1/.duet/.gitignore"
( cd "$WORK/i1" && bash "$SCRIPTS/duet-init.sh" >/dev/null )
eq "旧版 .duet/.gitignore 重跑即升级为 *" "*" "$(cat "$WORK/i1/.duet/.gitignore")"
mkdir -p "$WORK/i1/sub" && ( cd "$WORK/i1/sub" && bash "$SCRIPTS/duet-init.sh" >/dev/null )
[ -f "$WORK/i1/sub/.gitignore" ] && bad "子目录跑 init:写在 git 顶层" "sub 下出现 .gitignore" || ok "子目录跑 init:写在 git 顶层"
( cd "$WORK/i1/sub" && printf 'x\n' > ../.duet/journal.md && printf 'y\n' > ../.duet/next.md )
eq "journal/next 在 * 下被忽略" "0" "$(git -C "$WORK/i1" status --porcelain -uall | grep -c '\.duet' || true)"

# ---------- 静态:swarm 命令 / 动态分诊 / codex 镜像 ----------
echo "# 静态检查(v0.7 组件)"
SW="$ROOT/plugins/duet/commands/swarm.md"
[ -f "$SW" ] && ok "swarm.md 存在" || bad "swarm.md 存在"
has "swarm 有 description" "description:" "$(head -5 "$SW")"
has "swarm 含只读红线" "全程只读" "$(cat "$SW")"
not_has "swarm 权限无裸 Bash(只读由权限保证)" "Bash" "$(head -5 "$SW")"
has "swarm 有 Workflow 退化路径" "退化为并行 Agent" "$(cat "$SW")"
CL="$ROOT/plugins/duet/skills/clean-loop/SKILL.md"
has "clean-loop 含分诊表" "先分诊" "$(cat "$CL")"
has "clean-loop 含引擎选择" "选实现引擎" "$(cat "$CL")"
has "clean-loop 接入 swarm" "/duet:swarm" "$(cat "$CL")"
has "clean-loop 含派活纪律" "简报五要素" "$(cat "$CL")"
has "clean-loop 含耐心等待" "别反复刷状态" "$(cat "$CL")"
has "clean-loop 含活状态 checkpoint" "活状态文件" "$(cat "$CL")"
has "codex 镜像含活状态 checkpoint" "活状态文件" "$(cat "$ROOT/codex-skills/duet-clean-loop/SKILL.md")"
for s in duet-clean-loop duet-ship; do
  f="$ROOT/codex-skills/$s/SKILL.md"
  [ -f "$f" ] && ok "codex 镜像 $s 存在" || bad "codex 镜像 $s 存在"
  has "codex 镜像 $s name 与目录一致" "name: \"$s\"" "$(head -3 "$f")"
  has "codex 镜像 $s 共用 .duet 约定" ".duet/next.md" "$(cat "$f")"
done

# ---------- 汇总 ----------
printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
