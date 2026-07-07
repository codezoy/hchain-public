# TASK-HCHAIN-PLANNER-FEEDBACK-MVP-DESIGN-001

**Type:** Design Document
**Branch:** feature/planner-feedback-mvp
**Status:** DESIGN COMPLETE
**Date:** 2026-06-03

---

## Problem

Mission 완료 후 다음 Task 결정이 Human 수동 판단에 의존한다.

현재 흐름:
```
Task 완료
    ↓
Report 생성 (## Recommended Next Tasks 섹션)
    ↓
Human이 직접 읽고 판단
    ↓
Human이 next_task를 mission_state.json에 직접 입력
    ↓
Queue에 수동 등록
```

문제점:
- Task Report에 "추천 Task" 정보가 있지만 기계가 읽지 못한다
- next_task 갱신이 수동이라 Mission Loop가 중단된다
- 반복적인 단순 작업(파일 생성 + queue 등록)이 Human 부담으로 전가된다

---

## Goal

Task 완료 후 아래 흐름을 자동화한다:

```
Task Report
    ↓
Planner (Claude) reads report + mission_state.json
    ↓
Task Markdown 생성
    ↓
Queue 등록 (pending)
    ↓
mission_state.json.next_task 갱신
```

단일 Planner만 존재한다. Message Bus, Agent Runtime, Multi-Agent 없음.

---

## Architecture

### 전체 구조

```
[TRIGGER]
  Human: /hchain planner MISSION_ID TASK_ID
      OR
  미래: mission_step.sh post-completion hook (Agent Runtime 구현 후)

         ↓

[PLANNER INPUT]
  harness/missions/MISSION_ID/tasks/TASK_ID_report.md  ← primary
  harness/missions/MISSION_ID/mission_state.json        ← context

         ↓

[PLANNER (Claude)]
  1. Report에서 "## Next Tasks (Planner Feed)" 섹션 파싱
  2. 각 추천 Task에 대해 Task Markdown 생성
  3. Queue marker 파일 생성
  4. mission_state.json 갱신

         ↓

[PLANNER OUTPUT]
  harness/tasks/NEW_TASK_ID.md          (신규)
  harness/queue/pending/NEW_TASK_ID     (신규 marker)
  mission_state.json                    (수정: next_task, planner_last_run, feedback_cycle)
```

### 컴포넌트 역할

| 컴포넌트 | 역할 | 현재 상태 |
|----------|------|-----------|
| Task Report | Planner의 주요 입력 | 기존 존재 (포맷 확장 필요) |
| mission_state.json | 컨텍스트 + 갱신 대상 | 기존 존재 (필드 추가 필요) |
| Planner (Claude) | 파싱 + 생성 + 갱신 | 신규 (Claude prompt flow) |
| harness/tasks/ | Task Markdown 저장소 | 기존 존재 |
| harness/queue/pending/ | Queue 등록 | 기존 존재 |

---

## Data Flow

### Phase 1: Planner Input

```
Planner reads:
  1. TASK_ID_report.md
     - "## Next Tasks (Planner Feed)" 섹션 파싱
     - 추천 Task 목록, 우선순위, 설명 추출
  2. mission_state.json
     - mission_goal: 추천 적합성 판단에 사용
     - completed_tasks: 중복 방지에 사용
     - blocked_tasks: 재시도 여부 판단에 사용
     - feedback_cycle: 루프 감지에 사용
```

### Phase 2: Planner Processing

```
For each recommended task (priority 순):
  A. 중복 확인
     - harness/tasks/TASK_ID.md 존재 여부 확인
     - completed_tasks에 포함 여부 확인
     - queue/*/TASK_ID marker 존재 여부 확인
  B. Task Markdown 생성
     - harness/tasks/TASK_ID.md 생성 (templates 기반)
  C. Queue marker 생성
     - touch harness/queue/pending/TASK_ID
```

### Phase 3: State Update

