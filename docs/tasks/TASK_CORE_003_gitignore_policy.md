# TASK_CORE_003 - .gitignore 정책 강화

## 목표

현재 `.gitignore`가 `.hchain/` 만을 제외하는 최소 설정으로 되어 있다.
Core 저장소를 오염시킬 수 있는 모든 파일 패턴을 사전에 차단하는 강건한
`.gitignore` 정책을 수립한다.

## 문제 배경

현재 `.gitignore` 내용:

```
.hchain/
```

이 설정만으로는 다음 오염 시나리오를 방어하지 못한다.

- 개발자가 실수로 Core 디렉토리에서 작업하다 `.env` 파일을 생성하는 경우
- `logs/`, `reports/`, `queue/` 디렉토리가 생성되는 경우
- `active_state.json`, `*.state.json`, `*.checkpoint.json` 이 생성되는 경우
- `TASK_*` 런타임 파일이 Core 루트에 생성되는 경우
- Python `__pycache__`, `*.pyc`, `venv/` 등이 생성되는 경우
- macOS `.DS_Store`, IDE `.vscode/`, `.idea/` 가 포함되는 경우

Core 저장소는 엄격하게 관리되어야 하며, `.gitignore`는 1차 방어선이다.

## 범위

`.gitignore` 파일을 다음 카테고리를 커버하도록 확장:

1. **런타임 상태 파일**: `active_state.json`, `*.state.json`, `*.checkpoint.json`
2. **로그/보고서**: `logs/`, `reports/`, `*.log`
3. **큐/작업 상태**: `queue/`, `TASK_*.json`, `TASK_*.md` (docs/tasks/ 제외)
4. **환경 파일**: `.env`, `.env.*`, `*.env`
5. **Python 빌드**: `__pycache__/`, `*.pyc`, `*.pyo`, `venv/`, `.venv/`
6. **OS/IDE**: `.DS_Store`, `.vscode/`, `.idea/`, `*.swp`, `*.swo`
7. **hchain 런타임**: `.hchain/` (기존 유지)

## 제외 범위

- `docs/tasks/*.md` 는 gitignore 하지 않는다 (Task 문서는 추적 대상)
- `templates/`, `examples/` 하위 파일은 gitignore 하지 않는다
- `VERSION`, `install.sh`, `README.md` 는 항상 추적 대상

## 실행 절차

1. `.gitignore` 파일을 위 카테고리에 맞게 확장한다.
2. `git add .gitignore` → `git commit` (chore: strengthen .gitignore policy for core contamination prevention)
3. `git status --short` 로 의도치 않은 파일이 untracked 상태로 남지 않는지 확인

## 완료 조건

- [ ] `.env` 패턴 차단
- [ ] `logs/`, `reports/`, `queue/` 패턴 차단
- [ ] `*.state.json`, `*.checkpoint.json`, `active_state.json` 패턴 차단
- [ ] `__pycache__/`, `*.pyc` 패턴 차단
- [ ] `.DS_Store`, `.vscode/`, `.idea/` 패턴 차단
- [ ] `docs/tasks/*.md` 는 여전히 추적됨 (`git status` 확인)

## 검증 방법

```bash
# 각 오염 파일을 임시 생성 후 git status 에서 untracked 로 보이지 않아야 함
touch .env && git status --short | grep ".env" && rm .env
touch active_state.json && git status --short | grep "active_state" && rm active_state.json
touch test.state.json && git status --short | grep "test.state" && rm test.state.json
mkdir -p logs && touch logs/test.log && git status --short | grep "logs" && rm -rf logs
# docs/tasks/ 는 추적되어야 함
git status --short docs/tasks/
```

## 오염 방지 규칙

- `.gitignore` 자체는 항상 추적 대상이다.
- `!docs/tasks/` 와 같은 negation 패턴으로 Task 문서가 추적되도록 명시한다.
- `.gitignore` 변경 시 반드시 검증 방법을 실행하고 결과를 커밋 메시지에 기록한다.
