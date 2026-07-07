#!/usr/bin/env bash
# harness/lib/findings.sh — Findings Backlog 관리 라이브러리
# collect_findings_from_log, findings_summary, findings_list_open, findings_materialize

FINDINGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../findings" && pwd)"

# Finding JSON 생성
# $1=source_task_id $2=source_agent $3=source_log $4=severity $5=category
# $6=title $7=description $8=files $9=suggested_action $10=suggested_task_title
_make_finding_json() {
  local source_task_id="$1"
  local source_agent="$2"
  local source_log="$3"
  local severity="$4"
  local category="$5"
  local title="$6"
  local description="$7"
  local files="$8"
  local suggested_action="$9"
  local suggested_task_title="${10}"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # dedupe_key: SHA256(source_task_id|severity|title|files|suggested_action)
  local dedupe_key
  dedupe_key=$(printf '%s|%s|%s|%s|%s' \
    "$source_task_id" "$severity" "$title" "$files" "$suggested_action" \
    | sha256sum | awk '{print $1}')

  jq -n \
    --arg finding_id "" \
    --arg source_task_id "$source_task_id" \
    --arg source_agent "$source_agent" \
    --arg source_log "$source_log" \
    --arg severity "$severity" \
    --arg category "$category" \
    --arg title "$title" \
    --arg description "$description" \
    --arg files "$files" \
    --arg suggested_action "$suggested_action" \
    --arg suggested_task_title "$suggested_task_title" \
    --arg status "open" \
    --arg dedupe_key "$dedupe_key" \
    --arg created_at "$ts" \
    '{
      finding_id: $finding_id,
      source_task_id: $source_task_id,
      source_agent: $source_agent,
      source_log: $source_log,
      severity: $severity,
      category: $category,
      title: $title,
      description: $description,
      files: $files,
      suggested_action: $suggested_action,
      suggested_task_title: $suggested_task_title,
      status: $status,
      dedupe_key: $dedupe_key,
      created_at: $created_at
    }'
}

# 중복 dedupe_key 확인 (open 디렉터리에서만 체크)
_is_duplicate() {
  local dedupe_key="$1"
  local existing
  existing=$(grep -rl "\"dedupe_key\": \"${dedupe_key}\"" "$FINDINGS_DIR/open/" 2>/dev/null | head -1)
  [[ -n "$existing" ]]
}

# 로그에서 MINOR/NIT/INFO 이슈를 추출하여 findings/open/ 에 저장
# $1=log_file $2=source_task_id
collect_findings_from_log() {
  local log_file="$1"
  local source_task_id="$2"

  [[ -f "$log_file" ]] || return 0
  jq -e . "$log_file" >/dev/null 2>&1 || return 0

  local source_agent
  source_agent=$(jq -r '.agent // (.payload.agent // "UNKNOWN")' "$log_file" 2>/dev/null)

  # 이슈 배열 추출: payload.issues 또는 issues (REVIEWER)
  # blocking_issues 또는 payload.blocking_issues (VALIDATOR)
  local issues_json
  if [[ "$source_agent" == "REVIEWER" ]]; then
    issues_json=$(jq -c '(if has("payload") then .payload else . end) | (.issues // [])' "$log_file" 2>/dev/null)
  else
    # VALIDATOR: blocking_issues
    issues_json=$(jq -c '(if has("payload") then .payload else . end) | (.blocking_issues // [])' "$log_file" 2>/dev/null)
  fi

  [[ -z "$issues_json" || "$issues_json" == "[]" ]] && return 0

  local saved=0
  local ts_prefix
  ts_prefix=$(date -u +%Y%m%d_%H%M%S)

  # 각 이슈를 처리 (MINOR / NIT / INFO 만, CRITICAL/MAJOR 제외)
  local idx=0
  while IFS= read -r issue; do
    local severity
    severity=$(echo "$issue" | jq -r '.severity // ""')
    case "$severity" in
      MINOR|NIT|INFO) ;;
      *) idx=$((idx+1)); continue ;;
    esac

    # 필드 추출 (description // .desc 양쪽 지원)
    local description
    description=$(echo "$issue" | jq -r '.description // .desc // ""')
    local suggestion
    suggestion=$(echo "$issue" | jq -r '.suggestion // ""')
    local file
    file=$(echo "$issue" | jq -r '.file // (.type // "")' 2>/dev/null)
    local line
    line=$(echo "$issue" | jq -r '.line // 0' 2>/dev/null)

    local title
    title="${severity}: ${description:0:80}"
    local files_str="${file}:${line}"
    local category="$source_agent"

    local suggested_task_title="[개선] ${description:0:60}"

    # finding JSON 생성
    local finding_json
    finding_json=$(_make_finding_json \
      "$source_task_id" \
      "$source_agent" \
      "$log_file" \
      "$severity" \
      "$category" \
      "$title" \
      "$description" \
      "$files_str" \
      "$suggestion" \
      "$suggested_task_title")

    local dedupe_key
    dedupe_key=$(echo "$finding_json" | jq -r '.dedupe_key')

    # 중복 확인
    if _is_duplicate "$dedupe_key"; then
      idx=$((idx+1))
      continue
    fi

    local finding_id
    finding_id="FINDING_${ts_prefix}_${source_task_id}_$(printf '%03d' $((saved+1)))"
    finding_json=$(echo "$finding_json" | jq --arg id "$finding_id" '.finding_id = $id')

    local out_path="${FINDINGS_DIR}/open/${finding_id}.json"
    echo "$finding_json" > "$out_path"
    saved=$((saved+1))
    idx=$((idx+1))
  done < <(echo "$issues_json" | jq -c '.[]')

  if [[ $saved -gt 0 ]]; then
    echo "[findings] $saved finding(s) saved from $source_agent log → findings/open/" >&2
  fi
}

