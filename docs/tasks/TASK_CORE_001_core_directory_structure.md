# TASK_CORE_001 - Core 디렉토리 구조 스캐폴딩

## 목표

HCHAIN Core 명세에 정의된 허용 디렉토리 구조를 갖추고, README.md를 포함하여
Core 저장소가 자기완결적인 형태를 갖추도록 한다.

## 문제 배경

현재 Core 저장소에는 `install.sh`, `VERSION`, `.gitignore` 3개 파일만 존재한다.
Core 명세에서 허용하는 디렉토리(`scripts/`, `templates/`, `policies/`, `prompts/`, `docs/`)와
`README.md`가 모두 누락되어 있다.

이 구조 누락은 당장 오염 위험은 없지만 Core 운영 정책이 문서화·배포되지 못하는 원인이 된다.
향후 추가 기능(정책, 스크립트, 템플릿) 배치 시 위치 기준이 없으면 Core 저장소가
무질서하게 확장될 위험이 있다.

## 범위

- `docs/` 디렉토리 생성 (`.gitkeep` 포함)
- `scripts/` 디렉토리 생성 (`.gitkeep` 포함)
- `templates/` 디렉토리 생성 (`.gitkeep` 포함)
- `policies/` 디렉토리 생성 (`.gitkeep` 포함)
- `prompts/` 디렉토리 생성 (`.gitkeep` 포함)
- `README.md` 작성 (설치 방법, 구조 설명, 버전 정책 포함)

## 제외 범위

- `queue/`, `logs/`, `reports/` 생성 금지
- `examples/` 는 별도 Task(TASK_CORE_004)에서 다룬다
- 실제 스크립트·템플릿 내용 작성은 이 Task의 범위가 아님

## 실행 절차

1. 각 디렉토리를 생성하고 `.gitkeep` 파일을 추가한다.
2. `README.md`를 작성한다.
   - 프로젝트 설명
   - 설치 방법: `./install.sh <target_project_path>`
   - 디렉토리 구조 설명
   - 버전 정책 (VERSION 파일 기준)
3. `git add` → `git commit` (feat: scaffold core directory structure)

## 완료 조건

- [ ] `docs/`, `scripts/`, `templates/`, `policies/`, `prompts/` 디렉토리 존재
- [ ] `README.md` 존재 및 설치 방법 포함
- [ ] 각 디렉토리에 `.gitkeep` 또는 의미 있는 파일 존재
- [ ] `git status` 에서 오염 파일 없음

## 검증 방법

```bash
ls -la .
ls docs/ scripts/ templates/ policies/ prompts/
cat README.md
git status --short
```

## 오염 방지 규칙

- `examples/` 아래가 아닌 위치에 프로젝트 특정 예제 파일을 두지 않는다.
- `.gitkeep`만 추가하고 실제 런타임 파일은 넣지 않는다.
- `docs/tasks/` 이외 위치에 TASK_ 파일을 두지 않는다.
