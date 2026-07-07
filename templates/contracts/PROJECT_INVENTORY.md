# Project Inventory

## 목적

이 프로젝트에서 독립적으로 식별 가능한 시스템 구성 단위의 공식 목록이다.

- 레이어(backend) → 컴포넌트(Progress) → 파일(progress.py) 구조의 중간 레이어
- Feature Contract의 `영향 컴포넌트` 필드와 Planner Agent의 `component_impact[]`가
  이 목록을 참조한다
- 컴포넌트 추가 시에만 갱신한다. Task마다 재생성하지 않는다.

---

## UI

| ID    | Name | Layer | Description |
|-------|------|-------|-------------|
| UI-01 |      | UI    |             |

---

## Pipeline

| ID    | Name | Layer    | Description |
|-------|------|----------|-------------|
| PL-01 |      | Pipeline |             |

---

## Artifact

| ID    | Name | Layer    | Description |
|-------|------|----------|-------------|
| AF-01 |      | Artifact |             |

---

## Operation

| ID    | Name      | Layer     | Description |
|-------|-----------|-----------|-------------|
| OP-01 |           | Operation |             |

---

## Impact 분류 기준

| Impact  | 의미                         |
|---------|------------------------------|
| WRITE   | 해당 컴포넌트를 직접 수정    |
| VERIFY  | 수정은 없으나 동작 검증 필요 |
| READ    | 읽기 전용 참조               |
| NONE    | 이번 변경에 무관             |

---

## 갱신 이력

| 날짜 | 변경 내용 |
|------|-----------|
|      | 최초 작성 |
