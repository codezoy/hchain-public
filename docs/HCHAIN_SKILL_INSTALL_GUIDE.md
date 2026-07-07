# HCHAIN Skill Install Guide

> Claude Code용 `/hchain` Skill 설치 및 배포 가이드

---

## Overview

HCHAIN Skill은 Claude Code 세션에서 `/hchain` 명령어를 사용하면 자동으로 로드되는 Skill이다.
이 Skill이 활성화되면 Claude는 직접 구현하지 않고 HCHAIN Harness Task를 생성·실행하도록 유도된다.

### Skill 위치 (Source)

```
hchain/
└── skills/
    └── hchain/
        ├── SKILL.md
        ├── resources/
        │   ├── HCHAIN_USER_GUIDE.md
        │   ├── HCHAIN_CORE_CHANGE_CONTROL_POLICY.md
        │   ├── HCHAIN_PROMPT_STYLE.md
        │   └── HCHAIN_COMMANDS.md
        └── templates/
            ├── task_prompt.md
            ├── core_change_task.md
            └── update_project_task.md
```

### Claude Code Skill 로드 위치

Claude Code는 다음 경로에서 Skills를 로드한다:

```
~/.claude/skills/<skill-name>/SKILL.md
```

따라서 이 Skill은 `~/.claude/skills/hchain/` 에 설치해야 한다.

---

## 1. Mac mini 적용 방법

### 전제조건

- HCHAIN Core가 Mac mini에 클론되어 있어야 한다
- `~/.claude/skills/` 디렉토리가 존재해야 한다

### 설치 절차

```bash
# 1. skills 디렉토리 확인/생성
mkdir -p ~/.claude/skills

# 2. HCHAIN Core에서 Skill 복사
cp -r /path/to/hchain/skills/hchain ~/.claude/skills/hchain

# 3. 설치 확인
ls ~/.claude/skills/hchain/
# 출력: SKILL.md  resources/  templates/

cat ~/.claude/skills/hchain/SKILL.md | head -5
# 출력: --- name: hchain description: Use this skill ...
```

### GitHub에서 직접 클론하는 경우

```bash
# HCHAIN Core 클론
git clone <hchain-repo-url> ~/hchain

# Skill 설치
mkdir -p ~/.claude/skills
cp -r ~/hchain/skills/hchain ~/.claude/skills/hchain
```

---

## 2. N100 적용 방법

N100 서버 (<TAILSCALE_IP>, Tailscale 네트워크)에 적용하는 방법:

### Option A: SSH를 통한 직접 복사

```bash
# Mac mini 또는 로컬에서 실행
scp -r /path/to/hchain/skills/hchain user@<TAILSCALE_IP>:~/.claude/skills/hchain
```

### Option B: N100에서 Git pull 후 복사

```bash
# N100에 SSH 접속 후
ssh user@<TAILSCALE_IP>

# HCHAIN Core 업데이트
cd /path/to/hchain
git pull origin main

# Skill 복사
mkdir -p ~/.claude/skills
cp -r /path/to/hchain/skills/hchain ~/.claude/skills/hchain

# 확인
ls ~/.claude/skills/hchain/
```

### Option C: rsync (권장 — 변경분만 전송)

```bash
rsync -av /path/to/hchain/skills/hchain/ user@<TAILSCALE_IP>:~/.claude/skills/hchain/
```

---

## 3. Skill 업데이트 방법

HCHAIN Core의 Skill 파일이 변경된 경우 재복사한다.

### 로컬 머신

```bash
# 기존 Skill 삭제 후 재복사
rm -rf ~/.claude/skills/hchain
cp -r /path/to/hchain/skills/hchain ~/.claude/skills/hchain
```

### 또는 rsync (증분 업데이트)

```bash
rsync -av --delete /path/to/hchain/skills/hchain/ ~/.claude/skills/hchain/
```

**주의:** Skill 파일은 Claude Code 세션 시작 시 로드된다.
업데이트 후에는 새 Claude Code 세션을 시작해야 적용된다.

---

