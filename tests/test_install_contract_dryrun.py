"""Tests for --workflow --dry-run — TASK-HCHAIN-CONTRACT-DRYRUN-001."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import run_contract_workflow


@pytest.fixture
def hchain_target(tmp_path):
    """Minimal target with contracts structure."""
    contracts = tmp_path / "contracts"
    contracts.mkdir()
    (contracts / "PROJECT.md").write_text("## 목적\n## 기술 스택\n## 아키텍처\n", encoding="utf-8")
    (contracts / "ARCHITECTURE.md").write_text("## 아키텍처\n", encoding="utf-8")
    (contracts / "RULES.md").write_text("## 규칙\n", encoding="utf-8")
    (contracts / "VALIDATION.md").write_text("## 검증\n", encoding="utf-8")
    (contracts / "DONE.md").write_text("## 완료 기준\n", encoding="utf-8")
    (contracts / "features").mkdir()
    return tmp_path


# ── dry-run: 파일 생성 없음 ────────────────────────────────────────────────────

def test_dryrun_no_contract_file_created(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능 추가", hchain_target, dry_run=True
    )
    features_dir = hchain_target / "contracts" / "features"
    md_files = list(features_dir.glob("*.md"))
    assert md_files == [], f"dry-run에서 파일이 생성됨: {md_files}"


def test_dryrun_result_has_dry_run_flag(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능 추가", hchain_target, dry_run=True
    )
    assert result.get("dry_run") is True


def test_dryrun_result_still_returns_feature_name(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능 추가", hchain_target, dry_run=True
    )
    assert result["feature_name"] == "QUEUE_RETRY"


def test_dryrun_result_still_returns_impacts(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능 추가", hchain_target, dry_run=True
    )
    assert "all_impacts" in result
    assert isinstance(result["all_impacts"], list)


def test_dryrun_result_has_preview(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능 추가", hchain_target, dry_run=True
    )
    assert "preview" in result
    assert result["preview"]["feature_name"] == "QUEUE_RETRY"


def test_dryrun_output_contains_dry_run_prefix(hchain_target, capsys):
    run_contract_workflow("Queue Retry 기능 추가", hchain_target, dry_run=True)
    out = capsys.readouterr().out
    assert "[dry-run]" in out


# ── non-dry-run: 정상 파일 생성 ───────────────────────────────────────────────

def test_normal_mode_creates_contract_file(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능 추가", hchain_target, dry_run=False,
        _input_fn=lambda _: "yes",
    )
    contract = Path(result["contract_path"])
    assert contract.exists(), f"계약 파일이 생성되지 않음: {contract}"


def test_normal_mode_result_dry_run_false(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능 추가", hchain_target, dry_run=False,
        _input_fn=lambda _: "yes",
    )
    assert result.get("dry_run") is False


def test_normal_mode_output_no_dry_run_prefix(hchain_target, capsys):
    run_contract_workflow(
        "Queue Retry 기능 추가", hchain_target, dry_run=False,
        _input_fn=lambda _: "yes",
    )
    out = capsys.readouterr().out
    assert "[hchain]" in out
    assert "[dry-run]" not in out


# ── dry-run: 기존 파일도 수정 안 함 ──────────────────────────────────────────

def test_dryrun_does_not_overwrite_existing_file(hchain_target):
    existing = hchain_target / "contracts" / "features" / "QUEUE_RETRY.md"
    existing.write_text("기존 내용", encoding="utf-8")
    run_contract_workflow("Queue Retry 기능 추가", hchain_target, dry_run=True)
    assert existing.read_text(encoding="utf-8") == "기존 내용"
