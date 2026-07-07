#!/usr/bin/env bash
# mission_loop.sh — Mission Loop Runner
# Wraps mission_step.sh and repeats it until a terminal state is reached.
# Does NOT implement Agent Runtime, Codex, Token Budget, or Escalation.
#
# Usage:
#   ./mission_loop.sh show    <mission_state.json>
#   ./mission_loop.sh dry-run <mission_state.json>
#   ./mission_loop.sh run     <mission_state.json> [--max-steps N]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MISSION_STEP="${SCRIPT_DIR}/mission_step.sh"

DEFAULT_MAX_STEPS=5
HCHAIN_PLANNER_AUTO="${HCHAIN_PLANNER_AUTO:-0}"
HARNESS_AUTO_CONFIRM="${HARNESS_AUTO_CONFIRM:-0}"

# ── Dependency check ──────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
    echo "[ERROR] jq is required but not installed."
    echo "  Install: sudo apt-get install jq  OR  brew install jq"
    exit 1
fi

if [[ ! -f "$MISSION_STEP" ]]; then
    echo "[ERROR] mission_step.sh not found: ${MISSION_STEP}"
    exit 1
fi

# ── Usage ─────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage:
  $(basename "$0") show    <mission_state.json|MISSION_ID>
  $(basename "$0") dry-run <mission_state.json|MISSION_ID>
  $(basename "$0") run     <mission_state.json|MISSION_ID> [OPTIONS]

Commands:
  show      Delegate to mission_step.sh show
  dry-run   Delegate to mission_step.sh dry-run
  run       Repeatedly call mission_step.sh step until a terminal state

Options:
  --max-steps N   Maximum number of steps to run (default: ${DEFAULT_MAX_STEPS})
  --planner-auto  Enable Planner Feedback hook after PASS
                  Equivalent env var: HCHAIN_PLANNER_AUTO=1
  --auto-confirm  Bypass interactive gate confirmations
                  Equivalent env var: HARNESS_AUTO_CONFIRM=1

Note: <mission_state.json|MISSION_ID> accepts either a direct path to
      mission_state.json or a MISSION_ID (resolved to
      harness/missions/<MISSION_ID>/mission_state.json).
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
shift 2

# ── Resolve MISSION_ID → state file path ─────────────────────
# If STATE_FILE is not an existing file, try treating it as a MISSION_ID
# and look for missions/<MISSION_ID>/mission_state.json under HARNESS_DIR.
if [[ "$COMMAND" != "help" && ! -f "$STATE_FILE" ]]; then
    _candidate="${HARNESS_DIR}/missions/${STATE_FILE}/mission_state.json"
    if [[ -f "$_candidate" ]]; then
        STATE_FILE="$_candidate"
    fi
fi

# ── Validate state file ───────────────────────────────────────
if [[ "$COMMAND" != "help" ]]; then
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "[ERROR] Mission state file not found: ${STATE_FILE}"
        exit 1
    fi
    if ! jq -e . "$STATE_FILE" >/dev/null 2>&1; then
        echo "[ERROR] Invalid JSON in mission state file: ${STATE_FILE}"
        exit 1
    fi
fi

# ── Helper: validate_agent_mode ───────────────────────────────
# Reads allowed values from agent_mode_allowed_values in state file.
validate_agent_mode() {
    local mode
    mode=$(jq -r '.agent_mode // "contract"' "$STATE_FILE")
    local allowed
    allowed=$(jq -r '.agent_mode_allowed_values[]?' "$STATE_FILE" 2>/dev/null)
    if [[ -z "$allowed" ]]; then
        echo "[WARN] agent_mode_allowed_values not found in state file — cannot validate agent_mode."
        return 0
    fi
    if ! echo "$allowed" | grep -qx "$mode"; then
        echo "[ERROR] invalid agent_mode: ${mode}"
        echo "allowed:"
        while IFS= read -r v; do
            echo " - ${v}"
        done <<< "$allowed"
        exit 1
    fi
}

# ── cmd: show (delegate) ──────────────────────────────────────
cmd_show() {
    bash "$MISSION_STEP" show "$STATE_FILE"
}