```
mission_state.json 갱신:
  - next_task = 가장 높은 우선순위 Task ID
  - planner_last_run = ISO8601 timestamp
  - feedback_cycle += 1
  - updated_at = ISO8601 timestamp
```

---

## Task Report Format Extension

### 현재 포맷 (기존)

```markdown
## 11. Recommended Next Tasks

Priority 1 — TASK-HARNESS-REAL-TASK-E2E-001
  Description...

Priority 2 — TASK-HARNESS-ESCALATION-MVP-001
  Description...
```

문제: 기계 파싱이 어렵다 (비정형 자연어).

### 신규 포맷 추가 (Planner Feed 섹션)

기존 섹션을 **제거하지 않는다**. 신규 섹션을 **추가**한다.

```markdown
## Next Tasks (Planner Feed)

TASK-HARNESS-REAL-TASK-E2E-001 | HIGH | Validate full pipeline with real task file
TASK-HARNESS-ESCALATION-MVP-001 | HIGH | Implement human checkpoint escalation
TASK-HARNESS-TOKEN-BUDGET-MVP-001 | MEDIUM | Enforce token budget in mission loop
```

파싱 규칙:
- 형식: `TASK_ID | PRIORITY | DESCRIPTION`
- PRIORITY 허용값: `HIGH`, `MEDIUM`, `LOW`
- 빈 줄, `#` 주석 행은 무시
- 섹션이 없거나 비어 있으면 → No Tasks 처리

Planner는 이 섹션을 라인 단위로 파싱한다. `|`로 분할, trim 후 TASK_ID / PRIORITY / DESCRIPTION 추출.

---

## File Changes

### 신규 생성 (Planner 실행 시)

| 파일 | 생성 주체 | 비고 |
|------|-----------|------|
| `harness/tasks/TASK_ID.md` | Planner | 추천된 각 Task별 1개 |
| `harness/queue/pending/TASK_ID` | Planner | empty marker file |

### 수정 (Planner 실행 시)

| 파일 | 수정 필드 | 비고 |
|------|-----------|------|
| `mission_state.json` | `next_task`, `planner_last_run`, `feedback_cycle`, `updated_at` | atomic_write |

### 스키마 확장 (템플릿 업데이트 — 구현 Task에서 수행)

`templates/harness/templates/mission_state.json`에 추가:
```json
{
  "planner_last_run": null,
  "feedback_cycle": 0
}
```

`templates/harness/templates/mission_summary.md`에 추가:
```markdown
## Next Tasks (Planner Feed)

TASK_ID | PRIORITY | DESCRIPTION
```

---

## Mission State 변경안

### 현재 mission_state.json 구조 (관련 필드)

```json
{
  "next_task": null,
  "completed_tasks": [],
  "blocked_tasks": [],
  "progress_percent": 0,
  "last_report": null,
  "updated_at": "..."
}
```

### 추가 필드 (최소 2개)

```json
{
  "planner_last_run": null,
  "feedback_cycle": 0
}
```

**판단 근거:**

| 후보 필드 | 결정 | 이유 |
|-----------|------|------|
| `planner_status` | ❌ 제외 | 복잡도 증가. next_task 존재 여부로 충분 |
| `next_task` | 기존 재사용 | 이미 존재. Planner가 이 필드를 갱신 |
| `planner_last_run` | ✅ 추가 | 언제 Planner가 마지막 실행됐는지 추적 |
| `feedback_cycle` | ✅ 추가 | 무한 루프 감지. 동일 Task 반복 추천 시 경고 |

---

## Failure Cases

### Case 1: 추천 Task 없음

```
조건: "## Next Tasks (Planner Feed)" 섹션 없거나 비어 있음
처리:
  - completed_tasks 확인
  - 모든 task_batch 완료 → mission_status = DONE
  - 미완료 있음 → mission_status = BLOCKED, log: "Planner: no tasks recommended"
  - next_task = null 유지
  - planner_last_run 갱신
```

