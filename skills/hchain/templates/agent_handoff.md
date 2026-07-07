# Agent Handoff Template

**Version:** 0.1.0 (MVP)

이 템플릿은 Agent 간 작업 인계 시 사용하는 표준 Handoff 문서다.
각 Agent는 작업 완료 후 이 형식으로 다음 Agent에게 컨텍스트를 전달한다.

---

## Handoff 기본 원칙

1. 모든 Handoff는 파일시스템을 통해 이루어진다 (직접 호출 없음)
2. 각 Agent는 자신의 출력 파일을 생성한 후 완료 신호를 남긴다
3. 다음 Agent는 이전 Agent의 출력 파일을 읽어 입력으로 사용한다
4. Handoff 실패 시 Escalation Guard에 신호를 보낸다

---

## Handoff 파일 경로 규칙

```
harness/missions/{MISSION_ID}/
  ├── plan.json                   ← Mission Manager → Planner
  ├── mission_state.json          ← Mission Manager 관리
  ├── next_task.json              ← Mission Manager → Executor
  ├── escalation.json             ← Escalation Guard 출력
  ├── mission_report.json         ← Mission Manager 최종 보고
  └── tasks/
      ├── {TASK_ID}.plan.json     ← Planner → Executor
      ├── {TASK_ID}.exec.json     ← Executor → Reviewer
      ├── {TASK_ID}.review.json   ← Reviewer → Validator
      ├── {TASK_ID}.valid.json    ← Validator → Reporter
      ├── {TASK_ID}.codex.json    ← Codex Validation Agent (선택)
      └── {TASK_ID}.report.json   ← Reporter → Mission Manager
```

---

## Handoff 흐름 다이어그램

```
Mission Manager
    │ plan.json
    ▼
Planner Agent
    │ TASK_ID.plan.json
    ▼
[Approval Gate] ── (requires_approval=true 시 사용자 확인)
    │ (승인)
    ▼
Executor Agent
    │ TASK_ID.exec.json
    ├──────────────────────────── Escalation Guard (forbidden_files 시도 시)
    ▼
Reviewer Agent
    │ TASK_ID.review.json
    ├──────────────────────────── Escalation Guard (CRITICAL 이슈 시)
    ▼
Validator Agent
    │ TASK_ID.valid.json
    ├──────────────────────────── Escalation Guard (FAIL 반복 시)
    │ (codex_call_needed=true 시)
    ├──────► Codex Validation Agent → TASK_ID.codex.json
    │                                  └── Escalation Guard (HIGH Risk 시)
    ▼
Reporter Agent
    │ TASK_ID.report.json
    ▼
Mission Manager
    │
    ├─ next_task.json → 다음 Task → Planner (loop)
    └─ mission_report.json → Mission DONE
```

---

## Handoff 문서 작성 예시

### Planner → Executor Handoff (TASK_ID.plan.json)

```json
{
  "task_id": "TASK_20260602_001",
  "mission_id": "MISSION_20260602_001",
  "title": "JWT 토큰 갱신 API 구현",
  "goal": "만료된 JWT를 갱신하는 /auth/refresh 엔드포인트를 추가한다",
  "dod": [
    "[ ] POST /auth/refresh 엔드포인트 존재",
    "[ ] 유효 토큰 갱신 시 200 응답",
    "[ ] 만료 토큰 요청 시 401 응답",
    "[ ] 단위 테스트 추가"
  ],
  "depends_on": [],
  "assigned_agent": "Executor",
  "scope": {
    "allowed_files": [
      "src/api/auth.ts",
      "src/utils/token.ts",
      "src/api/__tests__/auth.test.ts"
    ],
    "forbidden_files": [
      "db/schema.sql",
      "config/env.ts",
      "harness/"
    ]
  },
  "validation_commands": [
    "pnpm test src/api/__tests__/auth.test.ts",
    "curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/auth/refresh"
  ],
  "requires_approval": false,
  "research_notes": "기존 /auth/login 구조 참고. token.ts의 verifyToken 함수 재사용.",
  "created_at": "2026-06-02T00:00:00Z"
}
```

