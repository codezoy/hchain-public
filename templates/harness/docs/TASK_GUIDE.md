# TASK_GUIDE — Task 실행 절차

> 본 문서는 `harness_runner.sh` / `taskctl.sh` 를 통해 task를 실행하는 표준 절차를 정의한다.

---

## 0. Task YAML frontmatter 형식

모든 task `.md` 파일은 파일 맨 위에 YAML frontmatter를 포함한다.

```yaml
---
task_id: TASK_YYYYMMDD_NNN
title: 태스크 제목
retry_limit: 3
severity_stop: MAJOR
validate: true
---
```

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `task_id` | string | (파일명 유추) | 고유 태스크 ID |
| `title` | string | — | 태스크 제목 |
| `retry_limit` | int | 3 | 최대 ACTION 재시도 횟수 |
| `severity_stop` | CRITICAL\|MAJOR\|MINOR\|NIT | MAJOR | 이 등급 이상 이슈 시 ACTION 재진입 |
| `validate` | bool | true | VALIDATE 단계 실행 여부 |

- `harness/lib/task_meta.sh` 의 `parse_task_meta()` 함수로 파싱한다.
- frontmatter 없는 기존 파일은 기본값이 적용되며 파싱 오류가 발생하지 않는다.

---

## 1. Task 파일 위치

| 파일 | 역할 |
|---|---|
| `harness/tasks/TASK_ID.md` | Task 정의서 (Source of Truth) |
| `harness/tasks/TASK_ID.state.json` | 장기 상태 추적 |
| `harness/tasks/TASK_ID.checkpoint.json` | 재개용 컨텍스트 |
| `harness/queue/{pending,running,done,blocked}/TASK_ID` | 큐 위치 마커 |

## 2. Task 생명주기

```
pending → running → done
                 ↘ blocked (loop_count==3 또는 user 중단)
```

- 상태 전환: `harness/queue/move.sh <TASK_ID> <FROM> <TO>`

## 3. 표준 워크플로우

```
PLAN → RESEARCH → ACTION → REVIEW → VALIDATE → DONE
```

- step enum 6개만 허용: `PLAN | RESEARCH | ACTION | REVIEW | VALIDATE | DONE`
- DECISION 은 step 이 아니라 REVIEW+VALIDATE 결과에 따른 분기 로직

### 3.1 RESEARCH 단계 정의

RESEARCH = 구현 전 조사 단계. 수행 주체 무관.

| 수행 주체 | 사용 시점 |
|-----------|-----------|
| Gemini CLI (RESEARCHER agent) | 외부 기술조사, 웹 검색 |
| Claude | 내부 파일 분석, 기존 코드 검토 |
| Human | 도메인 지식, 정책 판단 |

### 3.2 RESEARCH SKIP 정책

RESEARCH는 원칙적으로 생략 금지.
다음 경우에만 SKIP 허용:
- 단순 문구 수정 (조사할 내용 없음)
- 직전 Task에서 동일 대상 조사 완료 (같은 세션)
- 사용자 명시 선언

SKIP 기록 방법:
  step: "RESEARCH", result: "SKIP", reason: "단순 오타 수정"

## 4. INTERRUPTED 처리

- step 필드에 INTERRUPTED 기록 금지 (result/status 계층에서만 관리)
- 중단 전 반드시 checkpoint.json 의 `resume_prompt` 갱신
- 큐: `running → pending` 이동

## 5. 재개 조건

- 사용자가 "이어서" / "resume" / "TASK_XXX 마저" 표현 사용 시
- `next_resume_step` 에 저장된 step 부터 재개
- BLOCKED task 는 `taskctl.sh resume --force` 명시 승인 필요

## 7. Major Issue 감지 시 행동 규칙

다음 조건 중 하나라도 발생하면 **현재 Task 중단**, PLAN LOOP 선언:

```
MAJOR ISSUE DETECTED → PLAN LOOP REQUIRED
```

조건: 재발견 결함(A) / 새 Root Cause(B) / Contract GAP(C) / 재발방지 없음(D) /
      E2E 없음(F) / Health Score<10(G) / Remaining Issues(H) / 금지 문구(I) / PASS_WITH_ISSUES(J)

즉각 핫픽스로 처리 금지. 반드시 PLAN LOOP 10단계 완료 후 종료.

참조: `policies/HCHAIN_MAJOR_ISSUE_DEFINITION.md`

## 6. 세션 시작 체크리스트

1. `cat harness/active_state.json | jq .` 로 상태 로드
2. `loop_count >= 3` 이면 즉시 Safety Break
3. `human_checkpoint_required == true` 이면 승인 대기
4. INTERRUPTED task 스캔:
   ```bash
   ls harness/tasks/*.state.json | xargs -I{} jq -c '{task_id,status,next_resume_step}' {}
   ```
