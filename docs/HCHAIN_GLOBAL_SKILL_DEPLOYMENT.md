# HCHAIN Global Skill Deployment Guide

> Claude Code용 `/hchain` Skill을 Mac mini 및 N100 환경에 배포하는 표준 절차

---

## 1. 구조 (Structure)

### 1.1 Source (HCHAIN Repository)

```
hchain/
└── skills/
    └── hchain/
        ├── SKILL.md             ← Skill 진입점 (frontmatter + 지시문)
        ├── resources/           ← Skill이 참조하는 문서
        │   ├── HCHAIN_USER_GUIDE.md
        │   ├── HCHAIN_CORE_CHANGE_CONTROL_POLICY.md
        │   ├── HCHAIN_PROMPT_STYLE.md
        │   └── HCHAIN_COMMANDS.md
        ├── agents/              ← Multi-Agent Agent Loop Contract 파일
        │   ├── mission_manager_agent.md
        │   ├── planner_agent.md
        │   ├── executor_agent.md
        │   ├── reviewer_agent.md
        │   ├── validator_agent.md
        │   ├── reporter_agent.md
        │   └── escalation_guard.md
        └── templates/           ← Task 프롬프트 템플릿
            ├── task_prompt.md
            ├── core_change_task.md
            ├── update_project_task.md
            └── agent_handoff.md ← Agent 간 인계 템플릿
```

### 1.2 Destination (Claude Global Skills)

Claude Code는 세션 시작 시 아래 경로에서 Skills를 로드한다:

| 환경 | 경로 |
|------|------|
| N100 (Linux) | `~/.claude/skills/hchain/` |
| Mac mini (macOS) | `~/.claude/skills/hchain/` |

경로는 동일하다. 홈 디렉토리(`~`)가 OS별로 다를 뿐이다.

### 1.3 로드 조건

- `~/.claude/skills/hchain/SKILL.md` 파일이 존재해야 한다
- SKILL.md에 올바른 frontmatter(`name:`, `description:`)가 있어야 한다
- Claude Code 세션이 새로 시작될 때 로드된다 (기존 세션에는 반영 안 됨)

---

## 2. 설치 (Install)

### 2.1 N100 (Linux, 현재 환경)

```bash
# 1. 전제조건 확인
ls ~/.claude/skills/        # skills 디렉토리 존재 확인
ls ~/workspace/hchain/skills/hchain/   # Source 존재 확인

# 2. skills 디렉토리 생성 (없는 경우)
mkdir -p ~/.claude/skills

# 3. Skill 복사
cp -r ~/workspace/hchain/skills/hchain ~/.claude/skills/hchain

# 4. 설치 확인
ls ~/.claude/skills/hchain/
# 출력: SKILL.md  resources/  templates/

head -5 ~/.claude/skills/hchain/SKILL.md
# 출력:
# ---
# name: hchain
# description: Use this skill ...
# ---
```

### 2.2 Mac mini (macOS)

```bash
# HCHAIN 저장소 경로 (Mac mini 기준)
HCHAIN_SRC="/path/to/workspace/hchain/skills/hchain"
# 또는 클론 경로에 맞게 수정
# HCHAIN_SRC="$HOME/hchain/skills/hchain"

# 1. skills 디렉토리 생성
mkdir -p ~/.claude/skills

# 2. Skill 복사
cp -r "$HCHAIN_SRC" ~/.claude/skills/hchain

# 3. 설치 확인
ls ~/.claude/skills/hchain/
```

---

## 3. 업데이트 (Update)

### 3.1 표준 절차

```
GitHub push (HCHAIN 변경)
    ↓
git pull (각 머신)
    ↓
rsync (Source → Global Skill)
    ↓
새 Claude Code 세션 시작
    ↓
/hchain 동작 검증
```

### 3.2 N100 업데이트 명령

