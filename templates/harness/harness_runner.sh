#!/usr/bin/env bash
# harness_runner.sh — Multi-Agent Harness Orchestrator
# Usage:
#   ./harness/harness_runner.sh --task   TASK_ID [--dry-run] [--override-severity MAJOR|MINOR|NIT] [--skip-validate]
#   ./harness/harness_runner.sh --resume TASK_ID [--force]   [--dry-run] [--skip-validate]
#   ./harness/harness_runner.sh --list
#   ./harness/harness_runner.sh --status TASK_ID
#   ./harness/harness_runner.sh TASK_ID  [flags]            # legacy: same as --task TASK_ID
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STATE_FILE="${SCRIPT_DIR}/active_state.json"
LOGS_DIR="${SCRIPT_DIR}/logs"
AGENTS_DIR="${SCRIPT_DIR}/agents"
OVERRIDES_DIR="${SCRIPT_DIR}/logs/overrides"

# shellcheck source=lib/git_checkpoint.sh
source "${SCRIPT_DIR}/lib/git_checkpoint.sh"
# shellcheck source=lib/policy.sh
source "${SCRIPT_DIR}/lib/policy.sh"
# shellcheck source=lib/findings.sh
source "${SCRIPT_DIR}/lib/findings.sh"

# ── Global state ──────────────────────────────────────────────
TASK_ID=""
MODE=""          # task | resume | list | status | chain | findings
FINDINGS_MODE="" # "" | "open" | "materialize"
FORCE=false
DRY_RUN=false
OVERRIDE_SEVERITY=""
SKIP_VALIDATE=false
NO_CHAIN=false
AUTO_COMMIT="${HARNESS_AUTO_COMMIT:-false}"  # CLI --auto-commit or env HARNESS_AUTO_COMMIT=1
RESEARCHER_LOG=""
REVIEWER_JSON=""
VALIDATOR_JSON=""
LAST_FAIL_STAGE="REVIEW"
STARTED_AT=""
CHAIN_FROM=""
CHAIN_TO=""
CHAIN_SELECT=""
HARNESS_AUTO_CONFIRM="${HARNESS_AUTO_CONFIRM:-0}"   # CLI --auto-confirm or env HARNESS_AUTO_CONFIRM=1
HCHAIN_PLANNER_AUTO="${HCHAIN_PLANNER_AUTO:-0}"     # CLI --planner-auto or env HCHAIN_PLANNER_AUTO=1
HCHAIN_MISSION_ID="${HCHAIN_MISSION_ID:-}"          # CLI --mission ID or env HCHAIN_MISSION_ID=ID
HCHAIN_RESEARCH_PROVIDER="${HCHAIN_RESEARCH_PROVIDER:-codex}"  # codex | gemini | none

# ── Timeout constants (overridable via env) ───────────────────
GEMINI_TIMEOUT="${GEMINI_TIMEOUT:-900}"
CODEX_TIMEOUT="${CODEX_TIMEOUT:-1200}"
VALIDATE_TIMEOUT_DEFAULT="${VALIDATE_TIMEOUT_DEFAULT:-600}"
VALIDATE_TIMEOUT_E2E="${VALIDATE_TIMEOUT_E2E:-1800}"

# ── API health check target (overridable via env) ─────────────
HARNESS_API_HEALTH_URL="${HARNESS_API_HEALTH_URL:-http://localhost:8801/health}"

# ── Usage ─────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage:
  $(basename "$0") --task   TASK_ID [--dry-run] [--override-severity MAJOR|MINOR|NIT] [--skip-validate] [--no-chain] [--auto-commit] [--planner-auto] [--mission ID] [--auto-confirm]
  $(basename "$0") --resume TASK_ID [--force]   [--dry-run] [--skip-validate] [--auto-commit]
  $(basename "$0") --chain  [TASK_ID]                        [--auto-commit]   # auto-chain all pending tasks (hchain)
  $(basename "$0") --chain  --from TASK_ID --to TASK_ID      [--auto-commit]   # run tasks in range
  $(basename "$0") --chain  --select TASK_ID,TASK_ID,...     [--auto-commit]   # run selected tasks only
  $(basename "$0") --list
  $(basename "$0") --status TASK_ID
  $(basename "$0") --findings                  # show findings backlog summary
  $(basename "$0") --findings --open            # list open findings
  $(basename "$0") --findings --materialize FINDING_ID  # create draft task from finding
  $(basename "$0") TASK_ID  [flags]            # legacy: same as --task TASK_ID

Flags:
  --auto-commit       Create a git commit after DONE/SUCCESS (default: off)
                      Equivalent env var: HARNESS_AUTO_COMMIT=1
  --planner-auto      Enable Planner Feedback hook after PASS
                      Equivalent env var: HCHAIN_PLANNER_AUTO=1
  --mission ID        Set Mission context for Planner Feedback
                      Equivalent env var: HCHAIN_MISSION_ID=ID
  --auto-confirm      Bypass interactive gate confirmations
                      Equivalent env var: HARNESS_AUTO_CONFIRM=1
  --dry-run           Simulate run; with --auto-commit previews commit message only

Env vars (no CLI flag):
  HCHAIN_RESEARCH_PROVIDER  Research provider (codex|gemini|none, default: codex)
EOF
}

# ── Argument parsing ──────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --task)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --task requires TASK_ID"; usage; exit 1
            fi
            MODE="task"; TASK_ID="$2"; shift 2 ;;
        --resume)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --resume requires TASK_ID"; usage; exit 1
            fi
            MODE="resume"; TASK_ID="$2"; shift 2 ;;
        --list)
            MODE="list"; shift ;;
        --findings)
            MODE="findings"
            shift
            if [[ $# -ge 1 ]]; then
                case "$1" in
                    --open)
                        FINDINGS_MODE="open"; shift ;;
                    --materialize)
                        FINDINGS_MODE="materialize"
                        if [[ $# -lt 2 ]]; then
                            echo "[ERROR] --findings --materialize requires FINDING_ID"; usage; exit 1
                        fi
                        TASK_ID="$2"; shift 2 ;;
                esac
            fi ;;
        --status)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --status requires TASK_ID"; usage; exit 1
            fi
            MODE="status"; TASK_ID="$2"; shift 2 ;;
        --force)
            FORCE=true; shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        --override-severity)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --override-severity requires a value (MAJOR|MINOR|NIT)"
                usage; exit 1
            fi
            OVERRIDE_SEVERITY="$2"; shift 2 ;;
        --skip-validate)
            SKIP_VALIDATE=true; shift ;;
        --no-chain)
            NO_CHAIN=true; shift ;;
        --auto-commit)
            AUTO_COMMIT=true; shift ;;
        --auto-confirm)
            HARNESS_AUTO_CONFIRM=1; shift ;;
        --planner-auto)
            HCHAIN_PLANNER_AUTO=1; shift ;;
        --mission)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --mission requires MISSION_ID"; usage; exit 1
            fi
            HCHAIN_MISSION_ID="$2"; shift 2 ;;
        --help)
            usage; exit 0 ;;
        --from)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --from requires TASK_ID"; usage; exit 1
            fi
            CHAIN_FROM="$2"; shift 2 ;;
        --to)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --to requires TASK_ID"; usage; exit 1
            fi
            CHAIN_TO="$2"; shift 2 ;;
        --select)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --select requires comma-separated TASK_ID list"; usage; exit 1
            fi
            CHAIN_SELECT="$2"; shift 2 ;;
        --chain)
            MODE="chain"
            if [[ $# -ge 2 && "${2:0:1}" != "-" ]]; then
                TASK_ID="$2"; shift 2
            else
                shift
            fi ;;
        -*)
            echo "[ERROR] Unknown flag: $1"; usage; exit 1 ;;
        *)
            if [[ -z "$TASK_ID" ]]; then
                TASK_ID="$1"   # legacy positional arg
            else
                echo "[ERROR] Unexpected argument: $1"; usage; exit 1
            fi
            shift ;;
    esac
done

# Default mode for legacy positional usage
if [[ -z "$MODE" ]]; then
    if [[ -n "$TASK_ID" ]]; then
        MODE="task"
    else
        echo "[ERROR] No mode specified. Use --task, --resume, --list, or --status."
        usage; exit 1
    fi
fi

# Validate TASK_ID is provided for modes that require it
if [[ "$MODE" != "list" && "$MODE" != "chain" && "$MODE" != "findings" && -z "$TASK_ID" ]]; then
    echo "[ERROR] TASK_ID is required for mode=${MODE}"
    usage; exit 1
fi

# Validate --override-severity value; CRITICAL override is forbidden
if [[ -n "$OVERRIDE_SEVERITY" ]]; then
    case "$OVERRIDE_SEVERITY" in
        MAJOR|MINOR|NIT) ;;
        CRITICAL)
            echo "[ERROR] --override-severity CRITICAL is forbidden"
            exit 1 ;;
        *)
            echo "[ERROR] --override-severity must be MAJOR, MINOR, or NIT (got: ${OVERRIDE_SEVERITY})"
            exit 1 ;;
    esac
fi

# ── Helper: state_set <jq_filter> ────────────────────────────
# Atomically apply a jq filter to active_state.json
state_set() {
    local expr="$1"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] state_set: ${expr}"
        return 0
    fi
    local tmp
    tmp=$(mktemp)
    if ! { jq "${expr} | .last_updated = (now | todate)" "$STATE_FILE" > "$tmp" \
        && mv "$tmp" "$STATE_FILE" \
        && jq -e . "$STATE_FILE" > /dev/null; }; then
        echo "[FATAL] state_set failed — stopping to prevent corrupt state"; exit 1
    fi
}

# ── Helper: state_note_append <text> ─────────────────────────
state_note_append() {
    local text="$1"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] state_note_append: ${text}"
        return 0
    fi
    local tmp
    tmp=$(mktemp)
    if ! { jq --arg t "$text" \
        '.notes = (if (.notes // "" | length) > 0 then .notes + " | " + $t else $t end) | .last_updated = (now | todate)' \
        "$STATE_FILE" > "$tmp" \
        && mv "$tmp" "$STATE_FILE" \
        && jq -e . "$STATE_FILE" > /dev/null; }; then
        echo "[FATAL] state_note_append failed"; exit 1
    fi
}

# ── Helper: log_append <log_path> ────────────────────────────
log_append() {
    local log_path="$1"
    local rel_path="${log_path#"${PROJECT_ROOT}"/}"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] log_append: ${rel_path}"
        return 0
    fi
    local tmp
    tmp=$(mktemp)
    if ! { jq --arg p "$rel_path" '.current_logs += [$p]' "$STATE_FILE" > "$tmp" \
        && mv "$tmp" "$STATE_FILE"; }; then
        echo "[FATAL] log_append failed: ${rel_path}"; exit 1
    fi
}

# ── Helper: validate_json <path> ─────────────────────────────
validate_json() {
    local path="$1"
    if ! jq -e . "$path" > /dev/null 2>&1; then
        echo "[FATAL] Invalid JSON: ${path}"
        return 1
    fi
}

# ── Helper: validate_task_id_format <task_id> ─────────────────
validate_task_id_format() {
    local tid="$1"
    if [[ ! "$tid" =~ ^TASK_[0-9]{8}_[0-9]{3}$ ]]; then
        echo "[ERROR] Invalid TASK_ID format: ${tid} (expected TASK_YYYYMMDD_NNN)"
        exit 1
    fi
}

# ── Helper: count_severity <log_path> <severity> ─────────────
count_severity() {
    local log_path="$1"
    local severity="$2"
    jq --arg s "$severity" '
        (if has("payload") then .payload else . end) |
        [.issues[]? | select(.severity == $s)] | length
    ' "$log_path"
}

# ── Helper: count_blocking_severity <log_path> <severity> ────
count_blocking_severity() {
    local log_path="$1"
    local severity="$2"
    jq --arg s "$severity" '
        (if has("payload") then .payload else . end) |
        [.blocking_issues[]? | select(.severity == $s)] | length
    ' "$log_path"
}

