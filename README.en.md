<h1 align="center">🪦 tombstone-reaper-skill</h1>

<p align="center">
  <strong>Actually bury dead code and tombstoned skills, brag about your subtraction scoreboard, end context-pollution in the AI era.</strong>
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

## 🏆 Why Tombstone Reaper?

In classic development, dead code is just "ugly to look at"; but in the **AI agent / LLM era**, tombstoned code directly burns money (tokens), produces hallucinations, and stuffs deprecated logic into context.

| Today & classic practice | Typical consequence | 🪦 tombstone-reaper-skill solution |
|---|---|---|
| **Tombstone**: mark dead code/skills with `// deprecated` or `【已停用】` and leave the file | Scanners, RAG, and agent retrieval still push it into context — hallucinations and wasted tokens | **Bury**: one-shot identification of self-declared dead things, safe archive or physical removal |
| **AI Ghost Artifacts**: scratch scripts, `*.rej` patches, temp test files left by agents | Pollutes subsequent agent searches, causing hallucination loops and wasted context | **AI Ghost Reaper**: pinpoint and permanently smash agent residue and temporary scaffolds |
| **Silent subtraction, nobody notices**: deleted thousands of lines of dead code, the team has no idea | Developers lack the dopamine hit of subtraction, lean toward perpetually piling on "additions" | **Burial scoreboard**: auto-generates a snappy "subtraction report" — skills reaped, tokens freed |
| **Temp-file piles**: `*.bak` / `*.tmp` / `*.orig` / `.DS_Store` left from build debugging | Pollutes `git status`, easy to accidentally commit into history | **Radar smash**: auto-sniff and clean every useless backup and temporary mirror |
| **Cache bloat**: gigabytes of dormant npm/pip/go/brew build cache eating up disk space | Slows down indexing and silently consumes tens of GBs of local disk space | **Deep subtraction (`--cache`/`--deep`)**: safely evaporate build artifacts & system dependencies |
| **Afraid to delete**: "what if we need it later?" | The repo's entropy grows unbounded; every future maintainer pays an extra 10 minutes re-evaluating | **Git history is immortality**: uselessness is sufficient reason to delete; git history is the ultimate safety net |

---

## 📜 Brag about your subtraction scoreboard

Every burial run auto-generates a one-click-paste-able scoreboard for GitHub PRs and social media:

```markdown
==================================================
📜 🪦 Tombstone Reaper · Burial Certificate
==================================================
  ⚰️  Tombstoned skills reaped: 3
  🤖  AI ghost fragments smashed: 5
  📄  Draft fragments cleaned: 14
  🗑️  Ghost garbage smashed: 8 files
  🌳  Orphan worktrees pruned: 2
  ⚡  Project build cache cleared: 120 MB
  🧹  System dependency cache purged: 11.3 GB
  🧠  Context memory freed: ~15,200 tokens
  📦  Disk space reclaimed: ~11.4 GB
--------------------------------------------------
💬 Epitaph: Version control (Git) is their immortal home; the working tree is not a history museum.
==================================================
```

---

## ⚡ 30-second quickstart

No complex dependencies. Pure Bash driver. Run from any project root:

```bash
# 1. Run the autopsy (read-only — see what's dead)
./scripts/reap.sh --check        # alias: --dry-run

# 2. Execute safe burial (run cleanup, archive, generate scoreboard)
./scripts/reap.sh --bury         # alias: --apply

# 3. Deep subtraction (clean project build cache & system-level dev cache)
./scripts/reap.sh --bury --deep  # alias: --all (reclaims gigabytes of disk space)

# 4. Just the brag card, skip the per-item list (good for PR / social)
./scripts/reap.sh --bury --share

# 4. View the lifetime karma ledger
./scripts/reap.sh --stats
```

---

## 🤖 Hook as an AI Agent skill

Fully complies with `CS Skill Spec v1.0`. Mount `SKILL.md` and your agent (Claude Code / Codex / DSH / Cursor) gains the reaper instinct:

- Trigger words: `"reap tombstones"`, `"clean dead code"`, `"subtract-first"`, `"tombstone"`, `"show what should be deleted"`.

---

## 🧪 Local self-check

```bash
bash tests/run.sh
```

Runs the fixture autopsy + burial path, confirming the script hasn't regressed after edits.

---

## 📄 License

MIT — see [LICENSE](./LICENSE). Stars and issues welcome — contribute your reaping rules!