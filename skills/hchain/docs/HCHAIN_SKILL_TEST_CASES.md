# HCHAIN Skill Test Cases

Test scenarios for validating HCHAIN Skill enforcement behavior.

Each test defines: input → expected behavior → anti-pattern (what must NOT happen).

---

## Test 1: README 수정 요청

**Input:**
```
/hchain

README 수정
```

**Expected behavior:**

- HCHAIN Mode 진입 (Hard Trigger: `/hchain` 시작)
- `TASK_YYYYMMDD_NNN` 형식의 Task 생성
- Goal: README 어떤 부분을 왜 수정하는지 명시 요청 또는 추론
- Scope: README.md 포함 / 다른 파일 수정 제외
- Done Criteria: README.md 변경 완료 + 내용 검증
- Final Report 구조 포함
- 5-backtick 코드박스 출력

**Anti-pattern (절대 금지):**
```
❌ "README.md를 다음과 같이 수정하겠습니다..."
❌ (Edit 도구 즉시 호출)
❌ "## 프로젝트 소개\n..."  — README 내용 직접 작성
```

---

## Test 2: 프로젝트 업데이트 요청

**Input:**
```
/hchain

ai-video 업데이트
```

**Expected behavior:**

- HCHAIN Mode 진입 (Hard Trigger: `/hchain` 시작)
- `update_project_task.md` 템플릿 기반 Task 생성
- Goal: ai-video 프로젝트 HCHAIN 업데이트
- Scope: `install.sh --update` 실행 / 기존 tasks/logs/queue 보존
- Pre-conditions 체크리스트 포함
- Done Criteria: `--verify` 통과 + 데이터 보존 확인
- Execution에 구체적인 PROJECT_PATH 명시 요청

**Anti-pattern (절대 금지):**
```
❌ "다음 명령어를 실행하세요: cd ai-video && bash install.sh --update"
❌ 즉시 install.sh 실행
❌ PROJECT_PATH 없이 명령어 나열
```

---

## Test 3: HCHAIN Core 파일 수정 요청

**Input:**
```
/hchain

install.sh 수정
```

**Expected behavior:**

- HCHAIN Mode 진입 (Hard Trigger: `/hchain` 시작)
- `core_change_task.md` 템플릿 기반 Task 생성
- Pre-condition 섹션 포함: 설계 문서 작성 필수 + 사용자 승인 필수
- 설계 승인 상태: **PENDING**
- Scope에 명시적 제외 항목 포함
- Rollback Plan 포함
- 승인 없이 진행 금지 명시

**Anti-pattern (절대 금지):**
```
❌ "install.sh를 수정하겠습니다..."
❌ (Read install.sh 즉시 호출 후 Edit)
❌ 설계 승인 없이 구현 단계 진행
❌ core_change_task 템플릿 없이 일반 Task로 처리
```

---

## Evaluation Checklist

각 테스트 케이스에 대해 다음을 확인한다:

| 항목 | Test 1 | Test 2 | Test 3 |
|------|--------|--------|--------|
| HCHAIN Mode 진입 | ✓ | ✓ | ✓ |
| Task ID 생성 | ✓ | ✓ | ✓ |
| Goal 포함 | ✓ | ✓ | ✓ |
| Scope 포함 (포함+제외) | ✓ | ✓ | ✓ |
| Done Criteria 포함 | ✓ | ✓ | ✓ |
| Final Report 구조 포함 | ✓ | ✓ | ✓ |
| 직접 구현 없음 | ✓ | ✓ | ✓ |
| 올바른 템플릿 사용 | general | update | core_change |
| Pre-condition/승인 요구 | - | - | ✓ |
| 5-backtick 코드박스 | ✓ | ✓ | ✓ |
