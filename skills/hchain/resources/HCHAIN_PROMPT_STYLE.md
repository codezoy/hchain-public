# HCHAIN Prompt Style Guide

Guidelines for writing effective HCHAIN Harness Task prompts.

---

## Core Principle

**Goal/Scope/DOD 중심으로 작성한다. 세부 명령어 나열은 피한다.**

The harness orchestrates execution. The prompt defines *what* and *when done*, not *how*.

> "어떻게 구현할지"보다 "언제 완료되었다고 볼 수 있는지"를 먼저 정의한다.

---

## 1. Structure Every Task with Goal → Scope → DOD

Every Harness Task prompt must contain:

```
## Goal
[One paragraph: what problem this task solves and why]

## Scope
포함:
- [specific file, feature, or concern]

제외:
- [explicit exclusion to prevent scope creep]

## Done Criteria
- [ ] [measurable, verifiable condition]
- [ ] [measurable, verifiable condition]

## Final Report
[what must appear in the completion report]
```

**Missing any of these = incomplete task definition.**

---

## 2. Done Criteria (DOD) First — Completion Over Steps

Done Criteria가 실행 방법보다 중요하다:

**Wrong:** 단계별 명령어 목록이 DOD보다 상세한 경우
**Right:** DOD가 구체적이고 검증 가능하며, Steps는 그것을 달성하는 수단

좋은 DOD 예시:
```
- [ ] typecheck 0 errors
- [ ] API endpoint returns 200 for /health
- [ ] REVIEWER 로그에 CRITICAL/MAJOR 없음
- [ ] VALIDATOR checks[] 전체 PASS
- [ ] git diff --name-only 에 의도한 파일만 포함
```

나쁜 DOD 예시:
```
- [ ] 코드를 작성한다
- [ ] 테스트를 실행한다
- [ ] 완료한다
```

---

## 3. "Harness Task 생성 후 실행하라" 기본 포함

Every task prompt must end with or include:

> Harness Task를 생성하고 queue에 등록한 뒤 실행하라.

Or for Claude Code tasks:

> 위 내용을 기반으로 `harness/tasks/TASK_YYYYMMDD_NNN.md`를 작성한 뒤
> `bash harness/harness_runner.sh --task TASK_ID`로 실행하라.

---

## 4. Minimize Shell Commands — Let HCHAIN Handle Execution

세부 shell 명령어는 최소화한다. HCHAIN이 실행을 조율한다.

**Wrong:**
```
1. cd project
2. git checkout -b feature/auth
3. npm install jsonwebtoken
4. vi src/auth.ts
5. npm run test
6. git add -A && git commit -m "..."
```

**Right:**
```
## Steps
1. [ACTION] JWT 인증 미들웨어 구현: src/auth.ts
2. [VALIDATE] npm run test — auth 관련 테스트 통과 확인
3. [DONE] 최종 보고서 작성
```

예외적으로 명령어를 명시해야 하는 경우:
- 설치 명령어 (install.sh 실행 등)
- 검증용 단일 명령어 (curl, pgrep 등)
- 특정 플래그가 중요한 경우

---

## 5. Token Budget — Split Large Tasks

Claude Pro has token limits per session. For large implementations:

- One Task = one focused concern (one module, one feature, one bug fix)
- 5개 이상의 ACTION 단계가 있으면 → 서브 Task로 분할
- `--chain` 옵션으로 여러 Task를 순차 실행
- 각 Task는 독립적으로 REVIEW/VALIDATE 가능해야 한다

**Anti-pattern:** "모든 기능을 한 Task에 구현하라" → 토큰 한도 초과 또는 품질 저하

**Task 분할 기준:**
```
하나의 Task가 다음 중 하나라도 해당되면 분할 검토:
- 수정 파일 5개 초과
- ACTION 단계 5개 초과
- 서로 다른 도메인/모듈 포함
- 완료 검증이 2가지 이상의 독립적 방법이 필요한 경우
```

---

## 6. HCHAIN-installed Projects: Delegate Execution to HCHAIN

If the target project already has HCHAIN installed:

- Do NOT write raw implementation instructions
- Write a Task definition, then say "harness_runner.sh로 실행하라"
- The harness handles RESEARCH → ACTION → REVIEW → VALIDATE

**Wrong:** "파일 A를 열고, 함수 B를 수정하고, 테스트 C를 실행하라"
**Right:** "Goal: 함수 B를 수정하여 X 문제를 해결한다. Done Criteria: 테스트 C 통과"

---

## 7. Emphasize REVIEW → VALIDATE → Final Report

Never omit these stages:

```
## Final Report (필수)
- 변경 파일 목록 (git diff --name-only)
- REVIEWER 로그 경로
- VALIDATOR 결과 (checks[] 전체)
- Commit Hash
- 남은 리스크
```

Skipping REVIEW/VALIDATE means the task is NOT done.

---

## 8. Scope Exclusions Are As Important As Inclusions

Always write explicit exclusions:

```
제외:
- install.sh 수정 금지
- harness_runner.sh 수정 금지
- 외부 런타임(Python/Node) 추가 금지
- 기존 queue/tasks/logs 파일 삭제 금지
- 명시되지 않은 파일 수정 금지
```

Exclusions prevent the agent from solving adjacent problems autonomously.

---

## 9. HCHAIN Core Changes — Design First

If the task modifies HCHAIN Core:

```
## Pre-condition
설계 문서 작성 및 사용자 명시적 승인 필수.
docs/tasks/ 에 설계 문서를 먼저 생성하고 승인 받은 뒤 진행한다.
승인 상태: [PENDING / APPROVED by user on YYYY-MM-DD]
```

Never write a Core change task without this block.

---

## 10. Use Concrete IDs, Not Vague References

**Wrong:** "최근 task를 실행하라"
**Right:** "`bash harness/harness_runner.sh --task TASK_20260525_001`"

**Wrong:** "관련 파일을 수정하라"
**Right:** "`skills/hchain/SKILL.md` 의 Triggers 섹션에 추가하라"

---

## 11. Final Output Format for Claude

When using this skill to generate a task prompt, wrap in a 5-backtick code block:

`````markdown
# TASK_YYYYMMDD_NNN: [Title]
...
`````

This allows direct copy-paste without markdown rendering interference (per CLAUDE.md report format rule).
