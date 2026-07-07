# TASK-HARNESS-AGENT-LOOP-MVP-001

**Title:** HCHAIN Agent Loop MVP — Agent Role 정의 및 Handoff 템플릿 생성
**Status:** DONE
**Date:** 2026-06-02
**Stage:** ACTION (문서 생성 완료)
**Depends on:** TASK-HARNESS-MISSION-MULTI-AGENT-LOOP-001 (설계 문서)

---

## Goal

HCHAIN Mission Loop에서 사용할 수 있는 최소 Agent Loop 구조를 구현한다.

이번 Task는 거대한 Agent 실행기를 새로 만드는 것이 아니라,
Mission Loop가 Planner → Executor → Reviewer → Validator → Reporter → Next Task
흐름을 안정적으로 반복할 수 있도록
Agent Role 정의, Handoff Contract, Agent 상태 모델, 최소 템플릿을 추가하는 것이다.

---

## Scope

포함:
- Agent 정의 문서 7개 생성 (`skills/hchain/agents/`)
- Agent Handoff 템플릿 1개 생성 (`skills/hchain/templates/`)
- 각 Agent의 Role / Input / Output / Stop Conditions 정의
- Codex Validation 옵션 정의 (Validator Agent 문서 내)
- Handoff Contract (파일 경로, JSON 구조, 전달 흐름)

제외:
- 코드 실행 루프 구현 (shell 스크립트)
- Codex CLI 실제 호출 스크립트
- `harness_runner.sh` 수정 또는 대체
- 기존 harness/ 디렉토리 파일 수정

---

## Done Criteria

- [x] Agent 문서 7개 생성 (mission_manager, planner, executor, reviewer, validator, reporter, escalation_guard)
- [x] 각 Agent 문서에 Role / Responsibility / Input / Output / Allowed Actions / Forbidden Actions / Handoff To / Stop Conditions 포함
- [x] Codex 옵션은 Validator Agent 문서에만 정의
- [x] Agent Handoff 템플릿 생성 (흐름 다이어그램 + 예시 JSON 포함)
- [x] 기존 실행 파일 수정 없음

---

## Steps

1. [PLAN] Task 범위 및 생성 파일 목록 확정
2. [RESEARCH] 기존 HCHAIN 설계 문서 및 User Guide 검토 (SKIP — 설계 문서에서 충분히 정의됨)
3. [ACTION] Agent 문서 7개 + Handoff 템플릿 생성
4. [REVIEW] 생성 파일 목록 및 내용 확인
5. [VALIDATE] git diff로 기존 파일 무수정 확인
6. [DONE] Final Report 생성

---

## Created Files

| 파일 | 역할 |
|------|------|
| `skills/hchain/agents/mission_manager_agent.md` | Mission 생명주기 관리 Agent 정의 |
| `skills/hchain/agents/planner_agent.md` | Task 분해 및 DOD 정의 Agent 정의 |
| `skills/hchain/agents/executor_agent.md` | 코드 구현 Agent 정의 |
| `skills/hchain/agents/reviewer_agent.md` | 정적 코드 감사 Agent 정의 |
| `skills/hchain/agents/validator_agent.md` | DOD 런타임 검증 Agent 정의 (Codex 옵션 포함) |
| `skills/hchain/agents/reporter_agent.md` | Task/Mission 결과 보고 Agent 정의 |
| `skills/hchain/agents/escalation_guard.md` | Scope 초과 감지 및 루프 중단 Agent 정의 |
| `skills/hchain/templates/agent_handoff.md` | Agent 간 Handoff 계약 및 예시 JSON |
| `docs/tasks/TASK-HARNESS-AGENT-LOOP-MVP-001.md` | 이 문서 (Task 기록) |

---

## Final Report

최종 완료보고는 반드시 따5코(`````) 안에 작성한다. → 아래 참조.
