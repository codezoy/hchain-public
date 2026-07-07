# HCHAIN Planner Report Format Specification

**Version:** 1.0.0
**Status:** APPROVED
**Date:** 2026-06-03
**Scope:** Planner Feed 섹션 표준 규격 — Mission Report 포맷 확장

---

## 1. 목적

Mission Report에 `## Next Tasks (Planner Feed)` 섹션을 도입하여
Planner(Claude)가 정규식 한 줄로 안정적으로 파싱할 수 있는 기계 가독 Task 추천 포맷을 정의한다.

기존 자연어 추천 섹션은 제거하지 않는다. Planner Feed는 기존 섹션에 **추가**된다.

---

## 2. 배경: 기존 Report 포맷 조사

### 2-1. 조사 대상 파일

```
docs/tasks/TASK-HARNESS-MISSION-FOUNDATION-VERIFY-001_report.md
docs/tasks/TASK-HARNESS-MISSION-E2E-001_report.md
docs/tasks/TASK-HARNESS-MISSION-STEP-VERIFY-001_report.md
docs/tasks/TASK-HCHAIN-TEMPLATE-INSTALL-VERIFY-001_report.md
docs/tasks/TASK-HARNESS-CURRENT-TASK-LOOP-VERIFY-001_report.md
```

### 2-2. 기존 추천 Task 표현 방식 (비정형)

현재 Report에서 사용 중인 추천 Task 섹션은 통일된 형식이 없다.

**패턴 A — 번호 목록형 (FOUNDATION-VERIFY-001 Report)**

```markdown
## 7. 다음 추천 Task

### 즉시 실행 (Mission Manager 구현 전)

**TASK-HARNESS-SKILL-CONTEXT-FIX-001**
- Goal: SKILL.md에 새 세션 Agent Contract 로딩 지시 추가 및 Mission Status enum 단일 출처 정의
- Done Criteria:
  - SKILL.md에 새 세션 시작 시 agents/*.md 파일 읽기 지시가 명시됨
  ...

### 이후 실행

**TASK-HARNESS-MISSION-MANAGER-001**
- Goal: Mission Manager 구현 ...
```

**패턴 B — Priority 레이블형 (E2E-001 Report)**

```markdown
## 11. Recommended Next Tasks

Priority 1 — TASK-HARNESS-REAL-TASK-E2E-001
  Create a real, minimal task .md file ...

Priority 2 — TASK-HARNESS-ESCALATION-MVP-001
  Implement human_checkpoint_required escalation ...

Priority 3 — TASK-HARNESS-TOKEN-BUDGET-MVP-001
  Enforce max_context_tasks ...
```

**패턴 C — JSON 내 필드형 (reporter_agent.md 출력 스펙)**

```json
{
  "next_task_ready": true,
  "next_task_id": "TASK_YYYYMMDD_002"
}
```

### 2-3. 문제점

| 패턴 | 사람 가독성 | 기계 파싱 | 우선순위 추출 | ID 추출 |
|------|------------|-----------|--------------|---------|
| A (번호 목록형) | ✅ 좋음 | ❌ 어려움 | ❌ 비정형 | △ 가능하나 불안정 |
| B (Priority 레이블형) | ✅ 좋음 | △ 가능하나 불안정 | △ 숫자에 의존 | △ 대시 파싱 필요 |
| C (JSON 필드형) | ❌ 불편 | ✅ 쉬움 | ❌ 단일 next_task만 | ✅ 정확 |

결론: 기계 파싱이 안정적인 형식이 없다. Planner Feed 섹션 추가가 필요하다.

---

## 3. Planner Feed 섹션 규격

### 3-1. 섹션 헤더 (정확 일치 필수)

```
## Next Tasks (Planner Feed)
```

- 대소문자 구분: 정확히 일치해야 함
- 앞뒤 공백: 허용하지 않음
- 변형 금지: `## Planner Feed`, `## Next Tasks` 등은 인식 불가

### 3-2. 라인 포맷 (Grammar)

