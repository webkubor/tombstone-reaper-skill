#!/usr/bin/env bash
# reap.sh — Tombstone Reaper 墓碑收割引擎
# 专门清缴代码库里的墓碑文件、自称已废弃的技能、AI 幽灵碎片、临时备份与无用缓存。
# 遵循《减法优先》思维定律：无用本身就是删除的充分理由，保留才需要论证。

set -euo pipefail

# 锚定脚本所在仓库根（用于排除自身目录与自家归档，避免自食其果）
SELF_DIR="$(cd "$(dirname "$0")/.." && pwd)"

TARGET_DIR="."
MODE="dry-run"
SHARE_MODE=0
ENABLE_CACHE=0
ENABLE_SYSTEM_CACHE=0

usage() {
  cat <<EOF
用法: reap.sh [选项] [目标目录]

选项:
  --check | --dry-run   只读检查，不动文件（默认）
  --apply | --bury      执行安全入土清理
  --share               只打功德战报与晒单卡片，跳过逐项清单
  --cache               扫描并清理项目内的临时构建缓存（__pycache__, .turbo, .next 等）
  --system-cache        清理开发者系统全局依赖纯缓存（npm, pip, go, brew, updater）
  --deep | --all        全量减法模式（含墓碑、AI 碎片、项目缓存与系统缓存）
  --stats | --ledger    查看累计功德账本（~/.tombstone-ledger.json）
  -h | --help           显示本帮助

触发对象:
  ⚰️  墓碑技能   SKILL.md frontmatter 自称已废（【已停用】/status: deprecated/…）
  🤖  AI 幽灵    *.rej (补丁拒绝块) / *.scratch.* / temp_*.py / scratch/ 临时脚本
  🗑️  幽灵垃圾   *.bak / *.bak2 / *.update.lock / *~ / *.tmp / *.orig / .DS_Store
  📄  草稿碎片   < 100 字节且无 frontmatter 的散落 .md
  🌳  孤立工作树 仅 --apply：HEAD 干净且非主工作树，安全 prune
  ⚡  构建缓存   项目级构建产物与系统级包管理器纯缓存（需 --cache / --system-cache）
EOF
}

for arg in "$@"; do
  case "$arg" in
    --apply|--bury) MODE="apply" ;;
    --dry-run|--check) MODE="dry-run" ;;
    --share) SHARE_MODE=1 ;;
    --cache) ENABLE_CACHE=1 ;;
    --system-cache) ENABLE_SYSTEM_CACHE=1 ;;
    --deep|--all)
      ENABLE_CACHE=1
      ENABLE_SYSTEM_CACHE=1
      ;;
    --stats|--ledger)
      LEDGER="$HOME/.tombstone-ledger.json"
      echo "=================================================="
      echo "📜 🪦 Tombstone Reaper 累计功德账本 (Global Ledger)"
      echo "=================================================="
      if [ -f "$LEDGER" ]; then
        LEDGER_PATH="$LEDGER" python3 <<'PYEOF'
import json, os
p = os.environ.get('LEDGER_PATH', '')
d = json.load(open(p))
def fmt_b(b):
    if b >= 1073741824: return f'{b/1073741824:.2f} GB'
    if b >= 1048576: return f'{b/1048576:.1f} MB'
    if b >= 1024: return f'{b/1024:.0f} KB'
    return f'{b} B'
print(f'  ⚰️  累计超度墓碑技能: {d.get("total_skills", 0)} 个')
print(f'  🤖 累计粉碎 AI 碎片: {d.get("total_ai", 0)} 份')
print(f'  📄 累计清理草稿碎片: {d.get("total_drafts", 0)} 份')
print(f'  🗑️  累计粉碎幽灵垃圾: {d.get("total_garbage", 0)} 个')
cache_b = d.get("total_cache_bytes", 0)
if cache_b > 0:
    print(f'  ⚡ 累计蒸发依赖缓存: {fmt_b(cache_b)}')
