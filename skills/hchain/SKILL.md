---
name: hchain
description: Use this skill whenever the user starts with /hchain or [HCHAIN], or asks to use HCHAIN, Harness, Harness Task, queue, REVIEW, VALIDATE, or HCHAIN-based development workflow. Also triggers on Korean action phrases: 작업해줘, 구현해줘, 수정해줘, 개발해줘, 만들어줘, 추가해줘. This skill prevents direct implementation and forces HCHAIN Task-based execution.
---

# HCHAIN Skill

When this skill is active, **do not directly implement code or edit files first.**

Always convert the user's request into a HCHAIN Harness Task.

---

## Triggers

### Hard Triggers (무조건 HCHAIN Mode 진입)

메시지가 다음 중 하나로 **시작**하면 무조건 HCHAIN Mode 진입:

- `/hchain`
- `[HCHAIN]`

### Soft Triggers (문맥 판단 후 HCHAIN Mode 진입)

메시지에 다음 중 하나가 포함되면 HCHAIN Mode 진입:

- `HCHAIN`
- `하네스`
- `테스크` / `태스크`
- `Harness Task`
- `queue 등록`
- `REVIEW`
- `VALIDATE`
- `하네스 실행`
- `Task 생성`
- `작업해줘`
- `구현해줘`
- `수정해줘`
- `개발해줘`
- `만들어줘`
- `추가해줘`

### Command Triggers (명령어 직접 실행)

메시지가 다음 중 하나로 **정확히 시작**하면 Command Handler 진입:

- `/hchain help` → Help Handler 실행 (Harness Task 생성 안 함)
- `/hchain init` → Init Handler 실행 (PROJECT_ROOT 구조 생성)
- `/hchain task` → Task Handler 실행 (직전 요청 또는 인자 기반 Task 생성)
- `/hchain contract` → Contract Handler 실행 (계약 검토, 읽기 전용)

Command Trigger가 Hard/Soft Trigger보다 **우선 적용**된다.

---

## Mandatory Rules

1. **절대 직접 코드 작성 금지** — Harness Task 생성 전에 코드를 작성하거나 파일을 수정하지 않는다.
2. **절대 파일 수정 시작 금지** — Edit/Write 도구를 먼저 호출하지 않는다.
3. **절대 shell 명령어 나열 금지** — 구현 절차를 먼저 설명하거나 명령어를 나열하지 않는다.
4. 먼저 정의: Goal, Scope, Exclusions, Done Criteria, Final Report 형식.
5. 작업이 크면 여러 Harness Task로 분할한다.
6. HCHAIN이 설치된 프로젝트는 실행 세부사항을 HCHAIN에 위임한다.
7. shell 명령어는 꼭 필요한 경우에만 사용한다 (install, run 등).
8. **REVIEW와 VALIDATE는 절대 생략 금지** — 사용자가 명시적으로 승인한 경우에만 생략 가능.
9. HCHAIN Core 변경은 설계 승인 후에만 진행한다.
10. 외부 런타임 의존성은 명시적 승인 없이 추가 금지.
11. 기존 tasks, logs, findings, queue, active_state 파일은 보존한다.
12. **최종 출력은 새 Claude 세션에 바로 붙여넣을 수 있는 Markdown 프롬프트** 형태여야 한다.

---

## Output Format

Respond with a structured Harness Task prompt in this order:

1. **Task ID** — `TASK_YYYYMMDD_NNN` format
2. **Goal** — one-paragraph summary
3. **Scope (포함)** — bulleted list of what IS included
4. **Exclusions (제외)** — bulleted list of what is NOT included
5. **Done Criteria** — measurable completion checklist
6. **Execution Steps** — ordered numbered steps
7. **Final Report** — what the report must include
8. Shell command to run (if applicable)

Wrap the full prompt in a 5-backtick code block for easy copy-paste.

---

## Reference Files

Read these files as needed:

- `resources/HCHAIN_USER_GUIDE.md` — architecture, commands, workflow
- `resources/HCHAIN_CORE_CHANGE_CONTROL_POLICY.md` — Core change rules
- `resources/HCHAIN_PROMPT_STYLE.md` — prompt writing principles
- `resources/HCHAIN_COMMANDS.md` — verified shell commands
- `templates/task_prompt.md` — general task template
- `templates/core_change_task.md` — HCHAIN Core modification template
- `templates/update_project_task.md` — project HCHAIN update template
- `docs/HCHAIN_SKILL_TEST_CASES.md` — test scenarios and expected outputs

---

## Command Handlers

### /hchain help

메시지가 `/hchain help`로 **정확히 시작**하면:

- Harness Task를 생성하지 않는다
- 아래 도움말을 마크다운 형식으로 출력한다

