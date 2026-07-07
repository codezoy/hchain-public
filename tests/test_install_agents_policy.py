"""Unit tests for ensure_codex_agents_policy() in install.py."""

import sys
import os
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import (
    ensure_codex_agents_policy,
    CODEX_POLICY_START,
    CODEX_POLICY_END,
    CODEX_POLICY_BLOCK,
)


def _agents(tmpdir: str) -> Path:
    return Path(tmpdir) / "AGENTS.md"


def test_create_when_missing():
    with tempfile.TemporaryDirectory() as d:
        ensure_codex_agents_policy(Path(d))
        f = _agents(d)
        assert f.exists(), "AGENTS.md should be created"
        content = f.read_text(encoding="utf-8")
        assert CODEX_POLICY_START in content
        assert CODEX_POLICY_END in content


def test_append_when_existing_without_marker():
    with tempfile.TemporaryDirectory() as d:
        f = _agents(d)
        f.write_text("# Existing Rules\n\nDo not remove this line.\n", encoding="utf-8")
        ensure_codex_agents_policy(Path(d))
        content = f.read_text(encoding="utf-8")
        assert "Do not remove this line." in content, "existing content must be preserved"
        assert CODEX_POLICY_START in content
        assert CODEX_POLICY_END in content


def test_replace_when_marker_exists():
    with tempfile.TemporaryDirectory() as d:
        f = _agents(d)
        f.write_text(
            "# Existing Rules\n\n"
            f"{CODEX_POLICY_START}\nold policy content\n{CODEX_POLICY_END}\n",
            encoding="utf-8",
        )
        ensure_codex_agents_policy(Path(d))
        content = f.read_text(encoding="utf-8")
        assert "old policy content" not in content, "old policy block should be replaced"
        assert "Existing Rules" in content, "user content outside marker must be preserved"
        assert CODEX_POLICY_START in content
        assert CODEX_POLICY_END in content


def test_idempotent_repeat_update():
    with tempfile.TemporaryDirectory() as d:
        for _ in range(3):
            ensure_codex_agents_policy(Path(d))
        content = _agents(d).read_text(encoding="utf-8")
        assert content.count(CODEX_POLICY_START) == 1, "only one START marker allowed"
        assert content.count(CODEX_POLICY_END) == 1, "only one END marker allowed"


def test_preserves_existing_content():
    with tempfile.TemporaryDirectory() as d:
        f = _agents(d)
        original = "# My Custom Agent Rules\n\nLine A\nLine B\nLine C\n"
        f.write_text(original, encoding="utf-8")
        ensure_codex_agents_policy(Path(d))
        content = f.read_text(encoding="utf-8")
        for line in ["My Custom Agent Rules", "Line A", "Line B", "Line C"]:
            assert line in content, f"'{line}' must still exist in AGENTS.md"
