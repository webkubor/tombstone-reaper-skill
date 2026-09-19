#!/usr/bin/env bash
# tests/run.sh — tombstone-reaper-skill 自检
# 把 fixtures 拷到临时目录里跑 reap，验证：
#   1. --check 命中/不命中是否如预期
#   2. --bury 把墓碑归档到 archive/skills/，垃圾与草稿粉碎
#   3. --share 模式只输出卡片，不输出逐项清单
#   4. --help 输出用法
#
# 用法: bash tests/run.sh
# 退出码: 0 全过；非 0 有用例失败

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/reap.sh"
FIXTURE_SRC="$REPO_ROOT/tests/fixtures/has-tombstone"
TMP="$(mktemp -d)"
trap "rm -rf '$TMP' /tmp/reap-ledger.err" EXIT

PASS=0
FAIL=0
FAILED_TESTS=()

assert_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    期望包含: $needle"
    echo "    实际输出片段: $(echo "$haystack" | head -10 | tr '\n' '|')"
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$label")
  fi
}

assert_not_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    echo "  ✗ $label"
    echo "    期望不包含: $needle"
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$label")
  else
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  fi
}

assert_file_exists() {
  local label="$1"
  local p="$2"
  if [ -e "$p" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label — 期望存在: $p"
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$label")
  fi
}

assert_file_gone() {
  local label="$1"
  local p="$2"
  if [ ! -e "$p" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label — 期望不存在: $p"
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$label")
  fi
}

# 准备 fresh fixture 到临时目录
prepare_fixture() {
  rm -rf "$TMP"
  mkdir -p "$TMP"
  cp -R "$FIXTURE_SRC/." "$TMP/"
  # 动态生成测试用临时文件与垃圾（避免污染 git 仓库状态）
  echo "leftover" > "$TMP/scripts/leftover.bak"
  echo "lock" > "$TMP/scripts/old.build.update.lock"
  echo "dump" > "$TMP/scripts/dump.tmp"
  echo "broken" > "$TMP/scripts/merge-failed.rej"
  echo "agent test" > "$TMP/scripts/temp_agent_test.scratch.py"
  mkdir -p "$TMP/__pycache__" && echo "bytecode" > "$TMP/__pycache__/cache.pyc"
  # 在临时 fixture 里初始化 git（让 archive 用 git mv 也能跑）
  (cd "$TMP" && git init -q && git add -A && git -c user.email=test@x -c user.name=test commit -q -m "fixture" >/dev/null 2>&1) || true
}

echo ""
echo "=================================================="
echo "🪪 tombstone-reaper-skill test suite"
echo "=================================================="

# --- T1: --check 能识别墓碑、垃圾、草稿、AI 碎片 ---
echo ""
echo "T1 · --check 验尸报告命中正确"
prepare_fixture
out=$(cd "$TMP" && bash "$SCRIPT" --check --cache 2>&1)
assert_contains "  检出墓碑技能 deprecated-auth" "deprecated-auth/SKILL.md" "$out"
assert_contains "  检出 AI 幽灵碎片 .rej" ".rej" "$out"
assert_contains "  检出 AI 幽灵碎片 .scratch.py" ".scratch.py" "$out"
assert_contains "  检出 .bak 垃圾" ".bak" "$out"
assert_contains "  检出 .update.lock 垃圾" ".update.lock" "$out"
assert_contains "  检出 .tmp 垃圾（README/SKILL 声明要扫）" ".tmp" "$out"
assert_contains "  检出空草稿碎片" "空草稿碎片" "$out"
assert_contains "  检出项目构建缓存 __pycache__" "__pycache__" "$out"
assert_not_contains "  不误伤 healthy-payments" "healthy-payments/SKILL.md" "$out"
assert_not_contains "  不误伤有 frontmatter 的真文档" "real-doc.md" "$out"

# --- T2: --bury 把墓碑归档、垃圾与 AI 碎片粉碎、草稿清除、缓存删除 ---
echo ""
echo "T2 · --bury 执行入土"
prepare_fixture
(cd "$TMP" && bash "$SCRIPT" --apply --cache >/dev/null 2>&1)
assert_file_gone "  墓碑技能源目录消失" "$TMP/skills/deprecated-auth"
assert_file_exists "  墓碑技能归档到 archive/skills/" "$TMP/archive/skills/skills__deprecated-auth/SKILL.md"
assert_file_gone "  AI 补丁拒绝块 .rej 被粉碎" "$TMP/scripts/merge-failed.rej"
assert_file_gone "  AI 临时脚本 .scratch.py 被粉碎" "$TMP/scripts/temp_agent_test.scratch.py"
assert_file_gone "  .bak 被粉碎" "$TMP/scripts/leftover.bak"
assert_file_gone "  .update.lock 被粉碎" "$TMP/scripts/old.build.update.lock"
assert_file_gone "  .tmp 被粉碎" "$TMP/scripts/dump.tmp"
assert_file_gone "  空草稿 .md 被清除" "$TMP/scripts/draft.md"
assert_file_gone "  __pycache__ 缓存被清除" "$TMP/__pycache__"
assert_file_exists "  健康技能保留" "$TMP/skills/healthy-payments/SKILL.md"
assert_file_exists "  有 frontmatter 的真文档保留" "$TMP/note.d/real-doc.md"

# --- T3: --share 模式只打卡片，不打逐项清单 ---
echo ""
echo "T3 · --share 模式只输出卡片"
prepare_fixture
out=$(cd "$TMP" && bash "$SCRIPT" --check --share 2>&1)
assert_contains "  输出含晒单 Markdown" "晒单 Markdown" "$out"
assert_not_contains "  不输出验尸报告标题" "验尸报告" "$out"
assert_not_contains "  不输出逐项' 列举'" "发现自称已废的【墓碑技能】" "$out"

# --- T4: --help 正常输出 ---
echo ""
echo "T4 · --help 输出用法"
out=$(bash "$SCRIPT" --help 2>&1)
assert_contains "  --help 含用法字样" "用法" "$out"
assert_contains "  --help 含触发对象说明" "触发对象" "$out"

# --- T5: 自食其果防御（reaper 不应在自家目录检出自己） ---
echo ""
echo "T5 · 自食其果防御（在 reaper 自己目录 --check 不命中自身）"
out=$(bash "$SCRIPT" --check 2>&1)
assert_not_contains "  SKILL.md 不被误标为墓碑" "发现自称已废的【墓碑技能】" "$out"
assert_contains "  自检显示'项目很干净'" "项目很干净" "$out"

# --- T6: 撞名防御（两个同名 SKILL.md 在不同父目录，--bury 不互相覆盖） ---
echo ""
echo "T6 · 撞名防御"
rm -rf "$TMP"
mkdir -p "$TMP/plugins/auth" "$TMP/tools/auth"
cat > "$TMP/plugins/auth/SKILL.md" <<EOF
---
name: plugin-auth
description: "【已停用】老插件鉴权"
---
deprecated
EOF
cat > "$TMP/tools/auth/SKILL.md" <<EOF
---
name: tool-auth
description: "【已停用】老工具鉴权"
---
deprecated
EOF
(cd "$TMP" && git init -q && git add -A && git -c user.email=test@x -c user.name=test commit -q -m "fixture" >/dev/null 2>&1)
(cd "$TMP" && bash "$SCRIPT" --apply >/dev/null 2>&1)
assert_file_exists "  plugins/auth 被归档（不撞名）" "$TMP/archive/skills/plugins__auth/SKILL.md"
assert_file_exists "  tools/auth  被归档（不撞名）" "$TMP/archive/skills/tools__auth/SKILL.md"

# --- 汇总 ---
echo ""
echo "=================================================="
echo "汇总: $PASS 通过 / $FAIL 失败"
if [ "$FAIL" -gt 0 ]; then
  echo "失败的用例："
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi
echo "🎉 全过"
exit 0