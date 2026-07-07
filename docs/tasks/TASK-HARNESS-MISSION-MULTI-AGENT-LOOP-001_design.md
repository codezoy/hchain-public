# TASK-HARNESS-MISSION-MULTI-AGENT-LOOP-001 설계 문서

**Status:** DESIGN (pending user approval)
**Date:** 2026-06-02
**Author:** Claude (Design Phase)
**Stage:** PLAN → RESEARCH → DESIGN (코드 수정 없음)

---

## 1. 현재 HCHAIN/Harness 문제 정의

### 1.1 현재 구조

```
현재 HCHAIN = 단일 Task 실행기

사용자 → Task 하나 정의 → PLAN→RESEARCH→ACTION→REVIEW→VALIDATE→DONE → 끝
```

각 Task는 독립 실행 단위이며, Task 간 자동 연결 메커니즘이 없다.

### 1.2 한계점

| 문제 | 설명 |
|------|------|
| **Mission 개념 없음** | 최종 목표("화면 완성", "파이프라인 완성")를 표현할 상위 개념이 없다 |
| **Task 연쇄 없음** | Task A 완료 후 Task B 자동 진입 불가. 수동으로 다음 Task를 지정해야 한다 |
| **Multi-Agent 조율 없음** | 현재 RESEARCHER(Gemini), REVIEWER(Codex), VALIDATOR(shell)는 독립 실행. 결과를 다음 Agent에 전달하는 공식 Handoff 규칙이 없다 |
| **Approval Gate 없음** | 작업 시작 전 사용자 승인 게이트가 명시적으로 정의되어 있지 않다 |
| **Escalation 없음** | 승인 범위를 벗어나는 상황 발생 시 자동 중단 메커니즘이 없다 |
| **Auto Loop 없음** | Mission 목표 달성까지 사이클을 자동 반복할 수 없다 |

### 1.3 현재 Agent 구조

```
현재 Agents (stage-bound):
  RESEARCHER  → RESEARCH 단계 도구 (Gemini CLI, 선택)
  REVIEWER    → REVIEW 단계 도구 (Codex CLI, read-only)
  VALIDATOR   → VALIDATE 단계 도구 (shell commands)
```

이들은 특정 Stage에 바인딩된 도구이며, Agent 간 통신/Handoff 프로토콜이 없다.

---

## 2. Mission Loop 개념 정의

### 2.1 핵심 개념

```
Mission = 사용자가 정의한 최종 목표 + 성공 기준 + 허용 범위

Mission Loop = Mission 달성까지 아래 사이클을 자동 반복:

  [사용자] 목표 제시
      ↓
  [Mission Manager] Mission Plan 생성
      ↓
  [사용자] Mission Plan 승인 ← Approval Gate
      ↓
  Loop 시작 (승인된 범위 내 자동 실행):
    [Planner]   → Task 분해
    [Executor]  → 구현
    [Reviewer]  → 코드 감사
    [Validator] → DOD 검증
    [Reporter]  → Task Report 생성
    [Mission Manager] → 다음 Task 판단
      ↓
  (남은 Task 있음) → Loop 재진입
  (Mission 성공 기준 충족) → Mission DONE
  (Scope 초과 감지) → Escalation Guard → 자동 중단 → 사용자 승인 요청
```

### 2.2 현재 방식과의 차이

| 항목 | 현재 | Mission Loop |
|------|------|--------------|
| 실행 단위 | Task 1개 | Mission (N Tasks 묶음) |
| 연속 실행 | 불가 (수동) | 자동 순환 |
| 사용자 개입 | 매 Task | Mission Plan 승인 시 1회 (Scope 초과 시 추가) |
| 목표 추적 | 없음 | Mission 성공 기준으로 추적 |
| 안전장치 | Safety Break (loop_count≥3) | Escalation Guard (Scope 초과 시 즉시 중단) |

---

## 3. Multi-Agent Layer 개념 정의

### 3.1 Agent 계층 구조

```
┌─────────────────────────────────────┐
│         Mission Manager             │  ← 최상위: Mission 전체 조율
├─────────┬───────────┬───────────────┤
│ Planner │ Executor  │   Reporter    │  ← Task 레벨 Agent
├─────────┴─────┬─────┴───────────────┤
│   Reviewer    │    Validator        │  ← 검증 Agent
├───────────────┴─────────────────────┤
│        Codex Validation Agent       │  ← 선택형 외부 검증 (기본 OFF)
├─────────────────────────────────────┤
│         Escalation Guard            │  ← 수평 감시 (모든 단계 적용)
└─────────────────────────────────────┘
```

