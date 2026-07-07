# 기능 계약 작성법

## 기능 계약이란

기능 계약(Feature Contract)은 개발할 기능의 명세서다. 코드 작성 전에 작성하고, 구현 중에 참조하고, 구현 후에 검증 기준으로 사용한다.

계약서 위치: `contracts/features/<기능명>.md`

---

## 파일 구조

### YAML front-matter

파일 상단에 `---`로 감싸진 메타데이터 블록을 작성한다.

```yaml
---
관련 계약:
- PROJECT.md
- ARCHITECTURE.md
- RULES.md

영향 범위:
- backend
- worker

관련 기능:
- QUEUE.md

우선순위: 높음
---
```

| 필드 | 설명 |
|------|------|
| 관련 계약 | 이 기능과 연관된 base 계약 파일 목록 |
| 영향 범위 | frontend, backend, database, worker, scheduler 중 해당 항목 |
| 관련 기능 | 연관된 다른 기능 계약 파일 목록 |
| 우선순위 | 높음 / 보통 / 낮음 |

### 본문 14개 섹션

```markdown
## 목적
이 기능이 왜 필요한지 한 단락으로 설명한다.

## 범위
포함되는 것과 제외되는 것을 명시한다.

## 영향 범위
어떤 레이어, 서비스, 파일이 영향받는지 열거한다.

## 상태
현재 계약 상태 (draft / review / approved / implemented / deprecated)

## 입력
함수 시그니처, API 요청 바디, 큐 메시지 구조 등

## 출력
함수 반환값, API 응답 구조, 결과 상태 등

## UI
변경이 필요한 UI 컴포넌트, 화면, 플로우 (없으면 "해당 없음")

## API
추가/변경되는 API 엔드포인트 목록

## 데이터
DB 스키마 변경, 새 필드, 인덱스 등

## 실패 처리
오류 케이스별 처리 방법, 재시도 정책, 폴백

## 검증
어떻게 구현이 올바른지 확인할 것인가

## 완료 기준
체크리스트 형태로 완료 조건을 명시한다

## 확인 필요
미결정 항목, 승인이 필요한 사항
```

---

## Queue 예제

`contracts/features/QUEUE_RETRY.md`:

```markdown
---
관련 계약:
- PROJECT.md
- ARCHITECTURE.md
- RULES.md

영향 범위:
- backend
- worker

관련 기능:
- QUEUE.md

우선순위: 높음
---

# Queue 재시도 기능

## 목적
큐에서 처리 실패한 아이템을 자동으로 재시도하여 일시적 장애로 인한 데이터 손실을 방지한다.

## 범위
포함:
- 실패 아이템 자동 재시도 (최대 3회)
- 재시도 간격 설정 (5분)
- 최종 실패 시 dead-letter-queue 이동

제외:
- 수동 재시도 UI
- 재시도 이력 조회 API

## 영향 범위
- backend: queue_worker.py, retry_handler.py
- database: queue_items 테이블 (retry_count, last_retry_at 필드 추가)

## 상태
draft

## 입력
```json
{
  "item_id": "string",
  "retry_count": "integer",
  "last_error": "string"
}
```

## 출력
```json
{
  "success": "boolean",
  "retry_count": "integer",
  "next_retry_at": "ISO8601 | null"
}
```

## UI
해당 없음

## API
없음 (내부 Worker 로직)

## 데이터
ALTER TABLE queue_items ADD COLUMN retry_count INTEGER DEFAULT 0;
ALTER TABLE queue_items ADD COLUMN last_retry_at TIMESTAMP;
ALTER TABLE queue_items ADD COLUMN dead_letter BOOLEAN DEFAULT FALSE;

## 실패 처리
- retry_count < 3: 5분 후 재시도
- retry_count >= 3: dead_letter = TRUE로 표시, 알림 발송

## 검증
- 실패 아이템이 5분 후 재시도되는가
- 3회 실패 후 dead-letter-queue로 이동하는가
- retry_count 필드가 올바르게 증가하는가

## 완료 기준
- [ ] retry_count 필드 마이그레이션 완료
- [ ] retry_handler.py 구현 완료
- [ ] pytest tests/test_retry.py 통과

## 확인 필요
- 재시도 간격을 설정값으로 받을 것인가, 하드코딩할 것인가
```

---

## Template 예제

`contracts/features/VIDEO_TEMPLATE.md`:

```markdown
---
관련 계약:
- PROJECT.md
- ARCHITECTURE.md

영향 범위:
- backend
- frontend

관련 기능:
- RENDER.md
- TTS.md

우선순위: 보통
---

# 영상 템플릿 기능

## 목적
사전 정의된 템플릿으로 영상을 빠르게 생성할 수 있도록 한다.

## 범위
포함:
- 템플릿 목록 조회 API
- 템플릿 기반 영상 생성 요청

제외:
- 템플릿 직접 편집 UI
- 템플릿 공유 기능

## 상태
draft

...
```

---

## 계약 검증

계약서 작성 후 구조를 검사한다:

```bash
python3 ~/hchain/install.py --target . --contract-check
```

누락 섹션을 자동으로 추가하려면:

```bash
python3 ~/hchain/install.py --target . --contract-check --write
```

구현 완료 후 계약과 코드 사이의 차이를 확인한다:

```bash
python3 ~/hchain/install.py --target . --contract-review-diff
```
