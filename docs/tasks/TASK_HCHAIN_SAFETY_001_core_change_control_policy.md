# TASK-HCHAIN-SAFETY-001 — HCHAIN Core 변경 통제 정책 추가

## 목표

HCHAIN Core가 Claude에 의해 임의로 확장되거나 자동화되지 않도록
변경 통제 정책을 문서화하고, policies/ 디렉토리에 적용한다.

## 문제 배경

HCHAIN Core는 모든 프로젝트에 설치되는 메타데이터 레이어의 기반이다.
Core가 무분별하게 확장되면 설치된 모든 프로젝트에 회귀 위험이 발생한다.

현재 Core 수정에 대한 명시적 제한 정책이 없어 Claude가 요청 범위를 초과하는
변경을 수행할 가능성이 있다.

## 범위 (포함)

- `docs/tasks/TASK_HCHAIN_SAFETY_001_core_change_control_policy.md` 작성 (이 파일)
- `policies/HCHAIN_CORE_CHANGE_CONTROL_POLICY.md` 작성

## 범위 (제외)

- `install.sh` 수정 금지
- `harness_runner.sh` 등 실행 로직 수정 금지
- `queue`, `registry`, `sync-all` 기능 구현 금지
- Python/Node/Ruby 등 외부 런타임 추가 금지
- `ai-video` 및 기타 대상 프로젝트 수정 금지

## 실행 절차

1. 이 Task 문서 작성 (`docs/tasks/`)
2. Core 변경 통제 정책 작성 (`policies/HCHAIN_CORE_CHANGE_CONTROL_POLICY.md`)
3. git add → commit (chore: add HCHAIN Core change control policy)

## 완료 조건

- [x] `docs/tasks/TASK_HCHAIN_SAFETY_001_core_change_control_policy.md` 존재
- [x] `policies/HCHAIN_CORE_CHANGE_CONTROL_POLICY.md` 존재 및 9개 정책 조항 포함
- [x] `install.sh`, `harness_runner.sh` 등 실행 로직 변경 없음
- [x] `git diff --name-only` 결과가 docs/, policies/ 파일로만 제한됨

## 검증 방법

```bash
# 변경 파일 확인
git diff --name-only HEAD

# 정책 내용 확인
cat policies/HCHAIN_CORE_CHANGE_CONTROL_POLICY.md

# 실행 로직 미변경 확인
git diff install.sh
```

## 오염 방지 규칙

- 이 Task로 인해 실행 로직이 변경되어서는 안 된다.
- 정책 문서는 `policies/` 아래에만 위치한다.
- Task 문서는 `docs/tasks/` 아래에만 위치한다.
