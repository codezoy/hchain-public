# HCHAIN install.sh — Install/Update Design (STEP 2)

Date: 2026-05-25

---

## 1. Goals

1. Single entry point (`install.sh`) for both fresh install and safe update.
2. No data loss during update — task, log, queue, and findings data preserved.
3. CLAUDE.md policy automatically injected/updated so AI agents enforce HCHAIN.
4. Dry-run mode lets operators preview changes before committing.
5. Backward compatibility: existing positional-arg usage still works.

---

## 2. Flag Design

| Flag | Description |
|------|-------------|
| `<path>` (positional) | Target project directory (backward compat) |
| `--target <path>` | Target project directory (preferred) |
| `--update` | Safe update mode — preserve data, overwrite scripts |
| `--dry-run` | Print what would change; write nothing |
| `--verify <path>` | Check if hchain is installed (unchanged) |
| `--version` | Print version (unchanged) |
| `--help` | Print help (unchanged) |

Flags are combinable: `--target /path --update --dry-run`

---

## 3. Install Flow (fresh)

```
cmd_run (MODE=install)
  └─ cmd_install_harness
       ├─ Walk templates/harness/ (find -print0 | sort)
       ├─ mkdir -p for each directory
       ├─ Copy each file (chmod +x for .sh)
       └─ .gitkeep: create dir, write only if empty
  └─ _inject_claude_policy
       ├─ If CLAUDE.md absent → create with policy block
       ├─ If marker present  → replace block between markers
       └─ If marker absent   → append block
  └─ cmd_write_meta
       └─ Write .hchain/meta.json (version, commit, timestamp, host, os)
```

---

## 4. Update Flow (--update)

Same as install flow but `_is_preserved` gates every file write:

```
_is_preserved(rel):
  active_state.json       → SKIP (preserve runtime state)
  tasks/**                → SKIP (user task definitions)
  logs/**                 → SKIP (execution history)
  findings/**             → SKIP (issue backlog)
  queue/pending/**        → SKIP (pending markers)
  queue/running/**        → SKIP (running markers)
  queue/done/**           → SKIP (done markers)
  queue/blocked/**        → SKIP (blocked markers)
  <all other files>       → OVERWRITE (scripts, agents, docs, GUIDE.md)
```

Entering --update without an existing `.hchain/meta.json` → error + hint.

---

## 5. CLAUDE.md Policy Injection

Policy block delimited by HTML comments:

```
<!-- HCHAIN_POLICY_START -->
...policy content...
<!-- HCHAIN_POLICY_END -->
```

Logic:
- File absent → create with policy block
- Marker present → awk replaces between markers (idempotent)
- Marker absent → append policy block with leading newline

The policy block text is hardcoded in install.sh (no external file dependency).

---

## 6. Dry-run Mode

When `--dry-run` is set:
- All `cp`, `mkdir`, `cat >`, `printf` calls are replaced with `dry "ACTION path"` log lines.
- No files are written.
- Exit code 0 on success.

---

## 7. Compatibility

- install.sh itself: bash 3.2+ (no `declare -A`, no `[[` outside safe constructs)
- templates/harness/harness_runner.sh: bash 4.0+ (documented in GUIDE.md)
- `check_consistency.sh`: bash 3.2+ (tmpfile pattern, already validated)

---

## 8. Template Source

All harness files are sourced from `$HCHAIN_ROOT/templates/harness/`.
This directory is populated from `itemlabs_v3/harness/` and is version-controlled
inside HCHAIN Core, making the installer self-contained.