# ── Helper: write_synthetic_reviewer_fail <json_path> <reason> ─
write_synthetic_reviewer_fail() {
    local json_path="$1"
    local reason="$2"
    jq -n \
        --arg tid "$TASK_ID" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg desc "$reason" \
        '{
            task_id: $tid,
            agent: "REVIEWER",
            timestamp: $ts,
            status: "FAIL",
            issues: [{
                severity: "MAJOR",
                file: "harness/harness_runner.sh",
                line: 0,
                description: $desc,
                suggestion: "Retry review after Codex service recovers"
            }]
        }' > "$json_path"
}

# ── Helper: validate_reviewer_schema <json_path> ─────────────────
# Returns 0 = valid, 1 = invalid (emits reason on failure)
validate_reviewer_schema() {
    local path="$1"
    if ! jq -e . "$path" > /dev/null 2>&1; then
        echo "[REVIEW] Schema FAIL: not valid JSON"
        return 1
    fi
    local status
    status=$(jq -r '.status // empty' "$path" 2>/dev/null)
    if [[ -z "$status" ]]; then
        echo "[REVIEW] Schema FAIL: .status missing"
        return 1
    fi
    if [[ "$status" != "PASS" && "$status" != "FAIL" ]]; then
        echo "[REVIEW] Schema FAIL: .status='${status}' not PASS or FAIL"
        return 1
    fi
    local issues_type
    issues_type=$(jq -r 'if has("issues") then (.issues | type) else "missing" end' "$path" 2>/dev/null)
    if [[ "$issues_type" != "array" ]]; then
        echo "[REVIEW] Schema FAIL: .issues not array (${issues_type})"
        return 1
    fi
    local agent
    agent=$(jq -r '.agent // empty' "$path" 2>/dev/null)
    if [[ -n "$agent" && "$agent" != "REVIEWER" ]]; then
        echo "[REVIEW] Schema FAIL: .agent='${agent}' (expected REVIEWER)"
        return 1
    fi
    return 0
}

# ── Helper: review_infra_blocked <raw_path> <json_path> <reason> ─
# Codex service failure or invalid reviewer response → synthetic FAIL,
# sets result=BLOCKED/human_checkpoint_required=true, exits 0.
review_infra_blocked() {
    local raw_path="$1"
    local json_path="$2"
    local reason="$3"
    echo "[REVIEW] BLOCKED: ${reason}"
    [[ -f "$raw_path" ]] && log_append "$raw_path"
    # Write synthetic fail as payload, then wrap in envelope
    local payload_tmp
    payload_tmp=$(mktemp --suffix=.json)
    write_synthetic_reviewer_fail "$payload_tmp" "$reason"
    [[ -z "$STARTED_AT" ]] && STARTED_AT=$(date -u +%FT%TZ)
    emit_envelope "REVIEWER" "REVIEW" "FAIL" 1 "$reason" "" "" "$payload_tmp" > "$json_path"
    rm -f "$payload_tmp"
    log_append "$json_path"
    REVIEWER_JSON="$json_path"
    local tmp
    tmp=$(mktemp)
    if ! { jq --arg r "REVIEW_INFRA_BLOCKED: ${reason}" \
        '.result = "BLOCKED" | .human_checkpoint_required = true | .notes = $r | .last_updated = (now | todate)' \
        "$STATE_FILE" > "$tmp" \
        && mv "$tmp" "$STATE_FILE" \
        && jq -e . "$STATE_FILE" > /dev/null; }; then
        echo "[FATAL] review_infra_blocked: state update failed"; exit 1
    fi
    echo "[BLOCKED] Reviewer infrastructure failure — manual intervention required"
    echo "[BLOCKED] Synthetic FAIL written: ${json_path}"
    exit 0
}

# ── Dangerous command patterns (task validate guard) ─────────
DANGEROUS_CMD=(
    'rm -rf'
    'sudo'
    'chmod -R 777'
    'git reset --hard'
    'docker system prune'
)

is_dangerous_cmd() {
    local cmd="$1"
    local pat
    for pat in "${DANGEROUS_CMD[@]}"; do
        [[ "$cmd" == *"$pat"* ]] && return 0
    done
    return 1
}

# ── Parse task frontmatter YAML list ─────────────────────────
# parse_task_meta <task_id> <yaml_key> → prints list items, one per line
parse_task_meta() {
    local task_file="${SCRIPT_DIR}/tasks/${1}.md"
    local key="$2"
    [[ ! -f "$task_file" ]] && return 0
    awk -v key="$key" '
        /^---/ { fm++; next }
        fm == 0 || fm >= 2 { next }
        $0 ~ ("^" key ":") { in_key=1; next }
        in_key && /^  - / { sub(/^  - /, ""); gsub(/^"/, ""); gsub(/"$/, ""); print; next }
        in_key && /^[a-zA-Z_]/ { exit }
    ' "$task_file"
}

# task_validate_cmds <task_id> → prints validate list items
task_validate_cmds() { parse_task_meta "$1" "validate"; }

# ── Helper: run_validate_check <type> <cmd> ──────────────────
# Runs cmd under type-appropriate timeout. exit 124 = TIMEOUT → treated as FAIL.
run_validate_check() {
    local type="$1"
    local cmd="$2"
    local to="$VALIDATE_TIMEOUT_DEFAULT"
    [[ "$type" == "E2E" ]] && to="$VALIDATE_TIMEOUT_E2E"
    timeout "$to" bash -c "$cmd"
    return $?
}

# ── Validate: run_validate <task_id> <out_path> ───────────────
run_validate() {
    local task_id="$1"
    local out="$2"
    local checks='[]'
    local blocking='[]'

    # Prepare validate log directory
    local TASK_VALIDATE_LOG_DIR="${LOGS_DIR}/validate"
    mkdir -p "$TASK_VALIDATE_LOG_DIR"
    local tv_timestamp
    tv_timestamp=$(date -u +%Y%m%d_%H%M%S)
    local tv_log="${TASK_VALIDATE_LOG_DIR}/${tv_timestamp}_${task_id}.json"
    local tv_commands='[]'
    local tv_status="PASS"

    # Read task-specific validate commands from frontmatter
    local tv_cmds=()
    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] && tv_cmds+=("$cmd")
    done < <(task_validate_cmds "$task_id")

    if [[ "${#tv_cmds[@]}" -gt 0 ]]; then
        # Task frontmatter validate commands
        local tcmd_ec tcmd_desc
        for tcmd in "${tv_cmds[@]}"; do
            if is_dangerous_cmd "$tcmd"; then
                checks=$(echo "$checks" | jq --arg c "$tcmd" \
                    '. + [{"type":"TASK_VALIDATE","target":$c,"result":"BLOCKED","summary":"DANGEROUS_CMD blocked","evidence":"matched forbidden pattern"}]')
                blocking=$(echo "$blocking" | jq --arg c "$tcmd" \
                    '. + [{"severity":"CRITICAL","type":"TASK_VALIDATE","description":"Dangerous validate command blocked","suggestion":"Remove from task frontmatter","detail":$c}]')
                tv_commands=$(echo "$tv_commands" | jq --arg c "$tcmd" \
                    '. + [{"cmd":$c,"result":"BLOCKED","exit_code":-1}]')
                tv_status="FAIL"
                continue
            fi
            tcmd_ec=0
            timeout "$VALIDATE_TIMEOUT_DEFAULT" bash -c "$tcmd" \
                > /tmp/harness_task_validate.log 2>&1 || tcmd_ec=$?
            if [[ "$tcmd_ec" -eq 0 ]]; then
                checks=$(echo "$checks" | jq --arg c "$tcmd" \
                    '. + [{"type":"TASK_VALIDATE","target":$c,"result":"PASS","summary":"command passed","evidence":"exit 0"}]')
                tv_commands=$(echo "$tv_commands" | jq --arg c "$tcmd" \
                    '. + [{"cmd":$c,"result":"PASS","exit_code":0}]')
            else
                tcmd_desc="command failed (exit ${tcmd_ec})"
                [[ "$tcmd_ec" -eq 124 ]] && tcmd_desc="command timed out (${VALIDATE_TIMEOUT_DEFAULT}s)"
                checks=$(echo "$checks" | jq --arg c "$tcmd" --arg d "$tcmd_desc" \
                    '. + [{"type":"TASK_VALIDATE","target":$c,"result":"FAIL","summary":$d,"evidence":"see /tmp/harness_task_validate.log"}]')
                blocking=$(echo "$blocking" | jq --arg c "$tcmd" --arg d "$tcmd_desc" \
                    '. + [{"severity":"MAJOR","type":"TASK_VALIDATE","description":$d,"suggestion":"Fix validate command","detail":$c}]')
                tv_commands=$(echo "$tv_commands" | jq --arg c "$tcmd" --arg d "$tcmd_desc" \
                    '. + [{"cmd":$c,"result":"FAIL","exit_code":'"$tcmd_ec"',"error":$d}]')
                tv_status="FAIL"
            fi
        done
    else
        # Fallback: standard checks (no frontmatter validate section)

        # TYPECHECK
        local tc_ec=0
        run_validate_check "TYPECHECK" "pnpm -r typecheck > /tmp/harness_typecheck.log 2>&1" \
            || tc_ec=$?
        if [[ "$tc_ec" -eq 0 ]]; then
            checks=$(echo "$checks" | jq '. + [{"type":"TYPECHECK","target":"pnpm -r typecheck","result":"PASS","summary":"typecheck passed","evidence":"exit 0"}]')
        else
            local tc_desc="typecheck failed (exit ${tc_ec})"
            [[ "$tc_ec" -eq 124 ]] && tc_desc="typecheck timed out (${VALIDATE_TIMEOUT_DEFAULT}s)"
            checks=$(echo "$checks" | jq --arg d "$tc_desc" '. + [{"type":"TYPECHECK","target":"pnpm -r typecheck","result":"FAIL","summary":$d,"evidence":"see /tmp/harness_typecheck.log"}]')
            blocking=$(echo "$blocking" | jq --arg d "$tc_desc" '. + [{"severity":"MAJOR","type":"TYPECHECK","description":$d,"suggestion":"Fix TypeScript errors"}]')
        fi

        # LINT
        local lint_ec=0
        run_validate_check "LINT" "pnpm -r lint > /tmp/harness_lint.log 2>&1" \
            || lint_ec=$?
        if [[ "$lint_ec" -eq 0 ]]; then
            checks=$(echo "$checks" | jq '. + [{"type":"LINT","target":"pnpm -r lint","result":"PASS","summary":"lint passed","evidence":"exit 0"}]')
        else
            local lint_desc="lint failed (exit ${lint_ec})"
            [[ "$lint_ec" -eq 124 ]] && lint_desc="lint timed out (${VALIDATE_TIMEOUT_DEFAULT}s)"
            checks=$(echo "$checks" | jq --arg d "$lint_desc" '. + [{"type":"LINT","target":"pnpm -r lint","result":"FAIL","summary":$d,"evidence":"see /tmp/harness_lint.log"}]')
            blocking=$(echo "$blocking" | jq --arg d "$lint_desc" '. + [{"severity":"MAJOR","type":"LINT","description":$d,"suggestion":"Fix lint errors"}]')
        fi

        # TEST
        local test_ec=0
        run_validate_check "TEST" "pnpm -r test > /tmp/harness_test.log 2>&1" \
            || test_ec=$?
        if [[ "$test_ec" -eq 0 ]]; then
            checks=$(echo "$checks" | jq '. + [{"type":"TEST","target":"pnpm -r test","result":"PASS","summary":"test passed","evidence":"exit 0"}]')
        else
            local test_desc="test failed (exit ${test_ec})"
            [[ "$test_ec" -eq 124 ]] && test_desc="test timed out (${VALIDATE_TIMEOUT_DEFAULT}s)"
            checks=$(echo "$checks" | jq --arg d "$test_desc" '. + [{"type":"TEST","target":"pnpm -r test","result":"FAIL","summary":$d,"evidence":"see /tmp/harness_test.log"}]')
            blocking=$(echo "$blocking" | jq --arg d "$test_desc" '. + [{"severity":"MAJOR","type":"TEST","description":$d,"suggestion":"Fix failing tests"}]')
        fi

        # API HEALTH (SKIP if unreachable)
        local api_result="SKIP"
        local api_summary="not checked"
        if curl -sf --max-time 5 "$HARNESS_API_HEALTH_URL" > /tmp/harness_api.log 2>&1; then
            api_result="PASS"
            api_summary="API health OK"
        elif curl --max-time 5 "$HARNESS_API_HEALTH_URL" > /tmp/harness_api.log 2>&1; then
            api_result="SKIP"
            api_summary="API not reachable — skipped"
        fi
        checks=$(echo "$checks" | jq --arg r "$api_result" --arg s "$api_summary" --arg t "$HARNESS_API_HEALTH_URL" \
            '. + [{"type":"API_HEALTH","target":$t,"result":$r,"summary":$s,"evidence":"see /tmp/harness_api.log"}]')
    fi

    # Write task-validate log (schema: validate_status + commands[])
    jq -n \
        --arg tid "$task_id" \
        --arg ts "$(date -u +%FT%TZ)" \
        --arg vs "$tv_status" \
        --argjson cmds "$tv_commands" \
        '{task_id: $tid, timestamp: $ts, validate_status: $vs, commands: $cmds}' > "$tv_log"

    jq -n \
        --arg tid "$task_id" \
        --argjson checks "$checks" \
        --argjson blocking "$blocking" \
        '{
            task_id: $tid,
            agent: "VALIDATOR",
            timestamp: (now | todate),
            status: (if ([$blocking[]? | select(.severity == "CRITICAL" or .severity == "MAJOR")] | length) > 0 then "FAIL" else "PASS" end),
            checks: $checks,
            blocking_issues: $blocking
        }' > "$out"

    jq -e . "$out" > /dev/null
}

