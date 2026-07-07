# HCHAIN Commands Reference

Only verified, implemented commands are listed here.  
Commands marked **[확인 필요]** have not been verified in source code.

---

## Install / Update (run from HCHAIN Core directory)

```bash
# Install to target project
bash install.sh <target_project_path>
bash install.sh --target /path/to/project

# Dry-run (preview changes, no writes)
bash install.sh --target /path/to/project --dry-run

# Verify installation status
bash install.sh --verify /path/to/project

# Update (preserves task/log/queue data)
bash install.sh --target /path/to/project --update
bash install.sh --target /path/to/project --update --dry-run
```

**Note:** `--update` requires `.hchain/meta.json` to exist. Fails on uninstalled targets.

---

## harness_runner.sh (run from target project root)

```bash
# Run a task
bash harness/harness_runner.sh --task TASK_20260101_001

# Resume interrupted task
bash harness/harness_runner.sh --resume TASK_20260101_001

# List all tasks
bash harness/harness_runner.sh --list

# Check task status
bash harness/harness_runner.sh --status TASK_20260101_001

# Chain — run all pending tasks
bash harness/harness_runner.sh --chain

# Chain — run range (from → to)
bash harness/harness_runner.sh --chain --from TASK_001 --to TASK_005

# Chain — run selected tasks
bash harness/harness_runner.sh --chain --select TASK_001,TASK_003

# Findings backlog summary
bash harness/harness_runner.sh --findings

# List open findings
bash harness/harness_runner.sh --findings --open

# Create task draft from finding
bash harness/harness_runner.sh --findings --materialize FINDING_ID
```

### Flags (combinable with --task / --resume)

| Flag | Effect |
|------|--------|
| `--dry-run` | Simulate; no writes |
| `--force` | Force resume even if running state |
| `--override-severity MAJOR\|MINOR\|NIT` | Change severity stop threshold |
| `--skip-validate` | Skip VALIDATE stage (use sparingly) |
| `--no-chain` | Prevent auto-chaining to next task |
| `--auto-commit` | Git commit after DONE |

### Environment Variables

| Variable | Effect |
|----------|--------|
| `HARNESS_AUTO_COMMIT=1` | Auto git commit after DONE |
| `HARNESS_AUTO_CONFIRM=1` | Skip interactive y/N gates |
| `HARNESS_TOKEN_LIMIT` | Token budget guard |
| `GEMINI_TIMEOUT` | RESEARCH timeout (default: 900s) |
| `CODEX_TIMEOUT` | REVIEW timeout (default: 1200s) |
| `VALIDATE_TIMEOUT_DEFAULT` | VALIDATE timeout (default: 600s) |
| `VALIDATE_TIMEOUT_E2E` | E2E VALIDATE timeout (default: 1800s) |

---

## check_consistency.sh

```bash
# Check queue consistency
bash harness/queue/check_consistency.sh

# Extended check
bash harness/queue/check_consistency.sh --extended
```

---

## move.sh

```bash
# Move task between queue states
bash harness/queue/move.sh TASK_ID <from_state> <to_state>
# Example:
bash harness/queue/move.sh TASK_20260101_001 pending running
```

---

## Alias / Shorthand Commands

> **[확인 필요]** — The following aliases (`hn`, `hchain`) have been mentioned but  
> are NOT verified in the HCHAIN Core source. Confirm with `which hn` or `which hchain`  
> before using. They may be user-defined shell aliases set up post-install.

---

## State File Locations

| File | Purpose |
|------|---------|
| `harness/active_state.json` | Currently running task state |
| `harness/tasks/TASK_ID.md` | Task definition |
| `harness/tasks/TASK_ID.state.json` | Task execution state |
| `harness/tasks/TASK_ID.checkpoint.json` | Resume checkpoint |
| `.hchain/meta.json` | Installation metadata |
| `harness/queue/pending/` | Pending task markers |
| `harness/queue/running/` | Running task markers |
| `harness/queue/done/` | Completed task markers |
| `harness/queue/blocked/` | Blocked task markers |
| `harness/logs/` | Agent execution logs |
| `harness/findings/open/` | Open issue backlog |