# ── cmd: dry-run (delegate) ───────────────────────────────────
cmd_dry_run() {
    bash "$MISSION_STEP" dry-run "$STATE_FILE"
}

# ── cmd: run ─────────────────────────────────────────────────
cmd_run() {
    validate_agent_mode
    # Parse options
    local max_steps="$DEFAULT_MAX_STEPS"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --max-steps)
                if [[ -z "${2-}" || ! "${2-}" =~ ^[0-9]+$ ]]; then
                    echo "[ERROR] --max-steps requires a positive integer argument."
                    exit 1
                fi
                max_steps="$2"
                shift 2
                ;;
            --planner-auto)
                HCHAIN_PLANNER_AUTO=1
                shift
                ;;
            --auto-confirm)
                HARNESS_AUTO_CONFIRM=1
                shift
                ;;
            *)
                echo "[ERROR] Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Derive HCHAIN_MISSION_ID from state file if not already set
    if [[ -z "${HCHAIN_MISSION_ID:-}" ]]; then
        _mid_from_state=$(jq -r '.mission_id // ""' "$STATE_FILE" 2>/dev/null || true)
        if [[ -n "$_mid_from_state" ]]; then
            HCHAIN_MISSION_ID="$_mid_from_state"
        fi
    fi

    # Export so mission_step.sh → harness_runner.sh inherit the values
    export HCHAIN_PLANNER_AUTO HARNESS_AUTO_CONFIRM HCHAIN_MISSION_ID

    local step_count=0
    local agent_mode
    agent_mode=$(jq -r '.agent_mode // "contract"' "$STATE_FILE")

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Mission Loop Runner"
    echo "  state_file    : ${STATE_FILE}"
    echo "  max_steps     : ${max_steps}"
    echo "  planner_auto  : ${HCHAIN_PLANNER_AUTO}"
    echo "  auto_confirm  : ${HARNESS_AUTO_CONFIRM}"
    echo "  mission_id    : ${HCHAIN_MISSION_ID:-<not set>}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[MISSION] agent_mode=${agent_mode}"

    while true; do
        # ── Read current mission state ────────────────────────
        local mission_status next_task
        mission_status=$(jq -r '.mission_status // "UNKNOWN"' "$STATE_FILE")
        next_task=$(jq -r '.next_task // "null"' "$STATE_FILE")

        echo "[LOOP] step=${step_count}/${max_steps}  status=${mission_status}  next_task=${next_task}"

        # ── Stop condition: terminal mission_status ────────────
        case "$mission_status" in
            DONE)
                echo "[LOOP] Mission is DONE. Stopping."
                exit 0
                ;;
            BLOCKED)
                echo "[LOOP] Mission is BLOCKED. Manual intervention required. Stopping."
                exit 1
                ;;
            FAILED)
                echo "[LOOP] Mission is FAILED. Stopping."
                exit 1
                ;;
        esac

        # ── Stop condition: next_task is null ─────────────────
        if [[ "$next_task" == "null" || -z "$next_task" ]]; then
            echo "[LOOP] next_task is null — no more tasks to run. Stopping."
            exit 0
        fi

        # ── Stop condition: max_steps reached ─────────────────
        if [[ "$step_count" -ge "$max_steps" ]]; then
            echo "[LOOP] max_steps (${max_steps}) reached. Stopping safely."
            exit 0
        fi

        # ── Execute one step ───────────────────────────────────
        step_count=$(( step_count + 1 ))
        echo "[LOOP] Running step ${step_count}/${max_steps} — task: ${next_task}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        local step_ec=0
        bash "$MISSION_STEP" step "$STATE_FILE" || step_ec=$?

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # ── Stop condition: step exited non-zero ──────────────
        if [[ "$step_ec" -ne 0 ]]; then
            echo "[LOOP] mission_step.sh exited with code ${step_ec}. Stopping."
            exit "$step_ec"
        fi
    done
}

# ── Command dispatch ──────────────────────────────────────────
case "$COMMAND" in
    show)
        cmd_show
        ;;
    dry-run)
        cmd_dry_run
        ;;
    run)
        cmd_run "$@"
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
