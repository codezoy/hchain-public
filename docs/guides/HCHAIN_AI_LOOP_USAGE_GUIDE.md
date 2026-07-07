# HCHAIN AI Loop Usage Guide

Explains how to run the Planner Feedback Loop with `mission_loop.sh` and `harness_runner.sh`.

---

## Overview

The AI Loop connects `harness_runner.sh` → `planner_feedback.sh` → `mission_state.json` into a
self-advancing pipeline. When `HCHAIN_PLANNER_AUTO=1`, a completed (PASS) task automatically
invokes the Planner Feedback hook, which reads the task report, creates new tasks in queue, and
updates `next_task` in `mission_state.json`. The outer loop in `mission_loop.sh` then picks up
the next task and runs it.

---

## Setting Options

### Method 1: Environment Variables (original)

```bash
export HARNESS_AUTO_CONFIRM=1
export HCHAIN_PLANNER_AUTO=1
export HCHAIN_MISSION_ID=MISSION-AI-VIDEO-VISUAL-AUDIT-001

bash harness/scripts/mission_loop.sh run \
  harness/missions/MISSION-AI-VIDEO-VISUAL-AUDIT-001/mission_state.json \
  --max-steps 10
```

### Method 2: CLI Options (new)

```bash
bash harness/scripts/mission_loop.sh run MISSION-AI-VIDEO-VISUAL-AUDIT-001 \
  --max-steps 10 \
  --planner-auto \
  --auto-confirm
```

Or for a single task run via `harness_runner.sh` directly:

```bash
bash harness/harness_runner.sh \
  --task TASK-006 \
  --mission MISSION-AI-VIDEO-VISUAL-AUDIT-001 \
  --planner-auto \
  --auto-confirm
```

CLI options take effect for that invocation only. They do not modify environment variables
permanently.

---

## CLI Option Reference

### mission_loop.sh

| Option | Equivalent Env Var | Description |
|---|---|---|
| `--max-steps N` | — | Max iterations before stopping (default: 5) |
| `--planner-auto` | `HCHAIN_PLANNER_AUTO=1` | Enable Planner Feedback hook after PASS |
| `--auto-confirm` | `HARNESS_AUTO_CONFIRM=1` | Bypass interactive gate confirmations |

### harness_runner.sh

| Option | Equivalent Env Var | Description |
|---|---|---|
| `--task TASK_ID` | — | Task ID to run (required) |
| `--mission MISSION_ID` | `HCHAIN_MISSION_ID=ID` | Set Mission context for Planner Feedback |
| `--planner-auto` | `HCHAIN_PLANNER_AUTO=1` | Enable Planner Feedback hook after PASS |
| `--auto-confirm` | `HARNESS_AUTO_CONFIRM=1` | Bypass interactive gate confirmations |
| `--dry-run` | — | Show plan without executing |
| `--skip-validate` | — | Skip VALIDATE phase |
| `--no-chain` | — | Disable chained task execution |

---

## Mission ID Resolution

`mission_loop.sh` accepts either a direct path or a MISSION_ID as its second argument:

```bash
# Direct path (original, still supported)
bash harness/scripts/mission_loop.sh run \
  harness/missions/MISSION-FOO-001/mission_state.json

# MISSION_ID (new — resolved to harness/missions/<ID>/mission_state.json)
bash harness/scripts/mission_loop.sh run MISSION-FOO-001
```

---

## Env Var Propagation

When CLI options are set in `mission_loop.sh`, they are exported as env vars before the loop
starts. This means `mission_step.sh` and `harness_runner.sh` (called as subprocesses) inherit
them automatically without explicit passthrough.

When `mission_step.sh` is called directly (not via `mission_loop.sh`), it reads `mission_id`
from the state file and exports `HCHAIN_MISSION_ID` if not already set in the environment.

---

## Planner Feedback Hook

When `HCHAIN_PLANNER_AUTO=1` and a task completes with PASS, `harness_runner.sh` calls:

```bash
bash planner/planner_feedback.sh <MISSION_ID> <TASK_ID>
```

The script reads `## Next Tasks (Planner Feed)` from the task report, creates new task files,
registers them in `queue/pending/`, and updates `mission_state.json` with the next task.

The loop then reads the updated `next_task` and continues.

---

## Currently Unsupported Features

The following are NOT implemented and should NOT be expected:

- **Agent Runtime**: No autonomous multi-agent spawning
- **Message Bus**: No inter-agent messaging
- **Auto Report Generation**: Reports must be written by Claude manually
- **Automatic Next Task execution without loop**: Single `mission_step.sh` always stops after one task

---

## Example: ai-video Mission

```bash
# Start loop for ai-video mission with planner auto-advance
bash harness/scripts/mission_loop.sh run MISSION-AI-VIDEO-VISUAL-AUDIT-001 \
  --max-steps 10 \
  --planner-auto \
  --auto-confirm

# Or with explicit state file path
bash harness/scripts/mission_loop.sh run \
  harness/missions/MISSION-AI-VIDEO-VISUAL-AUDIT-001/mission_state.json \
  --max-steps 10 \
  --planner-auto \
  --auto-confirm
```

Single task dry-run (no execution):

```bash
bash harness/harness_runner.sh \
  --task TASK-006 \
  --mission MISSION-AI-VIDEO-VISUAL-AUDIT-001 \
  --planner-auto \
  --auto-confirm \
  --dry-run
```
