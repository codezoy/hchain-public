# harness/missions/

Mission State 디렉토리.

각 Mission 실행 중 생성된 `mission_state.json` 파일을 저장한다.

---

## 목적

Mission은 하나 이상의 Task로 구성된 목표 단위다.

이 디렉토리는 Mission 진행 상태를 저장하여
Task 완료 후 다음 Task 판단에 필요한 최소 컨텍스트를 유지한다.

Mission Auto Loop 런타임이 아니다.
상태 저장 구조만 정의한다.

---

## 파일 구조

```
harness/missions/
├── README.md                     # 이 파일
├── MISSION_<id>/
│   ├── mission_state.json        # Mission 진행 상태 (templates/mission_state.json 기반)
│   └── mission_summary.md        # Mission 압축 요약 (templates/mission_summary.md 기반)
```

---

## Mission Status 허용값

| 값          | 설명                          |
|-------------|-------------------------------|
| PLANNED     | Mission 정의됨, 미승인         |
| APPROVED    | 승인됨, 실행 대기               |
| RUNNING     | 현재 Task 실행 중              |
| BLOCKED     | 차단됨 (의존성 또는 에러)       |
| VALIDATING  | 최종 검증 단계                  |
| DONE        | 모든 Task 완료, 성공            |
| FAILED      | Mission 실패 또는 중단          |

---

## 관련 파일

- `harness/templates/mission_state.json` — Mission State 템플릿
- `harness/templates/mission_summary.md` — Mission Summary 템플릿
- `harness/queue/` — Task 단위 실행 큐 (Mission과 독립)

---

## Mission vs Task 관계

```
Mission (mission_state.json)
  └── Task 1 (harness/queue/done/TASK_...)
  └── Task 2 (harness/queue/running/TASK_...)
  └── Task 3 (harness/queue/pending/TASK_...)
```

Mission은 Queue를 직접 수정하지 않는다.
Task의 queue 이동은 기존 harness_runner.sh가 담당한다.

---

## Token Budget 정책

Mission State 안의 `token_budget` 필드로 컨텍스트 한계를 정의한다.

기본값:
- `max_context_tasks`: 3 — Loop에서 유지할 최근 Task 수
- `max_summary_size_kb`: 8 — mission_summary.md 최대 크기
- `report_retention_count`: 5 — 보관할 Task 완료 보고서 수

**정책 정의만 수행한다. 실제 적용 로직은 별도 구현한다.**

---

## 미구현 항목

다음은 이 디렉토리 구조가 존재하더라도 아직 구현되지 않은 항목이다:

- Mission Loop 런타임 (`mission_loop.sh`)
- Mission Manager 실행기 (`mission_manager.sh`)
- Context Compression 로직
- Codex CLI 연동
- Token Budget 자동 적용

Mission Loop 구현 전에 이 구조가 먼저 정의되어야 한다.
