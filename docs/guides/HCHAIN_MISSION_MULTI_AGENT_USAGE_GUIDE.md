# HCHAIN Mission & Multi-Agent 사용 가이드

## 1. HCHAIN Mission 기능 한 줄 정의

Mission 목표를 Mission State로 관리하고, Mission Manager/Step/Loop를 통해 승인된 Task를 반복 실행하는 최소 자동화 구조.

---

## 2. Multi-Agent 현재 지원 수준

### 현재 지원

- Agent Contract 문서
- Agent Handoff 템플릿
- `agent_mode = off / contract / runtime`
- `contract` 모드 기본값
- Mission Manager (`mission_manager.sh`)
- Mission Step (`mission_step.sh`)
- Mission Loop (`mission_loop.sh`)

### 아직 미지원

- 실제 Multi-Agent Runtime
- Planner/Executor/Reviewer/Validator/Reporter 독립 프로세스 실행
- Codex Runtime 자동 호출
- Token Budget Runtime
- Escalation Runtime 고도화

---

## 3. agent_mode 설명

```text
off      : Agent Contract 사용 안 함
contract : Agent Contract 문서를 기준으로 Claude가 역할을 준수하는 방식
runtime  : 미래 확장 예약값, 현재 구현 없음
```

```text
현재 기본값은 contract 이며, 별도의 --agent-mode CLI 옵션은 아직 없다.
agent_mode는 mission_state.json에 기록된다.
```

---

## 4. 기존 Task와 Mission Loop 차이

| 구분 | 기존 Task | Mission Loop |
|---|---|---|
| 목적 | 단일 작업 | 여러 Task로 목표 달성 |
| 상태 | Queue 중심 | Mission State 중심 |
| 실행 | `harness_runner.sh` | `mission_loop.sh` → `mission_step.sh` |
| 사용 시점 | 작은 수정 | 목표 단위 자동 진행 |

---

## 5. 사용 예시

### 단일 Task

```text
/hchain
TASK_ID: TASK-...
Goal: 단일 파일 수정
...
```

### Mission Plan

```text
/hchain
다음 목표를 Mission으로 분해하라.
목표: AI Video 10분 강의 생성
조건:
- 최소 수정
- Task 3~5개 이내
- 승인 전 구현 금지
```

### Mission Step (단계별 수동 실행)

```bash
harness/scripts/mission_step.sh step harness/missions/<mission_id>/mission_state.json
```

### Mission Loop (자동 반복 실행)

```bash
harness/scripts/mission_loop.sh run harness/missions/<mission_id>/mission_state.json --max-steps 3
```

---

## 6. 안전 원칙

- **처음에는 step 먼저** — Loop 실행 전 step으로 동작 확인
- **run은 step 검증 후** — 최소 1회 step 확인 없이 run 사용 금지
- **--max-steps 필수** — 무한 루프 방지를 위해 반드시 지정
- **BLOCKED 발생 시 사용자 확인** — 자동 재시도 금지, 원인 파악 후 진행
- **Codex는 기본 OFF** — 명시적 활성화 없이 사용 금지
- **runtime mode는 아직 사용 금지** — 구현 없음, 예약값만 존재
- **Token Budget은 아직 수동 관리** — 자동 분배 미구현
- **승인되지 않은 Scope 확장 금지** — Mission 외 작업 추가 금지

---

## 7. ai-video 적용 흐름

```text
hchain 최신화
→ ai-video git status 확인
→ install.sh --target <ai-video>
→ verify
→ 샘플 Mission
→ 실제 AI Video Mission
```
