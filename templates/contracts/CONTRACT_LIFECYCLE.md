# 기능 계약 라이프사이클

## 상태 정의

기능 계약은 아래 5가지 상태를 가진다. 계약서 YAML front-matter의 `status` 필드로 관리한다.

```
Draft
  ↓
Review
  ↓
Approved
  ↓
Implemented
  ↓
Deprecated
```

| 상태 | 의미 | 다음 상태 |
|------|------|-----------|
| `draft` | 작성 중. 내용이 미완성이거나 검토 전 | review |
| `review` | 검토 요청됨. 내용 확정 전 논의 중 | approved / draft |
| `approved` | 검토 완료. 구현 진행 가능 | implemented |
| `implemented` | 구현 완료. 계약과 코드가 일치 | deprecated |
| `deprecated` | 더 이상 사용되지 않음 | — |

---

## Feature Contract YAML front-matter

기능 계약서 상단에 다음 필드를 포함한다.

```yaml
---
관련 계약:
- PROJECT.md
- ARCHITECTURE.md

영향 범위:
- backend

관련 기능: []

우선순위: 보통

status: draft
created: 2026-06-26
updated: 2026-06-26
owner: 작성자명
---
```

| 필드 | 설명 | 예시 |
|------|------|------|
| `status` | 현재 라이프사이클 상태 | `draft` |
| `created` | 계약서 최초 작성일 (YYYY-MM-DD) | `2026-06-26` |
| `updated` | 마지막 수정일 (YYYY-MM-DD) | `2026-06-26` |
| `owner` | 계약 담당자 | `이현승` |

---

## 상태 전환 규칙

### Draft → Review

- 14개 필수 섹션이 모두 작성된 상태
- 계약 검사 통과: `python3 ~/hchain/install.py --target . --contract-check`

### Review → Approved

- 담당자 검토 완료
- 영향 범위, 완료 기준, 실패 처리 정책이 명확하게 작성됨

### Review → Draft

- 검토 중 수정이 필요한 경우
- `updated` 필드 갱신

### Approved → Implemented

- Task 실행 완료 (DONE 단계 통과)
- `--contract-review-diff`로 계약-코드 일치 확인
- `updated` 필드를 구현 완료일로 갱신

### Implemented → Deprecated

- 해당 기능이 제거되거나 대체됨
- 새 기능 계약서에 `관련 기능` 으로 이 파일을 참조

---

## Contract Workflow와의 통합

`--workflow` 명령 실행 시 Contract Workflow는 내부적으로 lifecycle 상태를 검사한다.

- `draft` 계약이 있으면 → 기존 초안을 활용하도록 안내
- `approved` 계약이 있으면 → 이미 승인된 계약임을 알리고 Task 생성으로 안내
- `implemented` 계약이 있으면 → 이미 구현된 기능임을 알리고 새 계약 생성 여부 확인
- 계약이 없으면 → 새 계약 초안 생성 (`status: draft`)

`--contract-review-diff` 실행 시 `implemented` 상태가 아닌 계약에서 코드-계약 불일치가 발견되면 별도 경고를 출력한다.

---

## 예시: Queue 재시도 기능 lifecycle

```
1. Draft 작성
   python3 ~/hchain/install.py --target . --workflow "큐 재시도 기능"
   → contracts/features/QUEUE_RETRY.md (status: draft)

2. 계약서 검토 및 수정
   → status: review

3. 승인
   → status: approved

4. Task 실행 및 구현 완료
   bash harness/harness_runner.sh --task TASK_20260626_001
   → status: implemented

5. 기능 폐기 시
   → status: deprecated
```
