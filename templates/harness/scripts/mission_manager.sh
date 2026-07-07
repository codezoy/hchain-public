#!/usr/bin/env bash
# mission_manager.sh — Mission State MVP Manager
# Manages mission_state.json: read, update, show, progress, next-task.
# Does NOT run agents, execute tasks, or move queue entries.
#
# Usage:
#   ./mission_manager.sh show            <mission_state.json>
#   ./mission_manager.sh update-progress <mission_state.json>
#   ./mission_manager.sh set-current     <mission_state.json> <TASK_ID>
#   ./mission_manager.sh set-next        <mission_state.json> <TASK_ID>
#   ./mission_manager.sh mark-completed  <mission_state.json> <TASK_ID>
#   ./mission_manager.sh mark-blocked    <mission_state.json> <TASK_ID>
#   ./mission_manager.sh dry-run         <mission_state.json>
set -euo pipefail

# ── Dependency check ─────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
    echo "[ERROR] jq is required but not installed."
    echo "  Install: sudo apt-get install jq  OR  brew install jq"
    exit 1
fi

# ── Usage ────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage:
  $(basename "$0") show            <mission_state.json>
  $(basename "$0") update-progress <mission_state.json>
  $(basename "$0") set-current     <mission_state.json> <TASK_ID>
  $(basename "$0") set-next        <mission_state.json> <TASK_ID>
  $(basename "$0") mark-completed  <mission_state.json> <TASK_ID>
  $(basename "$0") mark-blocked    <mission_state.json> <TASK_ID>
  $(basename "$0") dry-run         <mission_state.json>
EOF
}

