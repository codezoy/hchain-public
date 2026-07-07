# HCHAIN User Guide (Skill Resource)

> Summary for Skill context. Full guide: `docs/HCHAIN_USER_GUIDE.md`
> Version: 0.1.0

---

## AI Summary

```json
{
  "system": "HCHAIN",
  "version": "0.1.0",
  "architecture": "Core (installer) + Harness (runtime)",
  "workflow_stages": ["PLAN", "RESEARCH", "ACTION", "REVIEW", "VALIDATE", "DONE"],
  "agents": {
    "RESEARCHER": { "cli": "gemini", "mode": "read-only, headless" },
    "REVIEWER":   { "cli": "codex exec --json --ephemeral", "mode": "static code audit" },
    "VALIDATOR":  { "cli": "shell commands (pnpm, curl, pgrep...)", "mode": "runtime verification" }
  },
  "queue_states": ["pending", "running", "done", "blocked"],
  "severity_levels": { "CRITICAL": 4, "MAJOR": 3, "MINOR": 2, "NIT": 1 },
  "safety_break_trigger": "loop_count >= 3",
  "default_severity_stop": "MAJOR",
  "task_id_format": "TASK_YYYYMMDD_NNN",
  "key_state_files": {
    "active_state":      "harness/active_state.json",
    "task_definition":   "harness/tasks/TASK_ID.md",
    "task_state":        "harness/tasks/TASK_ID.state.json",
    "task_checkpoint":   "harness/tasks/TASK_ID.checkpoint.json",
    "install_meta":      ".hchain/meta.json"
  }
}
```

---

## Architecture

```
HCHAIN Core (install.sh)
    └── installs into → <target-project>/
                            ├── harness/
                            │   ├── harness_runner.sh
                            │   ├── active_state.json
                            │   ├── agents/
                            │   ├── lib/
                            │   ├── queue/
                            │   │   ├── pending/
                            │   │   ├── running/
                            │   │   ├── done/
                            │   │   └── blocked/
                            │   ├── tasks/       ← TASK_*.md + .state.json
                            │   ├── logs/
                            │   └── findings/
                            ├── .hchain/
                            │   └── meta.json
                            └── CLAUDE.md        ← HCHAIN policy block injected
```

**Core isolation**: Core never writes runtime state to its own directory.

---

## Workflow Pipeline

```
PLAN → RESEARCH → ACTION → REVIEW → VALIDATE → DONE
        (gemini)   (Claude)  (codex)   (shell)
```

- **RESEARCH**: Gemini CLI does technical research (read-only, headless)
- **ACTION**: Claude implements based on research findings
- **REVIEW**: Codex CLI audits the code statically
- **VALIDATE**: Shell commands verify runtime (typecheck, lint, test, API health)
- **Safety Break**: If `loop_count >= 3`, all automation stops, user intervention required

---

## Queue System

Tasks move through: `pending → running → done / blocked`

Each task has:
- `harness/tasks/TASK_ID.md` — definition
- `harness/tasks/TASK_ID.state.json` — current state
- `harness/tasks/TASK_ID.checkpoint.json` — resume point

---

## Task Definition Structure

```markdown
# TASK_YYYYMMDD_NNN: [Title]

## Goal
[One paragraph describing what this task achieves]

## Scope
포함:
- [item 1]
- [item 2]

제외:
- [item 1]

## Done Criteria
- [ ] criterion 1
- [ ] criterion 2

## Steps
1. [step]
2. [step]

## Final Report
- Changed files (git diff --name-only)
- Test results
- Validation status
- Commit hash
```

---

## Installation

```bash
# Install HCHAIN into a project
bash /path/to/hchain/install.sh <target_project_path>
bash /path/to/hchain/install.sh --target /path/to/project

# Dry-run (no changes)
bash /path/to/hchain/install.sh --target /path/to/project --dry-run

# Verify installation
bash /path/to/hchain/install.sh --verify /path/to/project

# Update (preserves tasks, logs, findings, queue)
bash /path/to/hchain/install.sh --target /path/to/project --update
```

### Update preserves (never overwritten):
- `harness/active_state.json`
- `harness/tasks/`
- `harness/logs/`
- `harness/findings/`
- `harness/queue/pending/`, `running/`, `done/`, `blocked/`

---

## Core Harness Commands

All commands run from the **target project root**:

