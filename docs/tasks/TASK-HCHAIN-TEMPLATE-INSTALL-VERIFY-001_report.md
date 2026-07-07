# TASK-HCHAIN-TEMPLATE-INSTALL-VERIFY-001 검증 보고서

> 작성일: 2026-06-03  
> 검증자: Claude (HCHAIN Skill)  
> 대상 버전: HCHAIN v0.1.0 (commit f9fe987)

---

## 1. install/update 구조 조사 결과

| 항목 | 결과 |
|------|------|
| install.sh 존재 여부 | ✅ 존재 |
| update.sh 존재 여부 | ❌ 없음 — `install.sh --update`로 대체 |
| `--target` 옵션 지원 | ✅ 지원 (`--target <path>`) |
| `--update` 옵션 지원 | ✅ 지원 (데이터 보존 업데이트) |
| `--dry-run` 옵션 지원 | ✅ 지원 |
| 기존 harness 덮어쓰기 정책 | `--update` 시 data 보존, script만 갱신 |
| 백업 생성 여부 | ❌ 없음 — 수동 백업 필요 |
| .hchain/meta.json 생성 여부 | ✅ 생성 (version, commit, installed_at 포함) |

### 보존 대상 경로 (`--update` 시)

`_is_preserved()` 함수가 다음 경로를 보존한다:

```
active_state.json
tasks/*  (모든 task 파일 포함 _state.template.json)
logs/*
findings/*
queue/pending/*
queue/running/*
queue/done/*
queue/blocked/*
```

---

## 2. Syntax / JSON 검증 결과

| 파일 | 결과 |
|------|------|
| install.sh | ✅ OK |
| update.sh | ❌ 없음 (예상됨) |
| harness_runner.sh | ✅ OK |
| lib/findings.sh | ✅ OK |
| lib/git_checkpoint.sh | ✅ OK |
| lib/policy.sh | ✅ OK |
| lib/task_meta.sh | ✅ OK |
| scripts/mission_loop.sh | ✅ OK |
| scripts/mission_manager.sh | ✅ OK |
| scripts/mission_step.sh | ✅ OK |
| queue/check_consistency.sh | ✅ OK |
| queue/move.sh | ✅ OK |
| tasks/_state.template.json | ✅ Valid JSON |

---

## 3. 신규 설치 E2E 결과

테스트 경로: `/tmp/hchain-install-e2e-new`

