#!/usr/bin/env bash
# reap.sh — Tombstone Reaper 墓碑收割引擎
# 专门清缴代码库里的墓碑文件、自称已废弃的技能、临时备份与幽灵资产。
# 遵循《减法优先》思维定律：无用本身就是删除的充分理由，保留才需要论证。

set -euo pipefail

TARGET_DIR="."
MODE="dry-run"
SHARE_CARD=0

for arg in "$@"; do
  case "$arg" in
    --apply|--bury) MODE="apply" ;;
    --dry-run|--check) MODE="dry-run" ;;
    --share) SHARE_CARD=1 ;;
    *) if [ -d "$arg" ]; then TARGET_DIR="$arg"; fi ;;
  esac
done

cd "$TARGET_DIR"

echo "=================================================="
echo "🪦 Tombstone Reaper 墓碑收割机 ($MODE 模式)"
echo "目标项目: $(basename "$(pwd)") [$(pwd)]"
echo "=================================================="

tombstones=()
garbage_files=()
empty_drafts=()

total_freed_bytes=0
freed_skills_count=0
freed_drafts_count=0
freed_garbage_count=0

# 1. 扫描自称已废的墓碑技能 (Tombstone Skills)
# 精准判据：只读前 25 行的 Frontmatter（description 或 status 明确写着已停用/已废弃/deprecated）
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if [[ "$f" =~ archive/ ]] || [[ "$f" =~ \.git/ ]] || [[ "$f" =~ tombstone-reaper ]]; then continue; fi
  fm_header=$(head -n 25 "$f" 2>/dev/null || true)
  if echo "$fm_header" | grep -qiE "【已停用|【已废弃|【已废除】|status:\s*deprecated|该链路整条退役|已停用 202"; then
    tombstones+=("$f")
    # 计算整个 skill 目录的大小
    dir_size=$(du -sk "$(dirname "$f")" 2>/dev/null | cut -f1 || echo 4)
    total_freed_bytes=$((total_freed_bytes + dir_size * 1024))
  fi
done < <(find . -name "SKILL.md" -not -path "*/.*/*" 2>/dev/null || true)

# 2. 扫描临时与备份垃圾 (Garbage / Bak / Lock files)
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if [[ "$f" =~ \.git/ ]]; then continue; fi
  garbage_files+=("$f")
  f_size=$(wc -c < "$f" 2>/dev/null | tr -d ' ' || echo 0)
  total_freed_bytes=$((total_freed_bytes + f_size))
done < <(find . -type f \( -name "*.bak" -o -name "*.bak2" -o -name "*.update.lock" -o -name "*~" \) -not -path "*/.*/*" 2>/dev/null || true)

# 3. 扫描空草稿碎片 (< 100 字节且没有 frontmatter 的 markdown)
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if [[ "$f" =~ \.git/ ]] || [[ "$f" =~ node_modules/ ]] || [[ "$f" =~ templates/ ]]; then continue; fi
  size=$(wc -c < "$f" 2>/dev/null | tr -d ' ' || echo 0)
  if [ "$size" -lt 100 ]; then
    if ! grep -q "^---" "$f" 2>/dev/null; then
      empty_drafts+=("$f")
      total_freed_bytes=$((total_freed_bytes + size))
    fi
  fi
done < <(find . -maxdepth 3 -name "*.md" -not -name "README.md" -not -path "*/.*/*" 2>/dev/null || true)

