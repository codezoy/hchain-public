#!/usr/bin/env bash
# mission_step.sh — Mission Step Runtime (single-step executor)
# Reads mission_state.json, runs the next task once via harness_runner.sh,
# and updates mission_state.json. Does NOT loop or auto-proceed.
#
# Usage:
#   ./mission_step.sh show    <mission_state.json>
#   ./mission_step.sh dry-run <mission_state.json>
#   ./mission_step.sh step    <mission_state.json>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MISSION_MANAGER="${SCRIPT_DIR}/mission_manager.sh"
RUNNER="${HARNESS_DIR}/harness_runner.sh"
HARNESS_STATE="${HARNESS_DIR}/active_state.json"

# ── Dependency check ──────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
    echo "[ERROR] jq is required but not installed."
    echo "  Install: sudo apt-get install jq  OR  brew install jq"
    exit 1
fi

# ── Usage ─────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage:
  $(basename "$0") show    <mission_state.json>
  $(basename "$0") dry-run <mission_state.json>
  $(basename "$0") step    <mission_state.json>

Commands:
  show      Display mission state summary
  dry-run   Show mission_status, current_task, next_task, progress_percent without executing
  step      Execute exactly ONE task from mission state, then exit
EOF
}

# ── Argument parsing ──────────────────────────────────────────
if [[ $# -ge 1 && ( "$1" == "help" || "$1" == "--help" || "$1" == "-h" ) ]]; then
    usage
    exit 0
fi

if [[ $# -lt 2 ]]; then
    echo "[ERROR] Missing arguments."
    usage
    exit 1
fi

COMMAND="$1"
STATE_FILE="$2"

# ── Validate state file ───────────────────────────────────────
if [[ ! -f "$STATE_FILE" ]]; then
    echo "[ERROR] Mission state file not found: ${STATE_FILE}"
    exit 1
fi

if ! jq -e . "$STATE_FILE" >/dev/null 2>&1; then
    echo "[ERROR] Invalid JSON in mission state file: ${STATE_FILE}"
    exit 1
fi

# ── Helper: now_iso ───────────────────────────────────────────
now_iso() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# ── Helper: atomic_write <jq_filter> ─────────────────────────
atomic_write() {
    local expr="$1"
    local tmp
    tmp=$(mktemp)
    if ! { jq "${expr}" "$STATE_FILE" > "$tmp" \
        && mv "$tmp" "$STATE_FILE" \
        && jq -e . "$STATE_FILE" >/dev/null 2>&1; }; then
        rm -f "$tmp" 2>/dev/null || true
        echo "[FATAL] atomic_write failed — state file may be corrupted: ${STATE_FILE}"
        exit 1
    fi
}

# ── cmd: show ─────────────────────────────────────────────────
cmd_show() {
    if [[ ! -f "$MISSION_MANAGER" ]]; then
        echo "[ERROR] mission_manager.sh not found: ${MISSION_MANAGER}"
        exit 1
    fi
    bash "$MISSION_MANAGER" show "$STATE_FILE"
}

# ── cmd: dry-run ──────────────────────────────────────────────
cmd_dry_run() {
    local mission_status current_task next_task progress

    mission_status=$(jq -r '.mission_status // "N/A"' "$STATE_FILE")
    current_task=$(jq -r '.current_task // "null"' "$STATE_FILE")
    next_task=$(jq -r '.next_task // "null"' "$STATE_FILE")
    progress=$(jq -r '.progress_percent // 0' "$STATE_FILE")

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Mission Step — Dry Run"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  mission_status   : ${mission_status}"
    echo "  current_task     : ${current_task}"
    echo "  next_task        : ${next_task}"
    echo "  progress_percent : ${progress}%"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ "$next_task" == "null" || -z "$next_task" ]]; then
        echo "  [DRY RUN] No next_task — step would exit with error."
    else
        echo "  [DRY RUN] Would call: harness_runner.sh --task ${next_task}"
        echo "  [DRY RUN] No changes made."
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── cmd: step ─────────────────────────────────────────────────
cmd_step() {
    # Validate dependencies
    if [[ ! -f "$RUNNER" ]]; then
        echo "[ERROR] harness_runner.sh not found: ${RUNNER}"
        exit 1
    fi
    if [[ ! -f "$MISSION_MANAGER" ]]; then
        echo "[ERROR] mission_manager.sh not found: ${MISSION_MANAGER}"
        exit 1
    fi

    # 1. Load mission state — read next_task
    local next_task
    next_task=$(jq -r '.next_task // "null"' "$STATE_FILE")

    # 2. Check next_task
    if [[ "$next_task" == "null" || -z "$next_task" ]]; then
        echo "[STEP] ERROR: No next_task in mission state — nothing to execute."
        exit 1
    fi

    local mission_id
    mission_id=$(jq -r '.mission_id // "N/A"' "$STATE_FILE")

    # Propagate HCHAIN_MISSION_ID to harness_runner.sh if not already set
    if [[ -z "${HCHAIN_MISSION_ID:-}" && "$mission_id" != "N/A" ]]; then
        export HCHAIN_MISSION_ID="$mission_id"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Mission Step — Execute"
    echo "  mission_id : ${mission_id}"
    echo "  task       : ${next_task}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 3. Set current_task and mission_status = RUNNING
    bash "$MISSION_MANAGER" set-current "$STATE_FILE" "$next_task"
    echo "[STEP] mission_state updated: current_task = ${next_task}"

    local ts
    ts=$(now_iso)
    atomic_write ".mission_status = \"RUNNING\" | .updated_at = \"${ts}\""
    echo "[STEP] mission_status = RUNNING"

    # 4. Call harness_runner.sh exactly once
    echo "[STEP] Calling: harness_runner.sh --task ${next_task}"
    local runner_ec=0
    bash "$RUNNER" --task "$next_task" || runner_ec=$?

    # 5. Check result from harness active_state.json
    local harness_result="UNKNOWN"
    if [[ -f "$HARNESS_STATE" ]]; then
        harness_result=$(jq -r '.result // "UNKNOWN"' "$HARNESS_STATE" 2>/dev/null || echo "UNKNOWN")
    fi

    echo "[STEP] runner_exit=${runner_ec} harness_result=${harness_result}"

    # 6. Update mission_state.json
    ts=$(now_iso)
    if [[ "$runner_ec" -eq 0 && "$harness_result" == "PASS" ]]; then
        # Success: mark completed, clear current_task
        bash "$MISSION_MANAGER" mark-completed "$STATE_FILE" "$next_task"
        atomic_write ".current_task = null | .updated_at = \"${ts}\""
        echo "[STEP] ✓ Task completed: ${next_task}"
    else
        # Failure: mark blocked, set mission_status = BLOCKED
        bash "$MISSION_MANAGER" mark-blocked "$STATE_FILE" "$next_task"
        atomic_write ".mission_status = \"BLOCKED\" | .current_task = null | .updated_at = \"${ts}\""
        echo "[STEP] ⛔ Task blocked: ${next_task}"
        echo "[STEP]   runner_exit=${runner_ec} harness_result=${harness_result}"
        echo "[STEP]   Mission status set to BLOCKED — manual intervention required."
    fi

    # 7. Exit — do NOT run next task automatically
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Mission Step complete. Run 'step' again to continue."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── Command dispatch ──────────────────────────────────────────
case "$COMMAND" in
    show)
        cmd_show
        ;;
    dry-run)
        cmd_dry_run
        ;;
    step)
        cmd_step
        ;;
    help|--help|-h)
        usage
        exit 0
        ;;
    *)
        echo "[ERROR] Unknown command: ${COMMAND}"
        usage
        exit 1
        ;;
esac
