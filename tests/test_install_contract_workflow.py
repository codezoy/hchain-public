"""Tests for Contract Workflow analyzer (TASK-HCHAIN-CONTRACT-WORKFLOW-ANALYZER-001)."""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import (
    run_contract_workflow,
    create_contracts_structure,
    _detect_missing_policies,
    _generate_questions,
)


# ── _detect_missing_policies ──────────────────────────────────────────────────

def test_detect_missing_policies_clean(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    result = _detect_missing_policies(tmp_path / "contracts")
    # Template contracts have ## headers so no missing sections
    assert isinstance(result, list)


def test_detect_missing_policies_no_contracts_dir(tmp_path):
    result = _detect_missing_policies(tmp_path / "contracts")
    assert len(result) > 0  # All base contracts reported missing


def test_detect_missing_policies_missing_file(tmp_path):
    (tmp_path / "contracts").mkdir()
    result = _detect_missing_policies(tmp_path / "contracts")
    file_missing = [m for m in result if "파일 없음" in m]
    assert len(file_missing) == 5  # All 5 base contracts missing


# ── _generate_questions ───────────────────────────────────────────────────────

def test_generate_questions_db_impact():
    questions = _generate_questions("queue", ["database", "backend"], [])
    assert any("[DB]" in q for q in questions)


def test_generate_questions_worker_impact():
    questions = _generate_questions("retry", ["worker"], [])
    assert any("[Worker]" in q for q in questions)


def test_generate_questions_frontend_impact():
    questions = _generate_questions("dashboard", ["frontend"], [])
    assert any("[UI]" in q for q in questions)


def test_generate_questions_missing_policies_adds_warning():
    questions = _generate_questions("login", [], ["RULES.md: 섹션 없음"])
    assert any("[정책]" in q for q in questions)


def test_generate_questions_no_impacts_has_default():
    questions = _generate_questions("feature", [], [])
    assert len(questions) >= 1


# ── run_contract_workflow ─────────────────────────────────────────────────────

def test_workflow_returns_dict(tmp_path, capsys):
    create_contracts_structure(tmp_path, update=False)
    result = run_contract_workflow("Queue 기능 추가", tmp_path, _input_fn=lambda _: "yes")
    assert isinstance(result, dict)
    assert "feature_name" in result
    assert "relevant_contracts" in result
    assert "all_impacts" in result
    assert "questions" in result
    assert "contract_path" in result


def test_workflow_creates_contract_file(tmp_path, capsys):
    create_contracts_structure(tmp_path, update=False)
    result = run_contract_workflow("Queue 기능 추가", tmp_path, _input_fn=lambda _: "yes")
    contract_path = Path(result["contract_path"])
    assert contract_path.exists()


def test_workflow_dry_run_no_contract_created(tmp_path, capsys):
    create_contracts_structure(tmp_path, update=False)
    result = run_contract_workflow("Auth 기능 추가", tmp_path, dry_run=True)
    contract_path = Path(result["contract_path"])
    assert not contract_path.exists()


def test_workflow_includes_base_contracts(tmp_path, capsys):
    create_contracts_structure(tmp_path, update=False)
    result = run_contract_workflow("Login 기능 추가", tmp_path, _input_fn=lambda _: "yes")
    names = [Path(p).name for p in result["relevant_contracts"]]
    assert "PROJECT.md" in names
    assert "ARCHITECTURE.md" in names


def test_workflow_preserves_existing_contract(tmp_path, capsys):
    create_contracts_structure(tmp_path, update=False)
    existing = tmp_path / "contracts" / "features" / "QUEUE.md"
    existing.parent.mkdir(parents=True, exist_ok=True)
    existing.write_text("# 사용자 작성\n중요한 내용\n", encoding="utf-8")
    run_contract_workflow("Queue 기능 추가", tmp_path, _input_fn=lambda _: "yes")
    assert "중요한 내용" in existing.read_text(encoding="utf-8")