```
# HCHAIN Help

HCHAIN는 Claude 채팅 기반 개발 작업 관리 시스템입니다.
요청을 Harness Task로 변환하고 PLAN → RESEARCH → ACTION → REVIEW → VALIDATE → DONE
파이프라인을 통해 안전하게 실행합니다.

## Commands

| 명령어              | 설명                                           |
|---------------------|------------------------------------------------|
| /hchain help        | 이 도움말 출력                                 |
| /hchain init        | 현재 프로젝트에 HCHAIN 기본 구조 생성          |
| /hchain task        | 직전 요청 기반으로 Harness Task 생성           |
| /hchain task <text> | <text> 내용 기반으로 Harness Task 생성         |

## Recommended Flow

1. /hchain init        ← 최초 1회 실행
2. 작업 요청 입력
3. /hchain task        ← Harness Task 자동 생성
4. Queue 등록 확인
5. 실행 및 검증
6. 따5코 완료보고

## Workflow Pipeline

PLAN → RESEARCH → ACTION → REVIEW → VALIDATE → DONE

- RESEARCH  : 조사 단계 (Gemini/Claude/Human; 구현 전 정보 수집)
- ACTION    : 구현 (Claude)
- REVIEW    : 정적 코드 감사 (Codex CLI)
- VALIDATE  : 런타임 검증 (shell 명령어)

## Rules

- 완료보고는 반드시 따5코(`````) 코드박스로 출력
- REVIEW와 VALIDATE는 명시적 승인 없이 생략 불가
- /hchain init 재실행 시 기존 파일 보호 — 누락 항목만 보강
- 모든 경로는 PROJECT_ROOT 기준 (절대경로 하드코딩 금지)
```

---

### /hchain init

메시지가 `/hchain init`으로 **정확히 시작**하면:

**1. PROJECT_ROOT 결정**
- 현재 세션의 working directory 기준
- CLAUDE.md가 존재하는 가장 가까운 상위 디렉토리
- 불명확 시 → 사용자에게 확인 요청 후 중단

**2. 기존 설치 점검**
- `PROJECT_ROOT/harness/` 존재 여부 확인
- `PROJECT_ROOT/.hchain/meta.json` 존재 여부 확인
- 존재하면 → 재실행 모드 (누락 항목만 보강)

**3. 변경 예정 항목 사전 보고 (실행 전 출력)**
```
생성 예정:
  - PROJECT_ROOT/harness/tasks/
  - PROJECT_ROOT/harness/queue/pending/
  ...

건너뜀 (기존 존재):
  - PROJECT_ROOT/harness/
  ...
```

**4. 생성 구조 (PROJECT_ROOT 기준)**
```
PROJECT_ROOT/
├── harness/
│   ├── tasks/
│   ├── queue/
│   │   ├── pending/
│   │   ├── running/
│   │   ├── done/
│   │   └── blocked/
│   ├── logs/
│   ├── findings/
│   ├── checkpoints/
│   ├── templates/
│   │   └── task_template.md
│   └── active_state.json
├── contracts/
│   ├── PROJECT.md
│   ├── ARCHITECTURE.md
│   ├── RULES.md
│   ├── VALIDATION.md
│   ├── DONE.md
│   └── features/
├── .hchain/
│   └── meta.json
└── CLAUDE.md
```

**5. 기존 파일 처리 규칙**
- 기존 파일/폴더 → 덮어쓰기 금지, 건너뜀
- 누락 항목만 생성
- 충돌 감지 시 → 보고 후 중단
- 기존 CLAUDE.md → 내용 보존, HCHAIN POLICY 블록이 없을 경우에만 말미에 추가

**6. 기본 파일 내용**

`PROJECT_ROOT/harness/active_state.json`:
```json
{
  "status": "IDLE",
  "current_task": null,
  "current_step": null,
  "last_success_step": null,
  "updated_at": "<UTC_ISO8601>"
}
```

`PROJECT_ROOT/.hchain/meta.json`:
```json
{
  "version": "0.1.0",
  "initialized_at": "<UTC_ISO8601>",
  "managed_by": "HCHAIN Global Skill"
}
```

`PROJECT_ROOT/harness/templates/task_template.md`:
```markdown
# TASK_YYYYMMDD_NNN: [제목]

## Goal

## Scope

포함:
-

제외:
-

## Done Criteria

- [ ]

## Steps

1. [PLAN]
2. [RESEARCH]   ← 조사 내용 또는 SKIP 사유 기록
3. [ACTION]
4. [REVIEW]
5. [VALIDATE]
6. [DONE]

## Final Report

