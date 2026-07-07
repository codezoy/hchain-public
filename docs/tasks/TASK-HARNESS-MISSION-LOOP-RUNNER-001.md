# TASK-HARNESS-MISSION-LOOP-RUNNER-001: Mission Loop Runner

## Goal

mission_step.sh를 반복 호출하는 최소 Mission Loop Runner를 구현한다.
새로운 Agent Runtime이 아니라, 기존 mission_step.sh를 얇게 감싸
Mission이 DONE/BLOCKED/FAILED 상태가 될 때까지 Step을 반복 실행하는 run 기능만 추가한다.

## Scope

포함:
- `templates/harness/scripts/mission_loop.sh` 생성
- show / dry-run / run 커맨드
- show, dry-run은 mission_step.sh에 위임
- run 커맨드: DONE/BLOCKED/FAILED/next_task=null/step 실패/max_steps 도달 시 종료
- --max-steps 옵션 (기본값 5)

제외:
- mission_step.sh 수정 없음
- mission_manager.sh 수정 없음
- harness_runner.sh 수정 없음
- queue 구조 수정 없음
- Agent Runtime 구현 없음
- Codex 호출 없음
- Token Budget 없음
- Escalation Runtime 없음

## Done Criteria

- [x] mission_loop.sh 생성
- [x] show 위임 동작
- [x] dry-run 위임 동작
- [x] run 동작 (loop with max_steps)
- [x] DONE/BLOCKED/FAILED 종료 조건
- [x] next_task null 종료 조건
- [x] max_steps 도달 시 안전 종료
- [x] bash -n 통과
- [x] 기존 파일 수정 없음

## Files

생성:
- `templates/harness/scripts/mission_loop.sh`
- `docs/tasks/TASK-HARNESS-MISSION-LOOP-RUNNER-001.md`

## Status

DONE