### Executor → Reviewer Handoff (TASK_ID.exec.json)

```json
{
  "task_id": "TASK_20260602_001",
  "mission_id": "MISSION_20260602_001",
  "status": "DONE",
  "changed_files": [
    "src/api/auth.ts",
    "src/api/__tests__/auth.test.ts"
  ],
  "unchanged_files": ["src/utils/token.ts"],
  "forbidden_file_attempted": false,
  "execution_log": "POST /auth/refresh 엔드포인트 추가. 기존 verifyToken 함수 재사용. 단위 테스트 3개 추가.",
  "error": null,
  "retry_count": 0,
  "completed_at": "2026-06-02T00:10:00Z"
}
```

### Reviewer → Validator Handoff (TASK_ID.review.json)

```json
{
  "task_id": "TASK_20260602_001",
  "mission_id": "MISSION_20260602_001",
  "status": "PASS",
  "issues": [
    {
      "severity": "NIT",
      "file": "src/api/auth.ts",
      "line": 87,
      "type": "STYLE",
      "message": "함수 반환 타입 명시 권장"
    }
  ],
  "out_of_scope_files": [],
  "escalation_required": false,
  "codex_risk_level": "NONE",
  "reviewed_at": "2026-06-02T00:15:00Z"
}
```

### Validator → Reporter Handoff (TASK_ID.valid.json)

```json
{
  "task_id": "TASK_20260602_001",
  "mission_id": "MISSION_20260602_001",
  "status": "PASS",
  "checks": [
    {
      "dod_item": "[ ] pnpm test 통과",
      "command": "pnpm test src/api/__tests__/auth.test.ts",
      "result": "PASS",
      "output": "3 passed",
      "exit_code": 0
    }
  ],
  "blocking_issues": [],
  "codex_call_needed": false,
  "codex_call_reason": null,
  "retry_count": 0,
  "validated_at": "2026-06-02T00:20:00Z"
}
```

### Reporter → Mission Manager Handoff (TASK_ID.report.json)

```json
{
  "task_id": "TASK_20260602_001",
  "mission_id": "MISSION_20260602_001",
  "status": "DONE",
  "changed_files": ["src/api/auth.ts", "src/api/__tests__/auth.test.ts"],
  "issues_remaining": [
    {"severity": "NIT", "message": "함수 반환 타입 명시 권장", "file": "src/api/auth.ts"}
  ],
  "next_task_ready": true,
  "next_task_id": "TASK_20260602_002",
  "mission_progress": "1/3 tasks completed",
  "summary": "JWT 갱신 API 구현 완료. 테스트 3개 통과. NIT 이슈 1건 기록.",
  "reported_at": "2026-06-02T00:25:00Z"
}
```

---

## Escalation 신호 예시 (escalation_signal.json)

```json
{
  "source_agent": "Executor",
  "task_id": "TASK_20260602_002",
  "trigger": "forbidden_file_attempted",
  "detail": "src/db/schema.sql 수정이 필요하나 forbidden_files에 포함됨",
  "severity": "IMMEDIATE"
}
```

---

## Handoff 체크리스트

Agent가 Handoff 파일을 생성하기 전 확인 항목:

- [ ] task_id와 mission_id가 일치하는가
- [ ] status 값이 정확한가 (PASS/FAIL/DONE/FAILED/BLOCKED)
- [ ] 필수 필드가 모두 채워져 있는가
- [ ] created_at / completed_at / reviewed_at / validated_at / reported_at 타임스탬프가 있는가
- [ ] forbidden_files 시도 여부가 기록되어 있는가 (Executor)
- [ ] escalation_required 판정이 포함되어 있는가 (Reviewer)
