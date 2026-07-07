"""Tests for contract reference parsing and selection (TASK-HCHAIN-CONTRACT-REFERENCE-001)."""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import parse_contract_header, select_relevant_contracts, create_contracts_structure


# ── parse_contract_header ─────────────────────────────────────────────────────

def test_parse_header_with_valid_frontmatter(tmp_path):
    md = tmp_path / "QUEUE.md"
    md.write_text(
        "---\n"
        "관련 계약:\n"
        "- PROJECT.md\n"
        "- ARCHITECTURE.md\n"
        "\n"
        "영향 범위:\n"
        "- backend\n"
        "- worker\n"
        "\n"
        "관련 기능:\n"
        "- retry\n"
        "\n"
        "우선순위: 높음\n"
        "---\n"
        "\n"
        "# Queue 기능\n",
        encoding="utf-8",
    )
    result = parse_contract_header(md)
    assert result["관련_계약"] == ["PROJECT.md", "ARCHITECTURE.md"]
    assert result["영향_범위"] == ["backend", "worker"]
    assert result["관련_기능"] == ["retry"]
    assert result["우선순위"] == "높음"


def test_parse_header_no_frontmatter(tmp_path):
    md = tmp_path / "PLAIN.md"
    md.write_text("# 제목\n\n내용\n", encoding="utf-8")
    result = parse_contract_header(md)
    assert result == {}


def test_parse_header_empty_lists(tmp_path):
    md = tmp_path / "EMPTY.md"
    md.write_text(
        "---\n"
        "관련 계약:\n"
        "- PROJECT.md\n"
        "\n"
        "영향 범위: []\n"
        "관련 기능: []\n"
        "우선순위: 보통\n"
        "---\n"
        "# 기능\n",
        encoding="utf-8",
    )
    result = parse_contract_header(md)
    assert result["관련_계약"] == ["PROJECT.md"]
    assert result["영향_범위"] == []
    assert result["관련_기능"] == []


def test_parse_header_missing_file(tmp_path):
    result = parse_contract_header(tmp_path / "nonexistent.md")
    assert result == {}


# ── select_relevant_contracts ─────────────────────────────────────────────────

def test_select_always_includes_base_contracts(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    selected = select_relevant_contracts(tmp_path / "contracts", ["queue"])
    names = [p.name for p in selected]
    for base in ("PROJECT.md", "ARCHITECTURE.md", "RULES.md", "VALIDATION.md", "DONE.md"):
        assert base in names, f"Base contract {base} should always be included"


def test_select_matches_by_filename(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    features = tmp_path / "contracts" / "features"
    (features / "QUEUE.md").write_text("# Queue\n\n## 목적\n큐 기능\n", encoding="utf-8")
    (features / "AUTH.md").write_text("# Auth\n\n## 목적\n인증\n", encoding="utf-8")

    selected = select_relevant_contracts(tmp_path / "contracts", ["queue"])
    names = [p.name for p in selected]
    assert "QUEUE.md" in names
    assert "AUTH.md" not in names


def test_select_matches_by_frontmatter_impact(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    features = tmp_path / "contracts" / "features"
    # AUTH.md — no "queue" in name, but 영향 범위 includes worker which is a queue keyword
    (features / "AUTH.md").write_text(
        "---\n"
        "관련 계약:\n- PROJECT.md\n"
        "영향 범위:\n- worker\n- backend\n"
        "관련 기능:\n- queue\n"
        "우선순위: 보통\n"
        "---\n"
        "# Auth\n",
        encoding="utf-8",
    )
    selected = select_relevant_contracts(tmp_path / "contracts", ["queue"])
    names = [p.name for p in selected]
    assert "AUTH.md" in names


def test_select_empty_features_dir(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    # No feature files → only base contracts returned
    selected = select_relevant_contracts(tmp_path / "contracts", ["retry"])
    assert all(p.parent.name == "contracts" for p in selected)


def test_select_no_contracts_dir(tmp_path):
    selected = select_relevant_contracts(tmp_path / "contracts", ["queue"])
    assert selected == []


def test_template_md_excluded_from_selection(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    selected = select_relevant_contracts(tmp_path / "contracts", ["template"])
    names = [p.name for p in selected]
    assert "TEMPLATE.md" not in names
