# TASK-HARNESS-AIVIDEO-MIGRATION-GUIDE-001: Mission Foundation Layer → ai-video 이전 가이드

**작성일**: 2026-06-02  
**대상 프로젝트**: ai-video  
**소스 저장소**: hchain  
**목적**: HCHAIN Mission Foundation Layer를 ai-video 프로젝트에 안전하게 이전하는 절차 가이드

---

## 1. 이전 전제 조건

아래 조건을 **모두** 충족한 후에만 이전을 시작한다.

| 조건 | 확인 방법 |
|------|-----------|
| hchain 저장소가 최신 commit 상태 | `git -C <hchain-repo> log --oneline -3` |
| ai-video 프로젝트에 미커밋 변경 없음 | `git -C <ai-video-repo> status` |
| ai-video 프로젝트가 원격 최신 상태 | `git -C <ai-video-repo> pull` |
| install.sh 실행 가능 | `ls -l <hchain-repo>/install.sh` |

**중요 원칙**:
- 수동 파일 복사는 절대 금지. 반드시 `install.sh` 를 통해 이전한다.
- 미커밋 변경이 있으면 먼저 `git commit` 또는 `git stash` 후 진행한다.

---

## 2. ai-video 이전 전 상태 확인 (git pull 원칙)

### 2-1. hchain 저장소 상태 확인

```bash
cd <hchain-repo>
git status
git log --oneline -5
```

예상 결과:
- `git status` → `nothing to commit, working tree clean`
- `git log` → 최신 commit에 `feat: mission foundation layer MVP` 포함 확인

### 2-2. ai-video 저장소 상태 확인 및 동기화

```bash
cd <ai-video-repo>
git status
git pull
```

- 미커밋 변경이 있으면 이전 **중단** 후 처리:
  ```bash
  # 옵션 A: 커밋
  git add -p
  git commit -m "chore: pre-migration checkpoint"

  # 옵션 B: 임시 보관
  git stash push -m "pre-hchain-migration"
  ```

**원칙**: ai-video 이전은 항상 `git pull` 이후에 시작한다. 로컬 변경이 있는 상태에서 install.sh를 실행하지 않는다.

---

## 3. install.sh 기반 HCHAIN 설치 절차

### 3-1. 신규 설치 (ai-video에 HCHAIN이 없는 경우)

```bash
cd <hchain-repo>

# 1. 설치 전 dry-run으로 변경 예정 항목 확인
./install.sh --target <ai-video-repo> --dry-run

# 2. 실제 설치
./install.sh --target <ai-video-repo>

# 3. 설치 검증
./install.sh --verify <ai-video-repo>
```

### 3-2. 업데이트 (이미 설치된 경우)

```bash
cd <hchain-repo>

# 1. 업데이트 전 dry-run
./install.sh --target <ai-video-repo> --update --dry-run

# 2. 실제 업데이트 (데이터 보존, 스크립트만 덮어씀)
./install.sh --target <ai-video-repo> --update

# 3. 업데이트 검증
./install.sh --verify <ai-video-repo>
```

### 3-3. Skill 설치 및 검증

```bash
cd <hchain-repo>

# Skill 파일을 ~/.claude/skills/hchain/ 에 설치
./install.sh --install-skill

# Skill 설치 검증
./install.sh --verify-skill
```

> `--install-skill` 은 Agent Contract, Agent Handoff, SKILL.md 등 Mission 실행에 필요한 Skill 파일을 설치한다.

---

## 4. --verify / --verify-skill 검증 절차

### 4-1. `--verify <path>` 출력 해석

```
[hchain] installed at <ai-video-repo>
  ✓ harness/scripts/mission_manager.sh (executable)
  ✓ harness/scripts/mission_step.sh (executable)
  ✓ harness/scripts/mission_loop.sh (executable)
```

- `✓` : 파일 존재 및 실행 권한 확인 → 정상
- `✗ (not executable)` : 파일은 있으나 실행 권한 없음 → `chmod +x` 필요
- `✗ (missing)` : 파일 없음 → 설치 재실행 필요

### 4-2. `--verify-skill` 출력 해석

모든 Skill 파일이 `~/.claude/skills/hchain/` 에 존재하면 정상.  
누락 파일이 있으면 `Run: ./install.sh --install-skill` 메시지 출력.

### 4-3. 검증 실패 시 처리

| 증상 | 조치 |
|------|------|
| mission_*.sh missing | `./install.sh --target <ai-video-repo>` 재실행 |
| mission_*.sh not executable | `chmod +x <ai-video-repo>/harness/scripts/mission_*.sh` |
| Skill 파일 누락 | `./install.sh --install-skill` 재실행 |
| meta.json 없음 | 설치가 중단됨 — dry-run으로 원인 확인 후 재실행 |

---

## 5. ai-video에서 Mission Foundation 파일 확인

설치 완료 후 ai-video 프로젝트에 아래 파일이 존재해야 한다.

```text
<ai-video-repo>/
├── harness/
│   ├── scripts/
│   │   ├── mission_manager.sh      ← Mission 생성/관리
│   │   ├── mission_step.sh         ← Mission 단계 실행
│   │   └── mission_loop.sh         ← Mission 자동 루프
│   └── templates/
│       ├── mission_state.json      ← Mission 상태 템플릿
│       └── mission_summary.md      ← Mission 완료 보고 템플릿
└── .hchain/
    └── meta.json                   ← 설치 메타데이터 (버전, 날짜)
```

확인 명령:

