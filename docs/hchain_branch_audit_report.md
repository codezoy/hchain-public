# HCHAIN Branch Audit Report

**작성일:** 2026-05-25
**작업 경로:** ~/workspace/hchain
**Remote:** git@github.com:codezoy/hchain.git
**감사 범위:** origin/main vs origin/master 정체 분석 및 기준 브랜치 선정

---

## 1. 브랜치 개요

| 항목 | origin/main | origin/master |
|------|-------------|---------------|
| 최신 commit | `47ecdb9` | `aa6339a` |
| 최초 commit 일시 | 2026-05-21 08:58 | 2026-05-21 15:42 |
| 최신 commit 일시 | 2026-05-21 12:34 | 2026-05-25 07:43 |
| commit 수 | 3 | 7 |
| VERSION | 2.1.0 | 0.1.0 |
| 공통 조상 | **없음 (unrelated histories)** | **없음** |
| 현재 로컬 브랜치 | ✗ | ✓ (HEAD) |

---

## 2. origin/main 정체

### 기본 정보
- **Version:** 2.1.0
- **Root commit:** `186bcda` — feat: initialize hchain central harness (2026-05-21 08:58)
- **최신 commit:** `47ecdb9` — Update harness auto-commit default (2026-05-21 12:34)

### Commit 이력
```
47ecdb9  2026-05-21 12:34  Update harness auto-commit default
f16a76b  2026-05-21 08:59  docs: add git repository guide
186bcda  2026-05-21 08:58  feat: initialize hchain central harness
```

### 파일 구조
```
installer/
  install_to_project.sh     (메인 설치 스크립트)
  update_project_harness.sh (업데이트 전용)
  verify_install.sh         (설치 검증)
templates/
  CLAUDE.md.patch
  harness/
    harness_runner.sh
    taskctl.sh              ← master에 없음
    conformance_check.sh    ← master에 없음
    watch_logs.sh           ← master에 없음
    harness_history.sh      ← master에 없음
    queue/
      check_consistency.sh  ← master에 없음
      move.sh               ← master에 없음
      pending/, running/, done/, blocked/
    logs/
    tasks/
    lib/
    agents/
    docs/
    mocks/
docs/
  architecture.md
  migration_guide.md
  git_repository.md
  migration_result.md
  git_init_report.md
VERSION
```

### 특징
- Python 시대 harness의 Shell 전환 완성형
- 분리된 installer/ 디렉토리 구조 (install/update/verify 분리)
- `HARNESS_AUTO_COMMIT` 기본값 `true` (자동 커밋 ON)
- taskctl.sh, conformance_check.sh 등 고급 제어 스크립트 포함
- CLAUDE.md.patch 방식으로 정책 주입
- 2026-05-21 당일 3개 commit 후 활동 중단

### 판정
> **구 아키텍처 (v2.x) 마지막 스냅샷.**
> 하루 만에 개발 중단. Python→Shell 전환 완료 시점의 보존 상태.

---

## 3. origin/master 정체

### 기본 정보
- **Version:** 0.1.0
- **Root commit:** `7bd7772` — feat: initialize hchain with install metadata tracking (2026-05-21 15:42)
- **최신 commit:** `aa6339a` — docs: add HCHAIN user guide (2026-05-25 07:43)

### Commit 이력
```
aa6339a  2026-05-25 07:43  docs: add HCHAIN user guide
80972c1  2026-05-25 07:20  feat(hchain): add safe install/update with policy injection
b2651d9  2026-05-24 22:52  feat(hchain): add macOS bash compatibility support
f728b60  2026-05-21 18:37  feat: scaffold core structure and strengthen install portability
5961d3e  2026-05-21 15:47  feat: replace Python with shell script for install
52cd7b6  2026-05-21 15:42  chore: add .gitignore and remove pycache from tracking
7bd7772  2026-05-21 15:42  feat: initialize hchain with install metadata tracking
```

### 파일 구조
```
install.sh                  (단일 통합 설치 스크립트)
policies/.gitkeep
prompts/.gitkeep
scripts/.gitkeep
templates/
  harness/
    harness_runner.sh
    GUIDE.md
    agents/
    docs/
    lib/
    findings/
    tasks/
README.md
VERSION
docs/
  HCHAIN_USER_GUIDE.md
  compatibility_*.md
  install_*.md
  tasks/TASK_CORE_*.md
```

