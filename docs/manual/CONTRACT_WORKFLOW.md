# Contract Workflow

## Contract First란?

코드를 작성하기 전에 반드시 **기능 계약서**를 작성한다는 원칙이다.

계약서에는 다음이 포함된다:
- 목적 (이 기능이 왜 필요한가)
- 범위 (무엇이 포함되고 무엇이 제외되는가)
- 영향 범위 (어떤 레이어/서비스가 영향받는가)
- 입력/출력 (인터페이스 명세)
- API 명세
- DB 스키마 변경
- 실패 처리 정책
- 검증 기준
- 완료 기준

계약 없이 Task를 시작하면 HCHAIN이 경고를 출력하고 계약서 작성을 요청한다.

---

## Contract Workflow 6단계 파이프라인

`--workflow REQUEST` 명령으로 실행한다. 단계는 내부적으로 순차 실행되며 사용자에게 결과만 출력된다.

```
1. 관련 계약 읽기
   ↓
2. 영향 범위 분석
   ↓
3. 빠진 정책 탐지
   ↓
4. 질문 생성
   ↓
5. 기능 계약 초안 생성
   ↓
6. Task 생성 안내
```

### 1단계: 관련 계약 읽기

요청에서 키워드를 추출하고 관련 계약 파일을 선택한다.

- 항상 포함: PROJECT.md, ARCHITECTURE.md, RULES.md, VALIDATION.md, DONE.md
- 추가 선택: 요청 키워드와 기능 계약(features/*.md)의 영향 범위·관련 기능 매칭

### 2단계: 영향 범위 분석

요청 키워드와 프로젝트 구조를 분석하여 영향받는 레이어를 파악한다.

#### 레이어 수준 분석 (기존)

| 영역 | 탐지 키워드 예시 |
|------|-----------------|
| frontend | ui, frontend, web, page, form |
| backend | api, backend, server, endpoint |
| database | db, database, model, schema, migration |
| worker | worker, queue, job, task, celery |
| scheduler | scheduler, cron, periodic |

#### 컴포넌트 수준 분석 (Project Inventory 사용 시)

`contracts/PROJECT_INVENTORY.md`가 존재하면 레이어 분석 이후 컴포넌트 수준 분석을 추가로 수행한다.

1. PROJECT_INVENTORY.md 전체 컴포넌트 목록 로드
2. 각 컴포넌트에 Impact 분류: `WRITE / VERIFY / READ / NONE`
3. 분류 결과를 Feature Contract의 `영향 컴포넌트:` 필드와 `## 영향 컴포넌트` 섹션에 기록

PROJECT_INVENTORY.md가 없으면 컴포넌트 수준 분석은 생략하고 레이어 수준만 수행한다.

영향 범위는 별도 명령이 아니라 Workflow 내부 단계로 통합되어 있다.

### 3단계: 빠진 정책 탐지

base 계약(PROJECT.md, ARCHITECTURE.md, RULES.md, VALIDATION.md, DONE.md)에서 필수 섹션이 누락되었는지 확인한다.

예: VALIDATION.md에 `## 검증 범위` 섹션이 없으면 빠진 정책으로 분류된다.

### 4단계: 질문 생성

영향 범위와 빠진 정책을 바탕으로 사용자에게 물어봐야 할 질문을 생성한다.

예시:
- `backend` 영향 → "API 엔드포인트 설계는 어떻게 되나요?"
- `database` 영향 → "DB 스키마 변경이 필요한가요?"
- 빠진 정책 → "VALIDATION.md에 검증 기준이 없습니다. 추가할까요?"

### 5단계: 기능 계약 초안 생성

분석 결과를 바탕으로 `contracts/features/<FEATURE_NAME>.md`를 자동 생성한다. 이미 파일이 존재하면 덮어쓰지 않는다.

생성된 계약서에는 YAML front-matter와 14개 섹션이 포함된다.

### 6단계: Task 생성 안내

계약서를 검토한 후 Task를 생성하도록 안내 메시지를 출력한다.

---

## 영향 범위 분석

영향 범위 분석은 두 가지 소스를 결합한다:

1. **요청 키워드 분석** — 자연어 요청에서 키워드 추출
2. **프로젝트 구조 스캔** — 실제 디렉터리 구조 확인

```python
# 내부 동작 예시
impacts = _infer_impacts_from_name("queue_retry")
# → ["backend", "worker"]

structure = analyze_project_structure(target)
# → {detected_impacts: ["backend", "worker"], has_api: True, has_worker: True}
```

---

## 질문 생성

질문은 영향 범위별로 자동 생성된다. 계약서를 완성하기 전에 사용자가 답변해야 할 항목들이다.

```bash
python3 ~/hchain/install.py \
  --target /path/to/your-project \
  --workflow "TTS 음성 클론 기능"
```

출력 예:

```
[질문 목록]
1. TTS API 제공자는 무엇인가요? (ElevenLabs, OpenAI 등)
2. 음성 클론 데이터 저장 위치는?
3. 실패 시 폴백 처리 방법은?
4. VALIDATION.md에 검증 기준이 없습니다. 추가가 필요합니다.
```

---

## 계약 생성

계약서는 `contracts/features/` 디렉터리에 저장된다.

YAML front-matter 구조:

```yaml
---
관련 계약:
- PROJECT.md
- ARCHITECTURE.md

영향 범위:
- backend
- worker

관련 기능: []

우선순위: 보통
---
```

본문 14개 섹션:

```
## 목적
## 범위
## 영향 범위
## 상태
## 입력
## 출력
## UI
## API
## 데이터
## 실패 처리
## 검증
## 완료 기준
## 확인 필요
```

---

## Task 생성

계약서 검토 후 Task를 생성한다. Task 파일은 계약 파일을 명시적으로 참조해야 한다.

```markdown
---
task_id: TASK_20260626_001
title: 큐 재시도 기능 구현
retry_limit: 3
severity_stop: MAJOR
validate:
  - pytest tests/
---

## 계약 참조
- contracts/features/QUEUE_RETRY.md
```