### 3.2 기존 Agent와의 관계

| 기존 Agent | 새 Agent Layer 내 위치 |
|------------|----------------------|
| RESEARCHER (Gemini) | Planner Agent 내 Research 도구로 통합 |
| REVIEWER (Codex) | Reviewer Agent의 실행 엔진 |
| VALIDATOR (shell) | Validator Agent의 실행 엔진 |
| (없음) | Mission Manager Agent (신규) |
| (없음) | Executor Agent (신규 — 기존 ACTION 단계 담당) |
| (없음) | Reporter Agent (신규) |
| (없음) | Codex Validation Agent (신규 — 선택형) |
| (없음) | Escalation Guard (신규 — 수평 감시) |

---

## 4. Agent별 책임/입력/출력

### 4.1 Mission Manager Agent

**역할:** 전체 Mission 생명주기 관리. Task Batch 오케스트레이션.

| 항목 | 내용 |
|------|------|
| **책임** | Mission Plan 생성, Task Batch 순서 결정, 진행률 추적, Mission DONE/BLOCKED 판단 |
| **입력** | 사용자 목표, 승인된 Mission Plan, Task Report 목록, Validation 결과 |
| **출력** | Mission Plan, Task Batch 정의, Next Task 결정, Mission Final Report |
| **트리거** | 사용자 목표 입력 시 / Task Report 수신 후 |
| **종료 조건** | Mission 성공 기준 충족(DONE) 또는 Escalation Guard 발동(BLOCKED) |

**상태 전이:**

```
INIT → PLAN_GENERATED → AWAITING_APPROVAL → RUNNING → DONE / BLOCKED
```

### 4.2 Planner Agent

**역할:** Mission을 기능 단위 Task로 분해. 각 Task의 DOD 정의.

| 항목 | 내용 |
|------|------|
| **책임** | Task 분해, DOD 정의, 의존성 명시, 승인 필요 항목 표시 |
| **입력** | Mission 목표, 현재 코드/문서 구조(RESEARCH 결과), 이전 Task Report |
| **출력** | Task Plan 목록, 각 Task DOD, 영향 범위, 승인 요청 문서 |
| **Research 도구** | Gemini CLI (외부 조사), Claude (내부 파일 분석) |
| **제약** | 코드 수정 금지. 조사 및 계획만 수행 |

**출력 구조 예시:**

```json
{
  "task_id": "TASK_20260602_001",
  "goal": "...",
  "dod": ["[ ] 조건 1", "[ ] 조건 2"],
  "depends_on": [],
  "assigned_agent": "Executor",
  "scope": {
    "include": ["파일A", "모듈B"],
    "exclude": ["DB schema", "외부 API"]
  },
  "requires_approval": false
}
```

### 4.3 Executor Agent

**역할:** 승인된 Task만 구현. 최소 수정 원칙 준수.

| 항목 | 내용 |
|------|------|
| **책임** | 코드 구현, 변경 파일 목록 관리, 실행 로그 기록 |
| **입력** | 승인된 Task Plan, 허용 변경 범위(scope), DOD |
| **출력** | 코드 변경 결과, 변경 파일 목록(`changed_files[]`), 실행 로그 |
| **금지** | 미승인 파일 수정, 관련 없는 리팩토링, 아키텍처 변경 |
| **Escalation 트리거** | 승인 범위 외 파일 변경 필요 시 → 즉시 중단 |

### 4.4 Reviewer Agent

**역할:** 아키텍처 준수, 코드 품질 정적 감사.

| 항목 | 내용 |
|------|------|
| **책임** | 아키텍처 위반, 하드코딩, 중복 구현, 불필요한 파일 변경, 승인 범위 초과 점검 |
| **입력** | `git diff`, 변경 파일 목록, Task Plan, 아키텍처 정책(CLAUDE.md) |
| **출력** | Review Report (JSON), PASS/FAIL, Escalation 필요 여부 |
| **실행 엔진** | Codex CLI (`codex exec --json --ephemeral`) |
| **심각도** | CRITICAL / MAJOR / MINOR / NIT (기존 기준 유지) |

