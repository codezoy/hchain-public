# HCHAIN Branch Rename Report

**작성일:** 2026-05-25
**작업 경로:** ~/workspace/hchain
**Remote:** git@github.com:codezoy/hchain.git
**Task ID:** TASK-HCHAIN-GIT-002

---

## 1. Step 진행표

| Step | 내용 | 결과 |
|------|------|------|
| RESEARCH | 현재 브랜치 상태 재확인 | ✓ |
| ACTION-1 | archive 태그 생성 (`archive-main-v2.1.0`) | ✓ |
| ACTION-2 | 태그 push to origin | ✓ |
| ACTION-3 | GitHub Default Branch → `master` (임시) | ✓ |
| ACTION-4 | `origin/main` (legacy v2.1.0) 삭제 | ✓ |
| ACTION-5 | 로컬 `master` → `main` rename | ✓ |
| ACTION-6 | `origin main` push | ✓ |
| ACTION-7 | GitHub Default Branch → `main` (확정) | ✓ |
| ACTION-8 | `origin/master` 삭제 | ✓ |
| VALIDATE | 최종 브랜치 구조 확인 | ✓ |
| DONE | 보고서 작성 | ✓ |

---

## 2. 작업 전 브랜치 상태

| 브랜치 | Commit | 역할 |
|--------|--------|------|
| `origin/main` (GitHub Default) | `47ecdb9` | Legacy v2.1.0 (구 아키텍처) |
| `origin/master` | `aa6339a` | 현재 운영 HCHAIN Core |
| 로컬 `master` (HEAD) | `aa6339a` | origin/master 추적 |

---

## 3. 생성된 태그

| 태그 | 가리키는 Commit | 설명 |
|------|-----------------|------|
| `archive-main-v2.1.0` | `47ecdb9b02ee842a3edf05f2575f2ee81ba2cd92` | legacy origin/main 영구 보존 |

원격 확인:
```
47ecdb9b02ee842a3edf05f2575f2ee81ba2cd92	refs/tags/archive-main-v2.1.0
```

---

## 4. 삭제된 브랜치

| 브랜치 | 삭제 시점 | 사전 조건 |
|--------|-----------|-----------|
| `origin/main` | ACTION-4 | archive 태그 생성 및 Default Branch 변경 후 |
| `origin/master` | ACTION-8 | 새 `origin/main` push 및 Default Branch 확정 후 |

---

## 5. 최종 브랜치 구조

```
* main (HEAD → main, origin/main)
  └── aa6339a docs: add HCHAIN user guide
      80972c1 feat(hchain): add safe install/update with policy injection
      b2651d9 feat(hchain): add macOS bash compatibility support
      f728b60 feat: scaffold core structure and strengthen install portability
      5961d3e feat: replace Python with shell script for install
      52cd7b6 chore: add .gitignore and remove pycache from tracking
      7bd7772 feat: initialize hchain with install metadata tracking

  (별도 히스토리, 태그로 보존)
  47ecdb9 (tag: archive-main-v2.1.0) ← legacy v2.1.0 최신
```

---

## 6. GitHub Default Branch 상태

| 시점 | Default Branch |
|------|---------------|
| 작업 전 | `main` (legacy v2.1.0) |
| 임시 변경 | `master` (삭제 허용을 위해) |
| 최종 | `main` (현재 운영 HCHAIN Core) |

---

## 7. 최종 Commit Hash

| 항목 | Hash |
|------|------|
| `origin/main` (HEAD) | `aa6339a6aa9056041f638fc306a4a2c15366b5cf` |
| archive 태그 | `47ecdb9b02ee842a3edf05f2575f2ee81ba2cd92` |

---

## 8. 수행 명령 전체 로그

```bash
# RESEARCH
git fetch --all --prune
git status
git branch -a
git remote -v
git log --oneline --decorate --graph --all -20
gh repo view codezoy/hchain --json defaultBranchRef

# ACTION-1: archive 태그 생성
git tag archive-main-v2.1.0 47ecdb9b02ee842a3edf05f2575f2ee81ba2cd92

# ACTION-2: 태그 push
git push origin archive-main-v2.1.0
git ls-remote --tags origin

# ACTION-3: Default Branch 임시 변경
gh repo edit codezoy/hchain --default-branch master
gh repo view codezoy/hchain --json defaultBranchRef  # → master 확인

# ACTION-4: legacy main 삭제
git push origin --delete main

# ACTION-5: 로컬 rename
git branch -m master main

# ACTION-6: 새 main push
git push -u origin main

# ACTION-7: Default Branch 확정
gh repo edit codezoy/hchain --default-branch main
gh repo view codezoy/hchain --json defaultBranchRef  # → main 확인

# ACTION-8: origin/master 삭제
git branch -a  # 삭제 전 확인
git push origin --delete master

# VALIDATE
git fetch --all --prune
git branch -a
git log --oneline --decorate --graph --all -10
git tag
git remote show origin
```

---

*보고서 끝*
