# HCHAIN PLAN LOOP 종료 기준

Version: 1.0.0
Date: 2026-06-29
Status: Active

---

## 목적

PLAN LOOP가 완전히 해결된 상태에서만 종료되도록 기준을 명시한다.
불완전한 상태에서 PLAN LOOP를 조기 종료하는 것을 방지한다.

---

## 종료 체크리스트

PLAN LOOP는 다음 **8개 항목 모두** 충족 시에만 종료한다.

```
□ 1. Root Cause 추가 발견 없음
□ 2. Policy GAP 없음
□ 3. Remaining Issues 없음
□ 4. PASS_WITH_ISSUES 없음
□ 5. 실제 E2E PASS
□ 6. Reviewer PASS
□ 7. Validator PASS
□ 8. Health Score = 10
```

단 하나라도 미충족 시 PLAN LOOP를 종료할 수 없다.

---

## 금지 문구 (Auto Re-entry Trigger)

보고서, 응답, Task 결과에 다음 문구가 **하나라도** 포함되면
PLAN LOOP를 **자동 재진입**한다.

```
- 근본 해결은 아님
- 향후 구현
- 현재 우회
- 낮은 우선순위
- hook 미연결
- 실제 E2E 미실행
- 호출 주체 없음
- 추후 고도화
- 일단 동작
- 임시 방편
- 나중에 수정
- 지금은 생략
- 우선순위 낮음
- TODO
- FIXME (미해결 상태)
- 추후 검토
- 미연결
- 연결 예정
- 실제 테스트 미실시
```

### 금지 문구 탐지 방법

Claude 또는 자동화 에이전트가 위 문구를 생성한 경우,
해당 응답을 출력 후 즉시:

```
[PLAN LOOP] 금지 문구 감지: "<감지된 문구>"
→ PLAN LOOP 자동 재진입
→ 이전 출력 무효화
```

를 선언하고 PLAN LOOP STEP-2로 돌아간다.

---

## 종료 선언 형식

모든 체크리스트 충족 시 다음 형식으로 종료 선언:

```
[PLAN LOOP COMPLETE]

종료 체크리스트:
□ Root Cause 추가 발견 없음     : PASS
□ Policy GAP 없음               : PASS
□ Remaining Issues 없음         : PASS
□ PASS_WITH_ISSUES 없음         : PASS
□ 실제 E2E PASS                 : PASS
□ Reviewer PASS                 : PASS
□ Validator PASS                : PASS
□ Health Score = 10             : PASS

금지 문구 없음: CONFIRMED

PLAN LOOP 종료. 일반 개발 흐름으로 복귀.
```

---

## PLAN LOOP 재진입 트리거 전체 목록

| 트리거 | 재진입 시 돌아갈 STEP |
|--------|----------------------|
| 새 Root Cause 발견 | STEP-2 |
| Policy GAP 발견 | STEP-3 |
| 재발방지 미흡 | STEP-4 |
| 구현 계획 변경 필요 | STEP-5 |
| E2E 실패 | STEP-8 |
| Health Score < 10 | STEP-9 |
| Remaining Issues > 0 | STEP-10 |
| PASS_WITH_ISSUES 발생 | STEP-7 |
| 금지 문구 감지 | STEP-2 |

---

## 정책 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0.0 | 2026-06-29 | 최초 제정 (MISSION-HCHAIN-MAJOR-ISSUE-PLAN-LOOP-POLICY-001) |