```bash
ls -la <ai-video-repo>/harness/scripts/
ls -la <ai-video-repo>/harness/templates/
cat <ai-video-repo>/.hchain/meta.json
```

---

## 6. 첫 테스트 Mission 실행 절차

**원칙**: 실제 ai-video 파이프라인을 건드리기 전에 샘플 Mission으로 먼저 검증한다.

### 6-1. 샘플 Mission 생성

```bash
cd <ai-video-repo>

# Mission 목록 확인
./harness/scripts/mission_manager.sh list

# 샘플 Mission 생성 (실제 기능 없음 — 동작 검증용)
./harness/scripts/mission_manager.sh create \
  --id TEST-MIGRATION-001 \
  --goal "Mission Foundation Layer 동작 검증"
```

### 6-2. 단계 실행 테스트

```bash
# PLAN 단계 실행
./harness/scripts/mission_step.sh \
  --mission TEST-MIGRATION-001 \
  --step PLAN

# 상태 확인
cat <ai-video-repo>/harness/missions/TEST-MIGRATION-001/mission_state.json
```

### 6-3. 검증 기준

- `mission_state.json` 이 생성되고 `status` 필드가 업데이트되면 정상
- `mission_summary.md` 가 생성되면 Mission Loop 완료 가능 상태
- 에러 없이 실행 완료 → ai-video 실제 Mission 투입 가능

---

## 7. 실패 시 롤백 방법

### 7-1. 설치 실패 (파일이 일부만 설치된 경우)

```bash
# dry-run으로 현재 상태 확인
./install.sh --target <ai-video-repo> --dry-run

# 재설치 시도
./install.sh --target <ai-video-repo>
```

### 7-2. 업데이트 실패 (기존 동작이 깨진 경우)

```bash
cd <ai-video-repo>

# git으로 harness 디렉토리를 이전 상태로 복원
git checkout HEAD -- harness/

# 복원 확인
./harness/scripts/mission_manager.sh list
```

### 7-3. stash 복원 (2-2에서 stash한 경우)

```bash
cd <ai-video-repo>
git stash pop
```

### 7-4. 완전 롤백 (harness 제거)

```bash
cd <ai-video-repo>

# harness 디렉토리 전체 제거 (데이터 삭제 주의)
rm -rf harness/
rm -rf .hchain/

# git으로 복원 가능한 경우
git checkout HEAD -- harness/
```

> 완전 제거 전에 `harness/missions/` 내 데이터를 백업한다.

---

## 8. 절대 하지 말아야 할 것

| 금지 행동 | 이유 |
|-----------|------|
| ai-video에 harness 파일 수동 복사 | 버전 불일치, 권한 오류 발생 가능 |
| harness_runner.sh 임의 수정 | Core 파일 변경은 설계 승인 필요 |
| Mission Loop부터 장시간 실행 | 단계 검증 없이 루프 실행 시 복구 불가 상태 진입 가능 |
| Token Budget / Codex Runtime / Escalation Runtime 추가 | 명시적 승인 없이 외부 런타임 의존성 추가 금지 |
| 검증 전 실제 ai-video 파이프라인 수정 | Mission Foundation 동작 미검증 상태에서 실제 작업 금지 |
| install.sh 없이 hchain 업데이트 | 수동 복사는 일관성 보장 불가 |
| ai-video에서 hchain 저장소 직접 참조 | 경로 하드코딩은 이식성 파괴 |

---

## 9. 다음 Task 제안

이전 완료 후 아래 순서로 진행을 권장한다.

### 9-1. 즉시 후속 (필수)

**TASK-HARNESS-AIVIDEO-FIRST-MISSION-001**
- 목표: ai-video 프로젝트에서 첫 실제 Mission 실행 및 검증
- 내용: 실제 ai-video 기능 1개를 대상으로 Mission 생성 → PLAN → ACTION → VALIDATE
- 전제 조건: 본 가이드의 6번 테스트 Mission 검증 완료

### 9-2. 안정화 후 진행

**TASK-HARNESS-AIVIDEO-AGENT-CONTRACT-001**
- 목표: ai-video 프로젝트 전용 Agent Contract 정의
- 내용: ai-video 특화 Role, Scope, Handoff 규칙 문서화

**TASK-HARNESS-AIVIDEO-MISSION-LOOP-001**
- 목표: ai-video Mission Loop 자동화 설정
- 전제 조건: Agent Contract 완료 후 진행

### 9-3. 장기 과제

**TASK-HARNESS-MULTI-PROJECT-SYNC-001**
- 목표: hchain → ai-video 동기화 자동화 (git hook 또는 CI)
- 내용: hchain 업데이트 시 ai-video에 자동 반영하는 메커니즘 설계

---

## Appendix: 설치 후 빠른 확인 체크리스트

```
[ ] git status <hchain-repo>     → clean
[ ] git status <ai-video-repo>   → clean
[ ] ./install.sh --verify <ai-video-repo>  → 모든 항목 ✓
[ ] ./install.sh --verify-skill            → 모든 항목 ✓
[ ] harness/scripts/mission_manager.sh  → 존재 + 실행 가능
[ ] harness/scripts/mission_step.sh     → 존재 + 실행 가능
[ ] harness/scripts/mission_loop.sh     → 존재 + 실행 가능
[ ] harness/templates/mission_state.json → 존재
[ ] harness/templates/mission_summary.md → 존재
[ ] .hchain/meta.json                    → 존재
[ ] 샘플 Mission TEST-MIGRATION-001 실행 성공
```