최종 완료보고는 반드시 따5코(`````) 안에 작성한다.
```

**7. 프로파일 옵션 (`--profile`)**

`/hchain init --profile <이름>` 형식으로 프로파일을 지정하면
`contracts/features/` 디렉토리에 프로파일별 계약 파일을 자동 생성한다.

지원 프로파일:

| 프로파일 | 생성 파일 |
|----------|-----------|
| `ai-video` | TEMPLATE.md, RENDER.md, TTS.md |
| `web`      | API.md, AUTH.md, UI.md |
| `api`      | API.md, AUTH.md |
| `cli`      | COMMAND.md, OUTPUT.md |

CLI:
```bash
python3 install.py --target <PROJECT_ROOT> --profile ai-video
python3 install.py --target <PROJECT_ROOT> --init-contracts --profile web
```

기존 파일은 덮어쓰지 않는다 (update 모드 동일).

**8. 완료 보고 (실행 후 출력)**
- 생성된 항목 목록
- 건너뛴 항목 목록
- PROJECT_ROOT/harness/ 구조 트리

---

### /hchain task

메시지가 `/hchain task`로 **정확히 시작**하면:

**Case A: 무인자 (`/hchain task`)**

```
직전 사용자 메시지 확인:

  존재:
    → 해당 메시지를 Goal로 사용
    → Correct Response Pattern에 따라 Task 생성
    → Task ID: TASK_<YYYYMMDD>_<NNN>

  없음 (세션 첫 메시지):
    → "작업 내용을 입력해주세요.
       예시: /hchain task 로그인 기능의 JWT 토큰 갱신 버그를 수정해줘"
```

**Case B: 인자 포함 (`/hchain task <text>`)**

```
<text>를 파싱:
  → Goal    : <text> 전체를 한 단락 Goal로 사용
  → Scope   : <text>에서 포함/제외 항목 도출
  → Done Criteria : 검증 가능한 완료 조건 3개 이상 생성
  → Steps   : PLAN → RESEARCH → ACTION → REVIEW → VALIDATE → DONE 표준 단계
  → Final Report : 따5코 필수 포함

출력: Correct Response Pattern 준수, 5-backtick 코드박스로 감싸기
```

**Task ID 생성 규칙**
```
TASK_<YYYYMMDD>_<NNN>
- YYYYMMDD : 현재 날짜
- NNN      : 001부터 순차 증가 (같은 날 여러 Task 생성 시)
```

---

### /hchain contract

메시지가 `/hchain contract`로 **정확히 시작**하면:

**기본 모드 (읽기 전용)**

**1. 계약 디렉토리 확인**
- `PROJECT_ROOT/contracts/` 존재 여부 확인
- 없으면 → "계약 없음. `/hchain init` 먼저 실행하세요." 안내 후 종료

**2. 계약 파일 읽기**

기본 계약(contracts/ 루트):
- `PROJECT.md`, `ARCHITECTURE.md`, `RULES.md`, `VALIDATION.md`, `DONE.md`

기능 계약(contracts/features/):
- 모든 `.md` 파일 (TEMPLATE.md 제외)

**3. 분석 항목**
- 필수 섹션 누락 탐지
- "확인 필요" 항목 수집
- 내용 없는 계약 탐지 (작성 필요)
- 계약 간 명백한 충돌 탐지

**4. 보고서 출력 (한글)**
```
## 계약 검토 결과

### 기본 계약
- PROJECT.md: ✅ / ⚠️ [이슈 설명]

### 기능 계약
- features/QUEUE.md: ✅ / ⚠️ [누락 섹션 목록]

### 확인 필요 항목
- [파일]: [항목 내용]

### 수정 제안
- [구체적 제안]
```

**자동 수정 모드 (`/hchain contract --write`)**

- `python3 install.py --target <PROJECT_ROOT> --contract-check --write` 실행
- 누락 섹션 헤더 자동 추가 ("작성 필요" 표시)
- 기존 내용은 절대 삭제하지 않는다
- 실행 전 변경 예정 항목을 출력한다

---

### Contract Workflow (자연어 요청 처리)

사용자가 기능 요청을 자연어로 입력하면 (`Queue 기능 추가해줘`, `Login 기능 추가` 등)
Claude는 코드 작성 전에 내부적으로 다음 단계를 자동 수행한다.

```text
[1] 관련 계약 읽기
    select_relevant_contracts(contracts_dir, keywords)

[2] 영향 범위 분석
    analyze_project_structure(target) + _infer_impacts_from_name(request)

[3] 빠진 정책 탐지
    _detect_missing_policies(contracts_dir)

[4] 사용자 질문 생성
    불명확한 요구사항 → "확인 필요" 항목으로 출력

[5] 기능 계약 초안 생성
    generate_feature_contract(feature_name, target)
    → contracts/features/<기능명>.md

[6] Task 생성 안내
    /hchain task <request> 로 Task 생성 안내
```

**규칙:**

- 별도의 "Impact Analyzer" 명령을 호출하지 않는다
- 위 단계는 Contract Workflow 내부 단계로만 존재한다
- 기능 계약 파일이 이미 존재하면 덮어쓰지 않는다
- 계약 없이 구현을 시작하지 않는다
- CLI: `python3 install.py --target <PROJECT_ROOT> --workflow "<요청 텍스트>"`

---

## Anti-patterns (Forbidden)

다음은 HCHAIN Mode에서 절대 해서는 안 되는 행동이다:

❌ **직접 구현 시작**
> "README를 수정하겠습니다. 다음과 같이 변경합니다..."

❌ **파일 수정부터 시작**
> (Edit/Write 도구를 Harness Task 생성 전에 호출)

❌ **명령어 나열**
> "다음 명령어를 실행하세요: cd project && npm install && ..."

❌ **구현 절차 설명부터 시작**
> "1. 파일 A를 열고 2. 함수 B를 수정하고 3. 테스트를 실행합니다"

❌ **REVIEW/VALIDATE 생략**
> 구현 완료 후 바로 "완료했습니다" 응답

❌ **Scope 없는 Task 생성**
> Goal만 있고 Exclusions가 없는 Task 정의

❌ **여러 기능을 하나의 Task에 묶기**
> "인증 + API + UI를 한 번에 구현하라"

---

## Correct Response Pattern

⭕ **항상 이 순서로 응답한다:**

```
# TASK_YYYYMMDD_NNN: [제목]

## Goal
[무엇을 왜 하는가 — 한 단락]

## Scope
포함:
- [구체적 파일/기능]

제외:
- [명시적 제외 항목]

## Done Criteria
- [ ] [검증 가능한 완료 조건]

## Final Report
[보고서에 포함되어야 할 항목]
```

---

## Multi-Agent Agent Loop

> **현재 상태: Agent Loop Contract 제공 단계**
> 실제 Mission Auto Loop 실행기는 후속 Task에서 구현 예정이다.

### 개념

HCHAIN Multi-Agent Agent Loop는 단일 Task 실행을 넘어, Mission(임무) 단위의 반복 루프를 통해
여러 Agent가 협력하여 대규모 작업을 자동 완료하는 시스템이다.
각 Agent는 독립적인 계약(Contract) 파일로 정의되며, Agent 간 인계는 표준 Handoff 템플릿을 사용한다.

### Agent 목록

| Agent | 파일 | 역할 |
|-------|------|------|
| Mission Manager | `agents/mission_manager_agent.md` | 임무 전체 조율, 루프 제어 |
| Planner | `agents/planner_agent.md` | Task 분해, 실행 계획 수립 |
| Executor | `agents/executor_agent.md` | 실제 구현 수행 |
| Reviewer | `agents/reviewer_agent.md` | 코드/결과 정적 검토 |
| Validator | `agents/validator_agent.md` | 런타임 검증 |
| Reporter | `agents/reporter_agent.md` | 완료 보고서 생성 |
| Escalation Guard | `agents/escalation_guard.md` | 무한 루프/위험 상황 차단 |

### 기본 흐름

```text
Mission Manager
→ Planner
→ Executor
→ Reviewer
→ Validator
→ Reporter
→ Mission Manager (다음 Task 또는 완료)
```

### Escalation Guard

- 루프 이탈 조건 감지 (최대 반복 횟수 초과, 오류 임계값 초과)
- 위험한 명령어 실행 시도 차단
- 사람에게 에스컬레이션 필요 시 루프 중단

### Codex Validation

- 기본값: **OFF**
- 명시적으로 활성화한 경우에만 Codex CLI를 호출한다
- Codex를 사용하지 않더라도 Agent Loop 자체는 정상 동작한다

### Handoff 템플릿

Agent 간 인계는 `templates/agent_handoff.md` 템플릿을 사용한다.

### 설치 (Agent Loop 파일)

```bash
# HCHAIN 저장소 루트에서 실행
./install.sh --install-skill

# 설치 검증
./install.sh --verify-skill
```

### Agent Contract 로딩 정책

**Mission / Agent Loop 관련 요청이 들어오면 Claude는 구현에 착수하기 전에 반드시 다음 파일을 읽어야 한다.**

```
agents/mission_manager_agent.md
agents/planner_agent.md
agents/executor_agent.md
agents/reviewer_agent.md
agents/validator_agent.md
agents/reporter_agent.md
agents/escalation_guard.md
templates/agent_handoff.md
```

규칙:

- Agent Contract를 읽기 전에는 Mission Plan, Mission Loop, Agent Loop, Mission Manager 구현에 착수하지 않는다.
- Agent Contract는 Role / Input / Output / Allowed Actions / Forbidden Actions / Stop Conditions 기준으로 해석한다.
- 새 프로젝트에서도 `install.sh --install-skill` 이후 동일한 상대 경로 기준으로 참조한다.
- 파일을 읽지 않고 Agent 동작을 가정하거나 요약해서 처리하는 것은 금지된다.
