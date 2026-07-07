#!/usr/bin/env bash
# harness/lib/git_checkpoint.sh — Auto Git Checkpoint for Harness
#
# Source from harness_runner.sh:
#   source "${SCRIPT_DIR}/lib/git_checkpoint.sh"
#
# Requires from parent scope:
#   STATE_FILE, LOGS_DIR, SCRIPT_DIR, DRY_RUN, SKIP_VALIDATE
#
# Entry point:
#   git_checkpoint <task_id>
#
# Commits only when: step=DONE, result=PASS|SUCCESS, git has changes.
# FAIL/BLOCKED/INTERRUPTED tasks are never committed.
# In DRY_RUN mode: previews commit message, creates no commit.

# ── Title extraction ──────────────────────────────────────────
# Priority: frontmatter title > first H1 > notes > task_id
_gc_extract_title() {
    local task_id="$1"
    local task_file="${SCRIPT_DIR}/tasks/${task_id}.md"

    if [[ -f "$task_file" ]]; then
        # 1. YAML frontmatter title:
        local fm_title
        fm_title=$(awk '
            NR==1 && /^---[[:space:]]*$/ { in_front=1; next }
            /^---[[:space:]]*$/ && in_front { exit }
            in_front && /^title:/ {
                sub(/^title:[[:space:]]*/, ""); print; exit
            }
        ' "$task_file" 2>/dev/null | tr -d '\r')
        if [[ -n "$fm_title" ]]; then
            echo "$fm_title"; return 0
        fi

        # 2. First Markdown H1 heading
        local h1
        h1=$(grep -m1 '^# ' "$task_file" 2>/dev/null | sed 's/^# //' | tr -d '\r')
        if [[ -n "$h1" ]]; then
            echo "$h1"; return 0
        fi
    fi

    # 3. active_state.json notes (first non-machine-code segment)
    if [[ -f "${STATE_FILE:-}" ]]; then
        local notes
        notes=$(jq -r '.notes // ""' "$STATE_FILE" 2>/dev/null | head -1)
        if [[ -n "$notes" && "$notes" != "null" && ! "$notes" =~ ^[A-Z_]+$ ]]; then
            # Truncate at first " | " separator if present
            echo "${notes%% | *}" | cut -c1-80; return 0
        fi
    fi

    # 4. Fallback: task_id itself
    echo "$task_id"
}

# ── Summary extraction ────────────────────────────────────────
# Priority: notes > validator checks > reviewer status > git diff --stat > fallback
_gc_extract_summary() {
    local task_id="$1"
    local summary_lines=()

    # 1. active_state.json notes — split by " | " separator
    if [[ -f "${STATE_FILE:-}" ]]; then
        local raw_notes
        raw_notes=$(jq -r '.notes // ""' "$STATE_FILE" 2>/dev/null)
        if [[ -n "$raw_notes" && "$raw_notes" != "null" ]]; then
            local parts
            IFS='|' read -ra parts <<< "$raw_notes"
            for part in "${parts[@]}"; do
                part=$(printf '%s' "$part" | sed 's/^[[:space:]]*//' | tr -d '\r')
                [[ -z "$part" ]] && continue
                # Skip pure machine-code tokens like VALIDATE_SKIPPED_BY_USER_REQUEST
                [[ "$part" =~ ^[A-Z_]+$ ]] && continue
                summary_lines+=("$part")
                [[ ${#summary_lines[@]} -ge 3 ]] && break
            done
        fi
    fi

    # 2. Latest VALIDATOR log — list passed checks
    if [[ ${#summary_lines[@]} -lt 3 ]]; then
        local v_log
        v_log=$(ls -t "${LOGS_DIR}"/*_VALIDATOR_"${task_id}".json 2>/dev/null | head -1 || true)
        if [[ -n "$v_log" && -f "$v_log" ]]; then
            local v_checks
            v_checks=$(jq -r '
                (if has("payload") then .payload else . end) |
                .checks[]? | select(.result=="PASS") |
                .type + " PASS"
            ' "$v_log" 2>/dev/null | head -2 || true)
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                summary_lines+=("$line")
                [[ ${#summary_lines[@]} -ge 5 ]] && break
            done <<< "$v_checks"
        fi
    fi

    # 3. Latest REVIEWER log status
    if [[ ${#summary_lines[@]} -lt 2 ]]; then
        local r_log
        r_log=$(ls -t "${LOGS_DIR}"/*_REVIEWER_"${task_id}".json 2>/dev/null | head -1 || true)
        if [[ -n "$r_log" && -f "$r_log" ]]; then
            local r_status
            r_status=$(jq -r '.status // "UNKNOWN"' "$r_log" 2>/dev/null)
            summary_lines+=("REVIEWER ${r_status}")
        fi
    fi

    # 4. git diff --stat summary line
    if [[ ${#summary_lines[@]} -eq 0 ]]; then
        local stat
        stat=$(git diff --stat HEAD 2>/dev/null | tail -1 | sed 's/^[[:space:]]*//' || true)
        [[ -n "$stat" ]] && summary_lines+=("$stat")
    fi

    # 5. Fallback
    if [[ ${#summary_lines[@]} -eq 0 ]]; then
        summary_lines+=("${task_id} completed successfully")
    fi

    local i=0
    for line in "${summary_lines[@]}"; do
        printf -- "- %s\n" "$line"
        (( i++ )) || true
        [[ $i -ge 5 ]] && break
    done
}

# ── Changed files list ────────────────────────────────────────
_gc_changed_files() {
    local output
    output=$(git status --porcelain 2>/dev/null)

    if [[ -z "$output" ]]; then
        echo "- (변경사항 없음)"; return 0
    fi

    while IFS= read -r line; do
        local xy="${line:0:2}"
        local fname="${line:3}"
        local sc

        case "$xy" in
            "M " | " M" | "MM") sc="M" ;;
            "A " | " A")        sc="A" ;;
            "D " | " D")        sc="D" ;;
            "R " | " R")        sc="R" ;;
            "C " | " C")        sc="C" ;;
            "??")               sc="A" ;;
            *)                  sc="${xy:0:1}" ;;
        esac

        printf -- "- %s %s\n" "$sc" "$fname"
    done <<< "$output" | head -30
}

# ── Review / Validate status ──────────────────────────────────
_gc_review_status() {
    local task_id="$1"
    local r_log
    r_log=$(ls -t "${LOGS_DIR}"/*_REVIEWER_"${task_id}".json 2>/dev/null | head -1 || true)
    if [[ -n "$r_log" && -f "$r_log" ]]; then
        jq -r '.status // "UNKNOWN"' "$r_log" 2>/dev/null || echo "UNKNOWN"
    else
        echo "UNKNOWN"
    fi
}

_gc_validate_status() {
    local task_id="$1"
    if [[ "${SKIP_VALIDATE:-false}" == "true" ]]; then
        echo "SKIP"; return 0
    fi
    local v_log
    v_log=$(ls -t "${LOGS_DIR}"/*_VALIDATOR_"${task_id}".json 2>/dev/null | head -1 || true)
    if [[ -n "$v_log" && -f "$v_log" ]]; then
        jq -r '.status // "UNKNOWN"' "$v_log" 2>/dev/null || echo "UNKNOWN"
    else
        echo "UNKNOWN"
    fi
}

# ── Risk notes ────────────────────────────────────────────────
_gc_notes_field() {
    local task_id="$1"
    local r_log
    r_log=$(ls -t "${LOGS_DIR}"/*_REVIEWER_"${task_id}".json 2>/dev/null | head -1 || true)
    if [[ -n "$r_log" && -f "$r_log" ]]; then
        local minor_count
        minor_count=$(jq '
            (if has("payload") then .payload else . end) |
            [.issues[]? | select(.severity=="MINOR" or .severity=="NIT")] | length
        ' "$r_log" 2>/dev/null || echo "0")
        if [[ "$minor_count" -gt 0 ]]; then
            echo "MINOR/NIT 이슈 ${minor_count}건 잔존 — 코드 품질 개선 권장"
            return 0
        fi
    fi
    echo "없음"
}

# ── Main entry point ──────────────────────────────────────────
# git_checkpoint <task_id>
# Checks all preconditions, builds commit message, commits.
git_checkpoint() {
    local task_id="$1"

    echo ""
    echo "[GIT_CHECKPOINT] task_id=${task_id} auto_commit=ON"

    # Guard: must be inside a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "[GIT_CHECKPOINT] Skip: not a git repository"; return 0
    fi

    # Guard: STATE_FILE must exist
    if [[ ! -f "${STATE_FILE:-}" ]]; then
        echo "[GIT_CHECKPOINT] Skip: STATE_FILE not found"; return 0
    fi

    # Guard: step must be DONE
    local final_step final_result
    final_step=$(jq -r '.step // ""' "$STATE_FILE" 2>/dev/null)
    final_result=$(jq -r '.result // ""' "$STATE_FILE" 2>/dev/null)

    if [[ "$final_step" != "DONE" ]]; then
        echo "[GIT_CHECKPOINT] Skip: step=${final_step} (requires DONE)"; return 0
    fi

    # Guard: result must be PASS or SUCCESS (FAIL task is never committed)
    if [[ "$final_result" != "PASS" && "$final_result" != "SUCCESS" ]]; then
        echo "[GIT_CHECKPOINT] Skip: result=${final_result} — FAIL/BLOCKED task는 commit하지 않음"
        return 0
    fi

    # Guard: working tree must have changes
    local has_changes
    has_changes=$(git status --porcelain 2>/dev/null | wc -l)
    if [[ "$has_changes" -eq 0 ]]; then
        echo "[GIT_CHECKPOINT] No git changes. Skip auto commit."; return 0
    fi

    # Extract commit message components
    local task_title loop_count r_status v_status summary changed notes_text

    task_title=$(_gc_extract_title "$task_id")
    loop_count=$(jq -r '.loop_count // 0' "$STATE_FILE" 2>/dev/null || echo "0")
    r_status=$(_gc_review_status "$task_id")
    v_status=$(_gc_validate_status "$task_id")
    summary=$(_gc_extract_summary "$task_id")
    changed=$(_gc_changed_files)
    notes_text=$(_gc_notes_field "$task_id")

    # Build commit message
    local commit_msg
    commit_msg=$(cat <<COMMIT_MSG
[harness][${task_id}] ${task_title}

Task:
- id: ${task_id}
- title: ${task_title}

Summary:
${summary}

Validation:
- REVIEW: ${r_status}
- VALIDATE: ${v_status}
- loop_count: ${loop_count}

Changed:
${changed}

Notes:
- ${notes_text}
COMMIT_MSG
)

    # Dry-run: preview only, no commit
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo "[GIT_CHECKPOINT] DRY_RUN: commit message preview:"
        echo "────────────────────────────────────────────"
        echo "$commit_msg"
        echo "────────────────────────────────────────────"
        echo "[GIT_CHECKPOINT] DRY_RUN: no actual commit created"
        return 0
    fi

    # Stage files (respect .gitignore; exclude sensitive files)
    echo "[GIT_CHECKPOINT] Staging changes (${has_changes} items)..."
    if ! git add -A -- . \
            ':(exclude).env' \
            ':(exclude).env.*' \
            ':(exclude)*.env*' \
            ':(exclude)**/node_modules/**' \
            ':(exclude)node_modules/**' \
            2>/dev/null; then
        # Fallback for older git versions without pathspec exclude support
        git add -A 2>/dev/null || {
            echo "[GIT_CHECKPOINT] WARN: git add failed — skipping commit"; return 1
        }
    fi

    # Verify staged count
    local staged_count
    staged_count=$(git diff --cached --name-only 2>/dev/null | wc -l)
    if [[ "$staged_count" -eq 0 ]]; then
        echo "[GIT_CHECKPOINT] Nothing staged. Skip commit."; return 0
    fi

    # Create commit
    echo "[GIT_CHECKPOINT] Creating commit (${staged_count} files staged)..."
    if git commit -m "$commit_msg"; then
        local commit_hash
        commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
        echo "[GIT_CHECKPOINT] ✓ commit=${commit_hash}"
        echo "[GIT_CHECKPOINT] ✓ [harness][${task_id}] ${task_title}"
    else
        echo "[GIT_CHECKPOINT] WARN: git commit failed — check git status"
        return 1
    fi
}