```bash
# 1. HCHAIN Core 업데이트
cd ~/workspace/hchain
git pull origin main

# 2. Global Skill 반영 (증분 업데이트, 삭제된 파일도 반영)
rsync -av --delete \
  ~/workspace/hchain/skills/hchain/ \
  ~/.claude/skills/hchain/

# 3. 변경 내용 확인
diff -rq \
  ~/workspace/hchain/skills/hchain/ \
  ~/.claude/skills/hchain/
# 출력이 없으면 동기화 완료
```

### 3.3 Mac mini 업데이트 명령

```bash
HCHAIN_REPO="/path/to/workspace/hchain"
# 또는: HCHAIN_REPO="$HOME/hchain"

# 1. 업데이트
cd "$HCHAIN_REPO"
git pull origin main

# 2. Skill 반영
rsync -av --delete \
  "$HCHAIN_REPO/skills/hchain/" \
  ~/.claude/skills/hchain/

# 3. 동기화 확인
diff -rq "$HCHAIN_REPO/skills/hchain/" ~/.claude/skills/hchain/
```

### 3.4 N100에 SSH로 원격 업데이트 (Mac mini에서)

```bash
ssh user@<TAILSCALE_HOST> \
  "cd ~/workspace/hchain && \
   git pull origin main && \
   rsync -av --delete skills/hchain/ ~/.claude/skills/hchain/"
```

---

## 4. 제거 (Remove)

### 4.1 Skill 제거

```bash
# Global Skill 디렉토리 삭제
rm -rf ~/.claude/skills/hchain

# 삭제 확인
ls ~/.claude/skills/hchain 2>/dev/null || echo "삭제 완료"
```

### 4.2 주의사항

- HCHAIN Core 레포(`~/workspace/hchain/`)는 영향받지 않는다
- Global Skill 제거 후 새 Claude Code 세션을 시작해야 `/hchain` 명령이 비활성화된다
- 재설치 시 2장의 설치 절차를 따른다

---

## 5. 검증 (Verify)

### 5.1 파일 레벨 검증

```bash
# Skill 파일 존재 확인
ls -la ~/.claude/skills/hchain/SKILL.md
ls -la ~/.claude/skills/hchain/resources/
ls -la ~/.claude/skills/hchain/templates/

# frontmatter 확인
head -5 ~/.claude/skills/hchain/SKILL.md
```

예상 출력:
```
---
name: hchain
description: Use this skill whenever the user starts with /hchain ...
---
```

### 5.2 Agent Loop 파일 검증

install.sh를 사용한 자동 검증:

```bash
# HCHAIN 저장소 루트에서 실행
cd /path/to/hchain
./install.sh --verify-skill
```

수동 검증 (설치된 각 파일 확인):

```bash
SKILL_DIR="$HOME/.claude/skills/hchain"

for f in \
  agents/mission_manager_agent.md \
  agents/planner_agent.md \
  agents/executor_agent.md \
  agents/reviewer_agent.md \
  agents/validator_agent.md \
  agents/reporter_agent.md \
  agents/escalation_guard.md \
  templates/agent_handoff.md
do
  if [ -f "$SKILL_DIR/$f" ]; then
    echo "✓ $f"
  else
    echo "✗ MISSING: $f"
  fi
done
```

누락 파일이 있는 경우:

```bash
./install.sh --install-skill
```

### 5.4 동기화 상태 확인

```bash
diff -rq \
  ~/workspace/hchain/skills/hchain/ \
  ~/.claude/skills/hchain/
# 출력 없음 = 동기화 완료
# 차이 존재 시 → 3장 업데이트 절차 실행
```

### 5.5 Claude Code 세션 동작 검증

새 Claude Code 세션을 시작한 뒤:

**테스트 1 — Skill 활성화 확인:**
```
/hchain 테스트: 현재 어떤 Skill이 활성화되어 있나요?
```

기대 응답: HCHAIN Skill이 로드되었다는 설명 + Harness Task 생성 방식으로 응답

**테스트 2 — Task 생성 동작 확인:**
```
/hchain README에 날짜 포맷 함수를 추가하라
```

