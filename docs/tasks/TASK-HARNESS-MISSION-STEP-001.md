# TASK-HARNESS-MISSION-STEP-001: Mission Step Runtime

## Goal

Mission Runtime의 가장 작은 실행 단위인 Mission Step을 구현한다.
Mission State에서 next_task 하나를 선택하고, 기존 harness_runner.sh에 전달하고,
Mission State를 갱신하는 단일 Step만 수행한다.
자동 반복 없이 반드시 종료한다.

## Scope

포함:
- `templates/harness/scripts/mission_step.sh` 생성
- `docs/tasks/TASK-HARNESS-MISSION-STEP-001.md` 생성
- 3개 명령: show, dry-run, step
- show: mission_manager.sh show 위임
- dry-run: mission_status / current_task / next_task / progress_percent 출력 (변경 없음)
- step: next_task → current_task 설정 → harness_runner.sh --task 호출 → 결과 확인 → mission_state.json 갱신 → 종료
- 성공 시: mark-completed + current_task = null + progress 갱신
- 실패 시: mark-blocked + mission_status = BLOCKED

제외:
- while 루프 / 자동 반복 / run 명령
- Agent Orchestration (Reviewer / Validator / Codex / Escalation)
- harness_runner.sh 수정
- queue 구조 수정
- install.sh / SKILL.md / Mission Manager 수정
- 개인 경로 하드코딩

## Done Criteria

- [x] `mission_step.sh` 생성
- [x] `show` 동작 (mission_manager.sh show 위임)
- [x] `dry-run` 동작 (4개 필드 출력, 변경 없음)
- [x] `step` 동작 (next_task → runner → state 갱신 → 종료)
- [x] Mission State 읽기 성공
- [x] Mission Manager와 연동 가능
- [x] 기존 Queue 구조 미변경
- [x] 기존 harness_runner.sh 미변경
- [x] `bash -n` 통과

## Status

DONE

## Final Report

→ 아래 완료보고 참조
