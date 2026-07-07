# HCHAIN install.sh — Audit Report (STEP 1)

Date: 2026-05-25  
Auditor: Claude (automated)

---

## 1. Current State (pre-change)

| Item | Status |
|------|--------|
| install.sh exists | ✅ |
| --version flag | ✅ |
| --verify flag | ✅ |
| --help flag | ✅ |
| positional target arg | ✅ |
| harness/ directory installation | ❌ Missing |
| --update flag | ❌ Missing |
| --dry-run flag | ❌ Missing |
| CLAUDE.md policy injection | ❌ Missing |
| templates/harness/ exists | ✅ (created this session) |

## 2. Findings

### F1 — No harness installation (HIGH)
`install.sh` only creates `.hchain/meta.json`. Running it does not install
`harness_runner.sh`, queue directories, lib/, agents/, or docs/ into the target
project. Projects cannot run tasks without a separate manual copy step.

### F2 — No --update flag (HIGH)
There is no safe update mechanism. Updating HCHAIN in an existing project
requires manual file replacement, risking data loss in tasks/, logs/, findings/.

### F3 — No --dry-run flag (MEDIUM)
Operators cannot preview what will change before running install/update.

### F4 — No CLAUDE.md policy injection (MEDIUM)
Projects that receive the harness get no automatic enforcement that Claude
must route work through HCHAIN tasks. Policy must be added by hand.

### F5 — bash version warning present, coverage incomplete (LOW)
`_check_bash_version` warns on bash < 4 but only during install. Individual
harness scripts that require bash 4+ should carry their own guard — this is
already done in harness_runner.sh via `#!/usr/bin/env bash` + BASH_VERSINFO.

## 3. Safe-to-preserve data directories (identified)

The following must NOT be overwritten during --update:

- `harness/active_state.json` — live runtime state
- `harness/tasks/` — task definition files (user-authored)
- `harness/logs/` — execution logs
- `harness/findings/` — issue backlog (open/accepted/resolved/rejected)
- `harness/queue/pending/`, `running/`, `done/`, `blocked/` — marker files

The following are safe to overwrite:

- `harness/harness_runner.sh`
- `harness/queue/check_consistency.sh`, `queue/move.sh`
- `harness/lib/*.sh`
- `harness/agents/*.md`
- `harness/docs/`
- `harness/GUIDE.md`

## 4. Conclusion

install.sh must be extended with harness installation, --update, --dry-run,
and CLAUDE.md injection. See `docs/install_update_design.md` for the design.
