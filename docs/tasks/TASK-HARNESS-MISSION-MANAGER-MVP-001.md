# TASK-HARNESS-MISSION-MANAGER-MVP-001: Mission Manager MVP

## Goal

Mission State (`mission_state.json`)를 관리하는 최소 Mission Manager를 구현한다.
Mission Loop, Agent 실행, Queue 이동은 포함하지 않는다.
단순 상태 읽기/쓰기, 진행률 계산, Dry Run만 수행한다.

## Scope

포함:
- `templates/harness/scripts/mission_manager.sh` 생성
- `docs/tasks/TASK-HARNESS-MISSION-MANAGER-MVP-001.md` 생성
- 7개 명령: show, update-progress, set-current, set-next, mark-completed, mark-blocked, dry-run
- jq 기반 JSON 조작 (jq 없으면 명확한 에러 출력)
- mission_status_allowed_values 기준 상태 검증 (하드코딩 금지)
- progress 계산: task_batch > success_criteria > 기존 값 유지 (경고 출력)

제외:
- mission_loop.sh 구현
- Agent 실행 (Executor / Reviewer / Validator / Codex)
- Queue 이동 (pending / running / done / blocked)
- Escalation 처리
- harness_runner.sh 수정
- install.sh / SKILL.md / Agent 문서 수정

## Done Criteria

- [x] `mission_manager.sh` 생성
- [x] `show` 동작 (상태 요약 출력)
- [x] `update-progress` 동작 (progress_percent 갱신)
- [x] `set-current` 동작 (current_task 갱신)
- [x] `set-next` 동작 (next_task 갱신)
- [x] `mark-completed` 동작 (completed_tasks 추가, progress 재계산)
- [x] `mark-blocked` 동작 (blocked_tasks 추가)
- [x] `dry-run` 동작 (상태 변경 없이 전체 필드 출력)
- [x] `bash -n` syntax check 통과
- [x] 기존 harness_runner.sh / queue 구조 미변경

## Status

DONE

## Final Report

→ 아래 완료보고 참조