**Review Report 구조:**

```json
{
  "task_id": "TASK_20260602_001",
  "status": "PASS | FAIL",
  "issues": [
    {"severity": "MAJOR", "file": "...", "line": 42, "message": "..."}
  ],
  "escalation_required": false,
  "codex_review_needed": false
}
```

### 4.5 Validator Agent

**역할:** DOD 충족 여부 런타임 검증.

| 항목 | 내용 |
|------|------|
| **책임** | DOD 체크리스트 실행, 산출물 존재 확인, 테스트 명령 실행 |
| **입력** | DOD, 검증 명령 목록, 실행 로그, 산출물 경로 |
| **출력** | Validation Report (JSON), PASS/FAIL, Codex 호출 필요 여부 |
| **실행 엔진** | shell commands (pnpm, curl, pgrep 등) |
| **Codex 호출 조건** | `codex_enabled=true` AND (테스트 실패 반복 OR 아키텍처 리스크 OR 보안 민감 변경) |

**Validation Report 구조:**

```json
{
  "task_id": "TASK_20260602_001",
  "status": "PASS | FAIL",
  "checks": [
    {"dod_item": "[ ] 파일 생성 확인", "result": "PASS", "output": "..."}
  ],
  "blocking_issues": [],
  "codex_call_needed": false,
  "retry_count": 0
}
```

### 4.6 Codex Validation Agent

**역할:** 선택형 심층 검증 에이전트. 기본 OFF.

| 항목 | 내용 |
|------|------|
| **책임** | 코드 리뷰(심층), 테스트 전략 제안, 실패 원인 분석, 보안/아키텍처 리스크 검토 |
| **기본값** | OFF (`validation.codex_enabled = false`) |
| **입력** | Reviewer Report, Validator Report, 변경 파일 목록, DOD |
| **출력** | Codex Review Report, Risk Finding, Suggested Fix, Recommended Next Action |
| **금지** | 직접 코드 수정 금지. 분석/제안 역할만 수행 |
| **High Risk 판정 시** | Mission Manager에게 BLOCKED 신호 전달 → Escalation Guard 발동 |

**Risk 등급:**

```
HIGH   → Escalation Guard 자동 발동, 자동 실행 중단
MEDIUM → Review Report에 경고 추가, 진행 가능
LOW    → Report에 기록 후 진행
```

### 4.7 Reporter Agent

**역할:** Task 결과를 구조화된 보고서로 생성.

| 항목 | 내용 |
|------|------|
| **책임** | 성공/실패 정리, 변경 파일 목록화, 남은 이슈 정리, Next Task 실행 가능 여부 판단 |
| **입력** | Executor 결과, Reviewer Report, Validator Report, Codex Review Report |
| **출력** | Task Report (Markdown + JSON), Mission Progress Update, Next Task Recommendation |

**Task Report 구조:**

```json
{
  "task_id": "TASK_20260602_001",
  "mission_id": "MISSION_20260602_001",
  "status": "DONE | FAILED | BLOCKED",
  "changed_files": ["..."],
  "issues_remaining": [],
  "next_task_ready": true,
  "next_task_id": "TASK_20260602_002",
  "mission_progress": "2/5 tasks completed"
}
```

### 4.8 Escalation Guard

**역할:** 승인 범위 초과 감지. 자동 루프 중단.

| 항목 | 내용 |
|------|------|
| **책임** | Scope 초과 감지, 자동 루프 즉시 중단, 사용자 승인 요청 |
| **감시 대상** | 모든 Agent 출력 (수평 감시) |
| **출력** | BLOCKED Report, 사용자 승인 요청, 수정된 Mission Plan 후보 |

---

## 5. Agent 간 Handoff 규칙

### 5.1 표준 Handoff 흐름

```
Mission Manager
    │ (Task Plan)
    ▼
Planner Agent
    │ (Task Plan + DOD)
    ▼
[Approval Gate] ← 사용자 확인
    │ (승인)
    ▼
Executor Agent
    │ (changed_files[], execution_log)
    ▼
Reviewer Agent ──── Escalation Guard (범위 초과 시)
    │ (Review Report: PASS)
    ▼
Validator Agent ─── Escalation Guard (DOD 미충족 반복 시)
    │ (Validation Report: PASS)
    │
    ├─ codex_call_needed=true → Codex Validation Agent
    │                               │ (Codex Review Report)
    │                               └─ High Risk → Escalation Guard
    │
    ▼
Reporter Agent
    │ (Task Report)
    ▼
Mission Manager ← 다음 Task 결정 또는 Mission DONE 판단
```