print(f'  🧠 累计释放上下文: ~{d.get("total_tokens", 0):,} Tokens')
print('--------------------------------------------------')
print(f'最近一次入土: {d.get("last_project", "无")} ({d.get("last_burial_time", "无")})')
PYEOF
      else
        echo "  尚无入土记录。运行 ./scripts/reap.sh --bury 开启第一笔功德！"
      fi
      echo "=================================================="
      exit 0
      ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "❌ 未知选项: $arg"; usage; exit 2 ;;
    *) if [ -d "$arg" ]; then TARGET_DIR="$arg"; else echo "❌ 未知参数（非目录）: $arg"; usage; exit 2; fi ;;
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
ai_artifacts=()
garbage_files=()
empty_drafts=()
project_caches=()

total_freed_bytes=0
freed_skills_count=0
freed_ai_count=0
freed_drafts_count=0
freed_garbage_count=0
freed_cache_bytes=0
system_cache_freed_bytes=0

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

# 人性化容量格式化
format_size() {
  local b="$1"
  if [ "$b" -ge 1073741824 ]; then
    awk "BEGIN { printf \"%.2f GB\", $b / 1073741824 }"
  elif [ "$b" -ge 1048576 ]; then
    awk "BEGIN { printf \"%.1f MB\", $b / 1048576 }"
  elif [ "$b" -ge 1024 ]; then
    awk "BEGIN { printf \"%d KB\", $b / 1024 }"
  else
    echo "${b} B"
  fi
}

# 工具：把 find 的相对路径解析成绝对路径 + 计算该 skill 单元大小
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
    du -sk "$dir" 2>/dev/null | awk '{print $1 * 1024}' || wc -c < "$abs_file" | tr -d ' '
  fi
}

# 1. 扫描自称已废的墓碑技能 (Tombstone Skills)
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
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/archive/*" \
  -print0 2>/dev/null || true)

# 2. 扫描 AI 幽灵碎片与临时脚手架 (*.rej / *.scratch.* / scratch/ 临时文件 / temp_*.py 等)
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
  is_in_self_archive "$abs" && continue
  is_in_self_dir "$abs" && continue
  ai_artifacts+=("$f")
  f_size=$(wc -c < "$f" 2>/dev/null | tr -d ' ' || echo 0)
  total_freed_bytes=$((total_freed_bytes + f_size))
done < <(find . \
  -type f \( -name "*.rej" -o -name "*.scratch.*" -o -name "*.scratch" -o -name "temp_*.py" -o -name "tmp_*.sh" -o -name "*.prompt.tmp" -o -path "*/scratch/tmp_*" -o -path "*/scratch/temp_*" \) \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/archive/*" \
  -print0 2>/dev/null || true)

# 3. 扫描传统临时与备份垃圾 (Garbage / Bak / Lock files)
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
  is_in_self_archive "$abs" && continue
  is_in_self_dir "$abs" && continue
  garbage_files+=("$f")
  f_size=$(wc -c < "$f" 2>/dev/null | tr -d ' ' || echo 0)
  total_freed_bytes=$((total_freed_bytes + f_size))