# ── Helper: create_task_branch ───────────────────────────────
# Creates harness/<task_id_lower>-<YYYYMMDD> branch on first ACTION.
# Gracefully degrades if not a git repo or branch already exists.
create_task_branch() {
    local task_lower
    task_lower=$(echo "$TASK_ID" | tr '[:upper:]' '[:lower:]')
    local branch_name="harness/${task_lower}-$(date +%Y%m%d)"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] Would create/checkout branch: ${branch_name}"
        return 0
    fi

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git checkout -b "$branch_name" 2>/dev/null \
            || git checkout "$branch_name"

        echo "🌿 branch: $branch_name"

        state_set '.git_branch = "'"$branch_name"'"'
    else
        echo "[WARN] git repo 아님"

        state_set '.git_branch = null'
        state_note_append "GIT_BRANCH_CREATION_FAILED"
    fi
}

# ── Phase: PLAN ───────────────────────────────────────────────
phase_plan() {
    echo "[PLAN] Initializing task_id=${TASK_ID}"

    if [[ "$DRY_RUN" == "true" ]]; then
        local skip_note=""
        [[ "$SKIP_VALIDATE" == "true" ]] && skip_note=" skip_validate=true"
        echo "[DRY_RUN] Would init active_state.json: task_id=${TASK_ID} step=PLAN loop_count=0${skip_note}"
        return 0
    fi

    mkdir -p "$LOGS_DIR"

    local tmp
    tmp=$(mktemp)
    if ! { jq --arg id "$TASK_ID" --arg mid "$HCHAIN_MISSION_ID" \
        '.task_id = $id
         | .step = "PLAN"
         | .loop_count = 0
         | .current_logs = []
         | .human_checkpoint_required = false
         | .result = "PENDING"
         | .notes = ""
         | .skipped_stages = []
         | .git_branch = null
         | .override_applied = false
         | .override_level = null
         | .mission_id = (if $mid == "" then null else $mid end)
         | .last_updated = (now | todate)' \
        "$STATE_FILE" > "$tmp" \
        && mv "$tmp" "$STATE_FILE" \
        && jq -e . "$STATE_FILE" > /dev/null; }; then
        echo "[FATAL] PLAN init failed"; exit 1
    fi

    if [[ "$SKIP_VALIDATE" == "true" ]]; then
        state_set '.skipped_stages = ["VALIDATE"] | .notes = "VALIDATE_SKIPPED_BY_USER_REQUEST"'
    fi

    echo "[PLAN] ✓ state initialized. logs_dir=${LOGS_DIR}"
}

# ── Phase: RESEARCH (provider-based: codex | gemini | none) ──
phase_research() {
    STARTED_AT=$(date -u +%FT%TZ)
    state_set '.step = "RESEARCH"'

    local provider="${HCHAIN_RESEARCH_PROVIDER}"

    if [[ "$provider" == "none" ]]; then
        echo "[RESEARCH] Provider: none — skipping (HCHAIN_RESEARCH_PROVIDER=none)"
        state_set '.skipped_stages += ["RESEARCH"] | .notes = "RESEARCH_SKIPPED_PROVIDER_NONE"'
        RESEARCHER_LOG=""
        return 0
    fi

    local TIMESTAMP
    TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
    local LOG_PATH="${LOGS_DIR}/${TIMESTAMP}_RESEARCHER_${TASK_ID}.json"

    if [[ "$DRY_RUN" == "true" ]]; then
        case "$provider" in
            codex)  echo "[DRY_RUN] codex exec --json --ephemeral -c sandbox_permissions=[\"disk-full-read-access\"] <researcher.md+TASK> → envelope ${LOG_PATH}" ;;
            gemini) echo "[DRY_RUN] gemini -p <researcher.md+TASK> --output-format json → envelope ${LOG_PATH}" ;;
            *)      echo "[DRY_RUN] unknown provider: ${provider}" ;;
        esac
        RESEARCHER_LOG="$LOG_PATH"
        return 0
    fi

    local TASK_DESCRIPTION TASK_FILE
    TASK_FILE="${SCRIPT_DIR}/tasks/${TASK_ID}.md"
    if [[ -f "$TASK_FILE" ]]; then
        TASK_DESCRIPTION=$(cat "$TASK_FILE")
    else
        TASK_DESCRIPTION="task_id: ${TASK_ID}"
    fi

    local PROMPT
    PROMPT="$(cat "${AGENTS_DIR}/researcher.md")

[TASK]
${TASK_DESCRIPTION}"

    echo "[RESEARCH] Provider: ${provider}"

    case "$provider" in
        codex)
            _research_via_codex "$LOG_PATH" "$PROMPT"
            ;;
        gemini)
            _research_via_gemini "$LOG_PATH" "$PROMPT"
            ;;
        *)
            echo "[RESEARCH] ERROR: unknown HCHAIN_RESEARCH_PROVIDER='${provider}'. Valid: codex | gemini | none"
            emit_interrupted "CLI_EXIT_NONZERO" "RESEARCH" "RESEARCHER" 1
            ;;
    esac

    validate_json "$LOG_PATH"
    log_append "$LOG_PATH"
    RESEARCHER_LOG="$LOG_PATH"
    echo "[RESEARCH] ✓ log=${LOG_PATH}"
}

_research_via_codex() {
    local LOG_PATH="$1"
    local PROMPT="$2"
    local RAW_JSONL="${LOG_PATH%.json}.jsonl"

    echo "[RESEARCH] Invoking codex (timeout=${CODEX_TIMEOUT}s) → ${RAW_JSONL}"
    local payload_tmp RESEARCHER_STDERR EC
    payload_tmp=$(mktemp --suffix=.json)
    RESEARCHER_STDERR=$(mktemp)
    STARTED_AT=$(date -u +%FT%TZ)
    EC=0

    timeout "$CODEX_TIMEOUT" codex exec \
        --json \
        --ephemeral \
        -c 'sandbox_permissions=["disk-full-read-access"]' \
        "$PROMPT" \
        > "$RAW_JSONL" 2> "$RESEARCHER_STDERR" || EC=$?

    if [[ "$EC" -ne 0 ]]; then
        local REASON
        REASON=$(classify_interruption "$EC" "$(cat "$RESEARCHER_STDERR")")
        rm -f "$RESEARCHER_STDERR" "$payload_tmp"
        emit_interrupted "$REASON" "RESEARCH" "RESEARCHER" "$EC"
    fi
    rm -f "$RESEARCHER_STDERR"

    log_append "$RAW_JSONL"

    if ! jq -rs \
        '[.[] | select(.type=="item.completed" and .item.type=="agent_message")] | last | .item.text | fromjson' \
        "$RAW_JSONL" > "$payload_tmp" 2>/dev/null; then
        rm -f "$payload_tmp"
        emit_interrupted "JSON_PARSE_FAIL" "RESEARCH" "RESEARCHER" 0
    fi

    if ! emit_envelope "RESEARCHER" "RESEARCH" "PASS" 0 "" "" "" "$payload_tmp" > "$LOG_PATH"; then
        rm -f "$payload_tmp"
        echo "[FATAL] emit_envelope failed for RESEARCHER"; exit 1
    fi
    rm -f "$payload_tmp"
}

_research_via_gemini() {
    local LOG_PATH="$1"
    local PROMPT="$2"
    local payload_tmp RESEARCHER_STDERR EC

    payload_tmp=$(mktemp --suffix=.json)
    RESEARCHER_STDERR=$(mktemp)

    echo "[RESEARCH] Invoking gemini (timeout=${GEMINI_TIMEOUT}s)"
    STARTED_AT=$(date -u +%FT%TZ)
    EC=0

    timeout "$GEMINI_TIMEOUT" gemini -p "$PROMPT" --output-format json \
        > "$payload_tmp" 2> "$RESEARCHER_STDERR" || EC=$?

    if [[ "$EC" -ne 0 ]]; then
        local REASON
        REASON=$(classify_interruption "$EC" "$(cat "$RESEARCHER_STDERR")")
        rm -f "$payload_tmp" "$RESEARCHER_STDERR"
        emit_interrupted "$REASON" "RESEARCH" "RESEARCHER" "$EC"
    fi
    rm -f "$RESEARCHER_STDERR"

    if ! jq -e . "$payload_tmp" > /dev/null 2>&1; then
        rm -f "$payload_tmp"
        emit_interrupted "JSON_PARSE_FAIL" "RESEARCH" "RESEARCHER" 0
    fi

    # Unwrap Gemini envelope: --output-format json wraps response in {session_id, response, stats}
    if jq -e 'has("response")' "$payload_tmp" > /dev/null 2>&1; then
        local tmp_unwrap
        tmp_unwrap=$(mktemp)
        if ! { jq -r '.response' "$payload_tmp" | jq '.' > "$tmp_unwrap" \
            && mv "$tmp_unwrap" "$payload_tmp" \
            && validate_json "$payload_tmp"; }; then
            rm -f "$payload_tmp" "$tmp_unwrap" 2>/dev/null || true
            emit_interrupted "JSON_PARSE_FAIL" "RESEARCH" "RESEARCHER" 0
        fi
        echo "[RESEARCH] Gemini envelope unwrapped"
    fi

    if ! emit_envelope "RESEARCHER" "RESEARCH" "PASS" 0 "" "" "" "$payload_tmp" > "$LOG_PATH"; then
        rm -f "$payload_tmp"
        echo "[FATAL] emit_envelope failed for RESEARCHER"; exit 1
    fi
    rm -f "$payload_tmp"
}

# ── Phase: ACTION (Claude itself applies changes) ─────────────
phase_action() {
    echo "[ACTION] Claude applying code changes (loop_count=$(jq -r '.loop_count' "${STATE_FILE}" 2>/dev/null || echo '?'))..."
    state_set '.step = "ACTION"'

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] Would present RESEARCH findings and signal Claude to apply changes"
        return 0
    fi

    # Create task branch on first ACTION entry (git_branch == null)
    local current_branch
    current_branch=$(jq -r '.git_branch // "null"' "$STATE_FILE" 2>/dev/null || echo "null")
    if [[ "$current_branch" == "null" ]]; then
        create_task_branch
    fi

    # ACTION 토큰 부족 자가 감지 (§14 — CLAUDE.md): 외부에서 HARNESS_TOKEN_LIMIT=1 설정 시
    if [[ "${HARNESS_TOKEN_LIMIT:-0}" == "1" ]]; then
        STARTED_AT=$(date -u +%FT%TZ)
        emit_interrupted "TOKEN_LIMIT" "ACTION" "SUPERVISOR" 0
    fi

    # Surface research findings for Claude (Coder) to act on
    if [[ -n "$RESEARCHER_LOG" && -f "$RESEARCHER_LOG" ]]; then
        local arch fc
        arch=$(jq -r '(.payload.recommended_architecture // .recommended_architecture) // "N/A"' "$RESEARCHER_LOG" 2>/dev/null || true)
        fc=$(jq '(.payload.findings // .findings) | length' "$RESEARCHER_LOG" 2>/dev/null || echo 0)
        echo "[ACTION] recommended_architecture: ${arch}"
        echo "[ACTION] findings count: ${fc}"
    fi

    echo "[ACTION] ⚠ Code modifications should now be applied based on RESEARCH findings."
    state_set '.notes = "ACTION: code modifications applied"'
}