기대 응답 구조:
```
# TASK_YYYYMMDD_NNN: ...
## Goal
## Scope (포함 / 제외)
## Done Criteria
## Steps
bash harness/harness_runner.sh --task TASK_YYYYMMDD_NNN
```

**테스트 3 — Core 변경 가드 확인:**
```
/hchain install.sh에 새 플래그를 추가하라
```

기대 응답: 직접 구현하지 않고 설계 승인 선행 필요 명시

---

## 6. Mac mini 가이드

### 6.1 전제조건

- HCHAIN 저장소가 Mac mini에 클론되어 있어야 한다
- Claude Code CLI가 설치되어 있어야 한다

### 6.2 최초 설치

```bash
# HCHAIN 저장소 경로를 환경에 맞게 설정
HCHAIN_SRC="/path/to/workspace/hchain/skills/hchain"

mkdir -p ~/.claude/skills
cp -r "$HCHAIN_SRC" ~/.claude/skills/hchain

# 확인
ls ~/.claude/skills/hchain/
```

### 6.3 업데이트

```bash
HCHAIN_REPO="/path/to/workspace/hchain"

cd "$HCHAIN_REPO"
git pull origin main

rsync -av --delete \
  "$HCHAIN_REPO/skills/hchain/" \
  ~/.claude/skills/hchain/

# 새 Claude Code 세션 시작
```

### 6.4 제거

```bash
rm -rf ~/.claude/skills/hchain
# 새 Claude Code 세션 시작
```

### 6.5 테스트

새 세션에서:
```
/hchain README 파일을 수정하라
```

기대: TASK 프롬프트 생성, 직접 구현하지 않음

---

## 7. N100 가이드

### 7.1 전제조건

- HCHAIN 저장소: `~/workspace/hchain/`
- Claude Code CLI 설치됨
- `~/.claude/skills/` 디렉토리 존재

### 7.2 최초 설치

```bash
mkdir -p ~/.claude/skills
cp -r ~/workspace/hchain/skills/hchain ~/.claude/skills/hchain

# 확인
ls ~/.claude/skills/hchain/
```

### 7.3 업데이트 (git pull 이후)

```bash
cd ~/workspace/hchain
git pull origin main

rsync -av --delete \
  ~/workspace/hchain/skills/hchain/ \
  ~/.claude/skills/hchain/

# 동기화 확인
diff -rq \
  ~/workspace/hchain/skills/hchain/ \
  ~/.claude/skills/hchain/
```

### 7.4 제거

```bash
rm -rf ~/.claude/skills/hchain
```

### 7.5 테스트

새 Claude Code 세션에서:
```
/hchain README 파일을 수정하라
```

---

## 8. 문제 해결 (Troubleshooting)

### Skill이 로드되지 않는 경우

**증상:** `/hchain` 입력 시 일반 응답이 옴 (Task 프롬프트가 아님)

**점검 순서:**

```bash
# 1. 파일 존재 확인
ls ~/.claude/skills/hchain/SKILL.md

# 2. frontmatter 확인
head -10 ~/.claude/skills/hchain/SKILL.md

# 3. 새 세션 시작했는지 확인
# Skill은 세션 시작 시 로드됨 — 기존 세션에는 반영 안 됨
```

### 소스와 설치본 불일치

**증상:** `diff` 명령이 차이를 출력함

**해결:**
```bash
rsync -av --delete \
  ~/workspace/hchain/skills/hchain/ \
  ~/.claude/skills/hchain/
```

### Claude Code CLI에서만 동작

- Skill은 **Claude Code CLI에서만** 동작한다
- claude.ai 웹 인터페이스에서는 로드되지 않는다

### rsync 명령의 trailing slash 주의

```bash
# 올바른 사용 (소스 경로 끝에 / 필요)
rsync -av --delete source/hchain/ dest/hchain/

# 잘못된 사용 (dest 안에 hchain/ 폴더가 중첩 생성됨)
rsync -av --delete source/hchain dest/hchain/
```

---

## 버전 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0.0 | 2026-05-25 | 최초 작성 (TASK-HCHAIN-SKILL-002) |
