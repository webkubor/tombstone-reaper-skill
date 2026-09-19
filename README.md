<h1 align="center">🪦 tombstone-reaper-skill</h1>

<p align="center">
  <strong>让死代码与墓碑技能真正入土为安，晒出你的减法战绩，终结 AI 时代的上下文污染。</strong>
</p>

<p align="center">
  <a href="https://github.com/webkubor/tombstone-reaper-skill/blob/main/LICENSE"><img src="https://img.shields.io/github/license/webkubor/tombstone-reaper-skill?style=for-the-badge" alt="License"></a>
  <a href="https://github.com/webkubor/tombstone-reaper-skill/releases"><img src="https://img.shields.io/github/v/release/webkubor/tombstone-reaper-skill?style=for-the-badge" alt="Release"></a>
  <a href="https://github.com/webkubor/tombstone-reaper-skill"><img src="https://img.shields.io/badge/Philosophy-Subtractive%20First-orange?style=for-the-badge" alt="Philosophy"></a>
</p>

<p align="center">
  <img src="https://cdn.jsdelivr.net/gh/webkubor/picx-images-hosting@master/tombstone-reaper/burial-certificate.png/%E6%88%AA%E5%B1%8F2026-09-19%2012.13.08.png" alt="Tombstone Reaper Cyberpunk Terminal UI" width="680" style="border-radius: 8px; box-shadow: 0 4px 20px rgba(0,255,170,0.15);">
</p>

---

## 🏆 为什么需要 Tombstone Reaper？ (Why This Table)

在传统开发中，死代码只是"看着难受"；而在 **AI Agent / LLM 时代，立了墓碑的死代码会直接烧钱（消耗 Token）、产生幻觉、并把废弃逻辑塞满上下文**。

| 现状与传统做法 | 典型后果 | 🪦 tombstone-reaper-skill 方案 |
|---|---|---|
| **立墓碑 (Tombstone)**：把废弃代码/技能加上注释 `// deprecated` 或 `【已停用】` 但留着文件 | 扫描器、RAG、Agent 检索依然把它塞进上下文，产生幻觉并浪费 Token | **入土安葬 (Bury)**：一键识别自称已废的死物，安全归档或物理移除 |
| **AI 幽灵残留**：Agent 调试留下的 `*.rej`、`scratch/` 脚本、临时 prompt 文件 | 再次被 Agent 检索扫描，引发多轮幻觉并污染上下文 | **AI 碎片清道夫**：精准定位并物理粉碎所有 AI 遗留脚手架 |
| **偷偷减法，无人知晓**：删除了几千行死代码，团队没人感知 | 开发者缺乏做减法的成就感，倾向于一直堆积"加法" | **入土功德战报**：自动生成炫酷的「减法战报」，晒出超度技能数与释放 Token |
| **临时文件堆积**：构建调试留下的 `*.bak`、`*.tmp`、`*.orig`、`.DS_Store` | 污染 `git status`，极易意外 commit 进版本历史 | **雷达粉碎**：自动嗅探并清理所有无用的备份与临时镜像 |
| **依赖缓存膨胀**：开发环境残留几十 GB 的 npm/go/pip/brew 构建缓存 | 蚕食硬盘容量，拖慢 IDE 索引速度 | **深度减法 (`--cache`/`--deep`)**：一键安全蒸发系统与项目构建垃圾 |
| **不敢删代码**："万一以后还要用呢？" | 仓库无限熵增，每个未来的维护者都要多花 10 分钟重新判断 | **版本控制即永生**：无用即删除的充分理由，Git 历史就是终极安全网 |

---

## 📜 晒出你的减法战报 (Bragging & Certificate)

每次执行入土清理，终端自动渲染高饱和度的**赛博朋克入土战报卡片**与一键复制 Markdown：

```markdown
==================================================
📜 🪦 墓碑收割·入土功德战报 (Burial Certificate)
==================================================
  ⚰️  超度墓碑技能: 3 个
  🤖 粉碎 AI 碎片: 5 份
  📄 清理草稿碎片: 14 份
  🗑️  粉碎幽灵垃圾: 8 个文件
  🌳 清理孤立工作树: 2 个
  ⚡ 清除项目构建缓存: 120 MB
  🧹 清理系统依赖纯缓存: 11.3 GB
  🧠 释放上下文记忆: ~15,200 Tokens
  📦 缩减磁盘空间: ~11.4 GB
--------------------------------------------------
💬 悼词: 版本控制（Git）是它们的永生之地，工作区不是历史陈列馆。
==================================================
```

---

## ⚡ 30 秒快速上手 (Quickstart)

无需任何复杂依赖，纯 Bash 驱动，随时随地在任何项目根目录下运行：

```bash
# 1. 运行验尸报告（只读，查看有哪些死物与墓碑）
./scripts/reap.sh --check        # 或 --dry-run，等价

# 2. 执行常规安全入土（清理墓碑、AI 碎片、临时垃圾并生成功德战报）
./scripts/reap.sh --bury         # 或 --apply，等价

# 3. 全量深度减法（含项目构建缓存与系统级包管理器纯缓存）
./scripts/reap.sh --bury --deep   # 或 --all，彻底回血数 GB 磁盘

# 4. 只打晒单卡片，跳过逐项清单（适合贴 PR / 社交媒体）
./scripts/reap.sh --bury --share

# 4. 查看累计功德账本
./scripts/reap.sh --stats
```

---

## 🤖 作为 AI Agent 技能接入

本仓库完全符合 `CS Skill Spec v1.0` 规范，只需挂载 `SKILL.md`，你的 Agent（Claude Code / Codex / DSH / Cursor）即可获得清道夫本能：
* 唤醒词：`"收割墓碑"`、`"清理死代码"`、`"减法优先"`、`"tombstone"`、`"看看有什么该删的"`。

---

## 🧪 本地自检

```bash
bash tests/run.sh
```

跑一遍 fixtures 验尸报告 + 入土链路，确认脚本在改动后没退化。

---

## 📄 开源协议

基于 [MIT License](./LICENSE) 开源。欢迎 Star 与提 Issue 贡献你的收割规则！