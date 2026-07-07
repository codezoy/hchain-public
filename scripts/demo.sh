#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# HCHAIN 공식 데모 — "Mission 하나를 주면 무슨 일이 일어나는가?"
#
#   One Mission → Multiple Tasks → One Report
#
# 임시 샌드박스에 HCHAIN을 설치하고, Mission 하나가
# Contract Workflow(Planner) → Task Queue → 파이프라인 실행(Executor)
# → REVIEW/VALIDATE 게이트 → Implementation Report로
# 이어지는 전체 흐름을 실제 기능만으로 재현한다.
#
# 사용법:
#   bash scripts/demo.sh
#
# 환경변수:
#   DEMO_PAUSE    단계 사이 대기 시간(초). 기본 1. 검증 시 0.
#   DEMO_VERBOSE  1이면 태스크별 전체 파이프라인 로그를 표시. 기본 0(요약).
#   DEMO_KEEP     1이면 종료 후 샌드박스 보존. 기본 0(자동 삭제).
#
# 요구사항: bash, python3, git, jq (HCHAIN 기본 요구사항과 동일)
# 정직성: 파이프라인은 러너의 공식 --dry-run 모드로 실행된다.
#         외부 AI CLI(Codex/Gemini/Claude) 없이 동작하며,
#         모든 ✔ 표시는 실제 러너 실행 결과(exit code + DONE 배너)에 근거한다.
#         전체 로그는 샌드박스 harness/logs/에 남는다 (DEMO_KEEP=1로 확인).
# ─────────────────────────────────────────────────────────────
set -euo pipefail

HCHAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_PAUSE="${DEMO_PAUSE:-1}"
DEMO_VERBOSE="${DEMO_VERBOSE:-0}"
DEMO_KEEP="${DEMO_KEEP:-0}"

MISSION_TEXT="큐에서 실패한 아이템을 재시도하는 기능"
MISSION_NAME="QUEUE_FAILED_RETRY"

# 태스크 목록: "ID|제목"
TASKS=(
    "TASK-001|재시도 정책 계약 확정"
    "TASK-002|큐 재시도 로직 구현"
    "TASK-003|실패 처리 및 백오프 구현"
    "TASK-004|통합 테스트 및 검증"
)

# ── 색상 (tty가 아니면 비활성) ──
if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
    BOLD=""; CYAN=""; GREEN=""; YELLOW=""; DIM=""; RESET=""
fi

pause()  { sleep "$DEMO_PAUSE"; }
half()   { sleep "$(awk "BEGIN{print ${DEMO_PAUSE}/2}")"; }
banner() {
    echo
    echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo "${BOLD}${CYAN}  $1${RESET}"
    echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
}

# ── 요구사항 확인 ──
for cmd in python3 git jq; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: '$cmd' 가 필요합니다."; exit 1; }
done

# ── 샌드박스 준비 (환경 세팅 — 데모 스토리 밖) ──
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/hchain-demo.XXXXXX")"
cleanup() {
    if [[ "$DEMO_KEEP" == "1" ]]; then
        echo "${DIM}샌드박스 보존: ${SANDBOX}${RESET}"
    else
        rm -rf "$SANDBOX"
    fi
}
trap cleanup EXIT

# ══ Opening ══════════════════════════════════════════════════
banner "HCHAIN — AI 개발을 위한 워크플로우 오케스트레이션"
echo "  ${BOLD}One Mission → Multiple Tasks → One Report${RESET}"
echo "  ${DIM}계약이 먼저, 코드가 나중이다.${RESET}"
pause

echo "${DIM}  샌드박스 프로젝트 준비 중... (${SANDBOX})${RESET}"
git -C "$SANDBOX" init -q
git -C "$SANDBOX" commit --allow-empty -q -m "init"
python3 "$HCHAIN_ROOT/install.py" --target "$SANDBOX" >/dev/null
rm -f "$SANDBOX"/harness/queue/pending/TASK-TEST-* \
      "$SANDBOX"/harness/queue/pending/TASK-E2E-PLANNER-* \
      "$SANDBOX"/harness/queue/pending/TASK-HCHAIN-PLANNER-HOOK-STABILIZE-001
echo "${DIM}  준비 완료 ✔${RESET}"
half

# ══ 1. Mission 제출 ═══════════════════════════════════════════
banner "1. Mission 제출"
echo "  ${BOLD}${YELLOW}\"${MISSION_TEXT}\"${RESET}"
pause

# ══ 2. Planner — Contract Workflow ═══════════════════════════
banner "2. Planner — 계약 분석 및 초안 생성 (Contract Workflow)"
echo yes | python3 "$HCHAIN_ROOT/install.py" --target "$SANDBOX" \
    --workflow "$MISSION_TEXT" 2>&1 | sed 's/^/  /'
