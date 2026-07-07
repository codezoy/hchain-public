#!/usr/bin/env bash
# Bootstrap a local .venv using only the standard library.
# install.py does NOT require .venv — this is optional for dev convenience.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 -m venv "$REPO_ROOT/.venv"
echo "[hchain] .venv created at $REPO_ROOT/.venv"
"$REPO_ROOT/.venv/bin/python3" --version
echo "[hchain] bootstrap complete — activate with: source .venv/bin/activate"