```
TASK_ID|PRIORITY|DESCRIPTION
```

**필드 정의:**

| 필드 | 타입 | 허용값 | 설명 |
|------|------|--------|------|
| TASK_ID | string | `[A-Z0-9][A-Z0-9_\-]+` | Task 고유 식별자 |
| PRIORITY | enum | `HIGH`, `MEDIUM`, `LOW` | 실행 우선순위 |
| DESCRIPTION | string | 자유 텍스트 (파이프 제외) | 한 줄 설명 |

**구분자:** 파이프 문자 `|` (앞뒤 공백 허용)

**허용 형식 예시:**

```
TASK-VISUAL-FIX-ITEMS-001|HIGH|Fill missing items and takeaways
TASK-VISUAL-FIX-TITLE-001 | HIGH | Add SummaryCard title fallback
TASK-VISUAL-COMPOSITION-001|MEDIUM|Increase composition diversity
```

**정규식 (파서 기준):**

```regex
^([A-Z0-9][A-Z0-9_\-]+)\s*\|\s*(HIGH|MEDIUM|LOW)\s*\|\s*(.+)$
```

그룹 1: TASK_ID  
그룹 2: PRIORITY  
그룹 3: DESCRIPTION (trim 후 사용)

### 3-3. 무시 규칙

파서가 무시하는 라인:

| 패턴 | 설명 |
|------|------|
| 빈 줄 | 빈 줄 또는 공백만 있는 줄 |
| `#`로 시작 | Markdown 헤더 또는 주석 |
| `-`로 시작 | Markdown 목록 항목 |
| `*`로 시작 | Markdown 강조 또는 목록 |
| `>`로 시작 | Markdown 인용 |
| 정규식 매칭 실패 | 포맷 불일치 라인 (로그만 기록, 에러 없음) |

### 3-4. 섹션 종료 조건

다음 중 하나가 나타나면 섹션 종료로 판단한다:

- 다음 `##` 헤더 라인 등장
- 파일 끝(EOF)
- 빈 줄 5개 이상 연속 (비표준 방어)

---

## 4. Mission Complete 규칙

### 4-1. 결정: `Planner Feed Empty`를 명시적으로 사용

**선택지 비교:**

| 방식 | 설명 | 문제 |
|------|------|------|
| 섹션 없음 → Mission Complete 자동 간주 | 간편 | 섹션 작성을 잊은 경우와 진짜 완료를 구분 불가 |
| `Planner Feed Empty` 명시 | 작성자의 의도를 명시 | 한 줄 추가 필요 |

**결정: `Planner Feed Empty` 명시 방식 채택**

근거:
- 섹션 누락과 진짜 완료 의도를 명확히 구분할 수 있다
- 작성자가 `Planner Feed Empty`를 보고 의도를 확인할 수 있다
- Planner가 자동으로 `Mission Complete` 판정하는 위험을 줄인다

### 4-2. Mission Complete 판정 흐름

```
Planner reads "## Next Tasks (Planner Feed)" 섹션

섹션 없음
  → WARN: "Planner Feed section missing"
  → mission_status = BLOCKED
  → 인간 개입 요청

섹션 있음, Planner Feed라인 0개 (빈 섹션)
  → WARN: "Planner Feed section empty — no parseable task lines"
  → mission_status = BLOCKED
  → 인간 개입 요청

섹션 있음, "MISSION_COMPLETE" 키워드 존재
  → mission_status = DONE
  → Planner 종료

섹션 있음, 1개 이상 유효 Task 라인 존재
  → Task 생성 및 Queue 등록 진행
```

### 4-3. Mission Complete 선언 방법

Report 작성자가 Mission 완료를 선언하려면:

```markdown
## Next Tasks (Planner Feed)

MISSION_COMPLETE
```

`MISSION_COMPLETE`는 특수 키워드다. TASK_ID|PRIORITY|DESCRIPTION 포맷이 아니어도 된다.

---

## 5. 완전한 Report 예시

### 5-1. 기본 예시 (추천 Task 3개)