pause

# ══ 3. Task Queue 생성 ════════════════════════════════════════
banner "3. Mission → Task 분해 + Queue 등록"
for entry in "${TASKS[@]}"; do
    tid="${entry%%|*}"; title="${entry#*|}"
    cat > "$SANDBOX/harness/tasks/${tid}.md" <<EOF
---
task_id: ${tid}
title: ${title}
retry_limit: 3
severity_stop: MAJOR
validate:
  - "echo validate-ok"
---

## 목표
contracts/features/${MISSION_NAME}.md 계약에 따라 '${title}' 수행

## 계약 참조
- contracts/features/${MISSION_NAME}.md
EOF
    touch "$SANDBOX/harness/queue/pending/${tid}"
    echo "  ${GREEN}+${RESET} ${tid}  ${title}  ${DIM}→ queue/pending/${RESET}"
    half
done
pause

# ══ 4. Executor — 파이프라인 순차 실행 ════════════════════════
banner "4. Executor — 파이프라인 순차 실행 ${DIM}(공식 dry-run 모드)${RESET}"
echo "  ${DIM}각 태스크: PLAN → RESEARCH → ACTION → REVIEW → VALIDATE → DONE${RESET}"
echo

PASS_COUNT=0
REVIEW_COUNT=0
VALIDATE_COUNT=0
DEMO_LOG_DIR="$SANDBOX/harness/logs"

for entry in "${TASKS[@]}"; do
    tid="${entry%%|*}"; title="${entry#*|}"
    printf "  ${BOLD}▶ %s${RESET}  %s\n" "$tid" "$title"
    LOG_FILE="$DEMO_LOG_DIR/demo_${tid}.out"

    set +e
    if [[ "$DEMO_VERBOSE" == "1" ]]; then
        bash "$SANDBOX/harness/harness_runner.sh" --task "$tid" --dry-run --no-chain 2>&1 | tee "$LOG_FILE"
        rc=${PIPESTATUS[0]}
    else
        bash "$SANDBOX/harness/harness_runner.sh" --task "$tid" --dry-run --no-chain > "$LOG_FILE" 2>&1
        rc=$?
    fi
    set -e

    if [[ $rc -eq 0 ]] && grep -q "\[HARNESS\] DONE" "$LOG_FILE"; then
        PASS_COUNT=$((PASS_COUNT + 1))
        grep -q "auto-approve REVIEW"   "$LOG_FILE" && REVIEW_COUNT=$((REVIEW_COUNT + 1))
        grep -q "auto-approve VALIDATE" "$LOG_FILE" && VALIDATE_COUNT=$((VALIDATE_COUNT + 1))
        printf "    PLAN → RESEARCH → ACTION → REVIEW → VALIDATE → DONE   ${GREEN}✔ PASS${RESET}\n"
    else
        printf "    ${YELLOW}✖ FAIL (exit=%s) — 로그: %s${RESET}\n" "$rc" "$LOG_FILE"
    fi
    half
done
pause

# ══ 5. Reviewer / Validator 게이트 ════════════════════════════
banner "5. 품질 게이트"
echo "  Reviewer  (정적 감사)   : ${GREEN}${REVIEW_COUNT}/${#TASKS[@]} 통과 ✔${RESET}"
echo "  Validator (런타임 검증) : ${GREEN}${VALIDATE_COUNT}/${#TASKS[@]} 통과 ✔${RESET}"
pause

# ══ 6. Implementation Report ══════════════════════════════════
if [[ $PASS_COUNT -eq ${#TASKS[@]} ]]; then
    RESULT="PASS"; HEALTH="10/10"
else
    RESULT="FAIL"; HEALTH="$((PASS_COUNT * 10 / ${#TASKS[@]}))/10"
fi

echo
echo "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${BOLD}  IMPLEMENTATION REPORT${RESET}"
echo "${BOLD}  MISSION: ${MISSION_TEXT}${RESET}"
echo "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "  계약        : contracts/features/${MISSION_NAME}.md"
echo "  Tasks       : ${PASS_COUNT}/${#TASKS[@]} PASS"
echo "  Reviewer    : ✔  (${REVIEW_COUNT}/${#TASKS[@]})"
echo "  Validator   : ✔  (${VALIDATE_COUNT}/${#TASKS[@]})"
echo "  Health Score: ${HEALTH}"
echo "  Result      : ${GREEN}${BOLD}${RESULT}${RESET}"
echo "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "  ${GREEN}${BOLD}Mission Completed.${RESET}"
echo "  ${DIM}파이프라인은 공식 dry-run 모드로 실행됨 — 전체 로그: harness/logs/${RESET}"
echo

[[ "$RESULT" == "PASS" ]]
