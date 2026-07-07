#!/usr/bin/env bash
# planner_feedback.sh — Planner Feedback Flow (MVP)
# Reads Mission Report Planner Feed, creates Tasks, registers in Queue,
# and updates mission_state.json.
#
# Usage:
#   planner_feedback.sh <MISSION_ID> <TASK_ID>
#
# Example:
#   planner_feedback.sh MISSION-AI-VIDEO-VISUAL-AUDIT-001 TASK-006

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── Dependency check ───────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
    echo "[ERROR] jq is required but not installed."
    echo "  Install: sudo apt-get install jq  OR  brew install jq"
    exit 1
fi

# ── Usage ──────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
Usage:
  planner_feedback.sh <MISSION_ID> <TASK_ID>

Arguments:
  MISSION_ID   Mission identifier (e.g., MISSION-AI-VIDEO-VISUAL-AUDIT-001)
  TASK_ID      Completed task identifier whose report to read (e.g., TASK-006)

The script reads the Planner Feed from:
  1. harness/missions/<MISSION_ID>/tasks/<TASK_ID>_report.md  (primary)
  2. harness/missions/<MISSION_ID>/tasks/*_report.md           (fallback: any with feed)
  3. harness/missions/<MISSION_ID>/mission_summary.md          (fallback)

Feed format (inside ## Next Tasks (Planner Feed) section):
  TASK_ID|PRIORITY|DESCRIPTION
  TASK_ID|HIGH|Task description
  MISSION_COMPLETE   (signals mission is done)
EOF
}

if [[ $# -ge 1 && ( "$1" == "help" || "$1" == "--help" || "$1" == "-h" ) ]]; then
    usage
    exit 0
fi

if [[ $# -lt 2 ]]; then
    echo "[ERROR] Missing arguments."
    usage
    exit 1
fi

MISSION_ID="$1"
TASK_ID="$2"

MISSION_DIR="${HARNESS_DIR}/missions/${MISSION_ID}"
MISSION_STATE="${MISSION_DIR}/mission_state.json"
TASKS_DIR="${HARNESS_DIR}/tasks"
QUEUE_PENDING="${HARNESS_DIR}/queue/pending"
QUEUE_RUNNING="${HARNESS_DIR}/queue/running"
QUEUE_DONE="${HARNESS_DIR}/queue/done"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Planner Feedback Flow"
echo "  MISSION_ID : ${MISSION_ID}"
echo "  TASK_ID    : ${TASK_ID}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Helper: now_iso ────────────────────────────────────────────
now_iso() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# ── Helper: atomic_write_state <jq_filter> ────────────────────
atomic_write_state() {
    local expr="$1"
    local tmp
    tmp=$(mktemp)
    if ! { jq "${expr}" "$MISSION_STATE" > "$tmp" \
        && mv "$tmp" "$MISSION_STATE" \
        && jq -e . "$MISSION_STATE" >/dev/null 2>&1; }; then
        rm -f "$tmp" 2>/dev/null || true
        echo "[FATAL] atomic_write_state failed — state file may be corrupted"
        exit 1
    fi
}

# ── STEP-1: Locate Mission Report ──────────────────────────────
echo ""
echo "[STEP-1] Locating report file..."

REPORT_FILE=""

# Primary: task-specific report
TASK_REPORT="${MISSION_DIR}/tasks/${TASK_ID}_report.md"
if [[ -f "$TASK_REPORT" ]]; then
    REPORT_FILE="$TASK_REPORT"
    echo "  Found: ${TASK_REPORT}"
fi

# Fallback: any report in tasks/ directory that contains the Planner Feed section
if [[ -z "$REPORT_FILE" && -d "${MISSION_DIR}/tasks" ]]; then
    while IFS= read -r -d '' f; do
        if grep -q "## Next Tasks (Planner Feed)" "$f" 2>/dev/null; then
            REPORT_FILE="$f"
            echo "  Found report with Planner Feed: ${f}"
            break
        fi
    done < <(find "${MISSION_DIR}/tasks" -name "*_report.md" -print0 2>/dev/null | sort -z)
fi

# Fallback: mission_summary.md
if [[ -z "$REPORT_FILE" && -f "${MISSION_DIR}/mission_summary.md" ]]; then
    if grep -q "## Next Tasks (Planner Feed)" "${MISSION_DIR}/mission_summary.md" 2>/dev/null; then
        REPORT_FILE="${MISSION_DIR}/mission_summary.md"
        echo "  Found Planner Feed in: mission_summary.md"
    fi
fi

if [[ -z "$REPORT_FILE" ]]; then
    echo "[ERROR] No report file found for MISSION_ID=${MISSION_ID} TASK_ID=${TASK_ID}"
    exit 1
fi

# ── STEP-1.5: Idempotency check ────────────────────────────────
REPORT_BASENAME=$(basename "$REPORT_FILE")

if [[ -f "$MISSION_STATE" ]]; then
    LAST_PROCESSED=$(jq -r '.last_processed_report // ""' "$MISSION_STATE" 2>/dev/null || true)
    if [[ -n "$LAST_PROCESSED" && "$LAST_PROCESSED" == "$REPORT_BASENAME" ]]; then
        echo "[INFO] Already processed: ${REPORT_BASENAME} — skip (idempotent)"
        exit 0
    fi
fi

# ── STEP-2: Extract Planner Feed section ───────────────────────
echo ""
echo "[STEP-2] Extracting '## Next Tasks (Planner Feed)' section..."

# Extract lines between the section header and the next ## header (or EOF)
FEED_CONTENT=$(
    awk '/^## Next Tasks \(Planner Feed\)/{found=1; next}
         found && /^## /{exit}
         found{print}' "$REPORT_FILE" \
    | grep -v '^[[:space:]]*$' || true
)

if [[ -z "$FEED_CONTENT" ]]; then
    echo "  [WARNING] '## Next Tasks (Planner Feed)' section is empty or not found"
    echo "  Setting mission_status=BLOCKED"
    if [[ -f "$MISSION_STATE" ]]; then
        TS=$(now_iso)
        atomic_write_state ".mission_status = \"BLOCKED\" | .updated_at = \"${TS}\""
        echo "  mission_status = BLOCKED"
    fi
    exit 0
fi

echo "  Feed section extracted ($(echo "$FEED_CONTENT" | wc -l | xargs) lines)"

# ── STEP-4: MISSION_COMPLETE check (before parsing) ────────────
echo ""
echo "[STEP-4] Checking for MISSION_COMPLETE..."

if echo "$FEED_CONTENT" | grep -q "^MISSION_COMPLETE[[:space:]]*$"; then
    echo "  MISSION_COMPLETE detected"
    if [[ -f "$MISSION_STATE" ]]; then
        TS=$(now_iso)
        atomic_write_state ".mission_status = \"DONE\" | .updated_at = \"${TS}\""
        echo "  mission_status = DONE"
    fi
    echo "  Mission complete. No tasks will be created."
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

echo "  No MISSION_COMPLETE signal."

# ── STEP-3: Parse Feed lines ───────────────────────────────────
echo ""
echo "[STEP-3] Parsing Planner Feed (TASK_ID|PRIORITY|DESCRIPTION)..."

# Use temp file to avoid subshell scope issues
TMPFILE=$(mktemp)
echo "$FEED_CONTENT" > "$TMPFILE"

HIGH_TASKS=()
MEDIUM_TASKS=()
LOW_TASKS=()
PARSE_ERRORS=0

while IFS='|' read -r raw_tid raw_priority raw_desc || [[ -n "$raw_tid" ]]; do
    TID=$(echo "$raw_tid" | tr -d '[:space:]')
    PRIORITY=$(echo "$raw_priority" | tr -d '[:space:]')
    DESC=$(echo "$raw_desc" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    # Skip empty lines, comments, and MISSION_COMPLETE (already handled)
    [[ -z "$TID" ]] && continue
    [[ "$TID" == \#* ]] && continue
    [[ "$TID" == "MISSION_COMPLETE" ]] && continue
    # Skip lines without the pipe separator (not valid task format)
    [[ -z "$PRIORITY" ]] && continue

    case "$PRIORITY" in
        HIGH)   HIGH_TASKS+=("${TID}|||${DESC}") ;;
        MEDIUM) MEDIUM_TASKS+=("${TID}|||${DESC}") ;;
        LOW)    LOW_TASKS+=("${TID}|||${DESC}") ;;
        *)
            echo "  [WARN] Unknown priority '${PRIORITY}' for '${TID}' — skipping"
            PARSE_ERRORS=$((PARSE_ERRORS + 1))
            ;;
    esac
done < "$TMPFILE"
rm -f "$TMPFILE"

# Combine in priority order: HIGH → MEDIUM → LOW
ORDERED_TASKS=()
for t in "${HIGH_TASKS[@]+"${HIGH_TASKS[@]}"}"; do ORDERED_TASKS+=("$t"); done
for t in "${MEDIUM_TASKS[@]+"${MEDIUM_TASKS[@]}"}"; do ORDERED_TASKS+=("$t"); done
for t in "${LOW_TASKS[@]+"${LOW_TASKS[@]}"}"; do ORDERED_TASKS+=("$t"); done

echo "  Parsed: ${#HIGH_TASKS[@]} HIGH | ${#MEDIUM_TASKS[@]} MEDIUM | ${#LOW_TASKS[@]} LOW"
echo "  Total valid: ${#ORDERED_TASKS[@]} | Parse errors: ${PARSE_ERRORS}"

if [[ ${#ORDERED_TASKS[@]} -eq 0 ]]; then
    echo ""
    echo "  [WARNING] No valid tasks parsed from Feed — setting mission_status=BLOCKED"
    if [[ -f "$MISSION_STATE" ]]; then
        TS=$(now_iso)
        atomic_write_state ".mission_status = \"BLOCKED\" | .updated_at = \"${TS}\""
        echo "  mission_status = BLOCKED"
    fi
    exit 0
fi

# ── Process each task ──────────────────────────────────────────
FIRST_NEW_TASK=""
CREATED_COUNT=0
SKIPPED_COUNT=0

for entry in "${ORDERED_TASKS[@]}"; do
    NEW_TASK_ID="${entry%%|||*}"
    NEW_TASK_DESC="${entry##*|||}"

    echo ""
    echo "  ── ${NEW_TASK_ID}"
    echo "     ${NEW_TASK_DESC}"

    # ── STEP-5: Duplicate check ────────────────────────────────
    TASK_FILE="${TASKS_DIR}/${NEW_TASK_ID}.md"
    PENDING_MARKER="${QUEUE_PENDING}/${NEW_TASK_ID}"
    RUNNING_MARKER="${QUEUE_RUNNING}/${NEW_TASK_ID}"
    DONE_MARKER="${QUEUE_DONE}/${NEW_TASK_ID}"

    if [[ -f "$TASK_FILE" || -e "$PENDING_MARKER" || -e "$RUNNING_MARKER" || -e "$DONE_MARKER" ]]; then
        echo "     [STEP-5] SKIP — already exists"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi

    # ── STEP-6: Create Task file ───────────────────────────────
    echo "     [STEP-6] Creating task file..."
    mkdir -p "$TASKS_DIR"

    CREATED_AT=$(now_iso)
    cat > "$TASK_FILE" <<TASKEOF
# ${NEW_TASK_ID}

## Goal

${NEW_TASK_DESC}

## Source

- Mission: ${MISSION_ID}
- Planner Feed: ${REPORT_FILE}
- Trigger Task: ${TASK_ID}
- Created: ${CREATED_AT}

## Scope

포함:
- (Planner Feed에서 자동 생성됨)

제외:
- (해당 없음)

## Done Criteria

- [ ] Task 목표 달성
- [ ] REVIEW PASS
- [ ] VALIDATE PASS

## Steps

1. [PLAN]
2. [RESEARCH]
3. [ACTION]
4. [REVIEW]
5. [VALIDATE]
6. [DONE]

## Final Report

최종 완료보고는 반드시 따5코(\`\`\`\`\`) 안에 작성한다.
TASKEOF

    if [[ ! -f "$TASK_FILE" ]]; then
        echo "[ERROR] Task file creation failed: ${TASK_FILE}"
        echo "[PLANNER] Aborting — state will NOT be updated."
        exit 1
    fi
    echo "     Created: ${TASK_FILE}"

    # ── STEP-7: Queue registration ─────────────────────────────
    echo "     [STEP-7] Registering in queue/pending..."
    mkdir -p "$QUEUE_PENDING"

    if ! touch "$PENDING_MARKER"; then
        echo "[ERROR] Queue registration failed: ${PENDING_MARKER}"
        echo "[PLANNER] Aborting — state will NOT be updated."
        exit 1
    fi
    echo "     Queued: ${PENDING_MARKER}"

    CREATED_COUNT=$((CREATED_COUNT + 1))
    if [[ -z "$FIRST_NEW_TASK" ]]; then
        FIRST_NEW_TASK="$NEW_TASK_ID"
    fi
done

# ── STEP-8: Update mission_state.json ─────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Summary: created=${CREATED_COUNT} skipped=${SKIPPED_COUNT}"

if [[ -z "$FIRST_NEW_TASK" ]]; then
    echo "  All tasks already existed. No state update needed."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

echo ""
echo "[STEP-8] Updating mission_state.json..."

if [[ ! -f "$MISSION_STATE" ]]; then
    echo "  [WARNING] mission_state.json not found: ${MISSION_STATE}"
    echo "  Tasks and queue entries were created, but state was NOT updated."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

TS=$(now_iso)
atomic_write_state \
    ".next_task = \"${FIRST_NEW_TASK}\" | .planner_last_run = \"${TS}\" | .feedback_cycle = ((.feedback_cycle // 0) + 1) | .last_processed_report = \"${REPORT_BASENAME}\" | .updated_at = \"${TS}\""

echo "  next_task        = ${FIRST_NEW_TASK}"
echo "  planner_last_run = ${TS}"
echo "  feedback_cycle   incremented (+1)"
echo ""
echo "  ✓ Planner Feedback Flow complete."
echo "  Next task: ${FIRST_NEW_TASK}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