done < <(find . \
  -type f \( -name "*.bak" -o -name "*.bak2" -o -name "*.update.lock" -o -name "*~" -o -name "*.tmp" -o -name "*.orig" -o -name ".DS_Store" \) \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/archive/*" \
  -print0 2>/dev/null || true)

# 4. 扫描空草稿碎片 (< 100 字节且没有 frontmatter 的 markdown)
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
  -not -name "README.en.md" \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/templates/*" \
  -not -path "*/archive/*" \
  -print0 2>/dev/null || true)

# 5. 扫描项目构建缓存（仅在启用 --cache 时）
if [ "$ENABLE_CACHE" -eq 1 ]; then
  while IFS= read -r -d '' d; do
    [ -d "$d" ] || continue
    abs="$(cd "$d" && pwd)"
    is_in_self_archive "$abs" && continue
    is_in_self_dir "$abs" && continue
    project_caches+=("$d")
    d_kb=$(du -sk "$d" 2>/dev/null | awk '{print $1}' || echo 0)
    freed_cache_bytes=$((freed_cache_bytes + d_kb * 1024))
  done < <(find . \
    -type d \( -name "__pycache__" -o -name ".pytest_cache" -o -name ".turbo" -o -name ".next" -o -name ".eslintcache" \) \
    -not -path "*/.git/*" \
    -not -path "*/node_modules/*" \
    -not -path "*/archive/*" \
    -print0 2>/dev/null || true)
fi

# 6. 系统全局缓存预估（仅在启用 --system-cache 时）
if [ "$ENABLE_SYSTEM_CACHE" -eq 1 ]; then
  for p in "$HOME/.npm/_npx" "$HOME/Library/Caches/go-build" "$HOME/.cache/go-build" "$HOME/Library/Caches/pip" "$HOME/.cache/pip" "$HOME/Library/Caches/Homebrew"; do
    if [ -d "$p" ]; then
      p_kb=$(du -sk "$p" 2>/dev/null | awk '{print $1}' || echo 0)
      system_cache_freed_bytes=$((system_cache_freed_bytes + p_kb * 1024))
    fi
  done
  for up in "$HOME/Library/Caches/"*updater*; do
    if [ -d "$up" ]; then
      u_kb=$(du -sk "$up" 2>/dev/null | awk '{print $1}' || echo 0)
      system_cache_freed_bytes=$((system_cache_freed_bytes + u_kb * 1024))
    fi
  done
fi

freed_skills_count=${#tombstones[@]}
freed_ai_count=${#ai_artifacts[@]}
freed_garbage_count=${#garbage_files[@]}
freed_drafts_count=${#empty_drafts[@]}
freed_caches_count=${#project_caches[@]}
total_items=$((freed_skills_count + freed_ai_count + freed_garbage_count + freed_drafts_count + freed_caches_count))

# 预估 Token 释放量：仅针对文本类死物计算（1 Token ≈ 3.5 字节）
est_tokens=$(awk "BEGIN { printf \"%d\", $total_freed_bytes / 3.5 }")
[ -z "$est_tokens" ] && est_tokens=0

# 总计缩减磁盘容量（文本类 + 缓存类）
grand_total_bytes=$((total_freed_bytes + freed_cache_bytes + system_cache_freed_bytes))

# 孤立 worktree 列表（用于报告与 reap）
wt_reap_targets=()
wt_skip_targets=()
if [ -d .git ] || [ -f .git ]; then
  root_resolved="$(cd "$ROOT_PWD" 2>/dev/null && pwd)"
  while IFS= read -r wt; do
    [ -z "$wt" ] && continue
    wt_path="$(echo "$wt" | awk '{print $1}')"
    wt_resolved="$(cd "$wt_path" 2>/dev/null && pwd)"
    [ "$wt_resolved" = "$root_resolved" ] && continue
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

  if [ "$freed_ai_count" -gt 0 ]; then
    echo ""
    echo "🤖 发现【AI 幽灵碎片与临时脚手架】($freed_ai_count 个):"
    for f in "${ai_artifacts[@]}"; do echo "  - $f"; done
  else
    echo "  ✅ 无 AI 幽灵碎片"
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

  if [ "$ENABLE_CACHE" -eq 1 ]; then
    echo ""
    if [ "$freed_caches_count" -gt 0 ]; then
      echo "⚡ 发现项目构建缓存 ($freed_caches_count 个目录, 约 $(format_size "$freed_cache_bytes")):"
      for d in "${project_caches[@]}"; do echo "  - $d"; done
    else
      echo "  ✅ 无项目构建缓存"
    fi
  fi

  if [ "$ENABLE_SYSTEM_CACHE" -eq 1 ]; then
    echo ""
    echo "🧹 发现系统级包管理纯缓存: 预估可释放 $(format_size "$system_cache_freed_bytes")"
  fi

  # 工作树报告
  if [ -d .git ] || [ -f .git ]; then
    echo ""
    echo "🌳 Git Worktree 状态:"
    if [ "${#wt_reap_targets[@]}" -gt 0 ] || [ "${#wt_skip_targets[@]}" -gt 0 ]; then
      if [ "${#wt_reap_targets[@]}" -gt 0 ]; then
        echo "  🪓 可安全清理 (${#wt_reap_targets[@]} 个候选):"
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

if [ "$total_items" -eq 0 ] && [ "${#wt_reap_targets[@]}" -eq 0 ] && [ "$system_cache_freed_bytes" -eq 0 ]; then
  if [ "$SHARE_MODE" -eq 0 ]; then
    echo "🎉 恭喜！未发现任何死代码与墓碑，项目很干净！"
  fi
  exit 0
fi

if [ "$MODE" = "dry-run" ]; then
  if [ "$SHARE_MODE" -eq 1 ]; then
    cat <<EOF
==================================================
📜 🪦 墓碑收割·入土功德战报 (Burial Certificate 预览)
==================================================
  ⚰️  预估超度墓碑技能: $freed_skills_count 个
  🤖 预估粉碎 AI 碎片: $freed_ai_count 个
  📄 预估清理草稿碎片: $freed_drafts_count 份
  🗑️  预估粉碎幽灵垃圾: $freed_garbage_count 个文件
  🌳 预估清理孤立工作树: ${#wt_reap_targets[@]} 个
EOF
    [ "$ENABLE_CACHE" -eq 1 ] && echo "  ⚡ 预估清除项目缓存: $(format_size "$freed_cache_bytes")"
    [ "$ENABLE_SYSTEM_CACHE" -eq 1 ] && echo "  🧹 预估清理系统缓存: $(format_size "$system_cache_freed_bytes")"
    cat <<EOF
  🧠 预估释放上下文记忆: ~$est_tokens Tokens
  📦 预估缩减磁盘空间: ~$(format_size "$grand_total_bytes")
--------------------------------------------------
💬 悼词: 版本控制（Git）是它们的永生之地，工作区不是历史陈列馆。
==================================================

📢 [一键晒单 Markdown 文本（预览），可直接粘贴至 PR 或社交媒体] :

> 🪦 **Tombstone Reaper 减法战报 (预览)**
> 本次将超度 **$freed_skills_count** 个墓碑技能、**$freed_ai_count** 个 AI 碎片、**$freed_drafts_count** 份死文档、粉碎 **$freed_garbage_count** 个垃圾文件！
> 🧠 预计为 AI Agent 释放 **~$est_tokens** 个上下文 Token，缩减磁盘占用 **~$(format_size "$grand_total_bytes")**！
> *"立了墓碑不叫下线，入土为安才叫下线。"*
EOF
  else
    echo "💡 预估收益: 缩减磁盘约 $(format_size "$grand_total_bytes") / 释放约 $est_tokens 潜在上下文 Token"
    echo "💡 执行入土: 运行 $0 --bury"
  fi
  exit 0
fi

# ===== apply 模式 =====
if [ "$SHARE_MODE" -eq 0 ]; then
  echo ""
  echo "🚀 执行安全入土清理..."
fi

for f in "${ai_artifacts[@]}"; do
  rm -f "$f"
  [ "$SHARE_MODE" -eq 0 ] && echo "  🤖 已粉碎 AI 幽灵碎片: $f"
done

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
  case "$dir" in
    .) safe_name="$(basename "$ROOT_PWD")" ;;
    ./*) safe_name="${dir#./}"; safe_name="${safe_name//\//__}" ;;
    *) safe_name="${dir//\//__}" ;;
  esac
  mkdir -p "$ARCHIVE_DIR"
  target="$ARCHIVE_DIR/$safe_name"
  if [ -d "$target" ]; then rm -rf "$target"; fi

  if git rev-parse --git-dir >/dev/null 2>&1; then
    if ! git mv "$dir" "$target" 2>/dev/null; then
      mv "$dir" "$target"
    fi
  else
    mv "$dir" "$target"
  fi
  [ "$SHARE_MODE" -eq 0 ] && echo "  ⚰️  已安全归档墓碑技能: $dir → $target"
done

# 清理项目构建缓存
if [ "$ENABLE_CACHE" -eq 1 ]; then
  for d in "${project_caches[@]}"; do
    rm -rf "$d"
    [ "$SHARE_MODE" -eq 0 ] && echo "  ⚡ 已清除构建缓存目录: $d"
  done
fi

# 清理系统全局纯缓存
if [ "$ENABLE_SYSTEM_CACHE" -eq 1 ]; then
  [ "$SHARE_MODE" -eq 0 ] && echo "  🧹 执行系统依赖纯缓存安全清除..."
  npm cache clean --force >/dev/null 2>&1 || true
  rm -rf "$HOME/.npm/_npx" 2>/dev/null || true
  go clean -cache -testcache >/dev/null 2>&1 || true
  brew cleanup --prune=all >/dev/null 2>&1 || true
  python3 -m pip cache purge >/dev/null 2>&1 || rm -rf "$HOME/Library/Caches/pip" "$HOME/.cache/pip" 2>/dev/null || true
  rm -rf "$HOME/Library/Caches/"*updater* 2>/dev/null || true
fi

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
  echo '{"total_skills":0,"total_ai":0,"total_drafts":0,"total_garbage":0,"total_tokens":0,"total_cache_bytes":0}' > "$LEDGER"
fi

ledger_cache_delta=$((freed_cache_bytes + system_cache_freed_bytes))
ledger_ok=0
python3 <<PYEOF 2>>/tmp/reap-ledger.err && ledger_ok=1
import json
p = '$LEDGER'
try:
    d = json.load(open(p))
except Exception:
    d = {'total_skills':0,'total_ai':0,'total_drafts':0,'total_garbage':0,'total_tokens':0,'total_cache_bytes':0}
d['total_skills'] = d.get('total_skills', 0) + $freed_skills_count
d['total_ai'] = d.get('total_ai', 0) + $freed_ai_count
d['total_drafts'] = d.get('total_drafts', 0) + $freed_drafts_count
d['total_garbage'] = d.get('total_garbage', 0) + $freed_garbage_count
d['total_tokens'] = d.get('total_tokens', 0) + $est_tokens
d['total_cache_bytes'] = d.get('total_cache_bytes', 0) + $ledger_cache_delta
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
  cat <<EOF
==================================================
📜 🪦 墓碑收割·入土功德战报 (Burial Certificate)
==================================================
  ⚰️  超度墓碑技能: $freed_skills_count 个
  🤖 粉碎 AI 碎片: $freed_ai_count 个
  📄 清理草稿碎片: $freed_drafts_count 份
  🗑️  粉碎幽灵垃圾: $freed_garbage_count 个文件
  🌳 清理孤立工作树: ${#wt_reap_targets[@]} 个
EOF
  [ "$ENABLE_CACHE" -eq 1 ] && echo "  ⚡ 清除项目构建缓存: $(format_size "$freed_cache_bytes")"
  [ "$ENABLE_SYSTEM_CACHE" -eq 1 ] && echo "  🧹 清理系统依赖纯缓存: $(format_size "$system_cache_freed_bytes")"
  cat <<EOF
  🧠 释放上下文记忆: ~$est_tokens Tokens
  📦 缩减磁盘空间: ~$(format_size "$grand_total_bytes")
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
  echo "  🤖 粉碎 AI 碎片: $freed_ai_count 个"
  echo "  📄 清理草稿碎片: $freed_drafts_count 份"
  echo "  🗑️  粉碎幽灵垃圾: $freed_garbage_count 个文件"
  echo "  🌳 清理孤立工作树: ${#wt_reap_targets[@]} 个"
  [ "$ENABLE_CACHE" -eq 1 ] && echo "  ⚡ 清除项目构建缓存: $(format_size "$freed_cache_bytes")"
  [ "$ENABLE_SYSTEM_CACHE" -eq 1 ] && echo "  🧹 清理系统依赖纯缓存: $(format_size "$system_cache_freed_bytes")"
  echo "  🧠 释放上下文记忆: ~$est_tokens Tokens"
  echo "  📦 缩减磁盘空间: ~$(format_size "$grand_total_bytes")"
  echo "--------------------------------------------------"
  echo "💬 悼词: 版本控制（Git）是它们的永生之地，工作区不是历史陈列馆。"
  echo "=================================================="
fi

# 一键晒单 Markdown
echo ""
echo "📢 [一键晒单 Markdown 文本，可直接粘贴至 PR 或社交媒体] :"
echo ""
echo "> 🪦 **Tombstone Reaper 减法战报**"
echo "> 本次入土仪式已成功超度 **$freed_skills_count** 个墓碑技能、**$freed_ai_count** 个 AI 幽灵碎片、**$freed_drafts_count** 份死文档、粉碎 **$freed_garbage_count** 个垃圾文件！"
echo "> 🧠 累计为 AI Agent 释放 **~$est_tokens** 个上下文 Token，缩减磁盘占用 **~$(format_size "$grand_total_bytes")**！"
echo "> *\"立了墓碑不叫下线，入土为安才叫下线。\"*"
echo ""