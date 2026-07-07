# HCHAIN Report Retention Policy

## 1. Report 목적

Task 수행 보고서(`*_report.md`)는 HCHAIN 시스템의 핵심 출력물이다.

보고서는 다음 목적을 위해 존재한다:

- **재현성**: Task 실행 결과를 언제든 재확인 가능
- **감사(Audit)**: 시스템 변경 이력의 공식 기록
- **Mission 추적**: 각 Mission 단계의 완료 증거
- **디버깅**: 문제 발생 시 이전 실행 상태 복원 기준

---

## 2. 저장 위치

모든 Report는 다음 경로에 저장한다.

```
docs/tasks/<TASK-ID>_report.md
```

Task 문서와 동일한 위치에 `_report.md` 접미사로 저장한다.

---

## 3. Commit 정책

**정책: Option A — Report는 프로젝트 자산, 전체 commit**

모든 `*_report.md` 파일은 git에 commit한다.

근거:

- `.gitignore`에 `!docs/tasks/*.md` 예외 처리가 이미 적용되어 있다
- HCHAIN는 감사 추적 시스템이며 Report가 주요 산출물이다
- 4/5 Report가 이미 committed 상태로 precedent가 확립되어 있다
- Option C(중요 Report만 commit)는 주관적 판단을 요구해 장기적으로 불일치를 초래한다
- Option B(commit 금지)는 감사 목적을 훼손한다

따라서:

```bash
# Task 완료 후 반드시 실행
git add docs/tasks/<TASK-ID>_report.md
git commit -m "docs: add report for <TASK-ID>"
```

---

## 4. 삭제 정책

Report 파일은 삭제하지 않는다.

예외:

- 테스트용 또는 오작동으로 생성된 Report는 명시적 승인 후 삭제 가능
- 삭제 시 반드시 commit message에 이유를 기록한다

```bash
git rm docs/tasks/<TASK-ID>_report.md
git commit -m "docs: remove erroneous report for <TASK-ID> (reason: ...)"
```

---

## 5. Audit 정책

Report는 다음 항목을 포함해야 감사 기록으로 인정된다.

필수 포함 항목:

```
- Task ID
- 실행 일시
- 정책 선택 및 근거 (해당 시)
- 처리한 파일 목록
- Validation 결과
- Commit Hash
- git status 결과
```

Report가 이 항목을 누락한 경우에도 commit은 유지하되,
다음 Task에서 보완 Report를 작성한다.

---

## 6. Mission Report 정책

Mission 단계별 검증 보고서(`*_VERIFY_*_report.md`)는
일반 Report와 동일하게 모두 commit한다.

Mission Report는 추가로 다음 항목을 포함해야 한다.

```
- Mission 단계 (PLAN / ACTION / REVIEW / VALIDATE / DONE)
- 이전 단계 Commit Hash (추적 가능성 확보)
- 다음 추천 Task
```

---

## 7. 불일치 발생 시 처리

`docs/tasks/` 아래에 untracked `*_report.md` 파일이 발견된 경우:

```bash
# 즉시 추가 후 commit
git add docs/tasks/<TASK-ID>_report.md
git commit -m "docs: recover untracked report for <TASK-ID>"
```

불일치가 반복되면 이 정책 문서를 기준으로 Task 완료 체크리스트를 갱신한다.
