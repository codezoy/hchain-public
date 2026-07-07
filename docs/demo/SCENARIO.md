# HCHAIN 공식 데모 시나리오

> 데모가 답해야 할 단 하나의 질문:
> **"HCHAIN에 Mission 하나를 주면 무슨 일이 일어나는가?"**

핵심 메시지: **One Mission → Multiple Tasks → One Report**
(개별 명령어 튜토리얼이 아니라, 미션 단위의 흐름을 보여준다)

---

## 스토리 구성 (20~30초)

| 구간 | 시간 | 화면 | 사용하는 실제 기능 |
|------|------|------|--------------------|
| Opening | 0~3초 | `HCHAIN — AI 개발을 위한 워크플로우 오케스트레이션` 타이틀 배너 | scripts/demo.sh 배너 |
| Mission 제출 | 3~6초 | 개발자가 Mission Contract 하나를 제출 | `install.py --workflow` (Contract Workflow) |
| Planner | 6~12초 | 관련 계약 선택 · 영향 범위 분석 → Task 4개 생성 + Queue 등록 | Contract Workflow 출력 + `harness/queue/pending/` |
| Executor | 12~20초 | Task-001 ✔ → Task-002 ✔ → Task-003 ✔ → Task-004 ✔ 순차 처리 | `harness_runner.sh --task --dry-run --no-chain` × 4 |
| Reviewer / Validator | 20~26초 | REVIEW ✔ · VALIDATE ✔ 게이트 통과 표시 | 러너 파이프라인의 REVIEW/VALIDATE 단계 결과 |
| Ending | 26~30초 | `IMPLEMENTATION REPORT — PASS · Mission Completed` 박스 | demo.sh가 실제 실행 결과(exit code)로 집계 |

---

## 정직성 원칙 (No Fake)

1. **모든 명령은 실제 HCHAIN 기능이다.**
   - Contract Workflow: `install.py --workflow` (휴리스틱 기반, 실제 계약 초안 생성)
   - Task Queue: 실제 파일시스템 큐 (`harness/queue/pending/`)
   - 파이프라인: `harness_runner.sh`의 공식 `--dry-run` 모드
2. **dry-run임을 숨기지 않는다.** 데모 화면에 `공식 dry-run 모드` 문구와
   `[DRY_RUN]` 로그가 노출되며, 전체 로그는 샌드박스 `harness/logs/`에 남는다.
3. **요약 표시는 실제 결과의 압축이다.** Task ✔ 표시는 러너의 exit code와
   DONE 배너를 근거로 하며, 스크립트가 임의로 만들어내지 않는다.
4. **인위적 애니메이션 없음.** 화면에 흐르는 것은 실제 명령 출력뿐이다.

### 데모에서 제외한 것 (사유)

- 실제 RESEARCH/REVIEW (Codex CLI) · ACTION (Claude): 외부 AI CLI 인증이 필요해
  재현성이 깨진다 → 공식 dry-run 모드로 대체
- `--chain` 모드: dry-run에서는 대상 목록만 출력하고 실행하지 않음 (러너 사양)
  → 태스크별 순차 호출로 대체 (동일한 실제 코드 경로)
- Mission Multi-Agent Loop (`mission_loop.sh`): Planner Feedback 훅 의존,
  30초 데모 범위 초과

---

## 실행 형태

```bash
bash scripts/demo.sh          # 기본 (요약 출력 — GIF 녹화용)
DEMO_VERBOSE=1 bash scripts/demo.sh   # 태스크별 전체 파이프라인 로그 표시
DEMO_PAUSE=0 bash scripts/demo.sh     # 대기 없이 (자동 검증용)
DEMO_KEEP=1 bash scripts/demo.sh      # 샌드박스 보존 (로그 확인용)
```

- 완전 재현 가능: 임시 샌드박스(mktemp)에 설치 → 실행 → 자동 정리
- 결정적 출력: 동일 시나리오 · 비대화식 · 타임스탬프/경로 외 출력 동일
- 수동 편집 불필요: 한 명령으로 전체 시퀀스 완주

## GIF 녹화 연계

- `docs/demo/demo.tape`(VHS)가 이 시나리오를 그대로 녹화한다.
- 녹화 절차: [README.md](README.md)의 "GIF 녹화" 섹션 참고.
