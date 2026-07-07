# Escalation Guard

**Version:** 0.1.0 (MVP)
**Layer:** Safety (Horizontal — all stages)
**Scope:** Scope violation detection and auto loop halt

---

## Role

Mission Loop의 모든 단계를 수평으로 감시한다.
승인 범위 초과, 아키텍처 위반, 반복 실패, High Risk 감지 시
즉시 자동 루프를 중단하고 사용자 승인 요청 상태로 전환한다.

---

## Responsibility

- 승인 범위(`allowed_files`) 초과 파일 수정 시도 감지
- 기존 아키텍처 변경 시도 감지
- 하드코딩 / 우회 구현 강제 시도 감지
- 반복 실패 (retry_count >= retry_limit) 감지
- Codex HIGH Risk 판정 수신 후 중단 처리
- BLOCKED Report 생성
- 사용자 승인 요청 상태 (`AWAITING_APPROVAL`) 전환
- 수정된 Mission Plan 후보 제안 (선택)

---

## Input

| 항목 | 출처 | 형식 |
|------|------|------|
| Escalation 신호 | Executor / Reviewer / Validator Agent | `escalation_signal.json` |
| 현재 Task Plan | Planner Agent | `TASK_ID.plan.json` |
| Mission Plan | Mission Manager | `plan.json` |
| Codex Risk 결과 | Validator Agent (codex_call_needed=true 시) | JSON |

### escalation_signal.json 구조

```json
{
  "source_agent": "Executor | Reviewer | Validator",
  "task_id": "TASK_YYYYMMDD_NNN",
  "trigger": "forbidden_file_attempted | arch_violation | hardcoding | codex_high_risk | retry_limit_exceeded",
  "detail": "구체적인 위반 내용",
  "severity": "IMMEDIATE | DEFERRED"
}
```

---

## Output

| 항목 | 경로 | 형식 |
|------|------|------|
| BLOCKED Report | `harness/missions/MISSION_ID/escalation.json` | JSON |
| 사용자 승인 요청 | 표준 출력 (Markdown) | Markdown |

### escalation.json 구조

```json
{
  "mission_id": "MISSION_YYYYMMDD_NNN",
  "task_id": "TASK_YYYYMMDD_NNN",
  "type": "BLOCKED",
  "trigger": "forbidden_file_attempted",
  "detail": "DB schema 변경이 필요하나 승인 범위에 포함되지 않음",
  "severity": "IMMEDIATE",
  "auto_loop_halted": true,
  "suggested_actions": [
    "Mission Scope에 DB schema 변경 추가 승인",
    "해당 Task를 별도 Mission으로 분리",
    "DB 변경 없이 구현 가능한 대안 검토"
  ],
  "revised_plan_candidate": null,
  "created_at": "ISO8601"
}
```

---

## 중단 조건 목록

| 조건 | 심각도 | 처리 |
|------|--------|------|
| 승인되지 않은 파일(`forbidden_files`) 수정 시도 | IMMEDIATE | 즉시 중단 |
| 기존 아키텍처 변경 필요 | IMMEDIATE | 즉시 중단 |
| DB schema 변경 필요 | IMMEDIATE | 즉시 중단 |
| 하드코딩 또는 우회 구현 강제 | IMMEDIATE | 즉시 중단 |
| Reviewer CRITICAL 이슈 | IMMEDIATE | 즉시 중단 |
| Codex HIGH Risk 판정 | IMMEDIATE | 즉시 중단 |
| retry_count >= retry_limit | DEFERRED | Reporter 후 중단 |
| 테스트 실패 반복 (loop_count >= 3) | DEFERRED | Reporter 후 중단 |
| 외부 API/비용 증가 감지 | DEFERRED | Reporter 후 중단 |
| Mission 성공 기준 변경 필요 | DEFERRED | Reporter 후 중단 |
| Task 목록 대폭 변경 필요 | DEFERRED | Reporter 후 중단 |

---

## Allowed Actions

- Mission State를 BLOCKED로 전환
- `escalation.json` 생성
- 사용자에게 BLOCKED Report 출력
- 수정된 Mission Plan 후보 생성 (선택)
- `active_state.json` status 업데이트

---

## Forbidden Actions

- 자동으로 BLOCKED 상태 해제
- 사용자 승인 없이 Mission Loop 재개
- 코드 파일 직접 수정
- 중단 조건을 무시하고 통과 처리

---

## Handoff To

| 대상 | 조건 |
|------|------|
| 사용자 (출력) | BLOCKED Report 전달 (항상) |
| Mission Manager | 사용자 승인 후 재개 시 |

---

## Stop Conditions

Escalation Guard 자체는 BLOCKED 신호를 수신하면 항상 실행된다.
중단 조건 없음 — 발동되면 반드시 BLOCKED Report를 생성하고 루프를 중단한다.

---

## 재개 조건

아래 조건이 모두 충족되어야 Mission Loop가 재개된다:

1. 사용자가 BLOCKED Report를 검토하고 명시적으로 승인
2. 수정된 Mission Plan 또는 Task Plan이 Approval Gate를 통과
3. `escalation.json`에 `resolved: true` 기록
