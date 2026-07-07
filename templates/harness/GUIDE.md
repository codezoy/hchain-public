# HCHAIN Harness — Quick Guide

## Usage

```bash
# Run a task
bash harness/harness_runner.sh --task TASK_20260101_001

# Resume interrupted task
bash harness/harness_runner.sh --resume TASK_20260101_001

# List all tasks
bash harness/harness_runner.sh --list

# Check queue consistency
bash harness/queue/check_consistency.sh
bash harness/queue/check_consistency.sh --extended
```

## Directory Structure

```
harness/
├── harness_runner.sh      # Main orchestrator
├── active_state.json      # Current task state
├── GUIDE.md               # This file
├── agents/                # AI agent prompts
│   ├── researcher.md
│   ├── reviewer.md
│   └── validator.md
├── docs/                  # Policy documents
│   ├── RULEBOOK.md
│   ├── TASK_GUIDE.md
│   └── VALIDATION_RULES.md
├── lib/                   # Shared shell libraries
│   ├── findings.sh
│   ├── git_checkpoint.sh
│   ├── policy.sh
│   └── task_meta.sh
├── queue/                 # Task queue directories
│   ├── pending/
│   ├── running/
│   ├── done/
│   ├── blocked/
│   ├── check_consistency.sh
│   └── move.sh
├── tasks/                 # Task definition files (TASK_*.md)
├── logs/                  # Execution logs
└── findings/              # Issue backlog
    ├── open/
    ├── accepted/
    ├── resolved/
    └── rejected/
```

## Requirements

- bash 4.0+ (macOS: `brew install bash`)
- jq
- gemini CLI (for RESEARCH phase)
- codex CLI (for REVIEW phase)

## Update

```bash
cd /path/to/hchain
./install.sh --target /path/to/project --update
```
