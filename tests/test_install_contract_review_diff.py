"""Tests for contract-code diff analysis (TASK-HCHAIN-CONTRACT-REVIEW-DIFF-001)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import (
    cmd_contract_review_diff,
    create_contracts_structure,
    _extract_api_names_from_contract,
    _scan_code_identifiers,
)


# ── _extract_api_names_from_contract ─────────────────────────────────────────

def test_extract_api_names_from_contract(tmp_path):
    content = (
        "## 목적\n내용\n\n"
        "## API\n"
        "POST /queue/enqueue\n"
        "GET /queue/status\n"
        "\n"
        "## 검증\n"
    )
    names = _extract_api_names_from_contract(content)
    assert "POST /queue/enqueue" in names
    assert "GET /queue/status" in names


def test_extract_api_names_empty_section(tmp_path):
    content = "## API\n작성 필요\n## 검증\n"
    names = _extract_api_names_from_contract(content)
    assert names == []


def test_extract_api_names_no_api_section():
    content = "## 목적\n내용\n"
    names = _extract_api_names_from_contract(content)
    assert names == []


# ── _scan_code_identifiers ────────────────────────────────────────────────────

def test_scan_detects_python_functions(tmp_path):
    (tmp_path / "app.py").write_text(
        "def enqueue(item):\n    pass\n"
        "async def dequeue():\n    pass\n",
        encoding="utf-8",
    )
    ids = _scan_code_identifiers(tmp_path)
    assert "enqueue" in ids
    assert "dequeue" in ids


def test_scan_ignores_pycache(tmp_path):
    cache = tmp_path / "__pycache__"
    cache.mkdir()
    (cache / "module.py").write_text("def secret_func(): pass\n", encoding="utf-8")
    ids = _scan_code_identifiers(tmp_path)
    assert "secret_func" not in ids


def test_scan_empty_dir(tmp_path):
    ids = _scan_code_identifiers(tmp_path)
    assert isinstance(ids, set)


# ── cmd_contract_review_diff ─────────────────────────────────────────────────

def test_review_diff_no_contracts_dir(tmp_path, capsys):
    result = cmd_contract_review_diff(tmp_path)
    assert result == {}
    out = capsys.readouterr().out
    assert "계약 없음" in out


def test_review_diff_returns_dict(tmp_path, capsys):
    create_contracts_structure(tmp_path, update=False)
    result = cmd_contract_review_diff(tmp_path)
    assert isinstance(result, dict)
    assert "계약에는 있으나 코드에 없음" in result
    assert "코드에는 있으나 계약에 없음" in result
    assert "API 불일치" in result
    assert "검증 누락" in result
    assert "상태 정의 불일치" in result


def test_review_diff_detects_missing_validation(tmp_path, capsys):
    create_contracts_structure(tmp_path, update=False)
    feature = tmp_path / "contracts" / "features" / "QUEUE.md"
    feature.write_text("# Queue\n\n## 목적\n큐 기능\n## 범위\n-\n", encoding="utf-8")
    result = cmd_contract_review_diff(tmp_path)
    assert any("QUEUE.md" in item for item in result["검증 누락"])


def test_review_diff_no_autofix(tmp_path, capsys):
    create_contracts_structure(tmp_path, update=False)
    feature = tmp_path / "contracts" / "features" / "QUEUE.md"
    feature.write_text("# Queue\n\n## 목적\n큐 기능\n", encoding="utf-8")
    mtime_before = feature.stat().st_mtime
    cmd_contract_review_diff(tmp_path)
    # File must not be modified (read-only)
    assert feature.stat().st_mtime == mtime_before


def test_review_diff_prints_categories(tmp_path, capsys):
    create_contracts_structure(tmp_path, update=False)
    cmd_contract_review_diff(tmp_path)
    out = capsys.readouterr().out
    assert "계약에는 있으나 코드에 없음" in out
    assert "코드에는 있으나 계약에 없음" in out
    assert "검증 누락" in out