```markdown
# TASK-HARNESS-SOME-TASK-001 Report

**Status:** DONE
**Date:** 2026-06-03

## Summary

작업이 완료되었습니다.

## Recommended Next Tasks

Priority 1 — TASK-VISUAL-FIX-ITEMS-001
  Fill missing items and takeaways in the video summary.

Priority 2 — TASK-VISUAL-FIX-TITLE-001
  Add SummaryCard title fallback for missing titles.

Priority 3 — TASK-VISUAL-COMPOSITION-001
  Increase visual composition diversity.

## Next Tasks (Planner Feed)

TASK-VISUAL-FIX-ITEMS-001|HIGH|Fill missing items and takeaways
TASK-VISUAL-FIX-TITLE-001|HIGH|Add SummaryCard title fallback
TASK-VISUAL-COMPOSITION-001|MEDIUM|Increase composition diversity
```

### 5-2. Mission Complete 선언 예시

```markdown
## Next Tasks (Planner Feed)

MISSION_COMPLETE
```

### 5-3. 주석 포함 예시

```markdown
## Next Tasks (Planner Feed)

# 아래 Task는 우선순위 순으로 정렬됨
TASK-FIX-AUTH-001|HIGH|Fix JWT token refresh bug

# 다음은 선택적 개선 사항
TASK-IMPROVE-LOGGING-001|LOW|Add structured logging to auth module
```

### 5-4. 섹션 없음 예시 (→ BLOCKED)

```markdown
# TASK-SOME-001 Report

## Summary

작업 완료.

## Next Steps

별도 후속 작업 없음.
```

Planner Feed 섹션이 없으므로 → `BLOCKED` 판정, 인간 개입 요청.

---

## 6. MISSION-AI-VIDEO-VISUAL-AUDIT-001 샘플 적용

실제 `MISSION-AI-VIDEO-VISUAL-AUDIT-001` Report에 Planner Feed 섹션을 추가한다면:

```markdown
# MISSION-AI-VIDEO-VISUAL-AUDIT-001 Final Report

**Mission:** AI 비디오 시각적 품질 감사
**Status:** DONE
**Date:** 2026-06-03

---

## Audit Summary

...

---

## Issues Found

1. SummaryCard에 items, takeaways 필드가 비어 있음 (HIGH)
2. SummaryCard title 누락 케이스 발생 (HIGH)
3. 시각적 구성 다양성 부족 (MEDIUM)

---

## Recommended Next Tasks

다음 Task를 순서대로 수행할 것을 권고합니다.

**Priority 1 — TASK-VISUAL-FIX-ITEMS-001**
SummaryCard의 items, takeaways 필드를 채우는 로직을 수정한다.
영향 파일: `src/components/SummaryCard.tsx`, `src/api/summary.ts`

**Priority 2 — TASK-VISUAL-FIX-TITLE-001**
title이 없을 때 fallback 텍스트를 표시하도록 수정한다.
영향 파일: `src/components/SummaryCard.tsx`

**Priority 3 — TASK-VISUAL-COMPOSITION-001**
비디오 썸네일 구성 요소 다양성을 높인다.
영향 파일: `src/components/ThumbnailComposer.tsx`

---

## Next Tasks (Planner Feed)

TASK-VISUAL-FIX-ITEMS-001|HIGH|Fill missing items and takeaways in SummaryCard
TASK-VISUAL-FIX-TITLE-001|HIGH|Add SummaryCard title fallback for missing titles
TASK-VISUAL-COMPOSITION-001|MEDIUM|Increase visual composition diversity
```

---

## 7. 파싱 규칙 (Planner 구현 시 참조)

### 7-1. 섹션 탐지

```python
# pseudocode
in_planner_feed = False

for line in report_lines:
    if line.strip() == "## Next Tasks (Planner Feed)":
        in_planner_feed = True
        continue

    if in_planner_feed:
        if line.startswith("## "):   # 다음 헤더 → 섹션 종료
            break
        # 나머지는 라인 파싱으로 전달
```