```bash
# Run a task
bash harness/harness_runner.sh --task TASK_20260101_001

# Resume interrupted task
bash harness/harness_runner.sh --resume TASK_20260101_001

# List all tasks
bash harness/harness_runner.sh --list

# Check task status
bash harness/harness_runner.sh --status TASK_20260101_001

# Chain: run all pending tasks
bash harness/harness_runner.sh --chain

# Chain: run range
bash harness/harness_runner.sh --chain --from TASK_001 --to TASK_005

# Chain: run selected
bash harness/harness_runner.sh --chain --select TASK_001,TASK_003

# Show findings backlog
bash harness/harness_runner.sh --findings

# Dry run
bash harness/harness_runner.sh --task TASK_ID --dry-run

# Skip validate (use sparingly)
bash harness/harness_runner.sh --task TASK_ID --skip-validate

# Override severity threshold
bash harness/harness_runner.sh --task TASK_ID --override-severity MINOR

# Auto-commit on DONE
bash harness/harness_runner.sh --task TASK_ID --auto-commit

# Check queue consistency
bash harness/queue/check_consistency.sh
bash harness/queue/check_consistency.sh --extended
```

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| `install.sh` | bash 3.2+ |
| `harness_runner.sh` | bash 4.0+ |
| Runtime | `jq` |
| RESEARCH stage | `gemini` CLI |
| REVIEW stage | `codex` CLI |

---

## Task Execution Mode (mode)

`mode`는 HCHAIN Core(harness_runner.sh)가 해석하는 파라미터다.

| 값 | 동작 |
|----|------|
| `NORMAL` (기본값) | 기존 동작 유지 |
| `ROOTCAUSE` | Final Report에 Agent Opinion Matrix 섹션 필수 |

미지정 시 `NORMAL`로 동작한다. 기존 Task에 영향 없음.

---

## Agent Strategy Metadata (agent_strategy)

`agent_strategy`는 Task Metadata 필드다. **HCHAIN Core는 이 값을 실행 분기에 사용하지 않는다.**

이 필드는 Task를 실행하는 Claude 및 Human Operator에게 분석 전략을 안내하기 위해 Task 정의에 기록된다.

| 값 | 의미 |
|----|------|
| `DEFAULT` (기본값) | 기존 동작 유지 (각 Agent 기본 설정 따름) |
| `CLAUDE_ONLY` | Claude만으로 분석 |
| `CODEX_ONLY` | Codex만으로 분석 |
| `DUAL` | Claude(Architect) + Codex(Code Detective) 순서대로 실행 후 통합 |

미지정 시 `DEFAULT`로 동작한다. Core 실행 경로 변경 없음.

---

## Agent Roles (DUAL Strategy Reference)

`agent_strategy: DUAL` 또는 `mode: ROOTCAUSE` 사용 시 각 Agent 역할:

**Claude = Architect**

```text
- WHY 분석 (설계 의도, 구조적 타당성)
- 아키텍처 방향 및 장기 유지보수성
- 설계 일관성 검토
- 출력: Architecture Finding List / Architecture Review Notes
```

**Codex = Code Detective**

```text
- Call Graph 분석
- Dead Code 탐지
- 실제 실행 경로 추적
- 중복 책임 탐지
- 설정 누락 발견
- 출력: Code Finding List / Code Review Notes
```

---

## ROOTCAUSE Mode Flow

`mode: ROOTCAUSE` 설정 시 각 단계에서 다음 흐름을 따른다:

```
[RESEARCH]
  Claude  → 구조 분석 (WHY, 아키텍처, 설계 문제)  → Architecture Finding List
  Codex   → 코드 분석 (HOW, Call Graph, Dead Code)  → Code Finding List
  통합    → 두 Finding List 비교 → 공통 결론 / 상충 결론

[REVIEW]
  Claude  → Architecture Review (구조적 타당성, 확장성)  → Architecture Review Notes
  Codex   → Code Review (회귀 위험, Side Effect)          → Code Review Notes
  통합    → Agent Opinion Matrix 생성

[DONE]
  Final Report에 Agent Opinion Matrix 포함 (필수)
```

---

## Agent Opinion Matrix

`mode: ROOTCAUSE` 또는 `agent_strategy: DUAL` 인 경우 Final Report 말미에 포함한다.

```markdown
## Agent Opinion Matrix

| 항목 | Claude 결론 | Codex 결론 | 공통 결론 | 상충 여부 |
|------|------------|-----------|----------|----------|
| [분석 항목] | [Claude 결과] | [Codex 결과] | [합의 결론] | 없음 / 있음 |

### 공통 결론 요약
- [두 Agent가 동의한 핵심 발견]

### 상충 결론 (있는 경우만)
- [Claude 주장] vs [Codex 주장]
- 해결 방안: [Human Operator 판단 필요]
```