### Case 2: 중복 Task 존재

```
조건: harness/tasks/TASK_ID.md 이미 존재
      OR completed_tasks에 포함
      OR queue/*/TASK_ID marker 존재

처리:
  - Task Markdown 생성 스킵
  - Queue 등록 스킵 (이미 등록된 경우)
  - 다음 우선순위 Task로 진행
  - 모든 추천 Task가 중복 → Case 1로 처리
  - log: "Planner: TASK_ID already exists — skipped"
```

### Case 3: Queue 등록 실패

```
조건: queue/pending/ 디렉토리 없음 또는 쓰기 권한 없음

처리:
  - Task Markdown 생성은 이미 완료된 경우 유지
  - mission_state.json.next_task 갱신 하지 않음 (정합성 보장)
  - Planner Report에 ERROR 표시
  - log: "Planner: queue registration failed for TASK_ID"
  - 인간 개입 요청
```

### Case 4: Task 파일 생성 실패

```
조건: harness/tasks/ 디렉토리 없음 또는 쓰기 권한 없음

처리:
  - Queue 등록 하지 않음
  - mission_state.json 갱신 하지 않음
  - Planner Report에 ERROR 표시
  - 인간 개입 요청
```

### Case 5: mission_state.json 갱신 실패

```
조건: atomic_write 실패 (JSON 파싱 오류 등)

처리:
  - Task 파일과 Queue marker는 유지 (rollback 안 함)
  - Planner Report에 WARN 표시
  - 인간이 수동으로 next_task 갱신하도록 안내
  - log: "Planner: state update failed — manual next_task update required"
```

### Case 6: feedback_cycle 과다

```
조건: feedback_cycle >= 10 (threshold)

처리:
  - Planner 실행을 중단하지 않음
  - Planner Report에 WARN 표시
  - log: "Planner: feedback_cycle = N — possible loop detected"
  - 인간 점검 권고
```

---

## MVP Scope

### 포함 (IN SCOPE)

```
✅ Task Report의 "## Next Tasks (Planner Feed)" 섹션 파싱
✅ 파싱된 추천 Task별 Task Markdown 생성 (harness/tasks/)
✅ Queue marker 생성 (harness/queue/pending/)
✅ mission_state.json 갱신 (next_task, planner_last_run, feedback_cycle)
✅ 중복 Task 감지 및 스킵
✅ Failure Case 처리 (5가지)
✅ Planner Report 출력 (따5코 형식)
✅ Task Report 포맷 확장 (## Next Tasks (Planner Feed) 섹션 추가 가이드)
✅ mission_state.json 스키마 확장 (planner_last_run, feedback_cycle)
```

### 제외 (OUT OF SCOPE)

```
❌ Message Bus
❌ Multi-Agent Runtime
❌ Agent Memory
❌ Codex Runtime 연동
❌ Gemini Runtime 연동
❌ mission_step.sh 자동 트리거 (Agent Runtime 구현 후 단계)
❌ Planner가 Task 우선순위를 자율 재판단 (Report에 명시된 우선순위 그대로 사용)
❌ Task 간 의존성 자동 추론
❌ Rollback 메커니즘 (파일 생성 실패 시)
❌ Token Budget 집행
❌ 여러 Mission 병렬 처리
❌ Escalation Guard 연동
❌ Task Markdown 내용 자동 생성 (제목 + goal만 채움, 나머지는 human)
```

---

## Validation (충돌 분석)

### 현재 HCHAIN 구조와 충돌 없는가?

| 항목 | 판단 | 근거 |
|------|------|------|
| mission_state.json 필드 추가 | 충돌 없음 | atomic_write 방식 유지. 기존 필드 변경 없음 |
| harness/tasks/ 파일 생성 | 충돌 없음 | 기존 Task 파일 덮어쓰지 않음. 신규 생성만 |
| harness/queue/pending/ marker | 충돌 없음 | queue/move.sh 규칙 준수. 중복 체크 포함 |
| next_task 갱신 | 충돌 없음 | mission_manager.sh set-next와 동일 로직 |

