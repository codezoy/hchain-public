# HCHAIN General Task Template

Use this template for any general implementation, fix, or improvement request.
For HCHAIN Core changes (install.sh, harness_runner.sh), use `core_change_task.md`.
For HCHAIN version updates to an existing project, use `update_project_task.md`.

---

## Template

`````markdown
# TASK_YYYYMMDD_NNN: [Task Title]

## Metadata (Optional)

<!--
  두 필드 모두 선택 사항이다. 미지정 시 기존 Task 흐름과 동일하게 동작한다.
  mode는 HCHAIN Core가 해석한다. agent_strategy는 Task Metadata이며 Core는 실행 분기에 사용하지 않는다.
-->

```yaml
mode: NORMAL             # NORMAL (기본값) | ROOTCAUSE
agent_strategy: DEFAULT  # DEFAULT (기본값) | CLAUDE_ONLY | CODEX_ONLY | DUAL
```

## Goal

[One paragraph describing the problem being solved and what success looks like.
Be specific: what changes, what is preserved, what the expected outcome is.]

## Scope

포함:
- [specific file, module, or concern 1]
- [specific file, module, or concern 2]
- REVIEW 및 VALIDATE 단계 포함
- 최종 보고서 생성

제외:
- [unrelated file or feature that must NOT be touched]
- [unrelated refactor or cleanup]
- 기존 queue/tasks/logs/findings 파일 변경 금지

## Done Criteria

- [ ] [measurable criterion — e.g., "typecheck passes with 0 errors"]
- [ ] [measurable criterion — e.g., "API endpoint returns 200 for X input"]
- [ ] REVIEWER 로그에 CRITICAL/MAJOR 없음
- [ ] VALIDATOR checks[] 전체 PASS
- [ ] 최종 보고서 생성

## Steps

1. [PLAN] 현재 상태 분석: 관련 파일 읽기
2. [RESEARCH] 기술 조사 (필요 시): [specific question]
3. [ACTION] 구현: [concrete change description]
4. [REVIEW] 정적 코드 감사
5. [VALIDATE] 런타임 검증: [specific checks — typecheck, test, curl, pgrep, etc.]
6. [DONE] 최종 보고서 작성

## Final Report (필수)

다음 항목을 backtick 5개 코드박스로 출력한다:

1. Step 진행표 (PLAN/RESEARCH/ACTION/REVIEW/VALIDATE/DONE)
2. 변경 파일 목록 (git diff --name-only)
3. REVIEWER 이슈 목록 (severity + description)
4. VALIDATOR checks[] 전체 결과
5. Commit Hash
6. 남은 리스크
7. Agent Opinion Matrix — `mode: ROOTCAUSE` 또는 `agent_strategy: DUAL` 인 경우에만 포함

## Execution

Harness Task를 생성하고 queue에 등록한 뒤 실행하라:

```bash
bash harness/harness_runner.sh --task TASK_YYYYMMDD_NNN
```
`````

---

## Usage Notes

- Replace all `[...]` placeholders before use
- Set a real date in `TASK_YYYYMMDD_NNN` (e.g., `TASK_20260525_001`)
- Done Criteria must be **verifiable** — not subjective
- Final Report must be a **5-backtick code block** (copy-paste safe)
- If Steps exceed 5 ACTION items, split into sub-tasks