# ── Phase: REVIEW (Codex CLI, headless) ──────────────────────
phase_review() {
    STARTED_AT=$(date -u +%FT%TZ)
    echo "[REVIEW] Calling Codex CLI..."
    state_set '.step = "REVIEW"'

    local TIMESTAMP
    TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
    local REVIEWER_RAW="${LOGS_DIR}/${TIMESTAMP}_REVIEWER_${TASK_ID}.jsonl"
    local REVIEWER_JSON_PATH="${LOGS_DIR}/${TIMESTAMP}_REVIEWER_${TASK_ID}.json"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] codex exec --json --ephemeral -c sandbox_permissions=[\"disk-full-read-access\"] <prompt> > ${REVIEWER_RAW}"
        echo "[DRY_RUN] jq extract agent_message → payload → envelope ${REVIEWER_JSON_PATH}"
        REVIEWER_JSON="$REVIEWER_JSON_PATH"
        return 0
    fi

    # Collect recently changed files
    local CHANGED_FILES
    CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null | head -20 || echo "N/A")

    local PROMPT
    PROMPT="$(cat "${AGENTS_DIR}/reviewer.md")

[REVIEW TARGETS]
task_id: ${TASK_ID}
changed_files:
${CHANGED_FILES}"

    echo "[REVIEW] Invoking codex (timeout=${CODEX_TIMEOUT}s) → ${REVIEWER_RAW}"
    local REVIEWER_STDERR
    REVIEWER_STDERR=$(mktemp)
    STARTED_AT=$(date -u +%FT%TZ)
    local EC=0
    timeout "$CODEX_TIMEOUT" codex exec \
        --json \
        --ephemeral \
        -c 'sandbox_permissions=["disk-full-read-access"]' \
        "$PROMPT" \
        > "$REVIEWER_RAW" 2> "$REVIEWER_STDERR" || EC=$?
    if [[ "$EC" -ne 0 ]]; then
        local REASON
        REASON=$(classify_interruption "$EC" "$(cat "$REVIEWER_STDERR")")
        rm -f "$REVIEWER_STDERR"
        emit_interrupted "$REASON" "REVIEW" "REVIEWER" "$EC"
    fi
    rm -f "$REVIEWER_STDERR"

    # Stage 1: scan raw JSONL for known Codex infra error patterns
    # item 필드가 없는 thread-level 이벤트만 검사, turn.completed(usage 통계)는 오탐지 방지를 위해 제외
    if jq -c 'select(.item == null and .type != "turn.completed" and .type != "turn.started")' "$REVIEWER_RAW" 2>/dev/null \
        | grep -qiE '503|Service Unavailable|rate.?limit|"unavailable"'; then
        review_infra_blocked "$REVIEWER_RAW" "$REVIEWER_JSON_PATH" \
            "Codex service error in raw JSONL (503/unavailable/rate-limit)"
    fi

    # Stage 2: extract agent_message into temp payload file
    local payload_tmp
    payload_tmp=$(mktemp --suffix=.json)
    echo "[REVIEW] Extracting agent_message from JSONL..."
    if ! jq -rs \
        '[.[] | select(.type=="item.completed" and .item.type=="agent_message")] | last | .item.text | fromjson' \
        "$REVIEWER_RAW" > "$payload_tmp" 2>/dev/null; then
        rm -f "$payload_tmp"
        emit_interrupted "JSON_PARSE_FAIL" "REVIEW" "REVIEWER" 0
    fi

    # Stage 3: validate reviewer JSON schema (on raw payload)
    if ! validate_reviewer_schema "$payload_tmp"; then
        rm -f "$payload_tmp"
        review_infra_blocked "$REVIEWER_RAW" "$REVIEWER_JSON_PATH" \
            "Reviewer response failed schema validation"
    fi

    # Stage 4: wrap in standard log envelope; envelope.status = payload.status
    local r_status
    r_status=$(jq -r '.status' "$payload_tmp")
    if ! emit_envelope "REVIEWER" "REVIEW" "$r_status" 0 "" "" "" "$payload_tmp" > "$REVIEWER_JSON_PATH"; then
        rm -f "$payload_tmp"
        review_infra_blocked "$REVIEWER_RAW" "$REVIEWER_JSON_PATH" \
            "emit_envelope failed for REVIEWER"
    fi
    rm -f "$payload_tmp"
    validate_json "$REVIEWER_JSON_PATH"

    log_append "$REVIEWER_RAW"
    log_append "$REVIEWER_JSON_PATH"
    REVIEWER_JSON="$REVIEWER_JSON_PATH"
    echo "[REVIEW] ✓ log=${REVIEWER_JSON_PATH}"

    # Collect MINOR/NIT findings from reviewer log
    collect_findings_from_log "$REVIEWER_JSON_PATH" "$TASK_ID"
}

# ── Phase: VALIDATE (runtime validation) ─────────────────────
phase_validate() {
    STARTED_AT=$(date -u +%FT%TZ)
    echo "[VALIDATE] Running validation checks..."
    state_set '.step = "VALIDATE"'

    local TIMESTAMP
    TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
    local VALIDATOR_JSON_PATH="${LOGS_DIR}/${TIMESTAMP}_VALIDATOR_${TASK_ID}.json"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] run_validate ${TASK_ID} → envelope ${VALIDATOR_JSON_PATH}"
        VALIDATOR_JSON="$VALIDATOR_JSON_PATH"
        return 0
    fi

    # Run validation into temp payload file
    local payload_tmp
    payload_tmp=$(mktemp --suffix=.json)
    if ! { run_validate "$TASK_ID" "$payload_tmp" \
        && validate_json "$payload_tmp"; }; then
        rm -f "$payload_tmp"
        echo "[FATAL] run_validate failed"; exit 1
    fi

    # Sync envelope.status = payload.status (task spec requirement)
    local v_status
    v_status=$(jq -r '.status' "$payload_tmp")

    # Wrap in standard log envelope
    if ! emit_envelope "VALIDATOR" "VALIDATE" "$v_status" 0 "" "" "" "$payload_tmp" > "$VALIDATOR_JSON_PATH"; then
        rm -f "$payload_tmp"
        echo "[FATAL] emit_envelope failed for VALIDATOR"; exit 1
    fi
    rm -f "$payload_tmp"
    validate_json "$VALIDATOR_JSON_PATH"

    log_append "$VALIDATOR_JSON_PATH"
    VALIDATOR_JSON="$VALIDATOR_JSON_PATH"
    echo "[VALIDATE] ✓ status=${v_status} log=${VALIDATOR_JSON_PATH}"

    # Collect MINOR/NIT findings from validator log
    collect_findings_from_log "$VALIDATOR_JSON_PATH" "$TASK_ID"
}

