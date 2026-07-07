#!/usr/bin/env bash
# harness/lib/policy.sh — Retry and severity-stop policy module
# Usage:
#   source harness/lib/policy.sh
#   result=$(decide_policy <highest_severity_found> <severity_stop> <loop_count> <retry_limit>)
#
# Returns: CONTINUE | RETRY | STOP | PASS_WITH_WARNINGS
#
# Severity ranking: CRITICAL(4) > MAJOR(3) > MINOR(2) > NIT(1) > none(0)
# Logic:
#   - no severity (rank 0)           → CONTINUE
#   - severity < severity_stop       → PASS_WITH_WARNINGS
#   - severity >= severity_stop:
#       loop_count == 0              → STOP
#       0 < loop_count < retry_limit → RETRY
#       loop_count >= retry_limit    → STOP

_policy_sev_rank() {
    case "$1" in
        CRITICAL) echo 4 ;;
        MAJOR)    echo 3 ;;
        MINOR)    echo 2 ;;
        NIT)      echo 1 ;;
        *)        echo 0 ;;
    esac
}

decide_policy() {
    local severity="$1"
    local severity_stop="$2"
    local loop_count="$3"
    local retry_limit="$4"

    local sev_rank stop_rank
    sev_rank=$(_policy_sev_rank "$severity")
    stop_rank=$(_policy_sev_rank "$severity_stop")

    if [[ "$sev_rank" -eq 0 ]]; then
        echo "CONTINUE"
        return 0
    fi

    if [[ "$sev_rank" -lt "$stop_rank" ]]; then
        echo "PASS_WITH_WARNINGS"
        return 0
    fi

    # severity >= severity_stop
    if [[ "$loop_count" -eq 0 ]]; then
        echo "STOP"
    elif [[ "$loop_count" -lt "$retry_limit" ]]; then
        echo "RETRY"
    else
        echo "STOP"
    fi
}
