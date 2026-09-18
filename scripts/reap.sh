#!/usr/bin/env bash
# reap.sh — Tombstone Reaper 墓碑收割引擎
# 专门清缴代码库里的墓碑文件、自称已废弃的技能、临时备份与幽灵资产。
# 遵循《减法优先》思维定律：无用本身就是删除的充分理由，保留才需要论证。

set -euo pipefail

# 锚定脚本所在仓库根（用于排除自身目录与自家归档，避免自食其果）
SELF_DIR="$(cd "$(dirname "$0")/.." && pwd)"

TARGET_DIR="."
MODE="dry-run"
SHARE_MODE=0

usage() {
  cat <<EOF
用法: reap.sh [选项] [目标目录]

选项:
  --check | --dry-run   只读检查，不动文件（默认）
  --apply | --bury      执行安全入土清理
  --share               只打功德战报与晒单卡片，跳过逐项清单
  --stats | --ledger    查看累计功德账本（~/.tombstone-ledger.json）

触发对象:
  ⚰️  墓碑技能   SKILL.md frontmatter 自称已废（【已停用】/status: deprecated/…）
  🗑️  幽灵垃圾   *.bak / *.bak2 / *.update.lock / *~ / *.tmp / *.orig 等临时与备份
  📄  草稿碎片   < 100 字节且无 frontmatter 的散落 .md
  🌳  孤立工作树 仅 --apply：HEAD 干净且非主工作树，安全 prune
  -h | --help           显示本帮助
EOF
}

for arg in "$@"; do
  case "$arg" in
    --apply|--bury) MODE="apply" ;;
    --dry-run|--check) MODE="dry-run" ;;
    --share) SHARE_MODE=1 ;;
    --stats|--ledger)
      LEDGER="$HOME/.tombstone-ledger.json"
      echo "=================================================="
      echo "📜 🪦 Tombstone Reaper 累计功德账本 (Global Ledger)"
      echo "=================================================="
      if [ -f "$LEDGER" ]; then
        python3 -c "
import json, os
d = json.load(open('$LEDGER'))
print(f'  ⚰️  累计超度墓碑技能: {d.get(\"total_skills\", 0)} 个')
print(f'  📄 累计清理草稿碎片: {d.get(\"total_drafts\", 0)} 份')
print(f'  🗑️  累计粉碎幽灵垃圾: {d.get(\"total_garbage\", 0)} 个')
print(f'  🧠 累计释放上下文: ~{d.get(\"total_tokens\", 0):,} Tokens')
print('--------------------------------------------------')
print(f'最近一次入土: {d.get(\"last_project\", \"无\")} ({d.get(\"last_burial_time\", \"无\")})')
"
      else
        echo "  尚无入土记录。运行 ./scripts/reap.sh --bury 开启第一笔功德！"
      fi
      echo "=================================================="
      exit 0
      ;;
    -h|--help) usage; exit 0 ;;
    *) if [ -d "$arg" ]; then TARGET_DIR="$arg"; else echo "⚠️  忽略未知参数: $arg"; fi ;;
  esac
done

cd "$TARGET_DIR"
ROOT_PWD="$(pwd)"
ARCHIVE_DIR="$ROOT_PWD/archive/skills"
SELF_ARCHIVE_DIR="$SELF_DIR/archive/skills"

if [ "$SHARE_MODE" -eq 0 ]; then
  echo "=================================================="
  echo "🪦 Tombstone Reaper 墓碑收割机 ($MODE 模式)"
  echo "目标项目: $(basename "$ROOT_PWD") [$ROOT_PWD]"
  echo "=================================================="
fi

tombstones=()
garbage_files=()
empty_drafts=()

total_freed_bytes=0
freed_skills_count=0
freed_drafts_count=0
freed_garbage_count=0

