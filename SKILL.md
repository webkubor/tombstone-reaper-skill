---
name: tombstone-reaper-skill
version: 1.1.0
description: "代码与技能墓碑收割机 — 识别并清除代码库中「自称已废」的墓碑技能、AI 幽灵碎片、死代码、临时备份与无用构建缓存，自动统计释放的 Token 与战报卡片。无用本身就是删除的充分理由，立了墓碑不叫下线，入土为安才叫下线。触发词: 墓碑、死代码、减法、垃圾回收、清理无用、tombstone、reaper、清理技能、代码下线、gc、减法优先、tombstone-reaper。"
license: MIT
author: webkubor
category: devops
platforms: [linux, macos]
metadata:
  openclaw:
    tags: [devops, cleanup, gc, dead-code, maintenance, tombstone, ai-artifacts, cache]
    requires:
      bins: [bash, git, python3, find, du, wc, grep]
---

# 🪦 墓碑收割者 (Tombstone Reaper)

> **"立了墓碑不叫下线，入土为安才叫下线。"**  
> 很多开发者在废弃某项功能时，习惯把文件头部改成 `【已停用】`、`deprecated`，以为结案了 —— 这是**立了墓碑**。  
> 墓碑比死代码更危险：它占着检索池，霸占触发词，继续污染 Agent 上下文并消耗 Token。

---

## 核心定律（减法优先）

依据系统思维宪法：**"无用本身就是删除的充分理由。删除不需要论证，保留才需要。"**
- **保留的代价**：分摊在未来的每一次 Agent 搜索、每一次 RAG 检索和每一个开发者的理解成本上。
- **删除的代价**：一次性的、完全可逆的（一次 `git revert` 即可召回）。版本控制就是它的永生之地，代码库工作区不是历史陈列馆。

---

## 收割核心对象（Tombstones & Ghosts）

| 类型 | 典型症状 | 危害 | 处置方式 |
|---|---|---|---|
| **⚰️ 墓碑技能** | `SKILL.md` 前 25 行 frontmatter 含 `【已停用】`、`已废弃`、`该链路退役` 或 `status: deprecated` | 占着关键词，Agent 依然会被误触发 | `git mv` 进 `archive/skills/`（保留 rename 历史） |
| **🤖 AI 幽灵** | `*.rej`（Patch 失败抛弃块）、`*.scratch.*`、`scratch/temp_*`、`temp_*.py` | 污染 Agent 检索上下文，产生模型幻觉 | 彻底粉碎删除 |
| **🗑️ 幽灵垃圾** | `*.bak`、`*.bak2`、`*.update.lock`、`*~`、`.DS_Store` | 污染 `git status`，容易误提交进仓库 | 彻底粉碎删除 |
| **📄 草稿碎片** | < 100 字节且无 frontmatter 的散落 `.md` | 误导全局搜索，形成知识噪音 | 归档或删除 |
| **🌳 孤立工作树** | 关联任务已结束、HEAD 干净但未 prune 的 `git worktree` | 导致本地全局搜索（grep/find）双倍冗余 | `--apply` 模式下 `git worktree remove` 安全解绑 |
| **⚡ 构建与系统缓存** | 项目级 `__pycache__` / `.turbo` 及系统级包管理器（npm/pip/go/brew）缓存 | 白白蚕食数 GB 到数十 GB 磁盘空间 | 需加 `--cache` 或 `--system-cache` 触发清理 |

---

## 快速开始

### 1. 运行验尸报告（只读安全检查）
```bash
bash scripts/reap.sh --check      # 或 --dry-run
```

### 2. 执行常规入土安葬（清理墓碑、AI 碎片与垃圾）
```bash
bash scripts/reap.sh --bury       # 或 --apply（两者完全等价）
```

### 3. 全量深度减法（含项目构建缓存与系统纯缓存）
```bash
bash scripts/reap.sh --bury --deep # 或 --all
```

### 4. 只打晒单卡片（适合贴 PR / 社交媒体）
```bash
bash scripts/reap.sh --bury --share
```

### 5. 查看累计功德账本
```bash
bash scripts/reap.sh --stats
```

> 旧版示例路径 `skills/devops/tombstone-reaper/scripts/reap.sh` 是历史命名；当前仓库路径是 `scripts/reap.sh`（仓库根即 SKILL 根）。

---

## 自动化判定铁律

命中以下任意一条，**直接执行减法，不需要请示**：
1. **自称已废**：SKILL.md 前 25 行已显式声明"已废弃/已停用/已退役/status: deprecated"；
2. **零调用且目标已死**：它所调用的 API/数据表/CLI 已从系统中物理移除；
3. **临时产物**：构建过程生成的 `.bak`、`.bak2`、`.update.lock`、`~` 文件。

---

## 行为约束（自我保护，避免自食其果）

- **自身目录排除**：脚本会在每次启动时锚定 `SELF_DIR`，任何落在自身目录（含 `archive/skills/`）下的命中都会被跳过，避免 reaper 在自己仓库跑时把 SKILL.md 自己归档了。
- **`archive/` 排除锚定自身**：用户项目里已有的 `archive/` 不会被一刀切排除 —— 只排除 reaper 自己的归档根。
- **撞名防御**：归档目标用「完整相对路径以 `/` 换 `__`」命名，`plugins/auth/SKILL.md` 与 `tools/auth/SKILL.md` 不会互相覆盖。
- **空草稿阈值**：< 100 字节且无 frontmatter 的 `.md` 才算碎片（≈ 30 CJK 或 100 ASCII 字符以内）。

---

## 恢复方式（如何从冥界召回）

任何通过本工具清理的内容都受 Git 严密保护：
```bash
git checkout HEAD~1 -- path/to/resurrected-file
# 或
git revert <cleanup-commit-hash>
```
不用担心误删，勇敢做减法！