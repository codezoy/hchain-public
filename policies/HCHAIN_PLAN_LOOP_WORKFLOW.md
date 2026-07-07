# HCHAIN PLAN LOOP 절차

Version: 1.0.0
Date: 2026-06-29
Status: Active

---

## 목적

Major Issue 감지 후 진입하는 "PLAN LOOP"의 표준 절차를 정의한다.

PLAN LOOP는 증상 핫픽스가 아닌 전체 Root Cause 수집 → 정책 확정 → 구현 재계획을
보장하는 필수 워크플로우다.

---

## 진입 조건

`HCHAIN_MAJOR_ISSUE_DEFINITION.md`의 A~J 조건 중 하나라도 해당.

```
MAJOR ISSUE DETECTED
→ PLAN LOOP REQUIRED
```

---

## PLAN LOOP 10단계

### STEP-1: 재현 (Reproduce)

**목표**: 현상을 정확히 재현하고 재현 방법을 기록한다.

완료 기준:
- [ ] 재현 가능한 최소 케이스 확인
- [ ] 재현 명령어 또는 절차 기록
- [ ] "재현 불가" 판정 시 추가 조사 진행 (STEP-2에서)

금지:
- 재현 없이 수정 시작

---

### STEP-2: 전체 Root Cause 수집 (Root Cause Complete)

**목표**: 이번 이슈의 모든 Root Cause를 수집한다.
하나만 찾고 멈추지 않는다. "이것뿐인가?"를 반복 질문한다.

완료 기준:
- [ ] Root Cause 목록 작성 (1개 이상)
- [ ] 각 Root Cause의 계층(직접 원인 / 구조적 원인) 구분
- [ ] "추가 Root Cause 없음" 명시적 확인

도구:
- `git log --oneline` 로 최근 변경 이력 확인
- Impact Scope 전수 분석

Impact Scope 전수 분석 절차:

1. `contracts/PROJECT_INVENTORY.md` 존재 여부 확인
2. Inventory가 있으면 전체 컴포넌트 목록 로드
3. 각 컴포넌트에 대해 이번 이슈와의 관계 분류:
   - `WRITE` : 직접 수정이 필요한 컴포넌트
   - `VERIFY` : 수정은 없으나 검증이 필요한 컴포넌트
   - `READ`   : 참조만 하는 컴포넌트
   - `NONE`   : 무관
4. `WRITE` 또는 `VERIFY`로 분류된 컴포넌트 중
   이번 이슈에서 다루지 않은 항목 → 누락 Root Cause 후보로 기록
5. Inventory가 없으면 기존 방식(자유 텍스트 분석)으로 수행하고
   "PROJECT_INVENTORY 없음"을 Root Cause 목록에 기록

금지:
- Root Cause 1개만 찾고 다음 STEP 진행

---

### STEP-3: Policy GAP 분석 (Policy Gap Analysis)

**목표**: 이번 이슈를 허용한 정책 공백을 식별한다.

분석 항목:
- 어떤 정책이 없었기에 이 버그가 발생했는가?
- 어떤 검증 단계가 빠졌는가?
- 어떤 계약(contract)이 없었는가?

완료 기준:
- [ ] Policy GAP 목록 작성 (0개 가능 — 명시적 "없음" 확인 필요)
- [ ] 각 GAP에 대한 재발방지 방안 초안

---

### STEP-4: 재발방지 정책 생성 (Prevention Policy)

**목표**: STEP-3에서 찾은 GAP을 메우는 정책을 확정한다.

완료 기준:
- [ ] 재발방지 정책 문서 작성 또는 기존 정책 업데이트
- [ ] "이 유형의 이슈는 앞으로 어떻게 탐지하는가" 기준 추가
- [ ] 사용자 승인 (자동 정책 추가 금지)

---

### STEP-5: 구현 계획 재작성 (Replan)

**목표**: 기존 핫픽스 계획을 폐기하고 Root Cause 기반으로 계획을 재작성한다.

완료 기준:
- [ ] 기존 핫픽스 계획 폐기 선언
- [ ] Root Cause 전체를 해결하는 구현 계획 작성
- [ ] 각 구현 항목이 어느 Root Cause를 해결하는지 명시

---

### STEP-6: TASK 재분할 (Task Decomposition)

**목표**: 재작성된 계획을 실행 가능한 TASK로 분할한다.

완료 기준:
- [ ] 각 TASK ID 생성
- [ ] 각 TASK의 Done Criteria 정의
- [ ] TASK 간 의존 관계 명시

---

### STEP-7: 구현 (Implementation)

**목표**: STEP-6의 TASK를 순서대로 실행한다.

완료 기준:
- [ ] 각 TASK DONE 상태 확인
- [ ] REVIEW PASS
- [ ] VALIDATE PASS (PASS_WITH_ISSUES 불가)
- [ ] Remaining Issues = 0

---

### STEP-8: E2E 검증 (End-to-End Verification)

**목표**: 구현 완료 후 실제 사용자 흐름 전체를 검증한다.

완료 기준:
- [ ] Happy Path E2E PASS
- [ ] Edge Case E2E PASS (정의된 케이스 전체)
- [ ] 이전에 발생한 버그 재현 → 수정 확인
- [ ] 신규 버그 없음 확인

금지:
- unit test PASS만으로 E2E 대체

---

### STEP-9: Health Check

**목표**: HCHAIN Health Score를 확인한다.

완료 기준:
- [ ] Health Score = 10
- [ ] Health Score < 10이면 PLAN LOOP 재진입

---

### STEP-10: Remaining Issues = 0 확인

**목표**: 미해결 이슈가 없음을 최종 확인한다.

완료 기준:
- [ ] findings backlog 점검
- [ ] Remaining Issues = 0
- [ ] "근본 해결은 아님" 류 문구 없음
- [ ] 다음 권장 Task가 긴급 수정이 아닌 일반 Task

---

## PLAN LOOP 종료

STEP-1~10 모두 완료 시 PLAN LOOP 종료.
종료 조건은 `HCHAIN_PLAN_LOOP_EXIT_CRITERIA.md` 참조.

---

## PLAN LOOP 재진입 트리거

STEP-10 이후에도 다음 조건 발생 시 즉시 재진입:

- 새 Root Cause 발견
- Policy GAP 발견
- E2E 실패
- Health Score < 10
- PASS_WITH_ISSUES 발생

---

## 정책 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0.0 | 2026-06-29 | 최초 제정 (MISSION-HCHAIN-MAJOR-ISSUE-PLAN-LOOP-POLICY-001) |
