#!/usr/bin/env bash
# harness/lib/task_meta.sh — Task YAML frontmatter parser
# Usage:
#   source harness/lib/task_meta.sh
#   parse_task_meta harness/tasks/TASK_20260515_002.md
#   echo "$TASK_TITLE"
#
# Exported vars: TASK_ID TASK_TITLE TASK_RETRY_LIMIT TASK_SEVERITY_STOP TASK_VALIDATE
#
# Fallback: if no frontmatter found, defaults are applied and function returns 0.
# No external dependencies (yq not required) — uses awk/grep/sed only.

# ── Defaults ──────────────────────────────────────────────────
_TASK_META_DEFAULT_RETRY_LIMIT=3
_TASK_META_DEFAULT_SEVERITY_STOP="MAJOR"
_TASK_META_DEFAULT_VALIDATE="true"

# ── parse_task_meta ───────────────────────────────────────────
# Args: $1 = path to task .md file
# Sets: TASK_ID, TASK_TITLE, TASK_RETRY_LIMIT, TASK_SEVERITY_STOP, TASK_VALIDATE
parse_task_meta() {
    local task_file="${1:-}"
    if [[ -z "$task_file" ]]; then
        echo "[task_meta] ERROR: no file argument" >&2
        return 1
    fi
    if [[ ! -f "$task_file" ]]; then
        echo "[task_meta] ERROR: file not found: $task_file" >&2
        return 1
    fi

    # Reset exported vars to defaults
    TASK_ID=""
    TASK_TITLE=""
    TASK_RETRY_LIMIT="$_TASK_META_DEFAULT_RETRY_LIMIT"
    TASK_SEVERITY_STOP="$_TASK_META_DEFAULT_SEVERITY_STOP"
    TASK_VALIDATE="$_TASK_META_DEFAULT_VALIDATE"

    # Extract frontmatter block: only if file starts with '---' on line 1
    local frontmatter
    frontmatter=$(awk '
        NR == 1 {
            if (/^---[[:space:]]*$/) { in_front = 1; next }
            else { exit }
        }
        /^---[[:space:]]*$/ && in_front == 1 { exit }
        in_front == 1 { print }
    ' "$task_file")

    if [[ -z "$frontmatter" ]]; then
        # No frontmatter — try to extract task_id from filename
        local basename
        basename=$(basename "$task_file" .md)
        if [[ "$basename" =~ ^TASK_[0-9]{8}_[0-9]{3}$ ]]; then
            TASK_ID="$basename"
        fi
        # Try to extract title from first '# Task:' line as fallback
        local title_line
        title_line=$(grep -m1 '^# Task:' "$task_file" 2>/dev/null || true)
        if [[ -n "$title_line" ]]; then
            TASK_TITLE="${title_line#\# Task: }"
        fi
        export TASK_ID TASK_TITLE TASK_RETRY_LIMIT TASK_SEVERITY_STOP TASK_VALIDATE
        return 0
    fi

    # Parse key: value pairs from frontmatter
    _parse_frontmatter_field() {
        local key="$1"
        echo "$frontmatter" | grep -m1 "^${key}:" | sed "s/^${key}:[[:space:]]*//" | tr -d '\r'
    }

    local v
    v=$(_parse_frontmatter_field "task_id"); [[ -n "$v" ]] && TASK_ID="$v"
    v=$(_parse_frontmatter_field "title");   [[ -n "$v" ]] && TASK_TITLE="$v"
    v=$(_parse_frontmatter_field "retry_limit"); [[ -n "$v" ]] && TASK_RETRY_LIMIT="$v"
    v=$(_parse_frontmatter_field "severity_stop"); [[ -n "$v" ]] && TASK_SEVERITY_STOP="$v"
    v=$(_parse_frontmatter_field "validate"); [[ -n "$v" ]] && TASK_VALIDATE="$v"

    # Fallback: derive task_id from filename if not in frontmatter
    if [[ -z "$TASK_ID" ]]; then
        local basename
        basename=$(basename "$task_file" .md)
        if [[ "$basename" =~ ^TASK_[0-9]{8}_[0-9]{3}$ ]]; then
            TASK_ID="$basename"
        fi
    fi

    export TASK_ID TASK_TITLE TASK_RETRY_LIMIT TASK_SEVERITY_STOP TASK_VALIDATE
    return 0
}