### 5.2 Handoff 데이터 형식

모든 Agent 간 전달 데이터는 JSON 파일로 파일시스템에 저장한다.

```
harness/missions/MISSION_ID/
  ├── plan.json              ← Mission Plan (Mission Manager 출력)
  ├── tasks/
  │   ├── TASK_ID.plan.json  ← Planner 출력
  │   ├── TASK_ID.exec.json  ← Executor 출력
  │   ├── TASK_ID.review.json← Reviewer 출력
  │   ├── TASK_ID.valid.json ← Validator 출력
  │   ├── TASK_ID.codex.json ← Codex 출력 (해당 시)
  │   └── TASK_ID.report.json← Reporter 출력
  └── mission_report.json    ← Mission Final Report
```

### 5.3 Handoff 실패 처리

| 조건 | 처리 |
|------|------|
| Reviewer FAIL (MAJOR 이하) | Executor 재시도 (최대 retry_limit 회) |
| Reviewer FAIL (CRITICAL) | Escalation Guard 발동 |
| Validator FAIL (retry 미만) | Executor/Validator 재시도 |
| Validator FAIL (retry 초과) | Escalation Guard 발동 |
| Codex High Risk | Escalation Guard 발동 |

---

## 6. Mission 상태 모델

### 6.1 Mission 정의 구조

```json
{
  "mission_id": "MISSION_YYYYMMDD_NNN",
  "title": "Mission 제목",
  "goal": "최종 목표 서술",
  "success_criteria": [
    "기준 1: 측정 가능한 완료 조건",
    "기준 2: ..."
  ],
  "scope": {
    "allow": ["허용 파일/디렉토리", "허용 모듈"],
    "deny": ["금지 항목 (DB schema 변경 등)"]
  },
  "tasks": ["TASK_ID_001", "TASK_ID_002", "..."],
  "progress": {
    "total": 5,
    "completed": 0,
    "failed": 0,
    "blocked": 0
  },
  "validation": {
    "final_check_commands": ["pnpm test", "curl /health"],
    "codex_enabled": false
  },
  "multi_agent_policy": {
    "auto_loop": true,
    "approval_gate": "mission_plan",
    "escalation_guard": true,
    "retry_limit": 3,
    "severity_stop": "MAJOR"
  },
  "status": "INIT | PLAN_GENERATED | AWAITING_APPROVAL | RUNNING | DONE | BLOCKED",
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### 6.2 Mission 상태 전이

```
INIT
  ↓ Mission Manager가 Plan 생성
PLAN_GENERATED
  ↓ 사용자에게 승인 요청
AWAITING_APPROVAL
  ↓ 사용자 승인
RUNNING
  ↓ 모든 Task DONE + 성공 기준 충족
DONE

