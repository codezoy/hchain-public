# ai-video HCHAIN 업데이트 가이드 (install.py 기준)

> 작성 기준: HCHAIN / install.py 전환 후  
> 작성일: 2026-06-04  
> 대상 프로젝트: Mac Mini의 ai-video (예: `/path/to/workspace/ai-video`)

---

> **주의:** install.sh는 호환 wrapper이며, 신규 사용자는 install.py를 사용한다.

---

## 설치 명령 (install.py 기준)

```bash
# 신규 설치
python3 install.py --target /path/to/project

# 업데이트 (기존 데이터 보존, 코어 파일만 갱신)
python3 install.py --update --target /path/to/project

# 변경 예정 작업 미리보기 (파일 변경 없음)
python3 install.py --dry-run --target /path/to/project
python3 install.py --update --dry-run --target /path/to/project
```

---

## Mac Mini ai-video 업데이트 절차

```bash
cd /path/to/workspace/hchain
git pull origin feature/planner-feedback-mvp

python3 -m venv .venv
source .venv/bin/activate

python install.py \
  --update \
  --target /path/to/workspace/ai-video
```

> `.venv`는 선택사항이다. `python3 install.py` 는 시스템 python3만으로도 동작한다.

---

## 검증 명령

```bash
cd /path/to/workspace/ai-video

grep -c HCHAIN_POLICY_START CLAUDE.md
grep -c HCHAIN_POLICY_END CLAUDE.md

bash harness/queue/check_consistency.sh
ls -al harness/planner/
grep -n "PLANNER" harness/harness_runner.sh
```

기대 결과:

```
HCHAIN_POLICY_START = 1
HCHAIN_POLICY_END = 1
Queue consistency: PASS
```

---

## 데이터 보존 정책

업데이트 시 아래 항목은 **절대 덮어쓰지 않는다:**

| 항목 | 설명 |
|------|------|
| `harness/tasks/*.md` | 사용자 Task 파일 |
| `harness/tasks/*.state.json` | Task 상태 |
| `harness/logs/**` | 실행 로그 |
| `harness/findings/**` | 검토 결과 |
| `harness/queue/pending/**` | 대기 중인 Task |
| `harness/queue/running/**` | 실행 중인 Task |
| `harness/queue/done/**` | 완료된 Task |
| `harness/queue/blocked/**` | 블록된 Task |
| `harness/missions/**` | Mission 데이터 |
| `harness/active_state.json` | 현재 실행 상태 |

아래 항목은 업데이트 시 **갱신된다:**

- `harness/harness_runner.sh`
- `harness/lib/**`
- `harness/scripts/**`
- `harness/planner/**`
- `harness/templates/**`
- `harness/docs/**`
- `harness/queue/check_consistency.sh`

---

## CLAUDE.md 정책 블록 처리

install.py는 다음 마커로 정책 블록을 관리한다:

```
<!-- HCHAIN_POLICY_START -->
...
<!-- HCHAIN_POLICY_END -->
```

동작:
- `CLAUDE.md` 없으면 새로 생성
- 기존 블록 없으면 말미에 추가
- 기존 블록 있으면 교체
- 중복 블록 여러 개 있으면 1개로 정리
- UTF-8 유지, idempotent

---

## 롤백 방법

```bash
cd /path/to/workspace/hchain

# 특정 커밋으로 롤백
git checkout <이전_커밋_SHA> -- templates/harness/

# ai-video에 재적용
python3 install.py --update --target /path/to/workspace/ai-video
```

또는 harness 디렉토리를 직접 백업/복원:

```bash
# 백업
cp -r /path/to/workspace/ai-video/harness \
       /tmp/harness_backup_$(date +%Y%m%d)

# 복원
cp -r /tmp/harness_backup_YYYYMMDD \
       /path/to/workspace/ai-video/harness
```

---

## .venv bootstrap (선택사항)

```bash
cd /path/to/workspace/hchain
bash scripts/bootstrap_venv.sh
source .venv/bin/activate
```

---

## 주의사항

- `install.sh`는 호환 wrapper로만 유지된다 — 내부적으로 `install.py`를 호출한다
- `.venv/`는 `.gitignore`에 포함되어 있으므로 커밋되지 않는다
- 외부 패키지 의존성 없음 — 표준 라이브러리만 사용
