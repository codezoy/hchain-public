"""Tests for approval workflow — TASK-HCHAIN-CONTRACT-APPROVAL-WORKFLOW-001."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import request_workflow_approval, run_contract_workflow


# ── request_workflow_approval ─────────────────────────────────────────────────

@pytest.mark.parametrize("answer", ["yes", "YES", "Yes", "y", "Y"])
def test_approval_yes_variants(answer):
    result = request_workflow_approval("FEATURE", _input_fn=lambda _: answer)
    assert result is True


@pytest.mark.parametrize("answer", ["approve", "APPROVE", "Approve"])
def test_approval_approve_variants(answer):
    result = request_workflow_approval("FEATURE", _input_fn=lambda _: answer)
    assert result is True


@pytest.mark.parametrize("answer", ["cancel", "CANCEL", "Cancel"])
def test_approval_cancel_variants(answer):
    result = request_workflow_approval("FEATURE", _input_fn=lambda _: answer)
    assert result is False


@pytest.mark.parametrize("answer", ["reject", "REJECT", "Reject", "no", "n", "q", ""])
def test_approval_reject_variants(answer):
    result = request_workflow_approval("FEATURE", _input_fn=lambda _: answer)
    assert result is False


def test_approval_eoferror_returns_false():
    def raise_eof(_):
        raise EOFError
    result = request_workflow_approval("FEATURE", _input_fn=raise_eof)
    assert result is False


# ── run_contract_workflow: approval integration ───────────────────────────────

@pytest.fixture
def hchain_target(tmp_path):
    contracts = tmp_path / "contracts"
    contracts.mkdir()
    (contracts / "PROJECT.md").write_text("## 목적\n## 기술 스택\n## 아키텍처\n", encoding="utf-8")
    (contracts / "ARCHITECTURE.md").write_text("## 아키텍처\n", encoding="utf-8")
    (contracts / "RULES.md").write_text("## 규칙\n", encoding="utf-8")
    (contracts / "VALIDATION.md").write_text("## 검증\n", encoding="utf-8")
    (contracts / "DONE.md").write_text("## 완료 기준\n", encoding="utf-8")
    (contracts / "features").mkdir()
    return tmp_path


def test_approved_creates_contract_file(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능", hchain_target,
        _input_fn=lambda _: "yes",
    )
    assert result["approved"] is True
    contract = Path(result["contract_path"])
    assert contract.exists()


def test_rejected_no_contract_file(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능", hchain_target,
        _input_fn=lambda _: "cancel",
    )
    assert result["approved"] is False
    features_dir = hchain_target / "contracts" / "features"
    md_files = list(features_dir.glob("*.md"))
    assert md_files == [], f"취소 후 파일이 생성됨: {md_files}"


def test_rejected_output_contains_cancel_message(hchain_target, capsys):
    run_contract_workflow(
        "Queue Retry 기능", hchain_target,
        _input_fn=lambda _: "reject",
    )
    out = capsys.readouterr().out
    assert "취소" in out


def test_approved_result_has_approved_true(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능", hchain_target,
        _input_fn=lambda _: "approve",
    )
    assert result["approved"] is True


def test_rejected_result_has_approved_false(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능", hchain_target,
        _input_fn=lambda _: "no",
    )
    assert result["approved"] is False


def test_dryrun_auto_approved_no_prompt(hchain_target):
    called = []
    def mock_input(_):
        called.append(True)
        return "yes"
    result = run_contract_workflow(
        "Queue Retry 기능", hchain_target,
        dry_run=True,
        _input_fn=mock_input,
    )
    # dry-run은 prompt 없이 자동 승인
    assert called == []
    assert result["approved"] is True


def test_approved_result_contains_preview(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능", hchain_target,
        _input_fn=lambda _: "yes",
    )
    assert "preview" in result
    assert result["preview"]["feature_name"] == "QUEUE_RETRY"


def test_rejected_result_still_contains_preview(hchain_target):
    result = run_contract_workflow(
        "Queue Retry 기능", hchain_target,
        _input_fn=lambda _: "cancel",
    )
    assert "preview" in result


def test_preview_shown_before_approval(hchain_target, capsys):
    run_contract_workflow(
        "Queue Retry 기능", hchain_target,
        _input_fn=lambda _: "cancel",
    )
    out = capsys.readouterr().out
    # Preview 내용이 출력에 있어야 함 (취소여도)
    assert "QUEUE_RETRY" in out
    assert "예상 파일" in out
