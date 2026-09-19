# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [1.1.0] - 2026-09-19

### 新特性 (Features)

- **🤖 AI 幽灵碎片收割**：自动定位并物理粉碎 AI Agent 遗留的脚手架、`*.rej`（Patch 失败抛弃块）、`*.scratch.*`、`scratch/temp_*` 临时脚本，防止污染后续 Agent 检索池并造成逻辑幻觉。
- **⚡ 依赖与构建缓存安全蒸发 (`--cache` / `--system-cache` / `--deep`)**：
  - 项目级缓存：`__pycache__`、`.pytest_cache`、`.turbo`、`.next`、`.eslintcache` 等；
  - 开发者全局依赖缓存：一键安全清理 `npm` 临时全局包与 npx 运行时（`~/.npm/_npx`）、`pip` wheel 缓存、`go clean -cache`、`brew cleanup` 及桌面客户端更新残留（`~/Library/Caches/@*updater`）。
- **📜 功德卡片全面升级**：卡片支持独立展示 AI 碎片粉碎数量、项目缓存与系统依赖缓存释放体积，磁盘空间按 B/KB/MB/GB 动态单位换算，减法战绩一目了然。

## [1.0.1] - 2026-09-18

### 修复（Round 3 起持续打磨）

- **自我排除**：reap.sh 不再吃自己的目录 / 自己的归档（避免「自食其果」）
- **撞名归档**：归档目录同名时按版本号 / 时间戳自增，避免覆盖
- **macOS 兼容**：`/tmp` 在 macOS 是 `/private/tmp` 符号链接，路径解析统一走 `cd && pwd` 兼容
- **工作树 reap**：HEAD 干净且非主工作树的安全 prune（仅 `--apply` 模式）
- **未知参数 `exit 2`**（Round 2 修复）：`--typo` / 非目录的 arg 不再静默回退 dry-run

## [1.0.0] - 2026-09-?? (init)

- `feat: 支持 --stats 随时查看累计功德账本`
- `feat: 🪦 初始化 tombstone-reaper-skill 墓碑收割与减法清道夫`

### 触发对象（v1 起稳定）

- ⚰️ **墓碑技能**：`SKILL.md` frontmatter 自称已废（【已停用】/`status: deprecated`/…）
- 🗑️ **幽灵垃圾**：`*.bak` / `*.bak2` / `*.update.lock` / `*~` / `*.tmp` / `*.orig` 等临时与备份
- 📄 **草稿碎片**：< 100 字节且无 frontmatter 的散落 `.md`
- 🌳 **孤立工作树**：仅 `--apply` —— HEAD 干净且非主工作树，安全 prune

---

完整 commit 列表见 `git log`。