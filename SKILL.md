---
name: tombstone-reaper-skill
version: 1.0.0
description: "代码与技能墓碑收割机 — 识别并清除代码库中「自称已废」的墓碑技能、死代码、临时备份文件与幽灵资产，自动统计释放的 Token 与战报卡片。无用本身就是删除的充分理由，立了墓碑不叫下线，入土为安才叫下线。触发词: 墓碑、死代码、减法、垃圾回收、清理无用、tombstone、reaper、清理技能、代码下线、gc、减法优先、tombstone-reaper。"
license: MIT
author: webkubor
category: devops
platforms: [linux, macos]
metadata:
  openclaw:
    tags: [devops, cleanup, gc, dead-code, maintenance, tombstone]
    requires:
      bins: [bash, git]
---

# 🪦 墓碑收割者 (Tombstone Reaper)

> **“立了墓碑不叫下线，入土为安才叫下线。”**  
> 很多开发者在废弃某项功能时，习惯把文件头部改成 `【已停用】`、`deprecated`，以为结案了 —— 这是**立了墓碑**。  
> 墓碑比死代码更危险：它占着检索池，霸占触发词，继续污染 Agent 上下文并消耗 Token。

---

## 核心定律（减法优先）

依据系统思维宪法：**“无用本身就是删除的充分理由。删除不需要论证，保留才需要。”**
- **保留的代价**：分摊在未来的每一次 Agent 搜索、每一次 RAG 检索和每一个开发者的理解成本上。
- **删除的代价**：一次性的、完全可逆的（一次 `git revert` 即可召回）。版本控制就是它的永生之地，代码库工作区不是历史陈列馆。

---

## 收割四大对象（Tombstones）

| 类型 | 典型症状 | 危害 | 处置方式 |
|---|---|---|---|
| **⚰️ 墓碑技能** | `SKILL.md` 写着 `【已停用】`、`已废弃`、`该链路退役` | 占着关键词，Agent 依然会被误触发 | 移入 `archive/skills/` 或物理删除 |
| **🗑️ 幽灵垃圾** | `*.bak`、`*.bak2`、`*.tmp`、`*.update.lock` | 污染 `git status`，容易误提交进仓库 | 彻底粉碎删除 |
| **📄 草稿碎片** | 长期未跟踪、<100 字节且无 frontmatter 的散落 `.md` | 误导全局搜索，形成知识噪音 | 归档或删除 |
| **🌳 孤立工作树** | 关联任务已结束但未 prune 的 `git worktree` | 导致本地全局搜索（grep/find）双倍冗余 | `git worktree remove` 安全解绑 |

---

## 快速开始

### 1. 运行验尸报告（只读安全检查）
```bash
bash skills/devops/tombstone-reaper/scripts/reap.sh --check
```

### 2. 执行入土安葬（安全清理）
```bash
bash skills/devops/tombstone-reaper/scripts/reap.sh --apply
```

---

## 自动化判定铁律

命中以下任意一条，**直接执行减法，不需要请示**：
1. **自称已废**：文件头部已显式声明“已废弃/已停用/已退役”；
2. **零调用且目标已死**：它所调用的 API/数据表/CLI 已从系统中物理移除；
3. **临时产物**：构建过程生成的 `.bak`、`.orig`、`.update.lock` 文件。

---

## 恢复方式（如何从冥界召回）

任何通过本工具清理的内容都受 Git 严密保护：
```bash
git checkout HEAD~1 -- path/to/resurrected-file
# 或
git revert <cleanup-commit-hash>
```
不用担心误删，勇敢做减法！
