# HCHAIN Core Install Safety Audit

**Audit Date**: 2026-05-21  
**Auditor**: Claude (HCHAIN Core Architect Role)  
**Repository**: git@github.com:codezoy/hchain.git  
**Branch**: master  
**Commit**: 5961d3e

---

## 1. 점검 목적

HCHAIN Core가 다른 프로젝트(Ubuntu, Mac mini, 임시 경로 등)에 안전하게
설치 가능한 상태인지 확인하고, Core 저장소 자체가 오염되지 않았는지 점검한다.

---

## 2. Git 상태

| 항목 | 값 |
|---|---|
| Branch | master |
| Remote | git@github.com:codezoy/hchain.git |
| Working tree | Clean (uncommitted changes 없음) |
| Untracked files | 없음 |
| 최근 커밋 | 5961d3e feat: replace Python with shell script for install |

**판정**: Git 상태 정상. Push 가능한 상태.

---

## 3. Core 오염 요소 점검 결과

### 3-1. 하드코딩 경로 / API Key / 프로젝트명 검색

```
grep -RInE "/home/|/Volumes/|itemlabs|itemlabs_v3|ai-video|personal_os|
  OPENAI_API_KEY|GEMINI_API_KEY|DATABASE_URL|REDIS_URL|POSTGRES_URL" .
```

**결과: NO_MATCHES** (완전 클린)

### 3-2. 오염 파일/디렉토리 존재 여부

```
find . -maxdepth 4 \( -name ".env" -o -name "active_state.json" -o
  -name "queue" -o -name "logs" -o -name "reports" -o -name "TASK_*" -o
  -name "*.checkpoint.json" -o -name "*.state.json" \) -print
```

**결과: (출력 없음)** — 오염 파일 전무

| Category | Result | Evidence | Risk |
|---|---|---|---|
| 절대경로 하드코딩 | PASS | grep NO_MATCHES | None |
| API Key 노출 | PASS | grep NO_MATCHES | None |
| 프로젝트명 종속 | PASS | grep NO_MATCHES | None |
| `.env` 파일 존재 | PASS | find 출력 없음 | None |
| `active_state.json` 존재 | PASS | find 출력 없음 | None |
| `queue/` 존재 | PASS | find 출력 없음 | None |
| `logs/` 존재 | PASS | find 출력 없음 | None |
| `reports/` 존재 | PASS | find 출력 없음 | None |
| `TASK_*` 런타임 파일 존재 | PASS | find 출력 없음 | None |
| `*.state.json` 존재 | PASS | find 출력 없음 | None |
| `*.checkpoint.json` 존재 | PASS | find 출력 없음 | None |

### 3-3. 현재 파일 목록

```
.git/
.gitignore   → 내용: ".hchain/" (단 1줄)
VERSION      → 내용: "0.1.0"
install.sh   → 895 bytes, 실행 권한 있음
```

---

## 4. 설치 가능성 판단

### 4-1. install.sh 구조 분석

```bash
HCHAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # 동적 경로
TARGET="$(cd "$1" && pwd)"                                     # 인자로 전달
HCHAIN_DIR="$TARGET/.hchain"                                   # 타겟 격리
```

- 절대경로 하드코딩 없음 ✅
- 타겟 경로를 인자로 수신 ✅
- 런타임을 `target/.hchain/` 에 격리 ✅
- Core 내부 상태 파일 비생성 ✅
- VERSION + git commit을 `meta.json` 에 기록 ✅

### 4-2. 주의 사항

`meta.json`에 `hchain_path` 필드가 기록됨:

```json
"hchain_path": "~/workspace/hchain"
```

이 값은 Core 자체 오염은 아니나, 타겟 프로젝트의 `meta.json`에
현재 머신의 Core 절대경로가 남는다. Core 이동 시 stale 해질 수 있다.

| Target | Result | Reason |
|---|---|---|
| Ubuntu: `~/projectA` | PASS | 절대경로 없음, 인자 기반 설치 |
| Mac mini: `/path/to/workspace/ai-video` | PASS | 동일 이유 |
| Temp: `/tmp/hchain-test-project` | PASS | 동일 이유 |

---

## 5. 발견 이슈

| Severity | Issue | File/Path | Recommended Task |
|---|---|---|---|
| LOW | `docs/`, `scripts/`, `templates/`, `policies/`, `prompts/` 디렉토리 누락 | Core root | TASK_CORE_001 |
| LOW | `README.md` 누락 | Core root | TASK_CORE_001 |
| LOW | `install.sh`의 `meta.json`에 머신 종속 `hchain_path` 기록 | install.sh | TASK_CORE_002 |
| LOW | `.gitignore`가 `.hchain/` 만 제외하는 최소 설정 | .gitignore | TASK_CORE_003 |

> **Critical / High 이슈 없음**

---

## 6. 생성한 개선 Task

| Task ID | 파일 | 내용 |
|---|---|---|
| TASK_CORE_001 | `docs/tasks/TASK_CORE_001_core_directory_structure.md` | Core 디렉토리 구조 스캐폴딩 및 README.md 작성 |
| TASK_CORE_002 | `docs/tasks/TASK_CORE_002_install_runtime_split.md` | install.sh 이식성 강화 및 --verify 옵션 추가 |
| TASK_CORE_003 | `docs/tasks/TASK_CORE_003_gitignore_policy.md` | .gitignore 오염 방지 정책 강화 |

---

## 7. Git Push 가능 여부

**가능**

변경 파일이 허용 범위 내에만 있음:

```
docs/core_install_safety_audit.md          ← 신규 생성
docs/tasks/TASK_CORE_001_*.md              ← 신규 생성
docs/tasks/TASK_CORE_002_*.md              ← 신규 생성
docs/tasks/TASK_CORE_003_*.md              ← 신규 생성
```

Core 오염 없음. `install.sh`, `VERSION`, `.gitignore` 미수정.

---

## 8. 최종 판정

**HCHAIN Core가 다른 프로젝트에 안전하게 설치 가능한 상태인지 여부: PASS**

현재 Core 저장소는:
- 하드코딩된 절대경로, API Key, 프로젝트명이 없다.
- 런타임 상태 파일(`.env`, `active_state.json`, `queue`, `logs`)이 없다.
- `install.sh`는 타겟 경로를 인자로 받아 `target/.hchain/`에만 파일을 생성한다.
- Core 저장소 자체는 설치 후에도 변경되지 않는다.

다만 구조적 미완성(디렉토리 스캐폴딩 부재, 최소 .gitignore)으로 인해
장기 운영 시 오염 위험이 있으므로 TASK_CORE_001~003 수행을 권장한다.