# findings/open/ 요약 출력
findings_summary() {
  local open_count accepted_count resolved_count rejected_count
  open_count=$(find "$FINDINGS_DIR/open" -name '*.json' 2>/dev/null | wc -l)
  accepted_count=$(find "$FINDINGS_DIR/accepted" -name '*.json' 2>/dev/null | wc -l)
  resolved_count=$(find "$FINDINGS_DIR/resolved" -name '*.json' 2>/dev/null | wc -l)
  rejected_count=$(find "$FINDINGS_DIR/rejected" -name '*.json' 2>/dev/null | wc -l)

  echo "=== Findings Backlog Summary ==="
  echo "  open:     $open_count"
  echo "  accepted: $accepted_count"
  echo "  resolved: $resolved_count"
  echo "  rejected: $rejected_count"
  echo ""

  if [[ $open_count -gt 0 ]]; then
    echo "--- Open Findings (severity breakdown) ---"
    local minor_count nit_count info_count
    minor_count=$(find "$FINDINGS_DIR/open" -name '*.json' -exec grep -l '"severity": "MINOR"' {} \; 2>/dev/null | wc -l || true)
    nit_count=$(find "$FINDINGS_DIR/open" -name '*.json' -exec grep -l '"severity": "NIT"' {} \; 2>/dev/null | wc -l || true)
    info_count=$(find "$FINDINGS_DIR/open" -name '*.json' -exec grep -l '"severity": "INFO"' {} \; 2>/dev/null | wc -l || true)
    echo "  MINOR: $minor_count  NIT: $nit_count  INFO: $info_count"
  fi
}

# open findings 목록 출력
findings_list_open() {
  local files
  files=$(find "$FINDINGS_DIR/open" -name '*.json' 2>/dev/null | sort)
  if [[ -z "$files" ]]; then
    echo "[findings] No open findings."
    return 0
  fi

  echo "=== Open Findings ==="
  while IFS= read -r f; do
    local finding_id severity title source_task_id created_at
    finding_id=$(jq -r '.finding_id' "$f" 2>/dev/null)
    severity=$(jq -r '.severity' "$f" 2>/dev/null)
    title=$(jq -r '.title' "$f" 2>/dev/null)
    source_task_id=$(jq -r '.source_task_id' "$f" 2>/dev/null)
    created_at=$(jq -r '.created_at' "$f" 2>/dev/null)
    printf "  [%s] %-7s  %s  (from: %s, %s)\n" \
      "$finding_id" "$severity" "${title:0:70}" "$source_task_id" "$created_at"
  done <<< "$files"
}

# open finding을 draft task로 materialization
# $1=finding_id
findings_materialize() {
  local finding_id="$1"
  local finding_file="${FINDINGS_DIR}/open/${finding_id}.json"

  if [[ ! -f "$finding_file" ]]; then
    echo "[findings] ERROR: Finding not found: $finding_id" >&2
    return 1
  fi

  local suggested_task_title description
  suggested_task_title=$(jq -r '.suggested_task_title' "$finding_file")
  description=$(jq -r '.description' "$finding_file")

  # taskctl.sh new 로 task 생성
  local harness_dir
  harness_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local new_task_id
  new_task_id=$(bash "${harness_dir}/taskctl.sh" new "$suggested_task_title" 2>&1 | grep -oP 'TASK_\d+_\d+' | head -1)

  if [[ -z "$new_task_id" ]]; then
    echo "[findings] ERROR: Failed to create task from finding $finding_id" >&2
    return 1
  fi

  # task md에 찾은 이슈 내용 보완
  local task_md="${harness_dir}/tasks/${new_task_id}.md"
  if [[ -f "$task_md" ]]; then
    echo "" >> "$task_md"
    echo "## Source Finding" >> "$task_md"
    echo "- finding_id: ${finding_id}" >> "$task_md"
    echo "- description: ${description}" >> "$task_md"
    echo "- source_task_id: $(jq -r '.source_task_id' "$finding_file")" >> "$task_md"
  fi

  echo "[findings] Materialized: $finding_id → $new_task_id"
  echo "  Task title: $suggested_task_title"
  echo "  Queue: harness/queue/pending/$new_task_id"
}
