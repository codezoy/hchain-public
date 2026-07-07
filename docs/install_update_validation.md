# HCHAIN install.sh — Validation Results (STEP 4)

Date: 2026-05-25  
Target: `/tmp/hchain-test-project`  
HCHAIN version: 0.1.0 (commit: b2651d9)

---

## Test 1 — Fresh install dry-run

```
bash install.sh --target /tmp/hchain-test-project --dry-run
```

Result: PASS  
All expected CREATE/MKDIR lines shown; no files written.

Expected output (abbreviated):
```
[hchain] Mode: INSTALL
[hchain] DRY-RUN enabled — no files will be written
[dry-run] CREATE    harness/GUIDE.md
[dry-run] CREATE    harness/active_state.json
[dry-run] MKDIR     harness/agents/
...
[dry-run] CREATE    harness/harness_runner.sh
...
[dry-run] CREATE /tmp/.../CLAUDE.md (new file with policy block)
[dry-run] WRITE /tmp/.../.hchain/meta.json
[hchain] dry-run complete — no changes made
```

Verified: no files created in target after dry-run.

---

## Test 2 — Fresh install (real)

```
bash install.sh --target /tmp/hchain-test-project
```

Result: PASS

Files created:
- `.hchain/meta.json` — version, commit, timestamp, host, os
- `CLAUDE.md` — policy block injected
- `harness/harness_runner.sh` — executable
- `harness/queue/check_consistency.sh` — executable
- `harness/queue/move.sh` — executable
- `harness/lib/*.sh` — executable
- `harness/agents/*.md`
- `harness/docs/*.md`
- `harness/GUIDE.md`
- `harness/active_state.json` — IDLE state template
- Data dirs: `tasks/`, `logs/`, `findings/(open|accepted|resolved|rejected)/`, `queue/(pending|running|done|blocked)/` — each with `.gitkeep`

CLAUDE.md content verified: contains `<!-- HCHAIN_POLICY_START -->` and `<!-- HCHAIN_POLICY_END -->` markers with full policy body.

---

## Test 3 — Update dry-run (with existing data)

Pre-condition: seeded test project with:
- `harness/tasks/TASK_001.md`
- `harness/logs/TASK_001.log`
- `harness/findings/open/FIND_001.md`
- `harness/queue/pending/TASK_001`
- `harness/active_state.json` (set to `{"status":"running"}`)

```
bash install.sh --target /tmp/hchain-test-project --update --dry-run
```

Result: PASS

Key lines observed:
```
[dry-run] PRESERVE  harness/active_state.json (data file)
[dry-run] OVERWRITE harness/GUIDE.md
[dry-run] OVERWRITE harness/harness_runner.sh
[dry-run] OVERWRITE harness/lib/findings.sh
...
[dry-run] UPDATE /tmp/.../CLAUDE.md (replace existing HCHAIN policy block)
```

tasks/, logs/, findings/, queue/pending/ marker — no PRESERVE or OVERWRITE line shown (correctly skipped via _is_preserved).

---

## Test 4 — Update (real) with data preservation

```
bash install.sh --target /tmp/hchain-test-project --update
```

Result: PASS

Post-update verification:

| File | Expected | Result |
|------|----------|--------|
| harness/tasks/TASK_001.md | preserved | ✅ |
| harness/logs/TASK_001.log | preserved | ✅ |
| harness/findings/open/FIND_001.md | preserved | ✅ |
| harness/queue/pending/TASK_001 | preserved | ✅ |
| harness/active_state.json content | `{"status":"running"}` | ✅ |
| harness/harness_runner.sh | overwritten from template | ✅ |
| CLAUDE.md | policy block updated | ✅ |
| .hchain/meta.json | updated timestamp | ✅ |

---

## Test 5 — --update guard (not yet installed)

```
bash install.sh --target /tmp/empty-dir --update
```

Result: PASS — exits with error:
```
[hchain] ERROR: --update requires hchain to be already installed.
[hchain]   Run without --update to install first.
```

---

## Summary

| Test | Result |
|------|--------|
| Fresh install dry-run | ✅ PASS |
| Fresh install real | ✅ PASS |
| Update dry-run | ✅ PASS |
| Update real (data preserved) | ✅ PASS |
| --update guard on uninstalled | ✅ PASS |

All 5 tests PASS. install.sh is ready for use.