freed_skills_count=${#tombstones[@]}
freed_garbage_count=${#garbage_files[@]}
freed_drafts_count=${#empty_drafts[@]}
total_items=$((freed_skills_count + freed_garbage_count + freed_drafts_count))

# 预估 Token 释放量：文本类 1 Token ≈ 3.5 字节
est_tokens=$((total_freed_bytes / 3))

echo ""
echo "🔍 验尸报告 (Tombstone Audit):"
echo "--------------------------------------------------"

if [ "$freed_skills_count" -gt 0 ]; then
  echo "⚰️  发现自称已废的【墓碑技能】($freed_skills_count 个):"
  for f in "${tombstones[@]}"; do
    echo "  - $f"
  done
else
  echo "  ✅ 无墓碑技能"
fi

if [ "$freed_garbage_count" -gt 0 ]; then
  echo ""
  echo "🗑️  发现临时与备份垃圾 ($freed_garbage_count 个):"
  for f in "${garbage_files[@]}"; do
    echo "  - $f"
  done
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

# 检查孤立 worktree
if [ -d .git ] || [ -f .git ]; then
  echo ""
  echo "🌳 Git Worktree 状态:"
  wt_list=$(git worktree list 2>/dev/null || true)
  wt_count=$(echo "$wt_list" | wc -l | tr -d ' ')
  if [ "$wt_count" -gt 1 ]; then
    echo "  ⚠️ 存在多个工作树 ($wt_count 个)，请确认是否有残留:"
    echo "$wt_list" | sed 's/^/    /'
  else
    echo "  ✅ 仅单一主工作区"
  fi
fi

echo "--------------------------------------------------"

if [ "$total_items" -eq 0 ]; then
  echo "🎉 恭喜！未发现任何死代码与墓碑，项目很干净！"
  exit 0
fi

if [ "$MODE" = "dry-run" ]; then
  echo "💡 预估收益: 释放约 $((total_freed_bytes / 1024)) KB 存储 / 约 $est_tokens 潜在上下文 Token"
  echo "💡 执行入土: 运行 $0 --bury"
else
  echo ""
  echo "🚀 执行安全入土清理..."
  for f in "${garbage_files[@]}"; do
    rm -f "$f"
    echo "  🗑️ 已删除临时文件: $f"
  done
  for f in "${empty_drafts[@]}"; do
    rm -f "$f"
    echo "  📄 已移除草稿碎片: $f"
  done
  for f in "${tombstones[@]}"; do
    dir=$(dirname "$f")
    mkdir -p archive/skills
    target="archive/skills/$(basename "$dir")"
    if [ -d "$target" ]; then rm -rf "$target"; fi
    mv "$dir" "$target"
    echo "  ⚰️  已安全归档墓碑技能: $dir → $target"
  done

  # 持久化累加至全局功德簿 (~/.tombstone-ledger.json)
  LEDGER="$HOME/.tombstone-ledger.json"
  if [ ! -f "$LEDGER" ]; then
    echo '{"total_skills":0,"total_drafts":0,"total_garbage":0,"total_tokens":0}' > "$LEDGER"
  fi
  python3 -c "
import json
p = '$LEDGER'
try:
    d = json.load(open(p))
except:
    d = {'total_skills':0,'total_drafts':0,'total_garbage':0,'total_tokens':0}
d['total_skills'] += $freed_skills_count
d['total_drafts'] += $freed_drafts_count
d['total_garbage'] += $freed_garbage_count
d['total_tokens'] += $est_tokens
json.dump(d, open(p, 'w'), indent=2)
" 2>/dev/null || true

  # 炫酷功德战报（晒单卡片）
  echo ""
  echo "=================================================="
  echo "📜 🪦 墓碑收割·入土功德战报 (Burial Certificate)"
  echo "=================================================="
  echo "  ⚰️  超度墓碑技能: $freed_skills_count 个"
  echo "  📄 清理草稿碎片: $freed_drafts_count 份"
  echo "  🗑️  粉碎幽灵垃圾: $freed_garbage_count 个文件"
  echo "  🧠 释放上下文记忆: ~$est_tokens Tokens"
  echo "  📦 缩减磁盘空间: ~$((total_freed_bytes / 1024)) KB"
  echo "--------------------------------------------------"
  echo "💬 悼词: 版本控制（Git）是它们的永生之地，工作区不是历史陈列馆。"
  echo "=================================================="

  echo ""
  echo "📢 [一键晒单 Markdown 文本，可直接粘贴至 PR 或社交媒体] :"
  echo ""
  echo "> 🪦 **Tombstone Reaper 减法战报**"
  echo "> 本次入土仪式已成功超度 **$freed_skills_count** 个墓碑技能、**$freed_drafts_count** 份死文档、粉碎 **$freed_garbage_count** 个垃圾文件！"
  echo "> 🧠 累计为 AI Agent 释放 **~$est_tokens** 个上下文 Token，仓库负熵减负！"
  echo "> *“立了墓碑不叫下线，入土为安才叫下线。”*"
  echo ""
fi
