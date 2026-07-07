# ai_video — HCHAIN Harness Install/Update Procedure (STEP 5)

Date: 2026-05-25  
Target project: `~/workspace/ai_video`  
HCHAIN Core: `~/workspace/hchain`

---

## Current State

| Item | Status |
|------|--------|
| `.hchain/meta.json` | ❌ Not installed |
| `harness/` directory | ❌ Absent |
| `CLAUDE.md` policy block | ❌ Not injected |

ai_video has no hchain installation. Use the **Install** procedure below.

---

## Procedure A — First Install

Run from any directory:

```bash
bash ~/workspace/hchain/install.sh --target ~/workspace/ai_video
```

What this does:
1. Creates `ai_video/.hchain/meta.json` (version + commit stamp)
2. Copies `harness/` from HCHAIN Core templates (scripts, agents, docs, queue dirs)
3. Creates `ai_video/CLAUDE.md` (or appends to existing) with HCHAIN policy block

Preview first (no files written):

```bash
bash ~/workspace/hchain/install.sh --target ~/workspace/ai_video --dry-run
```

---

## Procedure B — Update (after HCHAIN Core update)

Use when HCHAIN Core has been updated and you want to push new harness scripts
to ai_video without losing existing tasks, logs, or findings.

```bash
# Preview changes first
bash ~/workspace/hchain/install.sh \
  --target ~/workspace/ai_video \
  --update --dry-run

# Apply update
bash ~/workspace/hchain/install.sh \
  --target ~/workspace/ai_video \
  --update
```

### What is preserved (never touched)

| Path | Reason |
|------|--------|
| `harness/active_state.json` | Live runtime state |
| `harness/tasks/` | User-authored task definitions |
| `harness/logs/` | Execution history |
| `harness/findings/` | Issue backlog (open/accepted/resolved/rejected) |
| `harness/queue/pending/` | Pending task markers |
| `harness/queue/running/` | Running task markers |
| `harness/queue/done/` | Done task markers |
| `harness/queue/blocked/` | Blocked task markers |

### What is overwritten (safe to replace)

| Path | Reason |
|------|--------|
| `harness/harness_runner.sh` | Core orchestrator — always use latest |
| `harness/queue/check_consistency.sh` | Consistency checks — bug fixes apply |
| `harness/queue/move.sh` | Queue move helper |
| `harness/lib/*.sh` | Library functions |
| `harness/agents/*.md` | Agent prompt templates |
| `harness/docs/` | Policy documents |
| `harness/GUIDE.md` | Quick guide |
| `CLAUDE.md` (policy block only) | Policy markers idempotently updated |

---

## Verify Install

```bash
bash ~/workspace/hchain/install.sh --verify ~/workspace/ai_video
```

Expected output:
```
[hchain] installed at ~/workspace/ai_video
  "hchain_version": "0.1.0",
  "hchain_commit": "...",
  "installed_at": "..."
```

## Queue Consistency Check (post-install)

```bash
bash ~/workspace/ai_video/harness/queue/check_consistency.sh
bash ~/workspace/ai_video/harness/queue/check_consistency.sh --extended
```

---

## Notes

- `harness_runner.sh` requires **bash 4.0+**. On macOS: `brew install bash`.
- `check_consistency.sh` is bash 3.2 compatible (safe on macOS default shell).
- After install, add task files to `harness/tasks/TASK_YYYYMMDD_NNN.md` following
  the format in `harness/docs/TASK_GUIDE.md`.
