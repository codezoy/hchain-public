# TASK-HCHAIN-PLANNER-HOOK-STABILIZE-001: Stabilize Planner Hook

## Goal

현재 구현된 `Task DONE → Planner Hook → Task 생성 → Queue 등록` 구조를 안정화한다.
해결 대상: (1) Planner 중복 실행으로 인한 동일 Task 중복 생성, (2) HCHAIN_MISSION_ID 환경변수 수동 지정 의존성.

## Source

- Created: 2026-06-04T00:00:00Z
- Type: HCHAIN Core Stabilization

## Scope

포함:
- `planner/planner_feedback.sh` — Report 기준 idempotency 추가 (`last_processed_report` 체크)
- `harness_runner.sh` — Mission Context 자동 탐지 로직 추가 (Planner Auto Hook 섹션)
- Mission Context 탐지 우선순위: active_state.json → missions/**/mission_state.json(RUNNING) → 환경변수
- Fallback: 자동 감지 실패 시 WARN 출력 후 Planner Skip
- Validation: 동일 Report 3회 실행 시 Task 1회 생성, feedback_cycle 1회 증가 확인

제외:
- Agent Runtime 구현 금지
- Message Bus 구현 금지
- Next Task 자동 실행 금지
- Mission Loop 구조 변경 금지
- harness_runner.sh의 Planner Auto Hook 섹션 외 코드 변경 금지

## Done Criteria

- [ ] 동일 Report 3회 실행 → Task 1회 생성, feedback_cycle 1 증가만 발생
- [ ] HCHAIN_MISSION_ID 없이도 RUNNING Mission 자동 탐지 성공
- [ ] Mission 없을 시 WARN 출력 후 Planner Skip (에러 없음)
- [ ] 기존 Task Loop (chain, resume 등) 동작에 영향 없음
- [ ] `git commit -m "feat: stabilize planner hook"` 완료
- [ ] `git push origin feature/planner-feedback-mvp` 완료

## Steps

1. [PLAN] 현재 planner_feedback.sh 중복 방지 구조 분석 (STEP-5 duplicate check 확인)
2. [RESEARCH] Lock 전략 결정: `last_processed_report` 필드를 mission_state.json에 추가하는 방식 채택
   - planner.lock 방식: 경쟁 조건 위험, 프로세스 비정상 종료 시 stale lock 발생
   - last_processed_report 방식: atomic_write_state와 일관된 방식, 최소 수정
3. [ACTION]
   - **planner_feedback.sh 수정** (STEP-1 이후):
     - STEP-0 추가: mission_state.json에서 `last_processed_report` 읽기
     - REPORT_FILE 결정 후: basename과 last_processed_report 비교
     - 동일하면 `[INFO] Already processed: <report> — skip` 출력 후 exit 0
     - STEP-8 (state update) 시: `last_processed_report` 필드도 함께 갱신
   - **harness_runner.sh 수정** (Planner Auto Hook 섹션, line 2080-2101):
     - `HCHAIN_MISSION_ID` 없을 때 자동 탐지 로직 추가
     - 탐지 우선순위:
       1. `active_state.json`의 `mission_id` 필드
       2. `missions/*/mission_state.json` 중 `mission_status == "RUNNING"` 첫 번째
       3. 환경변수 `HCHAIN_MISSION_ID`
     - 탐지 실패 시: `[WARN] Planner SKIP — no Mission Context detected` 출력 후 skip
4. [REVIEW] 변경된 두 파일 정적 검토 (set -euo pipefail 호환, jq 구문, atomic_write_state 일관성)
5. [VALIDATE]
   - Case-1: MISSION-TEST-PLANNER-001 존재 → 자동 감지 성공 확인
   - Case-2: HCHAIN_MISSION_ID 미설정 + mission 없음 → WARN + Skip 확인
   - Case-3: 동일 Report로 planner_feedback.sh 3회 실행 → Task 1회, feedback_cycle 1 증가 확인
6. [DONE] commit + push

## Final Report

최종 완료보고는 반드시 따5코(`````）안에 작성한다.

```
=== TASK-HCHAIN-PLANNER-HOOK-STABILIZE-001 Final Report ===

1. 생성/수정 파일
2. Idempotency 설계 (last_processed_report 방식 채택 이유)
3. Mission Auto Detect 설계 (탐지 우선순위 및 구현)
4. Validation 결과
5. 중복 실행 테스트 결과 (3회 실행 → 1회 생성 확인)
6. Auto Detect 테스트 결과 (Case-1, Case-2)
7. Commit Hash
8. Push 결과
9. 기존 Task Loop 영향 분석
10. 다음 추천 Task
```