# ── Safety Break (loop_count == 3) ────────────────────────────
safety_break() {
    local break_report="${LOGS_DIR}/SAFETY_BREAK_${TASK_ID}.md"

    echo "[SAFETY BREAK] task_id=${TASK_ID} — see ${break_report}"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] Would write safety break report and set result=BLOCKED"
        exit 0
    fi

    # ── §1 TASK SUMMARY data ───────────────────────────────────
    local git_branch current_step task_start_time
    git_branch=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    current_step=$(jq -r '.step // "?"' "$STATE_FILE" 2>/dev/null)
    task_start_time=$(jq -r '.last_updated // "?"' "$STATE_FILE" 2>/dev/null)

    # ── §2 Collect per-loop log files from current_logs ────────
    local all_log_paths=()
    while IFS= read -r p; do
        all_log_paths+=("${PROJECT_ROOT}/${p}")
    done < <(jq -r '.current_logs[]?' "$STATE_FILE" 2>/dev/null || true)

    local reviewer_logs=()
    local validator_logs=()
    for p in "${all_log_paths[@]}"; do
        case "$p" in
            *_REVIEWER_*.json)  reviewer_logs+=("$p") ;;
            *_VALIDATOR_*.json) validator_logs+=("$p") ;;
        esac
    done

    # ── §3 LOOP HISTORY ────────────────────────────────────────
    local loop_history=""
    local max_loops=${#reviewer_logs[@]}
    [[ ${#validator_logs[@]} -gt $max_loops ]] && max_loops=${#validator_logs[@]}

    for ((i=0; i<max_loops; i++)); do
        local loop_num=$((i+1))
        local r_log="${reviewer_logs[$i]:-}" v_log="${validator_logs[$i]:-}"
        local r_status="N/A" v_status="N/A"
        local r_issues="" v_issues=""

        if [[ -n "$r_log" && -f "$r_log" ]] && jq -e . "$r_log" &>/dev/null 2>&1; then
            r_status=$(jq -r '.status // "?"' "$r_log" 2>/dev/null)
            r_issues=$(jq -r '
                (if has("payload") then .payload else . end) |
                .issues[]? | select(.severity=="CRITICAL" or .severity=="MAJOR") |
                "  [\(.severity)] \(.file // "?"):\(.line // "?") — \(.description | .[0:80])"
            ' "$r_log" 2>/dev/null | head -5 || true)
        fi
        if [[ -n "$v_log" && -f "$v_log" ]] && jq -e . "$v_log" &>/dev/null 2>&1; then
            v_status=$(jq -r '.status // "?"' "$v_log" 2>/dev/null)
            v_issues=$(jq -r '
                (if has("payload") then .payload else . end) |
                .blocking_issues[]? | select(.severity=="CRITICAL" or .severity=="MAJOR") |
                "  [\(.severity)] \(.type // "?") — \(.description | .[0:80])"
            ' "$v_log" 2>/dev/null | head -5 || true)
        fi

        loop_history+="### Loop ${loop_num}
- REVIEW status: ${r_status}
${r_issues:-(  이슈 없음)}
- VALIDATOR status: ${v_status}
${v_issues:-(  이슈 없음)}

"
    done
    [[ -z "$loop_history" ]] && loop_history="(루프 로그 없음)"

    # ── §4 REPEATED ISSUES ─────────────────────────────────────
    local repeated_reviewer="" repeated_validator=""

    if [[ ${#reviewer_logs[@]} -ge 2 ]]; then
        local all_r_descs=""
        for r_log in "${reviewer_logs[@]}"; do
            [[ -f "$r_log" ]] && jq -e . "$r_log" &>/dev/null 2>&1 || continue
            all_r_descs+=$(jq -r '
                (if has("payload") then .payload else . end) |
                .issues[]? | select(.severity=="CRITICAL" or .severity=="MAJOR") |
                "[\(.severity)] \(.file // "?"):\(.line // "?") — \(.description | .[0:100])"
            ' "$r_log" 2>/dev/null)
            all_r_descs+=$'\n'
        done
        repeated_reviewer=$(printf '%s' "$all_r_descs" | sort | uniq -d || true)
    fi
    [[ -z "$repeated_reviewer" ]] && repeated_reviewer="(3회 반복 이슈 없음)"

    if [[ ${#validator_logs[@]} -ge 2 ]]; then
        local all_v_descs=""
        for v_log in "${validator_logs[@]}"; do
            [[ -f "$v_log" ]] && jq -e . "$v_log" &>/dev/null 2>&1 || continue
            all_v_descs+=$(jq -r '
                (if has("payload") then .payload else . end) |
                .blocking_issues[]? | select(.severity=="CRITICAL" or .severity=="MAJOR") |
                "[\(.severity)] \(.type // "?") — \(.description | .[0:100])"
            ' "$v_log" 2>/dev/null)
            all_v_descs+=$'\n'
        done
        repeated_validator=$(printf '%s' "$all_v_descs" | sort | uniq -d || true)
    fi
    [[ -z "$repeated_validator" ]] && repeated_validator="(3회 반복 이슈 없음)"

    # ── §5 ACTION HISTORY ──────────────────────────────────────
    local action_history
    action_history=$(
        git -C "$PROJECT_ROOT" log --oneline --name-only -9 \
            --format="commit %h  %s" 2>/dev/null \
        | grep -v '^$' | head -40 \
        || echo "(git log unavailable)"
    )

    # ── §6 ROOT CAUSE ANALYSIS ─────────────────────────────────
    local root_cause="자동 분석 불가 — 수동 검토 필요"
    if [[ ${#reviewer_logs[@]} -ge 2 ]]; then
        local hot_files
        hot_files=$(
            for r_log in "${reviewer_logs[@]}"; do
                [[ -f "$r_log" ]] && jq -e . "$r_log" &>/dev/null 2>&1 || continue
                jq -r '(if has("payload") then .payload else . end) | .issues[]?.file // empty' "$r_log" 2>/dev/null
            done | sort | uniq -c | sort -rn | awk '$1>=2{print "  - "$2" ("$1"회 등장)"}' | head -5
        )
        if [[ -n "$hot_files" ]]; then
            root_cause="반복 등장 파일 (패턴 수정이 근본 원인 해소 없이 반복된 것으로 추정):
${hot_files}"
        fi
    fi

    # ── §7 Write report ────────────────────────────────────────
    cat > "$break_report" <<REPORT
# TASK SUMMARY

- task_id: ${TASK_ID}
- 시작 시각: ${task_start_time}
- 현재 step: ${current_step}
- git_branch: ${git_branch}
- loop_count: 3 (한계 도달)
- 마지막 실패 단계: ${LAST_FAIL_STAGE}

---

# LOOP HISTORY

${loop_history}
---

# REPEATED ISSUES

## Reviewer (CRITICAL/MAJOR — 2회 이상 반복)
${repeated_reviewer}

## Validator (CRITICAL/MAJOR — 2회 이상 반복)
${repeated_validator}

---

# ACTION HISTORY

\`\`\`
${action_history}
\`\`\`

---

# ROOT CAUSE ANALYSIS

${root_cause}

---

# NEXT OPTIONS

- [ ] 이슈를 수동 수정 후 loop_count=0, human_checkpoint_required=false 리셋 → 재실행
- [ ] 관련 파일 롤백 후 다른 접근법 시도
- [ ] 아키텍처 재설계 후 재시작
- [ ] 이슈를 무시하고 강제 종료 (주의: 품질 보증 없음)

---

사용자 개입 절차:
  1. 위 이슈를 수동 수정
  2. active_state.json의 loop_count를 0으로 리셋하고 human_checkpoint_required를 false로 변경
  3. harness_runner.sh를 재실행
REPORT

    state_set '.result = "BLOCKED" | .human_checkpoint_required = true'

    # Sync task.state.json
    sync_task_state "BLOCKED" "BLOCKED" "ACTION"

    # Move queue: running → blocked
    move_queue "$TASK_ID" "running" "blocked" \
        || echo "[WARN] safety_break: queue move to blocked failed"

    # Write recovery metadata
    local recovery_file="${SCRIPT_DIR}/tasks/${TASK_ID}.recovery.json"
    local ts_iso
    ts_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq -n \
        --arg tid "$TASK_ID" \
        --arg step "$(jq -r '.step // "ACTION"' "$STATE_FILE" 2>/dev/null)" \
        --arg ts "$ts_iso" \
        --arg report "$break_report" \
        '{task_id:$tid, loop_limit_reached_at:$ts, last_failed_step:$step,
          recoverable:true, next_resume_step:"ACTION",
          recovery_report:$report,
          recovery_instructions:[
            "1. SAFETY_BREAK report 내 이슈를 수동 수정",
            "2. active_state.json loop_count=0, human_checkpoint_required=false 리셋",
            "3. harness_runner.sh --resume TASK_ID --force 재실행"
          ]}' > "$recovery_file" \
        && echo "[SAFETY BREAK] Recovery metadata: ${recovery_file}" \
        || echo "[WARN] safety_break: recovery.json write failed"

    echo "[SAFETY BREAK]"
    echo "see ${break_report}"
    exit 0
}

# ── classify_interruption <exit_code> <stderr_text> ──────────
# Returns one of: TOKEN_LIMIT TIMEOUT CLI_AUTH_EXPIRED CLI_EXIT_NONZERO
#                 JSON_PARSE_FAIL NETWORK_ERROR USER_ABORT UNKNOWN
classify_interruption() {
    local exit_code="${1:-0}"
    local stderr_text="${2:-}"

    if [[ "$exit_code" -eq 124 ]]; then
        echo "TIMEOUT"; return 0
    fi
    if [[ "$exit_code" -eq 130 || "$exit_code" -eq 137 ]]; then
        echo "USER_ABORT"; return 0
    fi
    if echo "$stderr_text" | grep -qiE 'token|context length|rate limit'; then
        echo "TOKEN_LIMIT"; return 0
    fi
    if echo "$stderr_text" | grep -qiE 'auth|unauthenticated'; then
        echo "CLI_AUTH_EXPIRED"; return 0
    fi
    if echo "$stderr_text" | grep -qiE 'network|dns|ECONNREFUSED'; then
        echo "NETWORK_ERROR"; return 0
    fi
    if [[ "$exit_code" -ge 1 && "$exit_code" -le 3 ]]; then
        echo "CLI_EXIT_NONZERO"; return 0
    fi
    echo "UNKNOWN"
}

# ── emit_interrupted <reason> <step> <agent> <exit_code> ─────
# §14.3 — publishes INTERRUPTED log, updates state/checkpoint/queue, exits 0
emit_interrupted() {
    local reason="${1:-UNKNOWN}"
    local cur_step="${2:-UNKNOWN}"
    local agent="${3:-UNKNOWN}"
    local exit_code="${4:-0}"
    local timestamp
    timestamp=$(date -u +%Y%m%d_%H%M%S)
    local ts_iso
    ts_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] emit_interrupted: reason=${reason} step=${cur_step} agent=${agent} exit=${exit_code}"
        exit 0
    fi

    # 1. INTERRUPTED log — envelope format (§14 + Phase 7-5)
    local log_path="${LOGS_DIR}/${timestamp}_INTERRUPTED_${TASK_ID}.json"
    [[ -z "$STARTED_AT" ]] && STARTED_AT="$ts_iso"
    local payload_tmp
    payload_tmp=$(mktemp --suffix=.json)
    jq -n \
        --arg tid "$TASK_ID" \
        --arg reason "$reason" \
        --arg step "$cur_step" \
        --arg agent "$agent" \
        --argjson ec "$exit_code" \
        --arg ts "$ts_iso" \
        '{event:"INTERRUPTED", task_id:$tid, reason:$reason, step:$step,
          agent:$agent, exit_code:$ec, timestamp:$ts}' > "$payload_tmp"
    emit_envelope "$agent" "$cur_step" "INTERRUPTED" "$exit_code" \
        "$reason" "$cur_step" \
        "Resume from step=${cur_step} after INTERRUPTED reason=${reason}" \
        "$payload_tmp" > "$log_path"
    rm -f "$payload_tmp"
    jq -e . "$log_path" || { echo "[FATAL] emit_interrupted: log JSON invalid"; exit 1; }

    # 2. active_state.json
    local tmp
    tmp=$(mktemp)
    jq --arg reason "$reason" --arg step "$cur_step" --arg ts "$ts_iso" \
        '.result="INTERRUPTED" | .next_resume_step=$step | .notes=($reason + "_AT_" + $step) | .last_updated=$ts' \
        "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    jq -e . "$STATE_FILE" || { echo "[FATAL] emit_interrupted: active_state.json corrupt"; exit 1; }

    # 2.5. timeout_streak: 동일 step에서 연속 TIMEOUT 3회 감지 → BLOCKED
    local _move_to_queue="pending"
    if [[ "$reason" == "TIMEOUT" ]]; then
        local streak
        streak=$(jq -r --arg step "$cur_step" \
            '(.interruption_timeout_streak // {}) | .[$step] // 0' \
            "$STATE_FILE" 2>/dev/null || echo "0")
        streak=$(( streak + 1 ))
        local streak_tmp
        streak_tmp=$(mktemp)
        if jq --argjson s "$streak" --arg step "$cur_step" \
            '.interruption_timeout_streak[$step] = $s' \
            "$STATE_FILE" > "$streak_tmp" \
            && mv "$streak_tmp" "$STATE_FILE" \
            && jq -e . "$STATE_FILE" > /dev/null; then
            echo "[INTERRUPTED] timeout_streak[${cur_step}]=${streak}"
        else
            echo "[WARN] timeout_streak: state update failed"
        fi
        if [[ "$streak" -ge 3 ]]; then
            local blocked_tmp
            blocked_tmp=$(mktemp)
            jq '.result="BLOCKED" | .human_checkpoint_required=true' \
                "$STATE_FILE" > "$blocked_tmp" && mv "$blocked_tmp" "$STATE_FILE" || true
            _move_to_queue="blocked"
            echo "[INTERRUPTED] timeout_streak >= 3 at step=${cur_step} → status=BLOCKED"
        fi
    fi

    # 3. tasks/$TASK_ID.state.json (if exists)
    local task_state="${SCRIPT_DIR}/tasks/${TASK_ID}.state.json"
    if [[ -f "$task_state" ]]; then
        tmp=$(mktemp)
        jq --arg reason "$reason" --arg agent "$agent" --arg step "$cur_step" \
           --arg ts "$ts_iso" --argjson code "$exit_code" \
            '.status="INTERRUPTED" |
             .interruption={reason:$reason, agent:$agent, exit_code:$code, timestamp:$ts} |
             .next_resume_step=$step |
             .updated_at=$ts' \
            "$task_state" > "$tmp" && mv "$tmp" "$task_state"
        jq -e . "$task_state" || echo "[WARN] emit_interrupted: task state.json invalid — skipping"
    fi

    # 4. tasks/$TASK_ID.checkpoint.json (if exists)
    local task_ckpt="${SCRIPT_DIR}/tasks/${TASK_ID}.checkpoint.json"
    if [[ -f "$task_ckpt" ]]; then
        tmp=$(mktemp)
        jq --arg step "$cur_step" --arg reason "$reason" --arg ts "$ts_iso" \
            '.resume_prompt=("Resume from step=" + $step + " after INTERRUPTED reason=" + $reason) |
             .updated_at=$ts' \
            "$task_ckpt" > "$tmp" && mv "$tmp" "$task_ckpt"
        jq -e . "$task_ckpt" || echo "[WARN] emit_interrupted: checkpoint.json invalid — skipping"
    fi

    # 5. queue/running → queue/$_move_to_queue (pending or blocked if streak>=3)
    local move_sh="${SCRIPT_DIR}/queue/move.sh"
    if [[ -f "$move_sh" ]]; then
        bash "$move_sh" "$TASK_ID" "running" "$_move_to_queue" \
            && echo "[INTERRUPTED] queue: running → ${_move_to_queue}" \
            || echo "[WARN] emit_interrupted: move.sh failed — queue state may be inconsistent"
    fi

    # 6. exit 0 (재개 대기)
    echo "[INTERRUPTED] task_id=${TASK_ID} reason=${reason} step=${cur_step} — waiting for resume"
    exit 0
}

# ── emit_envelope <agent> <step> <status> <exit_code> <reason> <next_step> <resume_hint> <payload_file>
emit_envelope() {
    local agent="$1"
    local step="$2"
    local status="$3"
    local exit_code="$4"
    local reason="${5:-}"
    local next_step="${6:-}"
    local resume_hint="${7:-}"
    local payload_file="$8"

    jq -n \
        --arg tid "$TASK_ID" \
        --arg agent "$agent" \
        --arg step "$step" \
        --arg status "$status" \
        --argjson ec "$exit_code" \
        --arg s "$STARTED_AT" \
        --arg e "$(date -u +%FT%TZ)" \
        --arg r "$reason" \
        --arg ns "$next_step" \
        --arg rh "$resume_hint" \
        --slurpfile p "$payload_file" \
        '{task_id:$tid, agent:$agent, step:$step, status:$status,
          exit_code:$ec, started_at:$s, ended_at:$e,
          reason:(if $r=="" then null else $r end),
          next_step:(if $ns=="" then null else $ns end),
          resume_hint:(if $rh=="" then null else $rh end),
          payload:$p[0]}'
}

# ── Helper: _decision_done <reason> ──────────────────────────
_decision_done() {
    local reason="$1"
    local jq_expr='.step = "DONE" | .result = "PASS"'
    if [[ -n "$OVERRIDE_SEVERITY" ]]; then
        jq_expr+=" | .override_applied = true | .override_level = \"${OVERRIDE_SEVERITY}\""
    fi
    state_set "$jq_expr"

    if [[ -n "$OVERRIDE_SEVERITY" ]]; then
        echo ""
        echo "[WARN]"
        echo "override severity applied: ${OVERRIDE_SEVERITY}"
        echo "non-critical issues ignored"
        echo ""
        log_override_audit "${OVERRIDE_SEVERITY}" "${reason}"
    fi

    # Sync task.state.json
    sync_task_state "DONE" "PASS" "DONE"

    # Move queue: running → done (ignore if already in done)
    move_queue "$TASK_ID" "running" "done" \
        || echo "[WARN] _decision_done: queue move failed — run check_consistency.sh"

    echo "[DONE] ✓ task_id=${TASK_ID} — PASS (${reason})"
}

# ── DECISION branch (post-REVIEW+VALIDATE, §6 분기 표) ────────
decision_branch() {
    echo "[DECISION] Evaluating REVIEW + VALIDATE results..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] DECISION: assumed PASS → step=DONE"
        return 0
    fi

    local R_STATUS R_CRIT R_MAJOR
    R_STATUS=$(jq -r '.status' "$REVIEWER_JSON")
    R_CRIT=$(count_severity "$REVIEWER_JSON" "CRITICAL")
    R_MAJOR=$(count_severity "$REVIEWER_JSON" "MAJOR")

    local V_STATUS V_CRIT V_MAJOR
    if [[ "$SKIP_VALIDATE" == "true" ]]; then
        V_STATUS="SKIP"
        V_CRIT=0
        V_MAJOR=0
    else
        V_STATUS=$(jq -r '.status' "$VALIDATOR_JSON")
        V_CRIT=$(count_blocking_severity "$VALIDATOR_JSON" "CRITICAL")
        V_MAJOR=$(count_blocking_severity "$VALIDATOR_JSON" "MAJOR")
    fi

    echo "[DECISION] Reviewer: status=${R_STATUS} CRITICAL=${R_CRIT} MAJOR=${R_MAJOR}"
    echo "[DECISION] Validator: status=${V_STATUS} CRITICAL=${V_CRIT} MAJOR=${V_MAJOR}"

    if [[ "$OVERRIDE_SEVERITY" == "MAJOR" ]]; then
        echo "[DECISION] override=MAJOR: suppressing R_MAJOR=${R_MAJOR} V_MAJOR=${V_MAJOR} (CRITICAL preserved)"
        R_MAJOR=0
        V_MAJOR=0
    fi

    if [[ "$R_STATUS" == "PASS" && "$V_STATUS" == "PASS" ]]; then
        _decision_done "Reviewer PASS + Validator PASS"
        return 0
    fi

    if [[ "$R_STATUS" == "PASS" && "$V_STATUS" == "SKIP" ]]; then
        _decision_done "Reviewer PASS + Validator SKIP"
        return 0
    fi

    if [[ "$R_STATUS" == "FAIL" && "$R_CRIT" -eq 0 && "$R_MAJOR" -eq 0 && \
          ( "$V_STATUS" == "PASS" || "$V_STATUS" == "SKIP" ) ]]; then
        _decision_done "Reviewer MINOR/NIT only (after filter) + Validator ${V_STATUS}"
        return 0
    fi

    if [[ -n "$OVERRIDE_SEVERITY" && "$R_CRIT" -eq 0 && "$V_CRIT" -eq 0 \
          && "$R_MAJOR" -eq 0 && "$V_MAJOR" -eq 0 ]]; then
        _decision_done "override=${OVERRIDE_SEVERITY}: no CRITICAL found, blocking issues suppressed"
        return 0
    fi

    if [[ "$V_CRIT" -gt 0 || "$V_MAJOR" -gt 0 ]]; then
        LAST_FAIL_STAGE="VALIDATE"
    else
        LAST_FAIL_STAGE="REVIEW"
    fi

    local current_lc new_lc
    current_lc=$(jq -r '.loop_count' "$STATE_FILE")
    new_lc=$(( current_lc + 1 ))

    state_set ".loop_count = ${new_lc}"
    echo "[DECISION] loop_count: ${current_lc} → ${new_lc} | failing_stage=${LAST_FAIL_STAGE}"

    if [[ "$new_lc" -ge 3 ]]; then
        safety_break
    fi

    echo "[DECISION] FAIL (R_CRIT=${R_CRIT} R_MAJOR=${R_MAJOR} V_CRIT=${V_CRIT} V_MAJOR=${V_MAJOR}) → ACTION retry (loop_count=${new_lc})"
    state_set '.step = "ACTION"'

    # Sync loop_count and current_step to task.state.json to prevent active_state vs task.state mismatch (C6/C8)
    local _ts_isync _task_state_retry _tmp_isync
    _ts_isync=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _task_state_retry="${SCRIPT_DIR}/tasks/${TASK_ID}.state.json"
    if [[ -f "$_task_state_retry" ]]; then
        _tmp_isync=$(mktemp)
        if jq --argjson lc "$new_lc" --arg step "ACTION" --arg ts "$_ts_isync" \
            '.loop_count=$lc | .current_step=$step | .updated_at=$ts' \
            "$_task_state_retry" > "$_tmp_isync" \
            && mv "$_tmp_isync" "$_task_state_retry" \
            && jq -e . "$_task_state_retry" > /dev/null 2>&1; then
            echo "[SYNC] task.state.json: loop_count=${new_lc} step=ACTION (retry sync)"
        else
            echo "[WARN] decision_branch: task.state.json retry sync failed"
            rm -f "$_tmp_isync" 2>/dev/null || true
        fi
    fi

    return 1
}

# ── Phase Gate: interactive approval before each major stage ──
gate_check() {
    local stage="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[GATE] DRY_RUN: auto-approve ${stage}"
        return 0
    fi

    if [[ "$HARNESS_AUTO_CONFIRM" == "1" ]]; then
        echo "[GATE] AUTO_CONFIRM: auto-approve ${stage}"
        state_set '.human_checkpoint_required = false'
        return 0
    fi

    local loop_count
    loop_count=$(jq -r '.loop_count' "$STATE_FILE" 2>/dev/null || echo '?')

    state_set '.human_checkpoint_required = true'

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ▶ 다음 단계: ${stage}"
    echo "  현재 loop_count: ${loop_count}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    read -r -p "  진행하시겠습니까? [y/N/s(skip)] " choice || true

    case "$choice" in
        y|Y)
            state_set '.human_checkpoint_required = false'
            return 0 ;;
        s|S)
            state_set '.human_checkpoint_required = false'
            return 2 ;;
        *)
            state_set '.human_checkpoint_required = false' 2>/dev/null || true
            echo "  ⛔ 사용자 중단"
            exit 0 ;;
    esac
}

# ── Helper: step_idx <step_name> → integer ───────────────────
step_idx() {
    case "$1" in
        PLAN)     echo 0 ;;
        RESEARCH) echo 1 ;;
        ACTION)   echo 2 ;;
        REVIEW)   echo 3 ;;
        VALIDATE) echo 4 ;;
        DONE)     echo 5 ;;
        *)        echo 0 ;;
    esac
}

# ── Helper: move_queue <task_id> <from> <to> ─────────────────
# Handles stale duplicate markers: if source missing but dest exists → already moved (OK).
# If both exist → remove dest first, then move (idempotent).
move_queue() {
    local tid="$1" from="$2" to="$3"
    local move_sh="${SCRIPT_DIR}/queue/move.sh"
    local src="${SCRIPT_DIR}/queue/${from}/${tid}"
    local dst="${SCRIPT_DIR}/queue/${to}/${tid}"

    # Stale marker: destination already exists but source does not
    if [[ ! -e "$src" && -e "$dst" ]]; then
        echo "[QUEUE] stale move: ${tid} already in ${to} (no action needed)"
        return 0
    fi

    # Duplicate: both exist — remove stale destination before moving
    if [[ -e "$src" && -e "$dst" ]]; then
        echo "[QUEUE] duplicate marker detected for ${tid} in ${from} and ${to} — removing ${to} marker"
        rm -f "$dst"
    fi

    if [[ -f "$move_sh" ]]; then
        bash "$move_sh" "$tid" "$from" "$to"
    else
        echo "[WARN] move.sh not found: ${move_sh} — queue state not updated"
    fi
}

# ── Helper: sync_task_state <status> <result> <step> ─────────
# Syncs task.state.json to match active_state.json on terminal transitions.
# Also syncs loop_count from active_state.json to keep both files consistent.
sync_task_state() {
    local new_status="$1"   # DONE | BLOCKED | INTERRUPTED
    local result="${2:-}"   # PASS | FAIL | BLOCKED | INTERRUPTED
    local step="${3:-DONE}" # current step value
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local task_state="${SCRIPT_DIR}/tasks/${TASK_ID}.state.json"
    if [[ ! -f "$task_state" ]]; then
        echo "[WARN] sync_task_state: no state file for ${TASK_ID} — skipping"
        return 0
    fi

    # Read loop_count from active_state.json to keep both files in sync
    local active_lc
    active_lc=$(jq -r '.loop_count // 0' "$STATE_FILE" 2>/dev/null || echo "0")

    local tmp
    tmp=$(mktemp)
    local jq_expr='.status=$status | .current_step=$step | .next_resume_step=$step |
                   .result=$result | .loop_count=($lc|tonumber) | .updated_at=$ts'
    [[ "$step" == "DONE" ]] && jq_expr+=' | .last_success_step="VALIDATE"'

    if jq --arg status "$new_status" \
          --arg result "$result" \
          --arg step "$step" \
          --arg lc "$active_lc" \
          --arg ts "$ts" \
          "$jq_expr" "$task_state" > "$tmp" \
       && mv "$tmp" "$task_state" \
       && jq -e . "$task_state" > /dev/null 2>&1; then
        echo "[SYNC] task.state.json updated: ${TASK_ID} status=${new_status} result=${result} step=${step} loop_count=${active_lc}"
    else
        echo "[WARN] sync_task_state: failed to update ${task_state}"
        rm -f "$tmp"
    fi
}

# ── Helper: log_override_audit <level> <reason> ──────────────
log_override_audit() {
    local level="$1"
    local reason="${2:-}"
    local ts_stamp ts_iso
    ts_stamp=$(date -u +%Y%m%d_%H%M%S)
    ts_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    mkdir -p "${OVERRIDES_DIR}"
    local log_path="${OVERRIDES_DIR}/${ts_stamp}_${TASK_ID}.json"
    jq -n \
        --arg tid "$TASK_ID" \
        --arg level "$level" \
        --arg reason "$reason" \
        --arg ts "$ts_iso" \
        '{task_id:$tid, override_level:$level, reason:$reason, timestamp:$ts}' \
        > "$log_path"
    echo "[OVERRIDE] Audit log: ${log_path}"
}

# ── cmd: --list ───────────────────────────────────────────────
cmd_list() {
    printf "%-24s %-9s %-12s %-10s %5s  %s\n" "TASK_ID" "QUEUE" "STATUS" "STEP" "LOOPS" "UPDATED_AT"
    printf '%.0s-' {1..75}; echo
    local found_any=false
    for q in pending running done blocked; do
        for f in "${SCRIPT_DIR}/queue/${q}"/*; do
            [ -e "$f" ] || continue
            found_any=true
            local tid
            tid=$(basename "$f")
            local st="${SCRIPT_DIR}/tasks/${tid}.state.json"
            if [[ ! -f "$st" ]]; then
                printf "%-24s %-9s %-12s %-10s %5s  %s\n" "$tid" "$q" "(no state)" "" "" ""
                continue
            fi
            local status step lc ts
            status=$(jq -r '.status // "?"' "$st")
            step=$(jq -r '.current_step // "?"' "$st")
            lc=$(jq -r '.loop_count // 0' "$st")
            ts=$(jq -r '.updated_at // .started_at // ""' "$st")
            printf "%-24s %-9s %-12s %-10s %5d  %s\n" "$tid" "$q" "$status" "$step" "$lc" "$ts"
        done
    done
    if [[ "$found_any" == "false" ]]; then echo "(no tasks in queue)"; fi
}

# ── cmd: --status ─────────────────────────────────────────────
cmd_status() {
    local task_state="${SCRIPT_DIR}/tasks/${TASK_ID}.state.json"
    local task_ckpt="${SCRIPT_DIR}/tasks/${TASK_ID}.checkpoint.json"

    if [[ ! -f "$task_state" ]]; then
        echo "[ERROR] No state file found: ${task_state}"
        exit 1
    fi

    echo "── state ────────────────────────────────"
    jq . "$task_state"

    if [[ -f "$task_ckpt" ]]; then
        echo "── checkpoint ──────────────────────────"
        jq . "$task_ckpt"
    fi

    echo "── queue position ──────────────────────"
    local found=false
    for q in pending running done blocked; do
        if [[ -e "${SCRIPT_DIR}/queue/${q}/${TASK_ID}" ]]; then
            echo "queue=${q}"
            found=true
        fi
    done
    [[ "$found" == "false" ]] && echo "(not in any queue)"

    echo "── recent logs (last 5) ─────────────────"
    ls -t "${LOGS_DIR}"/*_"${TASK_ID}".json 2>/dev/null | head -5 || echo "(no logs)"
}

# ── cmd: --resume ─────────────────────────────────────────────
cmd_resume() {
    local task_state="${SCRIPT_DIR}/tasks/${TASK_ID}.state.json"

    if [[ ! -f "$task_state" ]]; then
        echo "[ERROR] No state file for task: ${TASK_ID}"
        exit 1
    fi

    # Determine queue position
    local queue_pos=""
    for q in pending running done blocked; do
        if [[ -e "${SCRIPT_DIR}/queue/${q}/${TASK_ID}" ]]; then
            queue_pos="$q"; break
        fi
    done

    # Validate status
    local status
    status=$(jq -r '.status // "UNKNOWN"' "$task_state")

    case "$status" in
        INTERRUPTED|PENDING)
            ;;
        BLOCKED)
            if [[ "$FORCE" != "true" ]]; then
                echo "[ERROR] Task ${TASK_ID} is BLOCKED. Use --force to resume."
                exit 1
            fi
            echo "[WARN] --force: resuming BLOCKED task ${TASK_ID}"
            ;;
        DONE)
            echo "[ERROR] Cannot resume a DONE task: ${TASK_ID}"
            exit 1
            ;;
        RUNNING)
            if [[ "$FORCE" != "true" ]]; then
                echo "[ERROR] Task ${TASK_ID} is already RUNNING. Use --force to override."
                exit 1
            fi
            echo "[WARN] --force: overriding RUNNING task ${TASK_ID}"
            ;;
        *)
            echo "[WARN] Unknown status=${status} for ${TASK_ID} — proceeding with caution"
            ;;
    esac

    # Validate queue position
    if [[ -n "$queue_pos" && "$queue_pos" == "done" ]]; then
        echo "[ERROR] Task is in done queue — cannot resume"
        exit 1
    fi

    # Get resume step
    local NEXT
    NEXT=$(jq -r '.next_resume_step // "PLAN"' "$task_state")
    echo "[RESUME] task_id=${TASK_ID} status=${status} queue=${queue_pos:-none} next_resume_step=${NEXT}"

    # Move queue to running
    if [[ -z "$queue_pos" ]]; then
        touch "${SCRIPT_DIR}/queue/running/${TASK_ID}"
        echo "[RESUME] Registered in running queue"
    elif [[ "$queue_pos" != "running" ]]; then
        move_queue "$TASK_ID" "$queue_pos" "running"
    else
        echo "[RESUME] Already in running queue"
    fi

    # Sync active_state.json step to resume point
    state_set ".step = \"${NEXT}\""

    main_loop "$NEXT"
}

# ── cmd: --task ───────────────────────────────────────────────
cmd_task() {
    while true; do
        local task_md="${SCRIPT_DIR}/tasks/${TASK_ID}.md"
        local task_state="${SCRIPT_DIR}/tasks/${TASK_ID}.state.json"

        if [[ ! -f "$task_md" ]]; then
            echo "[ERROR] Task file not found: ${task_md}"
            exit 1
        fi

        if [[ ! -f "$task_state" ]]; then
            echo "[INFO] No state file — creating from template"
            local tmpl="${SCRIPT_DIR}/tasks/_state.template.json"
            if [[ -f "$tmpl" ]]; then
                jq --arg id "$TASK_ID" --arg ts "$(date -u +%FT%TZ)" \
                    '.task_id=$id | .status="PENDING" | .current_step="PLAN" | .updated_at=$ts' \
                    "$tmpl" > "$task_state"
                echo "[INFO] Created: ${task_state}"
            else
                echo "[ERROR] State template not found: ${tmpl}"
                echo "[INFO]  Create ${task_state} manually, or restore _state.template.json to ${SCRIPT_DIR}/tasks/"
                exit 1
            fi
        fi

        # Queue management
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY_RUN] queue: ${TASK_ID} → running (skipped)"
        else
            local queue_pos=""
            for q in pending running done blocked; do
                if [[ -e "${SCRIPT_DIR}/queue/${q}/${TASK_ID}" ]]; then
                    queue_pos="$q"; break
                fi
            done

            if [[ -z "$queue_pos" ]]; then
                touch "${SCRIPT_DIR}/queue/running/${TASK_ID}"
                echo "[TASK] Registered in running queue"
            elif [[ "$queue_pos" == "pending" ]]; then
                move_queue "$TASK_ID" "pending" "running"
            elif [[ "$queue_pos" == "running" ]]; then
                echo "[INFO] Task already in running queue"
            elif [[ "$queue_pos" == "done" ]]; then
                if [[ "$FORCE" != "true" ]]; then
                    echo "[ERROR] Task ${TASK_ID} is already in 'done' queue. Use --force to re-run."
                    exit 1
                fi
                echo "[WARN] --force: re-running completed task ${TASK_ID}"
                move_queue "$TASK_ID" "done" "running"
            elif [[ "$queue_pos" == "blocked" ]]; then
                if [[ "$FORCE" != "true" ]]; then
                    echo "[ERROR] Task ${TASK_ID} is BLOCKED (human intervention required). Use hforce ${TASK_ID} or --force to override."
                    exit 1
                fi
                echo "[WARN] --force: overriding BLOCKED task ${TASK_ID}"
                move_queue "$TASK_ID" "blocked" "running"
            else
                echo "[WARN] Task in unknown queue=${queue_pos} — moving to running"
                move_queue "$TASK_ID" "$queue_pos" "running"
            fi

            # Pre-execution C1 gate: abort if same task marker exists in multiple queues
            local _precheck_sh="${SCRIPT_DIR}/queue/check_consistency.sh"
            if [[ -f "$_precheck_sh" ]]; then
                if ! bash "$_precheck_sh" > /dev/null 2>&1; then
                    echo "[ERROR] Pre-execution queue consistency check FAILED:"
                    bash "$_precheck_sh" >&2 || true
                    exit 1
                fi
            fi
        fi

        main_loop "PLAN"

        # ── Auto-chain: find and start next pending task ───────
        if [[ "$NO_CHAIN" == "true" ]]; then
            break
        fi

        # Determine effective result for chain decision
        local final_result
        if [[ "$DRY_RUN" == "true" ]]; then
            # In dry-run: state is not written — fall back to task's .state.json
            local dry_status
            dry_status=$(jq -r '.status // "PASS"' "${SCRIPT_DIR}/tasks/${TASK_ID}.state.json" 2>/dev/null || echo "PASS")
            case "$dry_status" in
                BLOCKED|INTERRUPTED) final_result="$dry_status" ;;
                *) final_result="PASS" ;;
            esac
        else
            final_result=$(jq -r '.result // "UNKNOWN"' "$STATE_FILE" 2>/dev/null || echo "UNKNOWN")
        fi

        if [[ "$final_result" == "BLOCKED" || "$final_result" == "INTERRUPTED" ]]; then
            echo "[CHAIN] ${TASK_ID} ${final_result} — 자동 연계 중단. 사용자 개입 필요"
            break
        fi

        if [[ "$final_result" != "PASS" ]]; then
            echo "[CHAIN] ${TASK_ID} result=${final_result} — 연계 중단"
            break
        fi

        # Pick next pending task
        local PREV_TASK_ID="$TASK_ID"
        local NEXT_TASK_ID
        NEXT_TASK_ID=$(ls -1 "${SCRIPT_DIR}/queue/pending/" 2>/dev/null | head -1 || true)

        if [[ -z "$NEXT_TASK_ID" ]]; then
            echo "[CHAIN] 모든 pending task 완료"
            break
        fi

        # Record chain metadata in active_state.json
        if [[ "$DRY_RUN" != "true" && -f "$STATE_FILE" ]]; then
            local _ctmp
            _ctmp=$(mktemp)
            if ! { jq --argjson c true \
                   --arg from "$PREV_TASK_ID" \
                   --arg to "$NEXT_TASK_ID" \
                   '.auto_chained = $c | .chained_from = $from | .chained_to = $to | .last_updated = (now | todate)' \
                   "$STATE_FILE" > "$_ctmp" \
                && mv "$_ctmp" "$STATE_FILE" \
                && jq -e . "$STATE_FILE" > /dev/null; }; then
                echo "[WARN] chain metadata write failed — proceeding anyway"
            fi
        else
            echo "[DRY_RUN] auto_chained: ${PREV_TASK_ID} → ${NEXT_TASK_ID}"
        fi

        echo "[CHAIN] ✓ ${PREV_TASK_ID} DONE → ${NEXT_TASK_ID} 자동 연계 시작"
        TASK_ID="$NEXT_TASK_ID"
    done
}

# ── cmd: --chain (hchain) ─────────────────────────────────────
# Starts auto-chain from first pending task (or from provided TASK_ID)
# With --from/--to: run tasks in range (pending queue, sorted, inclusive)
# With --select: run specified tasks only (comma-separated)
cmd_chain() {
    echo "[CHAIN] pending task 자동 순차 실행 시작..."

    # ── Ranged / selected execution mode ─────────────────────
    if [[ -n "$CHAIN_SELECT" || -n "$CHAIN_FROM" || -n "$CHAIN_TO" ]]; then
        local task_list=()

        if [[ -n "$CHAIN_SELECT" ]]; then
            # --select: comma-separated TASK_IDs
            IFS=',' read -ra raw_ids <<< "$CHAIN_SELECT"
            for tid in "${raw_ids[@]}"; do
                tid=$(echo "$tid" | tr -d '[:space:]')
                validate_task_id_format "$tid"
                if [[ -e "${SCRIPT_DIR}/queue/done/${tid}" ]]; then
                    echo "[CHAIN] skip (done): ${tid}"
                    continue
                fi
                task_list+=("$tid")
            done
        else
            # --from/--to: range within pending queue (sorted)
            [[ -n "$CHAIN_FROM" ]] && validate_task_id_format "$CHAIN_FROM"
            [[ -n "$CHAIN_TO" ]]   && validate_task_id_format "$CHAIN_TO"

            local all_pending=()
            while IFS= read -r tid; do
                [[ -n "$tid" ]] && all_pending+=("$tid")
            done < <(ls -1 "${SCRIPT_DIR}/queue/pending/" 2>/dev/null | sort)

            local in_range=false
            [[ -z "$CHAIN_FROM" ]] && in_range=true

            for tid in "${all_pending[@]}"; do
                [[ "$tid" == "$CHAIN_FROM" ]] && in_range=true
                if [[ "$in_range" == "true" ]]; then
                    if [[ -e "${SCRIPT_DIR}/queue/done/${tid}" ]]; then
                        echo "[CHAIN] skip (done): ${tid}"
                    else
                        task_list+=("$tid")
                    fi
                fi
                [[ "$tid" == "$CHAIN_TO" ]] && break
            done
        fi

        if [[ ${#task_list[@]} -eq 0 ]]; then
            echo "[CHAIN] 실행 대상 task 없음 — 종료"
            return 0
        fi

        echo "[CHAIN] 실행 대상 목록 (${#task_list[@]}개):"
        for tid in "${task_list[@]}"; do
            echo "  - ${tid}"
        done

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY_RUN] 실행 예정 목록 출력 완료 — 실제 실행 없음"
            return 0
        fi

        NO_CHAIN=true
        for tid in "${task_list[@]}"; do
            TASK_ID="$tid"
            echo ""
            echo "[CHAIN] ▶ 시작: ${TASK_ID}"
            cmd_task

            local final_result
            if [[ "$DRY_RUN" == "true" ]]; then
                local dry_status
                dry_status=$(jq -r '.status // "PASS"' \
                    "${SCRIPT_DIR}/tasks/${TASK_ID}.state.json" 2>/dev/null || echo "PASS")
                case "$dry_status" in
                    BLOCKED|INTERRUPTED) final_result="$dry_status" ;;
                    *) final_result="PASS" ;;
                esac
            else
                final_result=$(jq -r '.result // "UNKNOWN"' "$STATE_FILE" 2>/dev/null || echo "UNKNOWN")
            fi

            if [[ "$final_result" == "BLOCKED" || "$final_result" == "INTERRUPTED" ]]; then
                echo "[CHAIN] ${TASK_ID} ${final_result} — 체인 중단. 이후 task는 pending 유지"
                return 0
            fi
            if [[ "$final_result" != "PASS" ]]; then
                echo "[CHAIN] ${TASK_ID} result=${final_result} — 체인 중단"
                return 0
            fi
        done
        echo "[CHAIN] ✓ 선택 실행 완료"
        return 0
    fi

    # ── Default mode (original behavior unchanged) ────────────
    if [[ -z "$TASK_ID" ]]; then
        TASK_ID=$(ls -1 "${SCRIPT_DIR}/queue/pending/" 2>/dev/null | head -1 || true)
        if [[ -z "$TASK_ID" ]]; then
            echo "[CHAIN] pending task 없음 — 종료"
            return 0
        fi
        echo "[CHAIN] 시작 task: ${TASK_ID}"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY_RUN] 실행 예정 task: ${TASK_ID} — 실제 실행 없음"
        return 0
    fi

    NO_CHAIN=false
    cmd_task
}

# ── main_loop <start_step> ────────────────────────────────────
# Core execution engine. Accepts start_step to support resume from any phase.
main_loop() {
    local start_step="${1:-PLAN}"
    local si
    si=$(step_idx "$start_step")

    local validate_label="VALIDATE"
    [[ "$SKIP_VALIDATE" == "true" ]] && validate_label="[SKIP VALIDATE]"
    echo "================================================================"
    echo "[HARNESS] START  task_id=${TASK_ID}  mode=${MODE}  start_step=${start_step}  dry_run=${DRY_RUN}  override_severity=${OVERRIDE_SEVERITY:-none}"
    echo "[HARNESS] FLOW   PLAN → RESEARCH → ACTION → REVIEW → ${validate_label} → DONE"
    echo "================================================================"

    # §10 Pre-flight: only for fresh PLAN start (skip when resuming)
    if [[ "$si" -eq 0 && -f "$STATE_FILE" && "$DRY_RUN" != "true" ]]; then
        local hcr lc
        hcr=$(jq -r '.human_checkpoint_required // false' "$STATE_FILE" 2>/dev/null || echo "false")
        lc=$(jq -r '.loop_count // 0' "$STATE_FILE" 2>/dev/null || echo "0")
        if [[ "$hcr" == "true" ]]; then
            echo "[BLOCKED] human_checkpoint_required=true in active_state.json"
            echo "[BLOCKED] Resolve before re-running."
            exit 1
        fi
        if [[ "$lc" -ge 3 ]]; then
            echo "[BLOCKED] loop_count=${lc} >= 3 in active_state.json"
            echo "[BLOCKED] Manual intervention required."
            exit 1
        fi
    fi

    # ── PLAN ─────────────────────────────────────────────────
    if [[ "$si" -le 0 ]]; then
        phase_plan
    fi

    # ── RESEARCH ─────────────────────────────────────────────
    local gate_result=0
    if [[ "$si" -le 1 ]]; then
        gate_result=0
        gate_check "RESEARCH" || gate_result=$?
        if [[ "$gate_result" -eq 2 ]]; then
            state_set '.skipped_stages += ["RESEARCH"] | .notes = "RESEARCH_SKIPPED_BY_USER"'
            echo "[RESEARCH] Skipped by user"
        else
            phase_research
        fi
    fi

    # Restore REVIEWER_JSON when resuming from VALIDATE (needs REVIEWER result for decision_branch)
    if [[ "$si" -ge 4 && -z "$REVIEWER_JSON" && "$DRY_RUN" != "true" ]]; then
        local _rj
        _rj=$(ls -t "${LOGS_DIR}"/*_REVIEWER_"${TASK_ID}".json 2>/dev/null | head -1 || true)
        if [[ -n "$_rj" && -f "$_rj" ]]; then
            REVIEWER_JSON="$_rj"
            echo "[RESUME] Restored REVIEWER_JSON=${REVIEWER_JSON}"
        fi
    fi

    # ── ACTION → REVIEW → VALIDATE → DECISION loop ───────────
    local first_iter=true
    while true; do
        local action_skipped=false
        local review_skipped=false
        local changed_files=""
        gate_result=0

        # ── ACTION ───────────────────────────────────────────
        # Fast-forward on first iter when resuming from REVIEW or VALIDATE
        if [[ "$first_iter" == "true" && "$si" -ge 3 ]]; then
            echo "[ACTION] Fast-forward (resuming from ${start_step})"
        else
            gate_result=0
            gate_check "ACTION" || gate_result=$?
            if [[ "$gate_result" -eq 2 ]]; then
                state_set '.skipped_stages += ["ACTION"] | .notes = "ACTION_SKIPPED_BY_USER"'
                echo "[ACTION] Skipped by user"
                action_skipped=true
            else
                phase_action
            fi
        fi

        # REVIEW auto-skip when ACTION was user-skipped with no changed files
        if [[ "$action_skipped" == "true" ]]; then
            changed_files=$(git diff --name-only HEAD 2>/dev/null || true)
            if [[ -z "$changed_files" ]]; then
                state_set '.skipped_stages += ["REVIEW"] | .notes = "REVIEW_AUTO_SKIPPED_NO_CHANGES"'
                echo "[REVIEW] Auto-skipped (no changed files after ACTION skip)"
                review_skipped=true
            fi
        fi

        # ── REVIEW ───────────────────────────────────────────
        # Fast-forward on first iter when resuming from VALIDATE
        if [[ "$first_iter" == "true" && "$si" -ge 4 && "$review_skipped" == "false" ]]; then
            echo "[REVIEW] Fast-forward (resuming from ${start_step})"
        elif [[ "$review_skipped" == "false" ]]; then
            gate_result=0
            gate_check "REVIEW" || gate_result=$?
            if [[ "$gate_result" -eq 2 ]]; then
                state_set '.skipped_stages += ["REVIEW"] | .notes = "REVIEW_SKIPPED_BY_USER"'
                echo "[REVIEW] Skipped by user"
                review_skipped=true
            else
                phase_review
            fi
        fi

        first_iter=false

        if [[ "$review_skipped" == "true" ]]; then
            echo "[HARNESS] REVIEW skipped — ending run without DONE verdict"
            break
        fi

        # ── VALIDATE ─────────────────────────────────────────
        if [[ "$SKIP_VALIDATE" != "true" ]]; then
            gate_result=0
            gate_check "VALIDATE" || gate_result=$?
            if [[ "$gate_result" -eq 2 ]]; then
                state_set '.skipped_stages += ["VALIDATE"] | .notes = "VALIDATE_SKIPPED_BY_USER_REQUEST"'
                echo "[VALIDATE] Skipped by user"
                SKIP_VALIDATE="true"
            fi
        fi

        if [[ "$SKIP_VALIDATE" == "true" ]]; then
            echo "[VALIDATE] Skipped"
        else
            phase_validate
        fi

        # Post-VALIDATE queue/state consistency check (§6 requirement)
        local check_sh="${SCRIPT_DIR}/queue/check_consistency.sh"
        if [[ "$DRY_RUN" != "true" && -f "$check_sh" ]]; then
            if ! bash "$check_sh" --extended > /dev/null 2>&1; then
                echo "[WARN] Post-VALIDATE consistency check FAIL — see: bash ${check_sh} --extended"
            fi
        fi

        # decision_branch: returns 0 (done) or 1 (retry ACTION)
        if decision_branch; then
            break
        fi
    done

    echo "================================================================"
    echo "[HARNESS] DONE  task_id=${TASK_ID}"
    if [[ "$DRY_RUN" != "true" ]]; then
        jq '{task_id, step, loop_count, result, human_checkpoint_required}' "$STATE_FILE"
    fi

    # Auto-commit checkpoint: only when --auto-commit (or HARNESS_AUTO_COMMIT=1)
    if [[ "$AUTO_COMMIT" == "true" ]]; then
        git_checkpoint "$TASK_ID"
    fi

    # ── Planner Auto Hook ─────────────────────────────────────────
    # Activated only when HCHAIN_PLANNER_AUTO=1 (default: off).
    # Runs planner_feedback.sh after a PASS result; failure is non-fatal (WARN only).
    if [[ "$HCHAIN_PLANNER_AUTO" == "1" && "$DRY_RUN" != "true" ]]; then
        local _pr _planner_sh _pec _mission_id
        _pr=$(jq -r '.result // "UNKNOWN"' "$STATE_FILE" 2>/dev/null || echo "UNKNOWN")
        _planner_sh="${SCRIPT_DIR}/planner/planner_feedback.sh"
        _pec=0

        if [[ "$_pr" == "PASS" ]]; then
            # ── Mission Context 자동 탐지 ──────────────────────────
            _mission_id=""

            # 1. active_state.json의 mission_id 필드
            if [[ -z "$_mission_id" && -f "$STATE_FILE" ]]; then
                _mission_id=$(jq -r '.mission_id // ""' "$STATE_FILE" 2>/dev/null || true)
            fi

            # 2. missions/**/mission_state.json 중 mission_status == "RUNNING" 첫 번째
            if [[ -z "$_mission_id" && -d "${SCRIPT_DIR}/missions" ]]; then
                while IFS= read -r -d '' _msf; do
                    local _ms
                    _ms=$(jq -r '.mission_status // ""' "$_msf" 2>/dev/null || true)
                    if [[ "$_ms" == "RUNNING" ]]; then
                        _mission_id=$(jq -r '.mission_id // ""' "$_msf" 2>/dev/null || true)
                        [[ -n "$_mission_id" ]] && break
                    fi
                done < <(find "${SCRIPT_DIR}/missions" -name "mission_state.json" -print0 2>/dev/null | sort -z)
            fi

            # 3. 환경변수 fallback
            if [[ -z "$_mission_id" ]]; then
                _mission_id="$HCHAIN_MISSION_ID"
            fi

            if [[ -z "$_mission_id" ]]; then
                echo "[WARN] Planner SKIP — no Mission Context detected (set HCHAIN_MISSION_ID or ensure a RUNNING mission exists)"
            elif [[ ! -f "$_planner_sh" ]]; then
                echo "[PLANNER] SKIP — planner_feedback.sh not found: ${_planner_sh}"
            else
                echo "[PLANNER] AUTO MODE ENABLED"
                echo "[PLANNER] Mission: ${_mission_id} (auto-detected)"
                echo "[PLANNER] Executing planner_feedback.sh ${_mission_id} ${TASK_ID}"
                bash "$_planner_sh" "${_mission_id}" "${TASK_ID}" || _pec=$?
                if [[ "$_pec" -eq 0 ]]; then
                    echo "[PLANNER] SUCCESS"
                else
                    echo "[WARN] Planner execution failed (exit ${_pec})"
                fi
            fi
        fi
    fi

    echo "================================================================"
}

# ── cmd: --findings ──────────────────────────────────────────
cmd_findings() {
    case "$FINDINGS_MODE" in
        open)
            findings_list_open ;;
        materialize)
            findings_materialize "$TASK_ID" ;;
        *)
            findings_summary ;;
    esac
}

# ── Main dispatcher ───────────────────────────────────────────
main() {
    case "$MODE" in
        list)     cmd_list ;;
        status)   cmd_status ;;
        resume)   cmd_resume ;;
        task)     cmd_task ;;
        chain)    cmd_chain ;;
        findings) cmd_findings ;;
        *)
            echo "[ERROR] Unknown mode: ${MODE}"; usage; exit 1 ;;
    esac
}

main
