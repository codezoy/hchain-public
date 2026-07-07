# HCHAIN Planner State Schema

**Version:** 0.1.0
**Status:** Draft
**Date:** 2026-06-03
**Task:** TASK-HCHAIN-PLANNER-STATE-SCHEMA-001

---

## 1. Purpose

Planner Feedback MVP가 Mission 실행 기록과 피드백 루프 횟수를 추적할 수 있도록
`mission_state.json` 스키마에 최소 필드를 추가한다.

추가하지 않은 필드:
- `planner_status` → `mission_status`로 대체 가능 (중복)
- `next_task` → 기존 필드 재사용 (이미 존재)

---

## 2. Added Fields

### `planner_last_run`

| 항목 | 값 |
|------|-----|
| 타입 | `string \| null` |
| 형식 | ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`) |
| 초기값 | `null` |
| 갱신 주체 | Planner (Task 생성 완료 시) |

Planner가 마지막으로 실행된 시각을 기록한다.
`null`은 Planner가 아직 한 번도 실행되지 않았음을 의미한다.

### `feedback_cycle`

| 항목 | 값 |
|------|-----|
| 타입 | `integer` |
| 범위 | `>= 0` |
| 초기값 | `0` |
| 갱신 주체 | Planner (Task 생성 완료 시 +1) |

Planner가 Task를 생성한 횟수(피드백 루프 횟수)를 기록한다.
`0`은 Planner가 아직 Task를 생성하지 않았음을 의미한다.

---

## 3. Schema Examples

### 초기 상태 (Planner 미실행)

```json
{
  "mission_id": "MISSION-AI-VIDEO-VISUAL-AUDIT-001",
  "mission_status": "PLANNED",
  "next_task": null,
  "planner_last_run": null,
  "feedback_cycle": 0,
  "created_at": "2026-06-03T10:00:00Z",
  "updated_at": "2026-06-03T10:00:00Z"
}
```

### Planner 3회 실행 후

```json
{
  "mission_id": "MISSION-AI-VIDEO-VISUAL-AUDIT-001",
  "mission_status": "RUNNING",
  "next_task": "TASK-VISUAL-FIX-ITEMS-001",
  "planner_last_run": "2026-06-03T14:30:00Z",
  "feedback_cycle": 3,
  "created_at": "2026-06-03T10:00:00Z",
  "updated_at": "2026-06-03T14:30:00Z"
}
```

---

## 4. Applied Files

| 파일 | 변경 | 내용 |
|------|------|------|
| `templates/harness/templates/mission_state.json` | 수정 | `planner_last_run`, `feedback_cycle` 추가 |

---

## 5. Reviewed Files (No Change Required)

### mission_manager.sh

- jq 파싱 방식: `.field // "default"` 패턴 사용
- 새 필드를 직접 참조하는 코드 없음
- `atomic_write`는 지정 필드만 갱신 → 신규 필드 보존됨
- **영향 없음**

### mission_step.sh

- 읽는 필드: `.next_task`, `.mission_id`, `.mission_status`
- 새 필드 참조 없음
- **영향 없음**

### mission_loop.sh

- 읽는 필드: `.agent_mode`, `.agent_mode_allowed_values`, `.mission_status`, `.next_task`
- 새 필드 참조 없음
- **영향 없음**

---

## 6. Backward Compatibility

### 원칙

- 기존 `mission_state.json`에 `planner_last_run`과 `feedback_cycle`이 없어도 동작한다.
- 기존 Mission 파일을 강제로 수정하지 않는다.

### jq 접근 패턴 (권장)

Planner가 이 필드를 읽을 때는 반드시 기본값 fallback을 사용해야 한다:

```bash
planner_last_run=$(jq -r '.planner_last_run // null' "$STATE_FILE")
feedback_cycle=$(jq -r '.feedback_cycle // 0' "$STATE_FILE")
```

이렇게 하면 필드가 없는 구형 Mission에서도 안전하게 동작한다.

---

## 7. Migration Policy

| 상황 | 처리 방식 |
|------|----------|
| 신규 Mission | 템플릿 기본값 사용 (`null`, `0`) |
| 기존 Mission (필드 없음) | jq fallback으로 기본값 처리, 파일 수정 불필요 |
| 기존 Mission (강제 추가 원할 경우) | 수동으로 필드 추가 (자동화하지 않음) |

**강제 Migration 금지:** 기존 Mission 파일을 자동으로 수정하는 스크립트는 작성하지 않는다.

---

## 8. Failure Cases

| 케이스 | 원인 | 처리 |
|--------|------|------|
| `feedback_cycle`가 음수가 됨 | Planner 버그 | Planner 구현 시 `>= 0` 검증 추가 |
| `planner_last_run` 형식 오류 | ISO 8601 미준수 | Planner 구현 시 `date -u +%Y-%m-%dT%H:%M:%SZ` 사용 |
| `atomic_write` 중 충돌 | 동시 쓰기 | `mission_manager.sh`의 기존 atomic_write 패턴 그대로 활용 |
| 필드 누락 (구형 Mission) | 이전 템플릿 사용 | jq `// default` fallback으로 처리, 오류 없음 |

---

## 9. Validation Checklist

- [x] 기존 Mission과 호환되는가
  → jq fallback 패턴으로 필드 없어도 동작
- [x] Mission Loop (`mission_loop.sh`)와 충돌 없는가
  → 신규 필드를 참조하지 않음, 영향 없음
- [x] Planner가 필요한 정보를 저장할 수 있는가
  → `planner_last_run`(실행 시각), `feedback_cycle`(루프 횟수) 저장 가능
- [x] 향후 Agent Runtime 확장 가능한가
  → 독립 필드로 추가되어 기존 구조 비간섭, 확장 시 필드 추가만 하면 됨