### 7-2. 라인 파싱

```python
import re

PLANNER_FEED_PATTERN = re.compile(
    r"^([A-Z0-9][A-Z0-9_\-]+)\s*\|\s*(HIGH|MEDIUM|LOW)\s*\|\s*(.+)$"
)
MISSION_COMPLETE_KEYWORD = "MISSION_COMPLETE"

def parse_planner_feed_line(line: str):
    stripped = line.strip()

    # 무시 규칙
    if not stripped:
        return None  # 빈 줄
    if stripped.startswith(("#", "-", "*", ">")):
        return None  # 주석 또는 목록

    # Mission Complete 키워드
    if stripped == MISSION_COMPLETE_KEYWORD:
        return {"type": "MISSION_COMPLETE"}

    # Task 라인 파싱
    match = PLANNER_FEED_PATTERN.match(stripped)
    if match:
        return {
            "type": "TASK",
            "task_id": match.group(1),
            "priority": match.group(2),
            "description": match.group(3).strip()
        }

    # 매칭 실패 → 경고 로그, None 반환
    log_warn(f"Unrecognized Planner Feed line: {stripped!r}")
    return None
```

### 7-3. 결과 처리

```python
def process_planner_feed(parsed_lines):
    tasks = [l for l in parsed_lines if l and l["type"] == "TASK"]
    mission_complete = any(l and l["type"] == "MISSION_COMPLETE" for l in parsed_lines)

    if mission_complete:
        return {"status": "MISSION_COMPLETE", "tasks": []}

    if not tasks:
        return {"status": "EMPTY", "tasks": []}

    # 우선순위 정렬: HIGH → MEDIUM → LOW
    priority_order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
    tasks.sort(key=lambda t: priority_order[t["priority"]])

    return {"status": "HAS_TASKS", "tasks": tasks}
```

---

## 8. Failure Cases

| Case | 조건 | Planner 처리 |
|------|------|-------------|
| F-1: 섹션 없음 | `## Next Tasks (Planner Feed)` 헤더 미존재 | WARN → `BLOCKED` → 인간 개입 요청 |
| F-2: 섹션 비어 있음 | 섹션 있으나 유효 Task 라인 0개 | WARN → `BLOCKED` → 인간 개입 요청 |
| F-3: PRIORITY 오타 | `HIHG`, `high`, `Critical` 등 | 해당 라인 무시 (skip), 나머지 처리 계속 |
| F-4: TASK_ID 소문자 | `task-fix-001|HIGH|...` | 해당 라인 무시 (정규식 미매칭), 나머지 계속 |
| F-5: 파이프 누락 | `TASK-001 HIGH Fix something` | 해당 라인 무시, 나머지 계속 |
| F-6: 중복 Task | 동일 TASK_ID가 이미 존재 | 해당 Task 스킵, 다음 Task로 진행 |
| F-7: MISSION_COMPLETE + Task 혼재 | 둘 다 있는 경우 | MISSION_COMPLETE 우선, Task 무시 |
| F-8: 섹션 헤더 변형 | `## Planner Feed`, `## next tasks (planner feed)` | 섹션 인식 실패 → F-1로 처리 |

---

## 9. 하위 호환성 (Backward Compatibility)

### 9-1. 기존 Report 영향

Planner Feed 섹션이 없는 기존 Report는 **변경 없이 유지**된다.

| 기존 Report 상태 | Planner 동작 |
|-----------------|-------------|
| Planner Feed 섹션 없음 | `BLOCKED` 판정 (인간 개입 요청) |
| 기존 자연어 추천 섹션만 있음 | `BLOCKED` 판정 (Planner Feed 미인식) |
| 두 섹션 모두 있음 | Planner Feed 섹션만 파싱 |

### 9-2. 기존 섹션 변경 금지

Planner Feed 도입 시 기존 섹션(`## Recommended Next Tasks`, `## 다음 추천 Task` 등)을 **제거하거나 수정하지 않는다**.