### 특징
- 완전 재설계: 단일 install.sh (install/update/dry-run 모드 통합)
- 정책 블록을 CLAUDE.md에 직접 주입하는 방식
- `HARNESS_AUTO_COMMIT` 기본값 `false` (자동 커밋 OFF)
- policies/, prompts/, scripts/ 새로운 디렉토리 구조
- taskctl.sh, conformance_check.sh 등 제거 (설계 단순화)
- macOS bash 3.2 호환성 지원
- 4일간 7개 commit, 오늘(2026-05-25)까지 활성 개발 중
- .gitignore가 queue/, logs/, active_state.json 등 런타임 상태 파일 제외

### 판정
> **현재 운영 중인 HCHAIN Core.**
> main을 버리고 새로운 아키텍처(0.1.x)로 재시작. 활발히 개발 중.

---

## 4. Unrelated Histories 원인

```
origin/main root:   186bcda (2026-05-21 08:58) — 공통 조상 없음
origin/master root: 7bd7772 (2026-05-21 15:42) — 공통 조상 없음
```

**원인:** 같은 날(2026-05-21) main 브랜치를 버리고 별도의 Root commit으로 master를 새로 시작했음.
origin/main에서 fork하거나 branch한 것이 아니라 `git init` 후 새 리포지토리로 시작한 뒤 동일 remote에 push.

이로 인해 두 브랜치는 git 관점에서 완전히 별개의 히스토리를 가짐.

---

## 5. 현재 로컬 상태

```
현재 브랜치: master
추적 브랜치: origin/master
상태: 최신 (aa6339a, 작업 폴더 클린)
```

로컬 master = origin/master = HCHAIN Core Shell 기반 신버전.

로컬에 git-ignored 파일 존재 (runtime 상태, 개발 도중 생성):
- `templates/harness/queue/*` (queue/ rule)
- `templates/harness/logs/.gitkeep` (logs/ rule)
- `templates/harness/active_state.json` (active_state.json rule)

---

## 6. 기준 브랜치 선정

### 결론: **origin/master를 HCHAIN Core 기준 브랜치로 유지**

| 판단 요소 | origin/main | origin/master |
|-----------|-------------|---------------|
| 활성 개발 여부 | ✗ (중단) | ✓ (활성) |
| 최신 commit 일시 | 2026-05-21 | 2026-05-25 |
| 현재 로컬 브랜치 | ✗ | ✓ |
| 아키텍처 방향성 | 구 (2.x) | 신 (0.1.x) |
| macOS 호환성 | ✗ | ✓ |
| 단일 install.sh | ✗ | ✓ |

### origin/main 처리 방안
origin/main은 구 아키텍처의 참고용 스냅샷으로 보존 또는 archive 처리 권장.
taskctl.sh, conformance_check.sh, watch_logs.sh 등 master에 없는 스크립트는
필요 시 origin/main에서 cherry-pick 또는 수동 이식 검토 가능.

---

## 7. Merge 가능 여부

| 방법 | 가능 여부 | 위험도 | 비고 |
|------|-----------|--------|------|
| 일반 merge | ✗ | — | 공통 조상 없어 불가 |
| `--allow-unrelated-histories` | △ | 매우 높음 | 충돌 다수 예상 (VERSION, .gitignore, harness_runner.sh 등) |
| cherry-pick (선택 이식) | △ | 중간 | main의 특정 스크립트만 선별 이식 가능 |
| reset (master → main 덮어쓰기) | △ | 높음 | main 히스토리 소실 |
| 현상 유지 | ✓ | 없음 | 권장 |

### 권고
> **Merge 금지. 현상 유지.**
>
> origin/master(신)와 origin/main(구)은 아키텍처가 근본적으로 달라
> merge 시 구 스크립트(taskctl.sh, conformance_check.sh 등)와
> 신 구조(install.sh, policies/)가 충돌하여 일관성이 깨짐.
>
> main의 유용한 스크립트(taskctl.sh 등)가 필요하다면,
> **별도 Task로 master에 이식하는 방식을 권고.**

---

## 8. 최종 Commit Hash 정리

| 브랜치 | 최신 Hash | 메시지 |
|--------|-----------|--------|
| origin/main | `47ecdb9b02ee842a3edf05f2575f2ee81ba2cd92` | Update harness auto-commit default |
| origin/master (=로컬 master) | `aa6339a6aa9056041f638fc306a4a2c15366b5cf` | docs: add HCHAIN user guide |

---

*보고서 끝*