# ── Argument parsing ─────────────────────────────────────────
if [[ $# -lt 2 ]]; then
    echo "[ERROR] Missing arguments."
    usage
    exit 1
fi

COMMAND="$1"
STATE_FILE="$2"

# Validate state file exists and is valid JSON
if [[ ! -f "$STATE_FILE" ]]; then
    echo "[ERROR] Mission state file not found: ${STATE_FILE}"
    exit 1
fi

if ! jq -e . "$STATE_FILE" >/dev/null 2>&1; then
    echo "[ERROR] Invalid JSON in state file: ${STATE_FILE}"
    exit 1
fi

# ── Helper: atomic_write <jq_filter> ────────────────────────
# Applies jq filter to STATE_FILE atomically.
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

# ── Helper: now_iso ──────────────────────────────────────────
now_iso() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# ── Helper: validate_status <value> ─────────────────────────
# Reads allowed values from mission_status_allowed_values in state file.
validate_status() {
    local candidate="$1"
    local allowed
    allowed=$(jq -r '.mission_status_allowed_values[]?' "$STATE_FILE" 2>/dev/null)
    if [[ -z "$allowed" ]]; then
        echo "[WARN] mission_status_allowed_values not found in state file — cannot validate status."
        return 0
    fi
    if ! echo "$allowed" | grep -qx "$candidate"; then
        echo "[ERROR] Invalid mission_status: '${candidate}'"
        echo "  Allowed values: $(echo "$allowed" | tr '\n' ' ')"
        exit 1
    fi
}

# ── Helper: validate_agent_mode ─────────────────────────────
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

# ── Helper: calc_progress ────────────────────────────────────
# Returns progress_percent integer based on:
#   1. task_batch length (preferred)
#   2. success_criteria length (fallback)
#   3. existing value (fallback with warning)
calc_progress() {
    local completed_count
    completed_count=$(jq '.completed_tasks | length' "$STATE_FILE" 2>/dev/null || echo "0")

    # Priority 1: task_batch
    local total_batch
    total_batch=$(jq '.task_batch | length' "$STATE_FILE" 2>/dev/null || echo "0")
    if [[ "$total_batch" -gt 0 ]]; then
        echo $(( completed_count * 100 / total_batch ))
        return 0
    fi

    # Priority 2: success_criteria
    local total_criteria
    total_criteria=$(jq '.success_criteria | length' "$STATE_FILE" 2>/dev/null || echo "0")
    if [[ "$total_criteria" -gt 0 ]]; then
        echo "[WARN] task_batch not found — using success_criteria length (${total_criteria}) as total." >&2
        echo $(( completed_count * 100 / total_criteria ))
        return 0
    fi

    # Priority 3: keep existing value
    local existing
    existing=$(jq -r '.progress_percent // 0' "$STATE_FILE" 2>/dev/null || echo "0")
    echo "[WARN] Cannot calculate progress — no task_batch or success_criteria found. Keeping existing value: ${existing}%." >&2
    echo "$existing"
}

# ── cmd: show ────────────────────────────────────────────────
cmd_show() {
    validate_agent_mode
    local mission_id mission_goal mission_status current_task next_task
    local progress completed blocked agent_mode

    mission_id=$(jq -r '.mission_id // "N/A"' "$STATE_FILE")
    mission_goal=$(jq -r '.mission_goal // "N/A"' "$STATE_FILE")
    mission_status=$(jq -r '.mission_status // "N/A"' "$STATE_FILE")
    current_task=$(jq -r '.current_task // "null"' "$STATE_FILE")
    next_task=$(jq -r '.next_task // "null"' "$STATE_FILE")
    progress=$(jq -r '.progress_percent // 0' "$STATE_FILE")
    completed=$(jq -r '.completed_tasks | length' "$STATE_FILE" 2>/dev/null || echo "0")
    blocked=$(jq -r '.blocked_tasks | length' "$STATE_FILE" 2>/dev/null || echo "0")
    agent_mode=$(jq -r '.agent_mode // "contract"' "$STATE_FILE")

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Mission Manager — Status Report"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  mission_id     : ${mission_id}"
    echo "  mission_status : ${mission_status}"
    echo "  agent_mode     : ${agent_mode}"
    echo "  progress       : ${progress}%"
    echo "  current_task   : ${current_task}"
    echo "  next_task      : ${next_task}"
    echo "  completed_tasks: ${completed}"
    echo "  blocked_tasks  : ${blocked}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Goal:"
    echo "    ${mission_goal}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Show completed tasks list
    local completed_list
    completed_list=$(jq -r '.completed_tasks[]?' "$STATE_FILE" 2>/dev/null)
    if [[ -n "$completed_list" ]]; then
        echo "  Completed tasks:"
        while IFS= read -r t; do
            echo "    ✓ ${t}"
        done <<< "$completed_list"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    # Show blocked tasks list
    local blocked_list
    blocked_list=$(jq -r '.blocked_tasks[]?' "$STATE_FILE" 2>/dev/null)
    if [[ -n "$blocked_list" ]]; then
        echo "  Blocked tasks:"
        while IFS= read -r t; do
            echo "    ⛔ ${t}"
        done <<< "$blocked_list"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
}

# ── cmd: update-progress ────────────────────────────────────
cmd_update_progress() {
    local new_progress
    new_progress=$(calc_progress)
    local ts
    ts=$(now_iso)
    atomic_write ".progress_percent = ${new_progress} | .updated_at = \"${ts}\""
    echo "[update-progress] progress_percent = ${new_progress}%"
}

# ── cmd: set-current ────────────────────────────────────────
cmd_set_current() {
    local task_id="${3:-}"
    if [[ -z "$task_id" ]]; then
        echo "[ERROR] set-current requires <TASK_ID>"
        usage; exit 1
    fi
    local ts
    ts=$(now_iso)
    atomic_write ".current_task = \"${task_id}\" | .updated_at = \"${ts}\""
    echo "[set-current] current_task = ${task_id}"
}

# ── cmd: set-next ────────────────────────────────────────────
cmd_set_next() {
    local task_id="${3:-}"
    if [[ -z "$task_id" ]]; then
        echo "[ERROR] set-next requires <TASK_ID>"
        usage; exit 1
    fi
    local ts
    ts=$(now_iso)
    atomic_write ".next_task = \"${task_id}\" | .updated_at = \"${ts}\""
    echo "[set-next] next_task = ${task_id}"
}

# ── cmd: mark-completed ─────────────────────────────────────
cmd_mark_completed() {
    local task_id="${3:-}"
    if [[ -z "$task_id" ]]; then
        echo "[ERROR] mark-completed requires <TASK_ID>"
        usage; exit 1
    fi

    # Idempotent: skip if already in completed_tasks
    local already
    already=$(jq --arg t "$task_id" '.completed_tasks | index($t)' "$STATE_FILE" 2>/dev/null || echo "null")
    if [[ "$already" != "null" ]]; then
        echo "[mark-completed] ${task_id} already in completed_tasks — no change."
        return 0
    fi

    # Remove from blocked_tasks if present, add to completed_tasks.
    # Compute progress after adding the task (new_count = current + 1).
    local ts
    ts=$(now_iso)

    # Determine total for progress denominator (task_batch > success_criteria > warn)
    local total_batch total_criteria total_warn
    total_batch=$(jq '.task_batch | length' "$STATE_FILE" 2>/dev/null || echo "0")
    total_criteria=$(jq '.success_criteria | length' "$STATE_FILE" 2>/dev/null || echo "0")
    total_warn=false

    local total
    if [[ "$total_batch" -gt 0 ]]; then
        total="$total_batch"
    elif [[ "$total_criteria" -gt 0 ]]; then
        total="$total_criteria"
        total_warn=true
    else
        total=0
    fi

    local new_progress
    if [[ "$total" -gt 0 ]]; then
        local new_count
        new_count=$(( $(jq '.completed_tasks | length' "$STATE_FILE") + 1 ))
        new_progress=$(( new_count * 100 / total ))
        [[ "$total_warn" == "true" ]] && echo "[WARN] task_batch not found — using success_criteria length (${total}) as total." >&2
    else
        new_progress=$(jq -r '.progress_percent // 0' "$STATE_FILE")
        echo "[WARN] Cannot calculate progress — no task_batch or success_criteria. Keeping existing value: ${new_progress}%." >&2
    fi

    atomic_write "
        .completed_tasks += [\"${task_id}\"]
        | .blocked_tasks = [.blocked_tasks[]? | select(. != \"${task_id}\")]
        | .progress_percent = ${new_progress}
        | .updated_at = \"${ts}\"
    "
    echo "[mark-completed] ${task_id} → completed_tasks (progress: ${new_progress}%)"
}

# ── cmd: mark-blocked ───────────────────────────────────────
cmd_mark_blocked() {
    local task_id="${3:-}"
    if [[ -z "$task_id" ]]; then
        echo "[ERROR] mark-blocked requires <TASK_ID>"
        usage; exit 1
    fi

    # Idempotent: skip if already in blocked_tasks
    local already
    already=$(jq --arg t "$task_id" '.blocked_tasks | index($t)' "$STATE_FILE" 2>/dev/null || echo "null")
    if [[ "$already" != "null" ]]; then
        echo "[mark-blocked] ${task_id} already in blocked_tasks — no change."
        return 0
    fi

    local ts
    ts=$(now_iso)
    atomic_write "
        .blocked_tasks += [\"${task_id}\"]
        | .updated_at = \"${ts}\"
    "
    echo "[mark-blocked] ${task_id} → blocked_tasks"
}

# ── cmd: dry-run ─────────────────────────────────────────────
cmd_dry_run() {
    validate_agent_mode
    local mission_id mission_goal mission_status current_task next_task progress
    local max_ctx max_sum report_ret codex_enabled

    mission_id=$(jq -r '.mission_id // "N/A"' "$STATE_FILE")
    mission_goal=$(jq -r '.mission_goal // "N/A"' "$STATE_FILE")
    mission_status=$(jq -r '.mission_status // "N/A"' "$STATE_FILE")
    current_task=$(jq -r '.current_task // "null"' "$STATE_FILE")
    next_task=$(jq -r '.next_task // "null"' "$STATE_FILE")
    progress=$(jq -r '.progress_percent // 0' "$STATE_FILE")
    max_ctx=$(jq -r '.token_budget.max_context_tasks // "N/A"' "$STATE_FILE")
    max_sum=$(jq -r '.token_budget.max_summary_size_kb // "N/A"' "$STATE_FILE")
    report_ret=$(jq -r '.token_budget.report_retention_count // "N/A"' "$STATE_FILE")
    codex_enabled=$(jq -r '.codex_enabled // false' "$STATE_FILE")
    local agent_mode
    agent_mode=$(jq -r '.agent_mode // "contract"' "$STATE_FILE")

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Mission Manager — Dry Run"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  [Mission]"
    echo "  mission_id       : ${mission_id}"
    echo "  mission_goal     : ${mission_goal}"
    echo "  mission_status   : ${mission_status}"
    echo "  current_task     : ${current_task}"
    echo "  next_task        : ${next_task}"
    echo "  progress_percent : ${progress}%"
    echo ""
    echo "  [Token Budget]"
    echo "  max_context_tasks    : ${max_ctx}"
    echo "  max_summary_size_kb  : ${max_sum}"
    echo "  report_retention_count: ${report_ret}"
    echo ""
    echo "  [Runtime]"
    echo "  agent_mode       : ${agent_mode}"
    echo "  codex_enabled    : ${codex_enabled}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  [Dry Run — No changes made]"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── Command dispatch ─────────────────────────────────────────
case "$COMMAND" in
    show)
        cmd_show
        ;;
    update-progress)
        cmd_update_progress
        ;;
    set-current)
        cmd_set_current "$@"
        ;;
    set-next)
        cmd_set_next "$@"
        ;;
    mark-completed)
        cmd_mark_completed "$@"
        ;;
    mark-blocked)
        cmd_mark_blocked "$@"
        ;;
    dry-run)
        cmd_dry_run
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