이유:
- 기존 섹션은 사람이 읽는 용도로 계속 사용
- 레거시 Report와 새 Report의 공존 보장
- Report 작성자 혼란 방지

### 9-3. 점진적 도입 전략

```
단계 1 (현재): 신규 Report에만 Planner Feed 섹션 추가
단계 2 (선택): 자주 참조되는 기존 Report에 Planner Feed 섹션 소급 추가
단계 3 (미래): Planner Feed 없는 Report → Planner가 자동으로 경고만 발생
```

단계 2, 3은 별도 Task로 진행한다. 본 문서 범위 외.

---

## 10. Report 작성자 가이드

Report 작성 시 Planner Feed 섹션을 추가하는 방법:

### Step 1: 기존 추천 Task 섹션 유지

```markdown
## Recommended Next Tasks

Priority 1 — TASK-ID-001
  설명...
```

이 섹션은 그대로 둔다.

### Step 2: Planner Feed 섹션 추가

기존 섹션 **뒤에** 다음 섹션을 추가한다:

```markdown
## Next Tasks (Planner Feed)

TASK-ID-001|HIGH|한 줄 설명
TASK-ID-002|MEDIUM|한 줄 설명
```

### Step 3: Mission 완료 시

```markdown
## Next Tasks (Planner Feed)

MISSION_COMPLETE
```

### 작성 규칙 요약

```
✅ 섹션 헤더: ## Next Tasks (Planner Feed) — 정확히 일치
✅ TASK_ID: 대문자 + 숫자 + 하이픈 + 언더스코어만 허용
✅ PRIORITY: HIGH / MEDIUM / LOW 중 하나 (대문자 필수)
✅ 구분자: | (파이프, 앞뒤 공백 허용)
✅ DESCRIPTION: 한 줄, 파이프 문자 포함 금지
✅ 주석: # 로 시작하는 줄은 무시됨 (사용 가능)

❌ 소문자 TASK_ID 금지
❌ PRIORITY 변형 금지 (high, HIHG, Critical 등)
❌ 여러 줄 DESCRIPTION 금지
❌ 섹션 헤더 변형 금지
```

---

## 11. Validation 결과

| 질문 | 답변 |
|------|------|
| Planner가 정규식 하나로 파싱 가능한가? | ✅ 가능. `^([A-Z0-9][A-Z0-9_\-]+)\s*\|\s*(HIGH\|MEDIUM\|LOW)\s*\|\s*(.+)$` |
| Mission Report 작성자가 쉽게 작성 가능한가? | ✅ 가능. 파이프 구분 한 줄 포맷으로 직관적 |
| 기존 Report와 호환 가능한가? | ✅ 가능. 기존 섹션 유지, 신규 섹션 추가만 |
| Mission Complete 판정 가능한가? | ✅ 가능. `MISSION_COMPLETE` 키워드 또는 섹션 비어 있음으로 판정 |

---

## 12. 다음 구현 Task

이 문서를 기반으로 실행해야 할 후속 Task:

| Task ID | 설명 | 우선순위 |
|---------|------|---------|
| TASK-HCHAIN-PLANNER-STATE-SCHEMA-001 | mission_state.json 스키마에 planner_last_run, feedback_cycle 필드 추가 | HIGH |
| TASK-HCHAIN-PLANNER-FLOW-001 | Planner Claude Flow 구현 (파싱 + Task 생성 + Queue 등록) | HIGH |
| TASK-HCHAIN-PLANNER-E2E-001 | Planner Feedback E2E 검증 | MEDIUM |

---

## References

- `docs/design/TASK-HCHAIN-PLANNER-FEEDBACK-MVP-DESIGN-001.md` — Planner Feedback MVP 전체 설계
- `docs/guides/HCHAIN_REPORT_POLICY.md` — Report 보존 및 커밋 정책
- `skills/hchain/agents/reporter_agent.md` — Reporter Agent 출력 스펙
- `templates/harness/templates/mission_summary.md` — Mission Summary 템플릿
