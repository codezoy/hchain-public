# HCHAIN Major Issue 정의

Version: 1.0.0
Date: 2026-06-29
Status: Active

---

## 목적

"Major Issue"가 발생했을 때 Claude 또는 자동화 에이전트가
즉시 핫픽스(quick-fix) 모드로 진행하지 않도록 강제한다.

Major Issue 감지 즉시 PLAN LOOP를 진입하고,
전체 Root Cause 수집 → Policy GAP 분석 → 구현 재계획 순서를 따른다.

---

## Major Issue 판정 기준

다음 조건 중 **하나라도** 해당하면 Major Issue로 판정한다.

### A. 재발견된 결함

이미 수정했던 기능 또는 단계에서 새로운 결함이 발견됨.

```
예시: 1차 핫픽스 후 동일 기능에서 새 버그 발견
```

### B. 수정 후 새 Root Cause 발견

이전 수정이 증상만 제거하고 근본 원인이 남아 있음이 드러남.

```
예시: 핫픽스 후 "이것도 같은 원인이었네"가 발생
```

### C. Contract GAP 발견

계약서(contract)와 실제 구현 또는 동작 사이에 불일치 발견.

```
예시: 계약서에 정의된 API 응답 형식과 실제 응답이 다름
```

### D. 재발방지 이슈 존재

현재 수정으로 버그가 제거되었으나, 동일 유형 재발을 막는 정책이 없음.

```
예시: 버그를 수정했지만 "왜 이런 버그가 생기는가"에 대한 정책이 없음
```

### E. Helper 생성 후 호출 주체 없음

유틸리티/헬퍼 함수·클래스를 생성했으나 실제로 호출하는 코드가 없음.

```
예시: validate_input() 생성했지만 어디서도 호출하지 않음
```

### F. 실제 E2E 없음

테스트 또는 검증이 단위 테스트 수준에 머물고
실제 사용자 흐름(End-to-End) 검증이 없음.

```
예시: unit test PASS이지만 실제 API 호출 → 렌더 → 결과 확인 미실시
```

### G. Health Score < 10

HCHAIN Health Check 결과가 만점(10) 미만.

```
예시: Health Score = 7 → 자동 Major Issue 판정
```

### H. Remaining Issues 존재

REVIEW 또는 VALIDATE 결과에 미해결 이슈가 남아 있음.

```
예시: REVIEW에서 MAJOR 이슈 1건 → 해결하지 않고 DONE 처리 불가
```

### I. PASS이지만 "근본 해결은 아님"

검증이 PASS를 반환했으나 보고서 또는 응답에
"근본 해결은 아님", "향후 구현", "현재 우회" 등 문구 포함.

```
예시: "이번 수정으로 동작하지만 근본적으로는 구조 개선이 필요함"
```

### J. PASS_WITH_ISSUES 발생

REVIEW 또는 VALIDATE 결과 상태가 `PASS_WITH_ISSUES`.

```
예시: Validator status = "PASS_WITH_ISSUES" → 자동 Major Issue 판정
```

---

## 판정 시 필수 행동

```
MAJOR ISSUE DETECTED
→ PLAN LOOP REQUIRED
```

**즉시 핫픽스 금지.**

Major Issue 판정 즉시:

1. 작업 중단
2. PLAN LOOP 진입 선언
3. 전체 Root Cause 수집 시작
4. Policy GAP 분석
5. 구현 계획 재작성
6. TASK 재분할

---

## 금지 행동

Major Issue 판정 후 다음은 절대 금지:

- 즉각 코드 수정 (without PLAN LOOP)
- "일단 동작하니 넘어가자" 판단
- 부분 수정 후 DONE 처리
- Remaining Issues 존재 상태에서 DONE 처리
- PASS_WITH_ISSUES 상태에서 DONE 처리

---

## 정책 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0.0 | 2026-06-29 | 최초 제정 (MISSION-HCHAIN-MAJOR-ISSUE-PLAN-LOOP-POLICY-001) |
