# 실전 검증 케이스: ai-video Queue 재시도 기능

## 검증 일시

2026-06-26

## 검증 목적

HCHAIN Contract Workflow를 ai-video 프로젝트에 실제 적용하여 동작을 검증한다.

---

## 입력

```
요청: 큐에서 실패한 아이템을 재시도하는 Queue 기능 추가
프로파일: ai-video
```

---

## 1단계: 설치 및 프로파일 적용

```bash
python3 ~/hchain/install.py --target /tmp/hchain-test-aivideo --profile ai-video
```

**결과:**

```
[hchain] Installing HCHAIN into /tmp/hchain-test-aivideo
[hchain] CREATE contracts/features/TEMPLATE.md [profile=ai-video]
[hchain] CREATE contracts/features/RENDER.md [profile=ai-video]
[hchain] CREATE contracts/features/TTS.md [profile=ai-video]
[hchain] Install complete ✓
```

생성된 계약 파일:
- `contracts/features/TEMPLATE.md` — 영상 템플릿 계약 초안
- `contracts/features/RENDER.md` — 렌더링 파이프라인 계약 초안
- `contracts/features/TTS.md` — TTS 서비스 계약 초안

---

## 2단계: Contract Workflow 실행

```bash
python3 ~/hchain/install.py \
  --target /tmp/hchain-test-aivideo \
  --workflow "큐에서 실패한 아이템을 재시도하는 Queue 기능 추가"
```

### 관련 계약 선택 (Step 1)

```
contracts/PROJECT.md
contracts/ARCHITECTURE.md
contracts/RULES.md
contracts/VALIDATION.md
contracts/DONE.md
```

5개 base 계약 자동 선택됨. 기능 계약(features/)은 없어서 추가 선택 없음.

### 영향 범위 분석 (Step 2)

```
- frontend
- worker
```

분석 결과: `큐에서`, `재시도`, `Queue` 키워드에서 `worker`, `frontend` 영향 탐지.

> **발견된 문제**: 요청에서 `backend`를 탐지하지 못했다. 큐 재시도는 실제로 backend와 worker 모두 영향받는 기능이다. 이 부분은 `## 영향 범위`에서 사용자가 직접 보완해야 한다.

### 빠진 정책 탐지 (Step 3)

```
⚠️  DONE.md: '## 완료 기준' 섹션 없음
```

초기 설치 직후 DONE.md에 `## 완료 기준` 섹션이 없음. 사용자가 먼저 채워야 한다.

### 질문 생성 (Step 4)

```
? [Worker] 큐에서: 재시도 정책 및 실패 처리 방식이 정의되어 있나요?
? [UI] 큐에서: 화면 흐름과 에러 상태 표시 방법이 정의되어 있나요?
? [정책] 기본 계약에 누락된 항목이 있습니다 — 작성이 필요합니다.
```

### 기능 계약 초안 생성 (Step 5)

```
contracts/features/큐에서.md 생성됨 (status: draft)
```

> **발견된 문제**: 기능명이 요청의 첫 단어 "큐에서"로 추출되어 파일명이 `큐에서.md`가 되었다. 실제로는 `QUEUE_RETRY.md`가 적절하다. 별도로 직접 생성이 필요하다.

---

## 3단계: 직접 계약 생성

```bash
python3 ~/hchain/install.py \
  --target /tmp/hchain-test-aivideo \
  --generate-contract QUEUE_RETRY
```

```
contracts/features/QUEUE_RETRY.md 생성됨
```

---

## 4단계: 관련 계약 선택 확인

```bash
python3 ~/hchain/install.py \
  --target /tmp/hchain-test-aivideo \
  --select-contracts queue retry worker
```

```
contracts/PROJECT.md
contracts/ARCHITECTURE.md
contracts/RULES.md
contracts/VALIDATION.md
contracts/DONE.md
contracts/features/QUEUE_RETRY.md
contracts/features/큐에서.md
```

키워드 매칭으로 `QUEUE_RETRY.md`가 정상 선택됨.

---

## 5단계: 계약 상태 검사

```bash
python3 ~/hchain/install.py \
  --target /tmp/hchain-test-aivideo \
  --contract-check
```

```
[features/QUEUE_RETRY.md] 누락 섹션: ## 데이터
[features/RENDER.md] 누락 섹션: ## 범위, ## 영향 범위, ## 상태, ## UI, ## API, ## 데이터
[features/TTS.md] 누락 섹션: ## 범위, ## 영향 범위, ## 상태, ## UI, ## API, ## 데이터
[features/큐에서.md] 누락 섹션: ## 데이터
```

RENDER.md, TTS.md는 프로파일이 생성한 초안이므로 섹션 미완성이 정상이다.
QUEUE_RETRY.md는 `## 데이터` 섹션이 자동으로 생략됨 — 수동 보완 필요.

---

## 6단계: 계약-코드 차이 분석

```bash
python3 ~/hchain/install.py \
  --target /tmp/hchain-test-aivideo \
  --contract-review-diff
```

```
### 계약에는 있으나 코드에 없음
  이슈 없음

### 코드에는 있으나 계약에 없음
  이슈 없음

### 상태 정의 불일치
  - features/RENDER.md: '## 상태' 섹션 없음
  - features/TTS.md: '## 상태' 섹션 없음
```

코드가 없는 프로젝트이므로 코드-계약 불일치는 없음. RENDER.md, TTS.md의 `## 상태` 미작성은 프로파일 초안의 한계.

---

## 발견된 문제

| 번호 | 문제 | 심각도 | 비고 |
|------|------|--------|------|
| 1 | `--workflow` 첫 단어로 기능명 추출 → 한국어 요청 시 부적절한 파일명 | 보통 | `--generate-contract` 별도 실행으로 우회 가능 |
| 2 | `backend` 영향이 queue 요청에서 탐지 안 됨 | 낮음 | 사용자가 계약서에서 수동 보완 |
| 3 | 프로파일 초안(RENDER.md, TTS.md)에 필수 섹션 미포함 | 낮음 | 초안이므로 작성 필요 안내 포함 |
| 4 | DONE.md `## 완료 기준` 초기에 비어 있음 | 낮음 | 최초 install 후 사용자 작성 필요 |

---

## Reviewer 평가

- Contract Workflow 6단계 파이프라인 정상 동작
- 관련 계약 선택, 영향 범위 분석, 질문 생성, 계약 초안 생성 순서 올바름
- Lifecycle 검사 미동작 (기존 계약이 없었으므로 정상)
- `--select-contracts`, `--generate-contract`, `--contract-check`, `--contract-review-diff` 모두 정상 동작

## Validator 결과

```bash
pytest tests/ → 74 passed, 0 failed
```

---

## 결론

HCHAIN Contract Workflow가 ai-video 프로파일에서 정상적으로 동작한다.

한국어 자연어 요청의 첫 단어로 기능명을 추출하는 방식은 한계가 있다. 실제 사용 시 `--generate-contract FEATURE_NAME`으로 직접 이름을 지정하는 것을 권장한다.

Contract First 흐름 (`--workflow → 계약서 수정 → task 생성`)은 의도한 대로 동작한다.