# 工具：判断绝对路径是否落在 reaper 自家归档下（避免误伤用户自己的 archive/）
is_in_self_archive() {
  local abs="$1"
  [ -n "$abs" ] || return 1
  case "$abs" in
    "$SELF_ARCHIVE_DIR"/*|"$SELF_ARCHIVE_DIR") return 0 ;;
    *) return 1 ;;
  esac
}

# 工具：判断绝对路径是否在 reaper 自身目录里（避免自食其果）
is_in_self_dir() {
  local abs="$1"
  [ -n "$abs" ] || return 1
  case "$abs" in
    "$SELF_DIR"/*|"$SELF_DIR") return 0 ;;
    *) return 1 ;;
  esac
}

# 工具：把 find 的相对路径解析成绝对路径 + 计算该 skill 单元大小
# 同目录只算一次（防多 SKILL.md 重复计）
declare -A _seen_skill_dirs

compute_skill_size() {
  local rel_path="$1"
  local abs_file
  abs_file="$(cd "$(dirname "$rel_path")" && pwd)/$(basename "$rel_path")"
  local dir
  dir="$(cd "$(dirname "$rel_path")" && pwd)"

  if [ -n "${_seen_skill_dirs[$dir]:-}" ]; then
    echo 0
    return
  fi
  _seen_skill_dirs[$dir]=1

  # 根级 SKILL.md（dirname == ROOT_PWD）只算自身大小
  if [ "$dir" = "$ROOT_PWD" ]; then
    wc -c < "$abs_file" | tr -d ' '
  else
    du -sb --exclude=.git --exclude=node_modules --exclude=archive "$dir" 2>/dev/null \
      | cut -f1 || wc -c < "$abs_file" | tr -d ' '
  fi
}

# 1. 扫描自称已废的墓碑技能 (Tombstone Skills)
# 判据：前 25 行 frontmatter 含【已停用】/【已废弃】/status: deprecated/该链路整条退役/已停用 YYYY
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
  is_in_self_archive "$abs" && continue
  is_in_self_dir "$abs" && continue
  fm_header=$(head -n 25 "$f" 2>/dev/null || true)
  if echo "$fm_header" | grep -qiE "【已停用|【已废弃|【已废除】|status:\s*deprecated|该链路整条退役|已停用 20[0-9]{2}"; then
    tombstones+=("$f")
    total_freed_bytes=$((total_freed_bytes + $(compute_skill_size "$f")))
  fi
done < <(find . \
  -name "SKILL.md" \
  -not -path "*/.*/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/archive/*" \
  -print0 2>/dev/null || true)

# 2. 扫描临时与备份垃圾 (Garbage / Bak / Lock files)
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
  is_in_self_archive "$abs" && continue
  is_in_self_dir "$abs" && continue
  garbage_files+=("$f")
  f_size=$(wc -c < "$f" 2>/dev/null | tr -d ' ' || echo 0)
  total_freed_bytes=$((total_freed_bytes + f_size))
done < <(find . \
  -type f \( -name "*.bak" -o -name "*.bak2" -o -name "*.update.lock" -o -name "*~" -o -name "*.tmp" -o -name "*.orig" \) \
  -not -path "*/.*/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/archive/*" \
  -print0 2>/dev/null || true)

# 3. 扫描空草稿碎片 (< 100 字节且没有 frontmatter 的 markdown)
# 阈值 100 字节 ≈ 30 个 CJK 字符或 100 个 ASCII 字符；过小则判定为未完成草稿
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
  is_in_self_archive "$abs" && continue
  is_in_self_dir "$abs" && continue
  size=$(wc -c < "$f" 2>/dev/null | tr -d ' ' || echo 0)
  if [ "$size" -lt 100 ]; then
    if ! grep -q "^---" "$f" 2>/dev/null; then
      empty_drafts+=("$f")
      total_freed_bytes=$((total_freed_bytes + size))
    fi
  fi
done < <(find . \
  -maxdepth 3 -name "*.md" \
  -not -name "README.md" \
  -not -path "*/.*/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/templates/*" \
  -not -path "*/archive/*" \
  -print0 2>/dev/null || true)

freed_skills_count=${#tombstones[@]}
freed_garbage_count=${#garbage_files[@]}
freed_drafts_count=${#empty_drafts[@]}
total_items=$((freed_skills_count + freed_garbage_count + freed_drafts_count))

# 预估 Token 释放量：文本类 1 Token ≈ 3.5 字节（英文 ~4，中文 ~1.5，加权 3.5）
est_tokens=$(awk "BEGIN { printf \"%d\", $total_freed_bytes / 3.5 }")
[ -z "$est_tokens" ] && est_tokens=0

# 孤立 worktree 列表（用于报告与 reap）
wt_reap_targets=()
wt_skip_targets=()
if [ -d .git ] || [ -f .git ]; then
  root_resolved="$(cd "$ROOT_PWD" 2>/dev/null && pwd)"
  while IFS= read -r wt; do
    [ -z "$wt" ] && continue
    wt_path="$(echo "$wt" | awk '{print $1}')"
    wt_branch="$(echo "$wt" | awk '{print $3}' | tr -d '[]')"
    # 用 cd && pwd 兼容 macOS 上 /tmp → /private/tmp 的符号链接解析差异
    wt_resolved="$(cd "$wt_path" 2>/dev/null && pwd)"
    [ "$wt_resolved" = "$root_resolved" ] && continue
    # 仅当 worktree 内 HEAD 干净才列入 reap 候选
    if git -C "$wt_path" diff --quiet HEAD 2>/dev/null && \
       git -C "$wt_path" diff --quiet --cached 2>/dev/null; then
      wt_reap_targets+=("$wt_path")
    else
      wt_skip_targets+=("$wt_path")
    fi
  done < <(git worktree list 2>/dev/null || true)
fi

if [ "$SHARE_MODE" -eq 0 ]; then
  echo ""
  echo "🔍 验尸报告 (Tombstone Audit):"
  echo "--------------------------------------------------"

  if [ "$freed_skills_count" -gt 0 ]; then
    echo "⚰️  发现自称已废的【墓碑技能】($freed_skills_count 个):"
    for f in "${tombstones[@]}"; do echo "  - $f"; done
  else
    echo "  ✅ 无墓碑技能"
  fi

  if [ "$freed_garbage_count" -gt 0 ]; then
    echo ""
    echo "🗑️  发现临时与备份垃圾 ($freed_garbage_count 个):"
    for f in "${garbage_files[@]}"; do echo "  - $f"; done
  else
    echo "  ✅ 无临时备份垃圾"
  fi

  if [ "$freed_drafts_count" -gt 0 ]; then
    echo ""
    echo "📄 发现空草稿碎片 ($freed_drafts_count 个):"
    for f in "${empty_drafts[@]}"; do
      echo "  - $f ($(wc -c < "$f" | tr -d ' ') 字节)"
    done
  else
    echo "  ✅ 无空草稿碎片"
  fi

  # 工作树报告
  if [ -d .git ] || [ -f .git ]; then
    echo ""
    echo "🌳 Git Worktree 状态:"
    if [ "${#wt_reap_targets[@]}" -gt 0 ] || [ "${#wt_skip_targets[@]}" -gt 0 ]; then
      if [ "${#wt_reap_targets[@]}" -gt 0 ]; then
        echo "  🪓 可安全清理 ($((1 + ${#wt_reap_targets[@]})) 个候选):"
        for p in "${wt_reap_targets[@]}"; do echo "    - $p"; done
      fi
      if [ "${#wt_skip_targets[@]}" -gt 0 ]; then
        echo "  ⚠️  跳过（HEAD 不干净）(${#wt_skip_targets[@]} 个):"
        for p in "${wt_skip_targets[@]}"; do echo "    - $p"; done
      fi
    else
      echo "  ✅ 仅单一主工作区"
    fi
  fi

  echo "--------------------------------------------------"
fi

if [ "$total_items" -eq 0 ] && [ "${#wt_reap_targets[@]}" -eq 0 ]; then
  if [ "$SHARE_MODE" -eq 0 ]; then
    echo "🎉 恭喜！未发现任何死代码与墓碑，项目很干净！"
  fi
  exit 0
fi

if [ "$MODE" = "dry-run" ]; then
  # --share 模式也要打预览卡片（让用户预知会晒什么）；否则只打预估收益行
  if [ "$SHARE_MODE" -eq 1 ]; then
    cat <<EOF
==================================================
📜 🪦 墓碑收割·入土功德战报 (Burial Certificate 预览)
==================================================
  ⚰️  预估超度墓碑技能: $freed_skills_count 个
  📄 预估清理草稿碎片: $freed_drafts_count 份
  🗑️  预估粉碎幽灵垃圾: $freed_garbage_count 个文件
  🌳 预估清理孤立工作树: ${#wt_reap_targets[@]} 个
  🧠 预估释放上下文记忆: ~$est_tokens Tokens
  📦 预估缩减磁盘空间: ~$((total_freed_bytes / 1024)) KB
--------------------------------------------------
💬 悼词: 版本控制（Git）是它们的永生之地，工作区不是历史陈列馆。
==================================================

📢 [一键晒单 Markdown 文本（预览），可直接粘贴至 PR 或社交媒体] :

> 🪦 **Tombstone Reaper 减法战报 (预览)**
> 本次将超度 **$freed_skills_count** 个墓碑技能、**$freed_drafts_count** 份死文档、粉碎 **$freed_garbage_count** 个垃圾文件、清理 **${#wt_reap_targets[@]}** 个孤立工作树！
> 🧠 预计为 AI Agent 释放 **~$est_tokens** 个上下文 Token，仓库负熵减负！
> *"立了墓碑不叫下线，入土为安才叫下线。"*
EOF
  else
    echo "💡 预估收益: 释放约 $((total_freed_bytes / 1024)) KB 存储 / 约 $est_tokens 潜在上下文 Token"
    echo "💡 执行入土: 运行 $0 --bury"
  fi
  exit 0
fi

# ===== apply 模式 =====
if [ "$SHARE_MODE" -eq 0 ]; then
  echo ""
  echo "🚀 执行安全入土清理..."
fi

for f in "${garbage_files[@]}"; do
  rm -f "$f"
  [ "$SHARE_MODE" -eq 0 ] && echo "  🗑️ 已删除临时文件: $f"
done

for f in "${empty_drafts[@]}"; do
  rm -f "$f"
  [ "$SHARE_MODE" -eq 0 ] && echo "  📄 已移除草稿碎片: $f"
done

for f in "${tombstones[@]}"; do
  dir=$(dirname "$f")
  # 用完整相对路径做归档子目录名，避免 plugins/auth vs tools/auth 撞名
  # macOS realpath 不支持 --relative-to，用纯 bash 字符串处理代替
  case "$dir" in
    .) safe_name="$(basename "$ROOT_PWD")" ;;
    ./*) safe_name="${dir#./}"; safe_name="${safe_name//\//__}" ;;
    *) safe_name="${dir//\//__}" ;;
  esac
  mkdir -p "$ARCHIVE_DIR"
  target="$ARCHIVE_DIR/$safe_name"
  if [ -d "$target" ]; then rm -rf "$target"; fi

  # 在 git 仓库内优先 git mv，保留 rename 历史（与 SKILL.md "git 是永生之地" 一致）
  if git rev-parse --git-dir >/dev/null 2>&1; then
    if ! git mv "$dir" "$target" 2>/dev/null; then
      mv "$dir" "$target"
    fi
  else
    mv "$dir" "$target"
  fi
  [ "$SHARE_MODE" -eq 0 ] && echo "  ⚰️  已安全归档墓碑技能: $dir → $target"
done

# 收割孤立 worktree（仅 HEAD 干净的）
for p in "${wt_reap_targets[@]}"; do
  if git worktree remove --force "$p" 2>/dev/null; then
    [ "$SHARE_MODE" -eq 0 ] && echo "  🌳 已清理孤立工作树: $p"
  else
    [ "$SHARE_MODE" -eq 0 ] && echo "  ⚠️  工作树清理失败: $p"
  fi
done

# 持久化累加至全局功德簿 (~/.tombstone-ledger.json)
LEDGER="$HOME/.tombstone-ledger.json"
if [ ! -f "$LEDGER" ]; then
  echo '{"total_skills":0,"total_drafts":0,"total_garbage":0,"total_tokens":0}' > "$LEDGER"
fi

ledger_ok=0
python3 <<PYEOF 2>>/tmp/reap-ledger.err && ledger_ok=1
import json
p = '$LEDGER'
try:
    d = json.load(open(p))
except Exception:
    d = {'total_skills':0,'total_drafts':0,'total_garbage':0,'total_tokens':0}
d['total_skills'] += $freed_skills_count
d['total_drafts'] += $freed_drafts_count
d['total_garbage'] += $freed_garbage_count
d['total_tokens'] += $est_tokens
d['last_project'] = '$(basename "$ROOT_PWD")'
import datetime
d['last_burial_time'] = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
json.dump(d, open(p, 'w'), indent=2)
PYEOF
if [ "$ledger_ok" -eq 0 ]; then
  echo "⚠️  功德簿写入失败：$(cat /tmp/reap-ledger.err 2>/dev/null | head -3)"
  rm -f /tmp/reap-ledger.err
fi

# ===== 入土功德战报（bury card） =====
if [ "$SHARE_MODE" -eq 1 ]; then
  # 只打卡片，跳过逐项清单
  cat <<EOF
==================================================
📜 🪦 墓碑收割·入土功德战报 (Burial Certificate)
==================================================
  ⚰️  超度墓碑技能: $freed_skills_count 个
  📄 清理草稿碎片: $freed_drafts_count 份
  🗑️  粉碎幽灵垃圾: $freed_garbage_count 个文件
  🌳 清理孤立工作树: ${#wt_reap_targets[@]} 个
  🧠 释放上下文记忆: ~$est_tokens Tokens
  📦 缩减磁盘空间: ~$((total_freed_bytes / 1024)) KB
--------------------------------------------------
💬 悼词: 版本控制（Git）是它们的永生之地，工作区不是历史陈列馆。
==================================================
EOF
else
  echo ""
  echo "=================================================="
  echo "📜 🪦 墓碑收割·入土功德战报 (Burial Certificate)"
  echo "=================================================="
  echo "  ⚰️  超度墓碑技能: $freed_skills_count 个"
  echo "  📄 清理草稿碎片: $freed_drafts_count 份"
  echo "  🗑️  粉碎幽灵垃圾: $freed_garbage_count 个文件"
  echo "  🌳 清理孤立工作树: ${#wt_reap_targets[@]} 个"
  echo "  🧠 释放上下文记忆: ~$est_tokens Tokens"
  echo "  📦 缩减磁盘空间: ~$((total_freed_bytes / 1024)) KB"
  echo "--------------------------------------------------"
  echo "💬 悼词: 版本控制（Git）是它们的永生之地，工作区不是历史陈列馆。"
  echo "=================================================="
fi

# 一键晒单 Markdown
echo ""
echo "📢 [一键晒单 Markdown 文本，可直接粘贴至 PR 或社交媒体] :"
echo ""
echo "> 🪦 **Tombstone Reaper 减法战报**"
echo "> 本次入土仪式已成功超度 **$freed_skills_count** 个墓碑技能、**$freed_drafts_count** 份死文档、粉碎 **$freed_garbage_count** 个垃圾文件、清理 **${#wt_reap_targets[@]}** 个孤立工作树！"
echo "> 🧠 累计为 AI Agent 释放 **~$est_tokens** 个上下文 Token，仓库负熵减负！"
echo "> *"立了墓碑不叫下线，入土为安才叫下线。"*
echo ""