RUNNING → BLOCKED  (Escalation Guard 발동 시)
BLOCKED → RUNNING  (사용자 승인 후 재개)
```

---

## 7. Task 상태 모델

### 7.1 Task 상태 구조 (기존 확장)

```json
{
  "task_id": "TASK_YYYYMMDD_NNN",
  "mission_id": "MISSION_YYYYMMDD_NNN",
  "title": "Task 제목",
  "goal": "기능 단위 목표",
  "dod": ["[ ] 조건 1", "[ ] 조건 2"],
  "depends_on": ["TASK_ID_선행"],
  "assigned_agent": "Executor",
  "scope": {
    "include": ["파일A"],
    "exclude": ["파일B"]
  },
  "requires_approval": false,
  "status": "PENDING | RUNNING | REVIEW | VALIDATE | DONE | FAILED | BLOCKED",
  "retry_count": 0,
  "loop_count": 0,
  "last_step": null,
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### 7.2 Task 상태 전이

```
PENDING
  ↓ (선행 Task DONE 확인)
RUNNING (Executor 실행 중)
  ↓
REVIEW (Reviewer 실행 중)
  ↓ PASS
VALIDATE (Validator 실행 중)
  ↓ PASS
DONE

REVIEW → RUNNING      (FAIL + retry_count < limit)
VALIDATE → RUNNING    (FAIL + retry_count < limit)
REVIEW → BLOCKED      (CRITICAL 또는 retry 초과)
VALIDATE → BLOCKED    (DOD 미충족 + retry 초과)
```

---

## 8. Auto Loop 실행 흐름

### 8.1 전체 순서도

```
[사용자] Mission 목표 입력
         │
         ▼
[Mission Manager] Mission Plan 생성 (Task Batch 포함)
         │
         ▼
[Approval Gate] ──── 사용자 승인 요청
         │
    ┌────┘ (승인)
    ▼
[Auto Loop 시작]
    │
    ├─ Task = next pending Task (depends_on 충족 여부 확인)
    │
    ▼
[Planner] Task Plan + DOD 확정
    │
    ▼
[Executor] 코드 구현
    │         │
    │    [Escalation Guard] (범위 초과 감지 시 즉시 중단)
    ▼
[Reviewer] 정적 감사
    │ PASS
    ▼
[Validator] DOD 검증
    │ PASS
    │
    ├─ codex_enabled=true → [Codex Validation Agent]
    │                           │ PASS / LOW/MEDIUM Risk
    │                           └─ HIGH Risk → [Escalation Guard]
    ▼
[Reporter] Task Report 생성
    │
    ▼
[Mission Manager] 다음 Task 결정
    │
    ├─ 남은 Task 있음 → Loop 재진입
    ├─ 모든 Task DONE → Mission 성공 기준 최종 검증
    │                     ├─ 충족 → Mission DONE
    │                     └─ 미충족 → NEXT_PLAN 생성 → Approval Gate
    └─ Escalation 발동 → BLOCKED → 사용자 승인 대기
```

### 8.2 재시도 로직

```
retry_count < retry_limit:
  → 동일 Task 재시도 (Executor부터 재시작)

retry_count >= retry_limit:
  → Task BLOCKED 전환
  → Escalation Guard 발동
  → 자동 루프 중단
  → 사용자에게 BLOCKED Report 전달
```

---

## 9. Approval Gate 정책

### 9.1 승인이 필요한 시점

| 게이트 | 시점 | 승인 대상 |
|--------|------|-----------|
| **Mission Gate** | Mission 시작 전 | Mission Plan 전체 (목표, 범위, Task 목록, 성공 기준) |
| **Scope Change Gate** | Escalation Guard 발동 후 | 변경된 Mission Scope 또는 새 Task 목록 |
| **NEXT_PLAN Gate** | Mission 성공 기준 미충족 후 | 추가 Task 목록 (NEXT_PLAN) |
| **Codex Override Gate** | Codex High Risk 판정 후 | 계속 진행 여부 또는 수정된 접근 방법 |

### 9.2 승인 전 금지 행위

- ACTION 단계 진입 금지
- Executor Agent 실행 금지
- 파일 수정 금지

### 9.3 승인 후 자동 실행 허용 범위

- 승인된 Mission Scope 내 모든 Task 자동 실행
- 승인된 파일 목록 내 수정
- 승인된 DOD 기반 검증 명령 실행

---

## 10. Escalation Guard 정책

### 10.1 자동 중단 조건

| 조건 | 중단 레벨 |
|------|-----------|
| 승인되지 않은 파일 수정 필요 | IMMEDIATE (즉시) |
| 기존 아키텍처 변경 필요 | IMMEDIATE |
| DB schema 변경 필요 | IMMEDIATE |
| 하드코딩/우회 구현 필요 | IMMEDIATE |
| Reviewer CRITICAL 이슈 | IMMEDIATE |
| Codex High Risk 판정 | IMMEDIATE |
| Task retry_count >= retry_limit | DEFERRED (Reporter 후) |
| 테스트 실패 반복 (loop_count >= 3) | DEFERRED |
| 외부 API/비용 증가 감지 | DEFERRED |
| Mission 성공 기준 변경 필요 | DEFERRED |
| Task 목록 대폭 변경 필요 | DEFERRED |

### 10.2 중단 후 출력

```json
{
  "type": "BLOCKED",
  "trigger": "승인되지 않은 파일 수정 필요",
  "task_id": "TASK_20260602_002",
  "mission_id": "MISSION_20260602_001",
  "detail": "DB schema 변경이 필요하나 승인 범위에 포함되지 않음",
  "suggested_actions": [
    "Mission Scope에 DB schema 변경 추가 승인",
    "해당 Task를 별도 Mission으로 분리",
    "DB 변경 없이 구현 가능한 대안 검토"
  ],
  "revised_plan_candidate": null
}
```

### 10.3 재개 조건

- 사용자가 BLOCKED Report를 검토하고 명시적으로 승인
- 수정된 Mission Plan 또는 Task Plan이 승인됨
- Approval Gate를 통과한 후에만 Auto Loop 재개

---

## 11. Codex Validation Agent 옵션 설계

### 11.1 활성화 설정

Mission Plan의 `validation.codex_enabled` 필드로 제어:

```json
{
  "validation": {
    "codex_enabled": false,
    "codex_trigger_conditions": [
      "test_failure_repeat",
      "architecture_risk",
      "security_sensitive_change",
      "large_refactor",
      "user_request"
    ],
    "codex_report_path": "harness/missions/MISSION_ID/tasks/TASK_ID.codex.json"
  }
}
```

기본값: `codex_enabled = false`

### 11.2 Codex 활성화 방법

1. Mission Plan 정의 시 `codex_enabled: true` 설정
2. Validator Agent가 자동 판단하여 호출 (조건 충족 시)
3. 사용자가 명시적으로 Codex 검증 요청

---

## 12. Codex 호출 조건

| 조건 | 판단 주체 | 자동/수동 |
|------|-----------|-----------|
| `codex_enabled = true` AND 테스트 실패가 2회 이상 반복 | Validator Agent | 자동 |
| Reviewer가 MAJOR 이슈를 반복 감지 | Reviewer Agent | 자동 |
| 변경 파일에 인증/암호화/외부 API 키 처리 포함 | Executor Agent | 자동 |
| 변경 파일 수 > 10 또는 변경 라인 수 > 500 | Executor Agent | 자동 |
| 사용자가 명시적으로 "Codex 검증 요청" | 사용자 입력 | 수동 |

---

## 13. Codex 결과 반영 방식

### 13.1 결과 저장

```
harness/missions/MISSION_ID/tasks/TASK_ID.codex.json
```

### 13.2 Risk 등급별 반영

| Risk | Reviewer 반영 | Validator 반영 | Mission Manager 반영 |
|------|---------------|----------------|----------------------|
| HIGH | Escalation 요청 | FAIL 처리 | BLOCKED 전환 |
| MEDIUM | MAJOR 이슈 추가 | 재시도 권장 | 경고 기록 후 진행 |
| LOW | NIT 이슈 추가 | 진행 허용 | 기록만 |

### 13.3 Codex 결과 → Reviewer 판단 통합

```
Codex Report 존재 시:
  Reviewer Agent가 codex.json을 읽어 최종 판단에 반영
  
  통합 판단 우선순위:
    Codex HIGH Risk > Reviewer CRITICAL > Reviewer MAJOR
  
  최종 Review Report에 codex_risk_level 필드 추가:
    "codex_risk_level": "HIGH | MEDIUM | LOW | NONE"
```

---

## 14. REPORT → NEXT TASK 판단 로직

### 14.1 판단 흐름

```
Reporter 생성 Task Report
    │
    ▼
Mission Manager가 Task Report 분석
    │
    ├─ status = DONE
    │     └─ 남은 Task 확인
    │           ├─ 있음 → next_pending_task 선택 (depends_on 충족 확인)
    │           │         → Auto Loop 재진입
    │           └─ 없음 → Mission 성공 기준 최종 검증 실행
    │
    ├─ status = FAILED (retry 가능)
    │     └─ retry_count + 1
    │         ├─ < retry_limit → 동일 Task 재실행
    │         └─ >= retry_limit → BLOCKED 전환
    │
    └─ status = BLOCKED
          └─ Escalation Guard 발동
             → 사용자 승인 요청 (자동 루프 중단)
```

### 14.2 Next Task 선택 규칙

```
1. depends_on 목록의 모든 Task가 DONE 상태인 Task만 후보
2. PENDING 상태인 Task 중 가장 앞 순번 선택
3. 병렬 실행 가능한 Task는 동시 실행 가능 (향후 확장)
4. 후보가 없으면 Mission 성공 기준 검증으로 진입
```

---

## 15. Mission 완료 판단 로직

### 15.1 DONE 판단 조건

```
ALL of:
  1. Mission.tasks 목록의 모든 Task status = DONE
  2. Mission.success_criteria 각 항목 검증 통과
  3. Mission.validation.final_check_commands 모두 성공 (exit code 0)
  4. Escalation Guard 발동 이력 없음 (또는 모두 해소됨)
```

### 15.2 성공 기준 검증

```
final_check_commands 실행:
  PASS: exit code 0
  FAIL: → NEXT_PLAN 생성 제안 → Approval Gate → 추가 Task 실행
  
검증 실패 시 Mission Manager 출력:
  - 실패한 성공 기준 목록
  - 추가 필요 Task 제안 (NEXT_PLAN)
  - 사용자 승인 요청
```

### 15.3 Mission Final Report 구조

```json
{
  "mission_id": "MISSION_YYYYMMDD_NNN",
  "title": "Mission 제목",
  "status": "DONE",
  "completed_at": "ISO8601",
  "tasks_summary": {
    "total": 5,
    "done": 5,
    "failed": 0,
    "blocked": 0
  },
  "success_criteria_results": [
    {"criteria": "기준 1", "result": "PASS", "evidence": "..."}
  ],
  "changed_files": ["파일A", "파일B"],
  "escalations": [],
  "codex_calls": 0,
  "total_duration_minutes": 42
}
```

---

## 16. 파일/디렉토리 구조 제안

### 16.1 Harness 디렉토리 확장

```
PROJECT_ROOT/
├── harness/
│   ├── missions/                          ← [신규] Mission 단위 디렉토리
│   │   └── MISSION_YYYYMMDD_NNN/
│   │       ├── plan.json                  ← Mission Plan
│   │       ├── mission_state.json         ← Mission 상태
│   │       ├── mission_report.json        ← Mission Final Report
│   │       └── tasks/                     ← Task별 Agent 출력
│   │           ├── TASK_ID.plan.json
│   │           ├── TASK_ID.exec.json
│   │           ├── TASK_ID.review.json
│   │           ├── TASK_ID.valid.json
│   │           ├── TASK_ID.codex.json     ← Codex 결과 (해당 시)
│   │           └── TASK_ID.report.json
│   ├── tasks/                             ← 기존 유지 (단일 Task 호환)
│   ├── queue/                             ← 기존 유지
│   │   ├── pending/
│   │   ├── running/
│   │   ├── done/
│   │   └── blocked/
│   ├── logs/                              ← 기존 유지 (Agent 로그 추가)
│   │   └── YYYYMMDD_HHMMSS_AGENT_ID.json
│   ├── findings/                          ← 기존 유지
│   ├── checkpoints/                       ← 기존 유지
│   ├── templates/
│   │   ├── task_template.md               ← 기존 유지
│   │   └── mission_template.md            ← [신규] Mission 정의 템플릿
│   └── active_state.json                  ← 확장: mission_id 필드 추가
│
└── .hchain/
    ├── meta.json                          ← 기존 유지
    └── mission_policy.json                ← [신규] Mission 전역 정책
```

### 16.2 active_state.json 확장

```json
{
  "status": "IDLE | RUNNING | BLOCKED",
  "mode": "TASK | MISSION",
  "current_mission": null,
  "current_task": null,
  "current_step": null,
  "last_success_step": null,
  "updated_at": "ISO8601"
}
```

### 16.3 mission_policy.json

```json
{
  "default_retry_limit": 3,
  "default_severity_stop": "MAJOR",
  "default_codex_enabled": false,
  "default_auto_loop": true,
  "approval_gate": "mission_plan",
  "escalation_guard": true
}
```

---

## 17. 구현 대상 스크립트 후보

| 스크립트 | 역할 | 우선순위 |
|---------|------|----------|
| `scripts/mission_manager.sh` | Mission 생명주기 관리, Task Batch 오케스트레이션 | HIGH |
| `scripts/planner.sh` | Task 분해, DOD 생성, RESEARCH 수행 | HIGH |
| `scripts/mission_loop.sh` | Auto Loop 진입점, Task 순서 실행 | HIGH |
| `scripts/escalation_guard.sh` | Scope 초과 감지, 자동 중단 | HIGH |
| `scripts/reporter.sh` | Task/Mission Report 생성 | MEDIUM |
| `scripts/codex_validator.sh` | Codex Validation Agent 호출 래퍼 | MEDIUM |
| `harness/templates/mission_template.md` | Mission 정의 템플릿 | HIGH |
| `harness/templates/mission_template.json` | Mission JSON 스키마 | MEDIUM |

### 17.1 SKILL.md 확장 후보

```
/hchain mission <목표>     → Mission Plan 생성 (Mission Manager 호출)
/hchain mission approve    → 현재 대기 중인 Mission Plan 승인
/hchain mission status     → Mission 진행 현황 출력
/hchain mission report     → Mission Final Report 출력
/hchain mission resume     → BLOCKED Mission 재개
```

---

## 18. DOD (Definition of Done)

이 설계 Task의 완료 조건:

- [x] 현재 HCHAIN 한계점 문서화 완료
- [x] Mission 개념 정의 완료
- [x] Multi-Agent Layer 정의 완료 (8개 Agent)
- [x] Agent별 책임/입력/출력 정의 완료
- [x] Agent 간 Handoff 규칙 정의 완료
- [x] Mission 상태 모델 정의 완료
- [x] Task 상태 모델 정의 완료 (기존 확장)
- [x] Auto Loop 실행 흐름 정의 완료
- [x] Approval Gate 정책 정의 완료
- [x] Escalation Guard 정책 정의 완료
- [x] Codex Validation Agent 옵션 설계 완료
- [x] Codex 호출 조건 정의 완료
- [x] Codex 결과 반영 방식 정의 완료
- [x] REPORT → NEXT TASK 판단 로직 정의 완료
- [x] Mission 완료 판단 로직 정의 완료
- [x] 파일/디렉토리 구조 제안 완료
- [x] 구현 대상 스크립트 후보 목록 완료
- [x] 코드 수정 없음 (설계 문서만 생성)

---

## 19. 다음 구현 Task 제안

### Task 순서 (의존성 기준)

| 순번 | Task ID 후보 | 내용 | 의존 |
|------|-------------|------|------|
| 1 | TASK_20260602_001 | Mission 데이터 구조 정의 및 템플릿 생성 | 없음 |
| 2 | TASK_20260602_002 | `mission_manager.sh` 기본 구현 (Mission CRUD) | T1 |
| 3 | TASK_20260602_003 | `escalation_guard.sh` 구현 | T1 |
| 4 | TASK_20260602_004 | `mission_loop.sh` 구현 (Auto Loop 진입점) | T2, T3 |
| 5 | TASK_20260602_005 | `planner.sh` 구현 (Task 분해) | T2 |
| 6 | TASK_20260602_006 | `reporter.sh` 구현 | T4 |
| 7 | TASK_20260602_007 | `codex_validator.sh` 구현 | T4 |
| 8 | TASK_20260602_008 | SKILL.md에 `/hchain mission` 명령어 추가 | T2~T6 |
| 9 | TASK_20260602_009 | 통합 테스트 (Mission Loop E2E) | T1~T8 |

### 사용자 승인이 필요한 지점

1. **이 설계 문서 전체** — 구현 진입 전 사용자 검토 및 승인 필요
2. **스크립트 언어 선택** — bash 유지 vs Python/Node 도입 여부 결정 필요
3. **기존 harness/ 호환성** — 기존 단일 Task 실행 방식과의 하위 호환 전략 결정 필요
4. **Codex CLI 연동 방식** — 현재 `codex exec --json --ephemeral` 기반 유지 여부 확인 필요
5. **Mission ID 형식** — `MISSION_YYYYMMDD_NNN` 채택 여부

---

## 변경 요약

| 항목 | 변경 내용 |
|------|-----------|
| 생성 파일 | `docs/tasks/TASK-HARNESS-MISSION-MULTI-AGENT-LOOP-001_design.md` |
| 수정 파일 | 없음 |
| 삭제 파일 | 없음 |
| 코드 변경 | 없음 |

---

*이 문서는 설계 단계 산출물이며, 사용자 승인 후 구현 Task로 진입한다.*
