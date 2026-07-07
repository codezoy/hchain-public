# HCHAIN Core Change Task Template

Use this template ONLY for changes to HCHAIN Core itself:
`install.sh`, `harness_runner.sh`, `templates/harness/`, `scripts/`, `VERSION`.

**MANDATORY PRE-CONDITION: Design document must be created and user must explicitly approve before implementation proceeds.**

---

## Template

`````markdown
# TASK_YYYYMMDD_NNN: [Core Change Title]

## Pre-condition (MANDATORY)

이 Task는 HCHAIN Core 변경을 포함한다.

**구현 전 필수 절차:**
1. `docs/tasks/TASK_YYYYMMDD_NNN_design.md` 설계 문서 작성
2. 사용자 명시적 승인 확인
3. 승인 없이 `install.sh`, `harness_runner.sh`, `templates/harness/` 수정 금지

설계 승인 상태: **[PENDING / APPROVED by user on YYYY-MM-DD]**

## Goal

[One paragraph: what Core capability is being added/fixed and why.
Must reference the specific problem, not a general improvement.]

## Scope

포함:
- [specific Core file being changed, e.g., "install.sh의 --verify 플래그 수정"]
- 설계 문서 작성 (`docs/tasks/`)
- REVIEW 및 VALIDATE 단계 포함
- Rollback 방법 명시

제외:
- 명시되지 않은 다른 Core 파일 수정 금지
- 자동 전파(auto-propagation) 기능 추가 금지
- registry / sync-all / 글로벌 스캔 기능 추가 금지
- 외부 런타임(Python/Node/Ruby) 의존성 추가 금지
- `.env` 또는 API 키 참조 추가 금지
- 기존 API 계약 변경 금지 (하위 호환성 유지)

## Done Criteria

- [ ] 설계 문서 작성 완료 및 사용자 승인
- [ ] [specific measurable criterion for the change]
- [ ] `bash install.sh --dry-run` 정상 동작
- [ ] `bash install.sh --verify` 정상 동작
- [ ] REVIEWER 로그에 CRITICAL/MAJOR 없음
- [ ] VALIDATOR: install.sh syntax check 통과
- [ ] Rollback 방법 확인 (git revert <hash>)
- [ ] 최종 보고서 생성

## Rollback Plan

```bash
# 변경 취소
git revert <COMMIT_HASH>

# 또는 파일별 복원
git checkout -- install.sh
git checkout -- templates/harness/harness_runner.sh
```

## Steps

1. [DESIGN] 설계 문서 작성: `docs/tasks/TASK_YYYYMMDD_NNN_design.md`
2. [APPROVAL] 사용자 승인 대기 — 승인 없이 진행 금지
3. [PLAN] 현재 Core 상태 분석
4. [RESEARCH] 변경 영향 범위 조사
5. [ACTION] Core 파일 수정 (승인된 범위만)
6. [REVIEW] 정적 감사
7. [VALIDATE] 런타임 검증: install.sh dry-run + syntax check
8. [DONE] 최종 보고서 작성

## Final Report (필수)

다음 항목을 backtick 5개 코드박스로 출력한다:

1. Step 진행표 (DESIGN/APPROVAL/PLAN/RESEARCH/ACTION/REVIEW/VALIDATE/DONE)
2. 변경 파일 목록 (`git diff --name-only`)
3. 변경 이유
4. 회귀 위험 평가
5. Rollback 방법 (`git revert <hash>`)
6. REVIEWER 이슈 목록 (severity + description)
7. VALIDATOR checks[] 전체 결과
8. Commit Hash
9. 남은 리스크

## Execution

설계 승인 후 실행:

```bash
cd /path/to/hchain
bash harness/harness_runner.sh --task TASK_YYYYMMDD_NNN
```

**Note:** HCHAIN Core 자체에 Harness가 설치되어 있지 않은 경우,
Task 정의 파일을 `docs/tasks/`에 생성하고 수동으로 단계를 진행한다.
`````

---

## Usage Notes

- This template is **only** for modifying `install.sh`, `harness_runner.sh`, `templates/harness/`, `scripts/`, or `VERSION`
- Design approval is NOT optional — it is a hard gate
- If unsure whether a change qualifies as "Core change", refer to `HCHAIN_CORE_CHANGE_CONTROL_POLICY.md`
- Keep Core changes minimal: one purpose per task
