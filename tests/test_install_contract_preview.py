"""Tests for contract preview — TASK-HCHAIN-CONTRACT-PREVIEW-001."""

import sys
from io import StringIO
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import build_contract_preview, print_contract_preview


@pytest.fixture
def sample_preview(tmp_path):
    contract_path = tmp_path / "contracts" / "features" / "QUEUE_RETRY.md"
    return build_contract_preview(
        feature_name="QUEUE_RETRY",
        impacts=["backend", "worker"],
        contract_path=contract_path,
        question_count=3,
        target=tmp_path,
    )


# ── build_contract_preview ────────────────────────────────────────────────────

def test_preview_feature_name(sample_preview):
    assert sample_preview["feature_name"] == "QUEUE_RETRY"


def test_preview_impacts(sample_preview):
    assert sample_preview["impacts"] == ["backend", "worker"]


def test_preview_estimated_files(sample_preview):
    # 1 base + 2 impacts = 3
    assert sample_preview["estimated_files"] == 3


def test_preview_contract_path_is_relative(sample_preview):
    assert not sample_preview["contract_path"].startswith("/")
    assert "QUEUE_RETRY.md" in sample_preview["contract_path"]


def test_preview_question_count(sample_preview):
    assert sample_preview["question_count"] == 3


def test_preview_no_impacts(tmp_path):
    cp = tmp_path / "contracts" / "features" / "FEATURE.md"
    preview = build_contract_preview("FEATURE", [], cp, 0, tmp_path)
    assert preview["estimated_files"] == 1
    assert preview["impacts"] == []
    assert preview["question_count"] == 0


def test_preview_contract_path_outside_target(tmp_path):
    # contract_path not relative to target → absolute path used
    contract_path = Path("/some/other/place/FEATURE.md")
    preview = build_contract_preview("FEATURE", [], contract_path, 0, tmp_path)
    assert preview["contract_path"] == "/some/other/place/FEATURE.md"


def test_preview_many_impacts(tmp_path):
    cp = tmp_path / "contracts" / "features" / "AUTH.md"
    preview = build_contract_preview("AUTH", ["auth", "backend", "database", "frontend"], cp, 5, tmp_path)
    assert preview["estimated_files"] == 5  # 1 + 4


# ── print_contract_preview ────────────────────────────────────────────────────

def test_print_preview_contains_feature_name(sample_preview, capsys):
    print_contract_preview(sample_preview)
    out = capsys.readouterr().out
    assert "QUEUE_RETRY" in out


def test_print_preview_contains_impacts(sample_preview, capsys):
    print_contract_preview(sample_preview)
    out = capsys.readouterr().out
    assert "backend" in out
    assert "worker" in out


def test_print_preview_contains_file_count(sample_preview, capsys):
    print_contract_preview(sample_preview)
    out = capsys.readouterr().out
    assert "3개" in out


def test_print_preview_contains_contract_path(sample_preview, capsys):
    print_contract_preview(sample_preview)
    out = capsys.readouterr().out
    assert "QUEUE_RETRY.md" in out


def test_print_preview_contains_question_count(sample_preview, capsys):
    print_contract_preview(sample_preview)
    out = capsys.readouterr().out
    assert "3개" in out


def test_print_preview_no_impacts_shows_none(tmp_path, capsys):
    cp = tmp_path / "contracts" / "features" / "FEATURE.md"
    preview = build_contract_preview("FEATURE", [], cp, 0, tmp_path)
    print_contract_preview(preview)
    out = capsys.readouterr().out
    assert "(없음)" in out
