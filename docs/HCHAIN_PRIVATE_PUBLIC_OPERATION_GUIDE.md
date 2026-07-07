# HCHAIN Private/Public 운영 가이드

이 문서는 HCHAIN을 Private 저장소(작업장)와 Public 저장소(쇼룸)로 나누어 운영하는 방법을 정의한다.

---

## 기본 원칙

- Private repo는 **작업장** — 실제 개발·실험·harness task 실행이 일어나는 곳
- Public repo는 **쇼룸** — 검증된 산출물만 보여주는 곳
- 실제 개발은 Private에서 진행한다
- 공개 가능한 산출물만 Public으로 승격(promote)한다
- Public repo에서는 직접 개발하지 않는다

---

## 저장소 구조

```text
codezoy/hchain          ← Private (작업장, origin)
codezoy/hchain-public   ← Public  (쇼룸)
```

> 참고: 원래 권장 구조는 `hchain-private` / `hchain`이었으나,
> 기존 private repo가 `hchain` 이름을 사용 중이므로 public repo는 `hchain-public`을 사용한다.

---

## Remote 구성

```text
origin  → git@github.com:codezoy/hchain.git         (private)
public  → git@github.com:codezoy/hchain-public.git  (public)
```

확인:

```bash
git remote -v
```

---

## ⚠️ 중요: History 전략

**Private repo의 git history에는 sanitize 이전 커밋(내부 IP, 개인 경로, 사용자명)이 포함되어 있다.**

따라서 **전체 history를 public에 push하는 것은 금지**한다.
Public repo에는 항상 **history 없는 스냅샷(orphan commit)** 만 push한다.

```bash
# ❌ 절대 금지 — 전체 history가 공개됨
git push public main

# ✅ 올바른 방법 — 아래 "공개 반영 흐름" 참고
```

---

## 일반 개발 흐름 (Private)

```bash
git checkout main
git pull origin main
git checkout -b feature/xxx
# 개발
git push origin feature/xxx
# PR/merge 후 main 반영
```

---

## 공개 반영 흐름 (Private → Public)

### 1. 공개 전 검증

```bash
git status

# secret scan (working tree)
# <internal-ip>, <user>는 실제 내부 IP(Tailscale 100.x.x.x)와 로컬 사용자명으로 치환해서 실행한다
grep -RIn --exclude-dir=.git --exclude-dir=.venv --exclude-dir=node_modules \
  "<internal-ip>\|<user>@\|/home/<user>\|sk-\|ANTHROPIC_API_KEY\|OPENAI_API_KEY" . || echo CLEAN

# 테스트
pytest
```

### 2. 스냅샷 생성 및 push

공개하려는 커밋(보통 `main` 최신)을 history 없는 단일 커밋으로 만들어 push한다:

```bash
# 공개 기준 커밋에서 orphan 브랜치 생성
git checkout --orphan public-snapshot main
git commit -m "release: HCHAIN public snapshot ($(git -C . describe --always main 2>/dev/null || date +%Y%m%d))"

# public main으로 push (첫 push 이후에는 --force-with-lease로 스냅샷 교체)
git push public public-snapshot:main --force-with-lease

# 로컬 정리
git checkout main
git branch -D public-snapshot
```

> Public repo의 main은 "스냅샷 교체" 방식으로 운영한다.
> Public repo에는 협업 브랜치가 없으므로 스냅샷 교체는 안전하다.
> 단, Private(origin) main에 대한 force push는 여전히 금지한다.

---

## 공개 전 체크리스트

- [ ] README 확인 (가치 제안, 링크, 배지)
- [ ] Secret Scan (working tree 기준 CLEAN)
- [ ] Demo GIF 확인 (`docs/demo/hchain-demo.gif`)
- [ ] LICENSE 확인
- [ ] CI 확인 (`.github/workflows/ci.yml`)
- [ ] 내부 경로 제거 (`/home/<user>` 등)
- [ ] 개인 사용자명 제거
- [ ] Tailscale IP 제거 (`100.x.x.x`)
- [ ] history 미포함 확인 (orphan 스냅샷인지 확인: `git log public/main --oneline` 이 1~수 개 커밋인지)

---

## 공개하면 안 되는 것

- 개인 경로 (`/home/<user>`, Obsidian vault 경로 등)
- 내부 IP (Tailscale `100.x.x.x`, 사설망 주소)
- API Key (ANTHROPIC_API_KEY, OPENAI_API_KEY, `sk-*` 등)
- 회사 정보
- 실험 중인 harness task (queue/tasks/logs 실데이터)
- private 운영 로그
- 개인 Obsidian 경로

---

## 문제 발생 시 복구

| 상황 | 조치 |
|------|------|
| 잘못된 스냅샷 push | 올바른 커밋으로 스냅샷 재생성 후 `--force-with-lease` push |
| public remote 오염 | `git remote remove public` 후 재구성 |
| 민감 정보 노출 | 즉시 `gh repo edit codezoy/hchain-public --visibility private` 전환 → 스냅샷 재생성 |
| commit 실수 | private에서는 revert 사용 (force push 금지), public에서는 스냅샷 교체 |
| secret(API key) 노출 | **토큰 즉시 rotate** → repo private 전환 → 스냅샷 재생성. rotate가 최우선이다 (repo를 지워도 이미 노출된 키는 유효하다) |

---

## 운영 규칙

- Public repo에서 직접 개발하지 않는다
- Public repo는 검증된 결과만 반영한다 (secret scan + pytest 통과 필수)
- Public repo에는 항상 history 없는 스냅샷만 push한다
- README / Demo GIF / Release Note는 public 관점에서 관리한다
- origin(private) main에 force push하지 않는다