**결론: 충돌 없음**

### Mission Layer와 결합 가능한가?

```
mission_step.sh 완료 후:
  current_task = null
  next_task = (이전 값 유지 또는 null)

Planner 실행 후:
  next_task = 신규 Task ID (Planner가 갱신)
  mission_loop.sh는 다음 반복에서 next_task를 읽음

→ mission_step.sh → Planner → mission_step.sh 순환 가능
```

**결론: 결합 가능. 인터페이스 변경 없음**

### 향후 Agent Runtime으로 확장 가능한가?

현재 트리거 (MVP):
```
Human → /hchain planner MISSION_ID TASK_ID
```

Agent Runtime 구현 후 트리거:
```
mission_step.sh (task complete)
    → bash harness/scripts/planner.sh MISSION_ID TASK_ID
    → Claude API call (prompt 구성 후 자동 실행)
```

Planner의 Input/Output 구조는 동일하다. 트리거만 변경된다.

**결론: 확장 가능. 현재 설계가 그대로 사용됨**

### Bus 없이 가능한가?

```
Planner Input  → 파일 읽기 (mission_state.json, TASK_ID_report.md)
Planner Output → 파일 쓰기 (Task markdown, queue marker, mission_state.json)
```

모든 통신이 파일 기반이다. 단일 Planner이므로 동시성 문제 없음.

**결론: Bus 불필요. 파일 기반 통신으로 충분**

---

## Definition of Done

- [x] 설계 문서 생성 (`docs/design/TASK-HCHAIN-PLANNER-FEEDBACK-MVP-DESIGN-001.md`)
- [x] 데이터 흐름 정의 (Input → Processing → Output)
- [x] Task Report 포맷 확장 정의 (`## Next Tasks (Planner Feed)` 섹션)
- [x] 파일 변경 후보 정의 (신규 생성 2종, 수정 1종, 템플릿 확장 2종)
- [x] mission_state.json 스키마 변경안 정의 (`planner_last_run`, `feedback_cycle`)
- [x] Failure Case 정의 (6가지)
- [x] MVP Scope 정의 (IN SCOPE / OUT OF SCOPE 명확히 구분)
- [x] 현재 HCHAIN 구조 충돌 분석
- [x] Agent Runtime 확장성 분석

---

## 다음 구현 Task 제안

설계 승인 후 아래 순서로 구현한다:

### TASK-HCHAIN-PLANNER-REPORT-FORMAT-001 (Priority: HIGH)
**내용:** Task Report 포맷에 `## Next Tasks (Planner Feed)` 섹션 추가
- 대상: `templates/harness/templates/mission_summary.md`
- 내용: 섹션 가이드 + 포맷 예시 추가
- 기존 섹션 변경 없음

### TASK-HCHAIN-PLANNER-STATE-SCHEMA-001 (Priority: HIGH)
**내용:** mission_state.json 스키마에 planner 필드 추가
- 대상: `templates/harness/templates/mission_state.json`
- 추가 필드: `planner_last_run`, `feedback_cycle`
- 기존 필드 변경 없음

### TASK-HCHAIN-PLANNER-FLOW-001 (Priority: HIGH)
**내용:** Planner Claude Flow 구현 (핵심 Task)
- Planner prompt 작성 (`skills/hchain/agents/planner_agent.md` 확장)
- 파싱 로직 정의
- Task Markdown 생성 로직
- Queue 등록 로직
- mission_state.json 갱신 로직
- Failure Case 처리 포함

### TASK-HCHAIN-PLANNER-E2E-001 (Priority: MEDIUM)
**내용:** Planner Feedback E2E 검증
- 실제 Task Report 생성 → Planner 실행 → Queue 확인 → mission_loop 재개
- Failure Case 시나리오 테스트
