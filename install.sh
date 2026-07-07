#!/usr/bin/env bash
# install.sh — compatibility wrapper; delegates to install.py
# New users: use  python3 install.py --target <path>  directly.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/install.py" "$@"