## 4. GitHub push/pull 기반 배포 방법

여러 머신에 동시 배포하는 권장 워크플로우:

### 배포 절차

```bash
# 1. Mac mini (개발 머신)에서 Skill 수정
vim ~/.claude/skills/hchain/SKILL.md  # 또는 HCHAIN Core의 skills/hchain/ 수정

# 2. HCHAIN Core repo에 반영
cp -r ~/.claude/skills/hchain /path/to/hchain/skills/hchain

# 3. Git commit & push
cd /path/to/hchain
git add skills/hchain/
git commit -m "chore: update hchain skill"
git push origin main

# 4. N100에서 pull 및 재적용
ssh user@<TAILSCALE_IP>
cd /path/to/hchain
git pull origin main
rsync -av --delete skills/hchain/ ~/.claude/skills/hchain/
```

### 자동화 (선택)

N100에 cronjob 설정으로 자동 업데이트 (선택사항):

```bash
# crontab -e
0 3 * * * cd /path/to/hchain && git pull origin main && rsync -av --delete skills/hchain/ ~/.claude/skills/hchain/ >> /tmp/hchain-skill-update.log 2>&1
```

---

## 5. Claude Code 세션에서 `/hchain` 사용 방법

Skill이 설치된 후, Claude Code 세션에서:

```
/hchain [요청 내용]
```

예시:

```
/hchain API 인증 미들웨어를 JWT 기반으로 교체하라

/hchain HCHAIN Core의 install.sh에 --backup 플래그를 추가하라

/hchain [HCHAIN] ai-video 프로젝트에 HCHAIN update 적용하라
```

또는 트리거 키워드만 포함해도 Skill이 활성화된다:

```
이 기능을 하네스 Task로 만들어줘

HCHAIN으로 다음 작업을 queue에 등록해줘: ...
```

---

## 6. Skill이 실제로 로드되는지 확인하는 테스트 프롬프트

다음 프롬프트를 새 Claude Code 세션에서 입력한다:

### 테스트 1: Skill 로드 확인

```
/hchain 테스트: 현재 어떤 Skill이 활성화되어 있나요?
```

**기대 응답:** HCHAIN Skill이 로드되었고, Harness Task 생성 방식으로 응답한다는 설명

### 테스트 2: Task 생성 동작 확인

```
/hchain 다음 작업을 수행하라: src/utils.ts에 날짜 포맷 함수를 추가한다
```

**기대 응답:** 직접 코드를 작성하지 않고, 아래 구조의 Harness Task 프롬프트를 생성해야 함:
- `# TASK_YYYYMMDD_NNN: ...`
- `## Goal` 포함
- `## Scope` (포함/제외) 포함
- `## Done Criteria` 포함
- `bash harness/harness_runner.sh --task ...` 명령 포함

### 테스트 3: Core 변경 가드 확인

```
/hchain install.sh에 새 플래그를 추가하라
```

**기대 응답:** 
- 직접 구현하지 않음
- 설계 문서 작성 및 승인 선행 필요 명시
- `core_change_task.md` 템플릿 형식의 Task 프롬프트 생성

---

## Troubleshooting

### Skill이 로드되지 않는 경우

1. 파일 위치 확인:
   ```bash
   ls ~/.claude/skills/hchain/SKILL.md
   ```

2. SKILL.md frontmatter 확인:
   ```bash
   head -5 ~/.claude/skills/hchain/SKILL.md
   # 출력되어야 할 내용:
   # ---
   # name: hchain
   # description: Use this skill ...
   # ---
   ```

3. 새 Claude Code 세션 시작 (세션 재시작 필요)

### `/hchain` 입력 시 Skill이 아닌 일반 응답이 오는 경우

- Skill은 Claude Code CLI에서만 동작한다
- claude.ai 웹 인터페이스에서는 로드되지 않는다
- `~/.claude/skills/` 경로가 올바른지 확인한다

---

## 버전 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0.0 | 2026-05-25 | 최초 작성 (TASK-HCHAIN-SKILL-001) |
