"""Unit tests for contract-related functions in install.py."""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import (
    create_contracts_structure,
    inject_contract_first_policy,
    cmd_contract_check,
    CONTRACT_FIRST_START,
    CONTRACT_FIRST_END,
    CONTRACT_FIRST_BLOCK,
)


# ── create_contracts_structure ────────────────────────────────────────────────

def test_create_contracts_structure_new():
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        create_contracts_structure(target, update=False)
        contracts = target / "contracts"
        assert contracts.exists(), "contracts/ should be created"
        assert (contracts / "features").exists(), "features/ subdir should exist"
        for name in ("PROJECT.md", "ARCHITECTURE.md", "RULES.md", "VALIDATION.md", "DONE.md"):
            assert (contracts / name).exists(), f"{name} should exist"


def test_create_contracts_structure_update_preserves_user_content():
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        create_contracts_structure(target, update=False)
        user_contract = target / "contracts" / "PROJECT.md"
        user_contract.write_text("# 사용자 작성 내용\n\n중요한 계약\n", encoding="utf-8")
        create_contracts_structure(target, update=True)
        content = user_contract.read_text(encoding="utf-8")
        assert "중요한 계약" in content, "user content must be preserved on update"


def test_create_contracts_structure_update_creates_missing():
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        create_contracts_structure(target, update=False)
        (target / "contracts" / "ARCHITECTURE.md").unlink()
        create_contracts_structure(target, update=True)
        assert (target / "contracts" / "ARCHITECTURE.md").exists(), \
            "missing contract should be created on update"


def test_create_contracts_structure_idempotent():
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        for _ in range(3):
            create_contracts_structure(target, update=False)
        assert (target / "contracts" / "RULES.md").exists()


# ── inject_contract_first_policy ─────────────────────────────────────────────

def test_inject_contract_first_policy_appends_to_existing():
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        claude_md = target / "CLAUDE.md"
        claude_md.write_text("# 기존 규칙\n\n내용 보존 확인\n", encoding="utf-8")
        inject_contract_first_policy(target)
        content = claude_md.read_text(encoding="utf-8")
        assert "내용 보존 확인" in content, "existing content must be preserved"
        assert CONTRACT_FIRST_START in content
        assert CONTRACT_FIRST_END in content


def test_inject_contract_first_policy_idempotent():
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        (target / "CLAUDE.md").write_text("# Rules\n", encoding="utf-8")
        for _ in range(3):
            inject_contract_first_policy(target)
        content = (target / "CLAUDE.md").read_text(encoding="utf-8")
        assert content.count(CONTRACT_FIRST_START) == 1, "only one block allowed"
        assert content.count(CONTRACT_FIRST_END) == 1, "only one block allowed"


def test_inject_contract_first_policy_skips_missing_claude_md():
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        inject_contract_first_policy(target)
        assert not (target / "CLAUDE.md").exists(), "should not create CLAUDE.md"


def test_inject_contract_first_policy_replaces_existing_block():
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        old_block = f"{CONTRACT_FIRST_START}\n구버전 정책\n{CONTRACT_FIRST_END}\n"
        (target / "CLAUDE.md").write_text("# Rules\n\n" + old_block, encoding="utf-8")
        inject_contract_first_policy(target)
        content = (target / "CLAUDE.md").read_text(encoding="utf-8")
        assert "구버전 정책" not in content, "old block must be replaced"
        assert CONTRACT_FIRST_START in content


# ── cmd_contract_check ────────────────────────────────────────────────────────

def test_contract_check_no_contracts_dir(capsys):
    with tempfile.TemporaryDirectory() as d:
        cmd_contract_check(Path(d))
        out = capsys.readouterr().out
        assert "계약 없음" in out or "install" in out.lower()


def test_contract_check_clean_passes(capsys):
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        create_contracts_structure(target, update=False)
        cmd_contract_check(target)
        out = capsys.readouterr().out
        assert "이슈 없음" in out


def test_contract_check_detects_missing_sections(capsys):
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        create_contracts_structure(target, update=False)
        feature_file = target / "contracts" / "features" / "LOGIN.md"
        feature_file.write_text("# 로그인\n\n## 목적\n로그인 기능\n", encoding="utf-8")
        cmd_contract_check(target)
        out = capsys.readouterr().out
        assert "LOGIN.md" in out
        assert "누락" in out


def test_contract_check_write_adds_sections():
    with tempfile.TemporaryDirectory() as d:
        target = Path(d)
        create_contracts_structure(target, update=False)
        feature_file = target / "contracts" / "features" / "QUEUE.md"
        feature_file.write_text("# 큐\n\n## 목적\n큐 기능\n", encoding="utf-8")
        cmd_contract_check(target, write=True)
        content = feature_file.read_text(encoding="utf-8")
        assert "## 범위" in content, "missing section should be added in --write mode"
        assert "## 목적" in content, "existing section must be preserved"
        assert "큐 기능" in content, "existing content must be preserved"
