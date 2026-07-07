# TASK-HARNESS-MISSION-STATE-001

**Title:** Mission Loop 기반 — Mission State 구조 설계 및 구현
**Status:** DONE
**Date:** 2026-06-02
**Stage:** DONE
**Depends on:** TASK-HARNESS-AGENT-LOOP-MVP-001

---

## Goal

Mission Loop의 기반이 되는 Mission State 구조를 설계하고 구현한다.

이번 Task의 목적은 Mission Auto Loop 구현이 아니다.
Mission 진행 상태를 저장하고,
Task 완료 후 다음 Task 판단에 필요한 최소 정보만 유지할 수 있는
Mission State 구조를 만드는 것이다.

---

## Scope

포함:
- `templates/harness/missions/README.md` 생성 (Mission 디렉토리 구조 정의)
- `templates/harness/templates/mission_state.json` 템플릿 생성
- `templates/harness/templates/mission_summary.md` 템플릿 생성
- Mission Status 허용값 정의 (PLANNED / APPROVED / RUNNING / BLOCKED / VALIDATING / DONE / FAILED)
- Token Budget 정책 정의 (문서화만, 로직 구현 없음)

제외:
- `mission_loop.sh` 구현
- `mission_manager.sh` 구현
- Codex CLI 호출 기능
- Context Compression 로직
- 기존 `harness_runner.sh` 수정
- 기존 `active_state.json` 수정
- 기존 queue 구조 수정
- Mission Runtime 구현

---

## Done Criteria

- [x] `templates/harness/missions/README.md` 생성
- [x] `templates/harness/templates/mission_state.json` 생성 (필수 13개 필드 포함)
- [x] `templates/harness/templates/mission_summary.md` 생성 (필수 6개 섹션 포함)
- [x] Mission Status 허용값 7개 정의
- [x] Token Budget 정책 3개 필드 정의 (기본값 포함)
- [x] 기존 harness 파일 수정 없음
- [x] git diff 확인

---

## Steps

1. [PLAN] Task 범위 및 생성 파일 목록 확정
2. [RESEARCH] 기존 harness 구조 확인 — `templates/harness/` 기준 경로 확정 (SKIP 불필요, 직접 탐색)
3. [ACTION] 파일 4개 생성
4. [REVIEW] 생성 파일 내용 및 필수 필드 확인
5. [VALIDATE] git diff로 기존 파일 무수정 확인
6. [DONE] Final Report 생성

---

## Created Files

| 경로 (repo 기준) | 설명 |
|-----------------|------|
| `templates/harness/missions/README.md` | Mission 디렉토리 구조, 상태값, 관계 정의 |
| `templates/harness/templates/mission_state.json` | Mission State 템플릿 (13개 필드) |
| `templates/harness/templates/mission_summary.md` | Mission 압축 요약 템플릿 (6개 섹션) |
| `docs/tasks/TASK-HARNESS-MISSION-STATE-001.md` | 이 파일 |

---

## mission_state.json 필수 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `mission_id` | string | Mission 고유 ID (MISSION_YYYYMMDD_NNN) |
| `mission_goal` | string | Mission 목표 |
| `mission_status` | enum | 현재 상태 (7개 허용값) |
| `success_criteria` | array | 완료 조건 목록 |
| `current_task` | string\|null | 현재 실행 중인 Task ID |
| `next_task` | string\|null | 다음 실행 예정 Task ID |
| `completed_tasks` | array | 완료된 Task ID 목록 |
| `blocked_tasks` | array | 차단된 Task ID 목록 |
| `progress_percent` | number | 진행률 (0–100) |
| `last_report` | string\|null | 마지막 보고서 경로 |
| `mission_summary_ref` | string | mission_summary.md 경로 |
| `token_budget` | object | 컨텍스트 한계 정책 |
| `codex_enabled` | boolean | Codex CLI 연동 여부 |

---

## Token Budget 기본값

| 필드 | 기본값 | 설명 |
|------|--------|------|
| `max_context_tasks` | 3 | Loop에서 유지할 최근 Task 수 |
| `max_summary_size_kb` | 8 | mission_summary.md 최대 크기 |
| `report_retention_count` | 5 | 보관할 Task 완료 보고서 수 |

---

## 미구현 항목

- Mission Loop 런타임 (`mission_loop.sh`)
- Mission Manager 실행기 (`mission_manager.sh`)
- Context Compression 로직
- Codex CLI 연동
- Token Budget 자동 적용 로직
- Mission State 자동 업데이트

---

## 다음 Task 제안

**TASK-HARNESS-MISSION-RUNNER-001**: Mission Loop 런타임 구현
- mission_state.json을 읽어 다음 Task 판단
- harness_runner.sh 호출 연동
- Mission Status 자동 업데이트

---

## Final Report

아래 참조.
