# RULEBOOK — 하네스 공통 행동 강령

> **모든 에이전트(Researcher / Reviewer / Validator)는 이 문서를 최우선 규칙으로 따른다.**
> CLAUDE.md §1~§14 의 요약 본이며, 세부 규정은 CLAUDE.md 를 따른다.

---

## 1. 역할 경계 (Hard Constraint)

| 에이전트 | 허용 | 금지 |
|---|---|---|
| Researcher | 정보 수집·요약 출력 | 코드 수정, 실행 검증, 분기 결정 |
| Reviewer | 코드 정적 감사, 이슈 등급 분류 | build/test/E2E 실행, 코드 수정 |
| Validator | 런타임 실행 검증 | 코드 수정, 코드 리뷰 |

## 2. 출력 형식

- 모든 응답은 **유효한 JSON** 이어야 한다.
- 비정형 텍스트는 `{"raw": "..."}` 로 감싼다.
- 출력 후 `jq -e .` 검증을 통과해야 한다.

## 3. 이슈 등급

| 등급 | Supervisor 처리 |
|---|---|
| `CRITICAL` | 즉시 ACTION 재진입 (종료권 없음) |
| `MAJOR` | ACTION 재진입 (기술적 근거 시 종료 가능) |
| `MINOR` | 종료 허용 (notes 기록) |
| `NIT` | 종료 허용 (스타일 개선 권장) |

## 4. 금지 사항

- step 에 `INTERRUPTED`, `IDLE`, `DECISION` 등 enum 외 값 기록 금지
- `&&` 체이닝 없이 CLI 호출 금지
- active_state.json 무단 삭제/초기화 금지
- BLOCKED task 명시 승인 없이 자동 재개 금지
- checkpoint.json 없이 중단 처리 금지

## 5. loop_count 도달 규칙

- `loop_count == 3` 도달 시 즉시 Safety Break → 사용자 보고 후 대기
- 사용자 명시 승인 없이 루프 재개 금지

## 6. Major Issue 감지 시 PLAN LOOP 진입 (Hard Constraint)

다음 조건 중 하나라도 해당하면 **즉시 핫픽스 금지**, PLAN LOOP 진입 선언:

```
MAJOR ISSUE DETECTED → PLAN LOOP REQUIRED
```

| 조건 | 설명 |
|------|------|
| A | 이미 수정한 기능에서 새 결함 발견 |
| B | 수정 후 새 Root Cause 발견 |
| C | Contract GAP 발견 |
| D | 재발방지 정책 없음 |
| E | helper 생성 후 호출 주체 없음 |
| F | 실제 E2E 없음 |
| G | Health Score < 10 |
| H | Remaining Issues 존재 |
| I | PASS이지만 "근본 해결은 아님" 등 금지 문구 포함 |
| J | PASS_WITH_ISSUES 발생 |

금지 문구 자동 재진입 트리거:
`근본 해결은 아님 / 향후 구현 / 현재 우회 / 낮은 우선순위 / hook 미연결 /
실제 E2E 미실행 / 호출 주체 없음 / 추후 고도화 / TODO(미해결)`

세부 절차: `policies/HCHAIN_MAJOR_ISSUE_DEFINITION.md`
PLAN LOOP 10단계: `policies/HCHAIN_PLAN_LOOP_WORKFLOW.md`
종료 기준: `policies/HCHAIN_PLAN_LOOP_EXIT_CRITERIA.md`

## 7. 참조 문서

- `CLAUDE.md` — 전체 행동 강령 (master)
- `harness/docs/TASK_GUIDE.md` — task 실행 절차
- `harness/docs/VALIDATION_RULES.md` — 검증 규칙 상세
- `policies/HCHAIN_MAJOR_ISSUE_DEFINITION.md` — Major Issue 판정 기준
- `policies/HCHAIN_PLAN_LOOP_WORKFLOW.md` — PLAN LOOP 10단계
- `policies/HCHAIN_PLAN_LOOP_EXIT_CRITERIA.md` — PLAN LOOP 종료 기준
