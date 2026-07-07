# HCHAIN Core 변경 통제 정책

Version: 1.0.0
Date: 2026-05-25
Status: Active

---

## 목적

이 정책은 HCHAIN Core가 Claude 또는 다른 자동화 에이전트에 의해
임의로 확장·수정되지 않도록 보호한다.

HCHAIN Core는 모든 대상 프로젝트에 설치되는 기반이므로,
Core의 변경은 전체 설치 생태계에 즉각적인 영향을 미친다.

---

## 핵심 원칙

**Core는 작을수록 안전하다.**
기능 추가보다 기능 억제가 우선이다.

---

## 정책 조항

### 1. 수정 전 설계 승인 필수

HCHAIN Core 수정은 즉시 구현하지 않는다.
Core 수정 요청을 받으면 먼저 설계 문서(`docs/tasks/`)를 작성하고
사용자의 명시적 승인을 받은 후 구현한다.

### 2. 핵심 스크립트 보호

다음 파일은 사용자의 명시적 지시 없이 수정하지 않는다:

- `install.sh`
- `harness_runner.sh` (템플릿 포함)
- `queue` 관련 스크립트 (`templates/harness/queue/` 등)
- policy injection 로직

### 3. 순수 Bash 유지

`install.sh`는 순수 bash(bash 3.2+ 호환)로 유지한다.
Python, Node.js, Ruby 등 외부 런타임 의존성을 추가하지 않는다.

### 4. 금지 기능

다음 기능은 어떤 이유로도 Core에 추가하지 않는다:

- 자동 전파 (auto-propagation)
- registry
- sync-all
- 글로벌 프로젝트 스캔
- 원격 실행 트리거

### 5. 설치 대상 제한

`install.sh` 및 update 로직은 사용자가 명시한 단일 `<target>` 경로에 대해서만 수행한다.
여러 프로젝트에 동시 배포하는 기능을 Core에 내장하지 않는다.

### 6. Core 자체도 Harness Task 통해 수정

HCHAIN Core 자체를 수정할 때도 Harness Task 문서를 먼저 생성하고
작업 범위를 명시한 뒤 진행한다.

### 7. 외부 의존성 금지

Core는 다음에 의존하지 않는다:

- 특정 프로젝트 경로 (하드코딩 금지)
- API 키 또는 환경 변수 (`.env` 참조 금지)
- 네트워크 접근 (install.sh 내 curl/wget 제한)
- 런타임 상태 파일 (Core 디렉토리 내 상태 파일 금지)

모든 런타임 상태는 `<target>/.hchain/` 에만 기록된다.

### 8. 변경 범위 최소화

하나의 Task = 하나의 목적.
관련 없는 파일은 함께 수정하지 않는다.
리팩토링은 별도 Task로 분리한다.

### 9. 작업 완료 보고 형식

Core 수정 작업 완료 시 다음을 포함한 보고서를 제출한다:

- 변경 파일 목록 (`git diff --name-only`)
- 변경 이유
- 회귀 위험 평가
- Rollback 방법 (`git revert <hash>`)
- Commit Hash

---

## 적용 범위

이 정책은 다음 경로의 파일에 적용된다:

```
hchain/
├── install.sh                    ← 보호 대상
├── VERSION                       ← 보호 대상
├── scripts/                      ← 보호 대상
├── templates/harness/            ← 보호 대상
└── policies/                     ← 이 정책 문서 위치
```

`docs/` 및 `policies/`의 **문서 파일**은 이 정책의 승인 절차 없이 추가 가능하다.

---

## 위반 시 처리

정책 위반 변경이 감지된 경우:

1. 즉시 작업 중단
2. `git diff`로 변경 범위 확인
3. 사용자에게 위반 내용 보고
4. `git checkout -- <file>` 또는 `git revert`로 원복

---

## 정책 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0.0 | 2026-05-25 | 최초 제정 (TASK-HCHAIN-SAFETY-001) |
