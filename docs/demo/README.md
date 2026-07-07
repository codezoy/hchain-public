# HCHAIN Demo Experience

HCHAIN의 전체 워크플로우를 30초 안에 보여주는 공식 데모.

> **"HCHAIN에 Mission 하나를 주면 무슨 일이 일어나는가?"**
> One Mission → Multiple Tasks → One Report

임시 샌드박스에서 **실제 기능만** 사용해 재현하며, 외부 AI CLI(Codex/Gemini/Claude) 없이 동작한다.
시나리오 설계 문서: [SCENARIO.md](SCENARIO.md)

---

## 실행

레포 루트에서:

```bash
bash scripts/demo.sh
```

요구사항: `bash`, `python3`, `git`, `jq` (HCHAIN 기본 요구사항과 동일)

### 데모 흐름

```
Opening   HCHAIN 타이틀
   ↓
Mission   "큐에서 실패한 아이템을 재시도하는 기능" 제출
   ↓
Planner   Contract Workflow — 관련 계약 선택 · 영향 범위 · 질문 · 계약 초안
   ↓
Queue     Task 4개 분해 → harness/queue/pending/ 등록
   ↓
Executor  TASK-001~004 순차 실행 (PLAN→RESEARCH→ACTION→REVIEW→VALIDATE→DONE)
   ↓
Gates     Reviewer ✔ · Validator ✔
   ↓
Report    IMPLEMENTATION REPORT — PASS · Mission Completed
```

### 환경변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `DEMO_PAUSE` | `1` | 단계 사이 대기 시간(초). GIF 녹화 시 `2`, 자동 검증 시 `0` |
| `DEMO_VERBOSE` | `0` | `1`이면 태스크별 전체 파이프라인 로그 표시 (기본은 요약) |
| `DEMO_KEEP` | `0` | `1`이면 종료 후 샌드박스 디렉터리를 보존 (로그 확인용) |

```bash
DEMO_PAUSE=0 bash scripts/demo.sh              # 빠른 검증 (대기 없음)
DEMO_VERBOSE=1 DEMO_KEEP=1 bash scripts/demo.sh # 전체 로그 + 샌드박스 보존
```

### 정직성 원칙 (No Fake)

- 데모의 모든 명령은 실제 HCHAIN 기능이다 (`install.py --workflow`, `harness_runner.sh`).
- 파이프라인은 러너의 공식 `--dry-run` 모드로 실행되며, 데모 화면과 로그에
  이를 명시한다 — 시뮬레이션임을 숨기지 않는다.
- 모든 `✔ PASS` 표시는 실제 러너 실행 결과(exit code + DONE 배너)에 근거한다.
- 실제 RESEARCH/REVIEW(Codex CLI)·ACTION(Claude) 단계는 외부 AI CLI 인증이
  필요하므로 데모에서는 dry-run으로 대체한다.

---

## GIF 재녹화 (공식 README Demo GIF)

공식 GIF는 `docs/demo/hchain-demo.gif`로 커밋되어 README에 임베드된다.
데모가 바뀌면 아래 명령으로 재생성한다 — 수동 편집 없음.

### 방법 1 — VHS (권장, 결정적 재현)

```bash
# VHS 설치: https://github.com/charmbracelet/vhs (+ ttyd, ffmpeg)
vhs docs/demo/demo.tape
# → docs/demo/hchain-demo.gif 재생성
```

`demo.tape`가 해상도·테마·폰트·타이밍을 고정하므로 누가 실행해도 같은 GIF가 나온다.
한글 렌더링을 위해 CJK 폰트(Noto Sans Mono CJK KR)가 필요하다.

### 방법 2 — asciinema + agg (대안)

```bash
asciinema rec demo.cast -c "DEMO_PAUSE=2 bash scripts/demo.sh"
agg --font-size 15 demo.cast docs/demo/hchain-demo.gif
```

### GIF 구성 (실측 약 26초)

| 구간 | 시간 | 내용 |
|------|------|------|
| Opening | 0~3초 | 명령 입력 + HCHAIN 타이틀 배너 |
| Mission → Planner | 3~10초 | Mission 제출 → Contract Workflow 분석·계약 초안 |
| Queue → Executor | 10~20초 | Task 4개 등록 → TASK-001~004 ✔ 순차 처리 |
| Gates → Report | 20~26초 | Reviewer ✔ Validator ✔ → IMPLEMENTATION REPORT · PASS |

---

## 아키텍처 다이어그램

공식 다이어그램은 [`architecture.mmd`](architecture.mmd) (Mermaid)로 관리한다.

- GitHub에서 자동 렌더링되므로 별도 이미지 export가 필요 없다.
- 텍스트 기반이라 PR diff로 변경 이력을 리뷰할 수 있다.
- README와 문서 어디든 코드블록으로 임베드해 재사용한다.