| 검증 항목 | 결과 |
|-----------|------|
| harness/ 디렉토리 생성 | ✅ PASS |
| harness_runner.sh 설치 | ✅ PASS |
| tasks/_state.template.json 설치 | ✅ PASS |
| queue/check_consistency.sh 설치 | ✅ PASS |
| .hchain/meta.json 생성 | ✅ PASS |
| CLAUDE.md 정책 블록 생성 | ✅ PASS |
| lib/*.sh 설치 | ✅ PASS |
| scripts/*.sh 설치 | ✅ PASS |
| agents/*.md 설치 | ✅ PASS |

실행 명령:
```bash
bash install.sh --target /tmp/hchain-install-e2e-new
```

결과:
```
[hchain] Mode: INSTALL
[hchain] Harness installed → /tmp/hchain-install-e2e-new/harness
[hchain] done ✓  target=... version=0.1.0
```

---

## 4. 첫 Task Loop 실행 결과 (dry-run)

Task ID: `TASK_20260603_001`

| 단계 | 결과 |
|------|------|
| task.md 생성 | ✅ 수동 생성 성공 |
| queue/pending 등록 | ✅ 마커 생성 성공 |
| task.state.json 생성 (from template) | ✅ `[INFO] No state file — creating from template` |
| PLAN 단계 | ✅ 실행 |
| RESEARCH 단계 | ✅ dry-run 실행 |
| ACTION 단계 | ✅ dry-run 실행 |
| REVIEW 단계 | ✅ dry-run 실행 |
| VALIDATE | ✅ `--skip-validate`로 Skip |
| DONE | ✅ `[HARNESS] DONE task_id=TASK_20260603_001` |
| check_consistency.sh | ✅ `Queue consistency PASS (tasks: 2)` |

Flow 확인:
```
PLAN → RESEARCH → ACTION → REVIEW → [SKIP VALIDATE] → DONE
```

실행 명령:
```bash
cd /tmp/hchain-install-e2e-new/harness
HARNESS_AUTO_CONFIRM=1 bash harness_runner.sh --task TASK_20260603_001 --dry-run --skip-validate --no-chain
```

---

## 5. 기존 프로젝트 Update E2E 결과

테스트 경로: `/tmp/hchain-install-e2e-existing`

기존 데이터 구성:
- `tasks/TASK_EXISTING_001.md`
- `tasks/TASK_EXISTING_001.state.json`
- `logs/20260601_000000_ACTION_TASK_EXISTING_001.json`
- `findings/open/FINDING_001.md`
- `queue/done/TASK_EXISTING_001`

`install.sh --update` 실행 후 보존 확인:

| 보존 항목 | 결과 |
|-----------|------|
| tasks/TASK_EXISTING_001.md | ✅ 보존 |
| tasks/TASK_EXISTING_001.state.json | ✅ 보존 |
| logs/ 샘플 | ✅ 보존 |
| findings/ 샘플 | ✅ 보존 |
| queue/done/TASK_EXISTING_001 | ✅ 보존 |
| tasks/_state.template.json 존재 | ✅ 보존 (기존 파일 유지) |
| harness_runner.sh 최신화 | ✅ 동일 버전으로 갱신 |
| check_consistency.sh | ✅ PASS |

---

## 6. 발견된 문제

### [BUG-TEMPLATE-001] 데이터 파일이 템플릿에 포함됨

**심각도**: Medium

`templates/harness/` 디렉토리에 실제 Task 데이터 파일이 포함되어 있다.
모든 신규 설치에 이 파일들이 복사된다.

영향 파일:
```
templates/harness/tasks/TASK_20260525_002.md       ← 실제 task 파일
templates/harness/queue/done/TASK_20260525_002     ← 실제 queue 마커
```

결과: 신규 설치 환경에서 check_consistency.sh가 "tasks: 2"로 표시되며,
실제 빈 설치처럼 보이지 않는다.

**권장 조치**: 위 두 파일을 `templates/harness/`에서 제거

---

### [BUG-TEMPLATE-002] `_state.template.json`이 `--update` 시 갱신되지 않음

**심각도**: Low

`_is_preserved()` 함수에서 `tasks/*` 패턴이 `_state.template.json`까지 보존 대상에 포함한다.
향후 template 포맷이 변경되어도 기존 설치에 반영되지 않는다.

```bash
# _is_preserved() 현재 패턴
tasks|tasks/*)  return 0 ;;   # _state.template.json도 포함됨
```

**권장 조치**: `_state.template.json`을 보존 예외로 처리 (항상 덮어쓰기)

---

### [INFO] update.sh 별도 파일 없음

update.sh가 없고 `install.sh --update` 방식으로 동작한다.
기능적으로는 문제없으나, 사용자 가이드에서 `update.sh` 참조 시 혼동 가능성 있다.

---

## 7. 보존되어야 할 데이터 목록

install/update 시 반드시 보존되어야 하는 경로:

```
harness/tasks/*.md               # task 정의 파일
harness/tasks/*.state.json       # task 실행 상태
harness/tasks/*.recovery.json    # blocked 복구 정보
harness/logs/                    # 실행 로그
harness/findings/                # 발견 사항
harness/queue/pending/           # 대기 마커
harness/queue/running/           # 실행 중 마커
harness/queue/done/              # 완료 마커
harness/queue/blocked/           # 차단 마커
harness/active_state.json        # 현재 실행 상태
```

업데이트 대상 (항상 갱신):
```
harness/harness_runner.sh
harness/lib/*.sh
harness/scripts/*.sh
harness/queue/check_consistency.sh
harness/queue/move.sh
harness/agents/*.md
harness/tasks/_state.template.json   ← 현재는 보존됨 (BUG-002)
```

---

## 8. ai-video 적용 가능성 판단

| 항목 | 판단 |
|------|------|
| ai-video HCHAIN 설치 여부 | ❌ 미설치 |
| 신규 설치 방식 적용 가능 | ✅ 가능 |
| `--target` 옵션 적용 가능 | ✅ 가능 |
| 기존 파일 충돌 가능성 | 낮음 (harness/ 없음) |
| 실제 적용 전 백업 필요 | ✅ 권장 |

적용 명령 (백업 후):
```bash
# 백업
cp -r ~/workspace/ai_video /tmp/ai_video_backup_$(date +%Y%m%d)

# HCHAIN 신규 설치
bash ~/workspace/hchain/install.sh --target ~/workspace/ai_video
```

참고 가이드: `docs/guides/AIVIDEO_HCHAIN_UPDATE_GUIDE.md`

---

## 9. git status

```
(clean) — 변경 없음
이 보고서 파일 자체가 유일한 변경 사항
```

---

## 10. 다음 추천 Task

### TASK-HCHAIN-TEMPLATE-CLEANUP-001 (Medium Priority)
템플릿 디렉토리 정리:
- `templates/harness/tasks/TASK_20260525_002.md` 제거
- `templates/harness/queue/done/TASK_20260525_002` 제거
- `_is_preserved()`에서 `_state.template.json` 예외 처리 추가

### TASK-HCHAIN-AIVIDEO-INSTALL-001 (High Priority)
ai-video 프로젝트에 HCHAIN 신규 설치:
- 백업 생성
- `bash install.sh --target ~/workspace/ai_video` 실행
- 설치 후 검증 (check_consistency.sh)
- 첫 Task Loop dry-run 테스트
