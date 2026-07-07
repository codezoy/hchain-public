"""Tests for feature contract auto-generation (TASK-HCHAIN-CONTRACT-GENERATOR-001)."""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import (
    analyze_project_structure,
    generate_feature_contract,
    create_contracts_structure,
)


# ── analyze_project_structure ─────────────────────────────────────────────────

def test_analyze_detects_python_backend(tmp_path):
    (tmp_path / "app.py").write_text("# app", encoding="utf-8")
    result = analyze_project_structure(tmp_path)
    assert "backend" in result["detected_impacts"]
    assert result["has_api"] is True


def test_analyze_detects_frontend(tmp_path):
    (tmp_path / "index.js").write_text("// js", encoding="utf-8")
    result = analyze_project_structure(tmp_path)
    assert "frontend" in result["detected_impacts"]
    assert result["has_ui"] is True


def test_analyze_detects_db_dir(tmp_path):
    (tmp_path / "models").mkdir()
    result = analyze_project_structure(tmp_path)
    assert "database" in result["detected_impacts"]
    assert result["has_db"] is True


def test_analyze_detects_worker_dir(tmp_path):
    (tmp_path / "workers").mkdir()
    result = analyze_project_structure(tmp_path)
    assert "worker" in result["detected_impacts"]
    assert result["has_worker"] is True


def test_analyze_empty_dir(tmp_path):
    result = analyze_project_structure(tmp_path)
    assert isinstance(result["detected_impacts"], list)
    assert result["has_api"] is False


# ── generate_feature_contract ─────────────────────────────────────────────────

def test_generate_creates_file(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    path = generate_feature_contract("queue", tmp_path)
    assert path.exists()
    assert path.name == "QUEUE.md"


def test_generate_contains_required_sections(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    path = generate_feature_contract("login", tmp_path)
    content = path.read_text(encoding="utf-8")
    for section in ("## 목적", "## 범위", "## 영향 범위", "## 상태",
                     "## 입력", "## 출력", "## UI", "## API",
                     "## DB", "## Worker", "## 실패 처리",
                     "## 검증", "## 완료 기준", "## 확인 필요"):
        assert section in content, f"Expected section {section} in generated contract"


def test_generate_contains_yaml_frontmatter(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    path = generate_feature_contract("payment", tmp_path)
    content = path.read_text(encoding="utf-8")
    assert content.startswith("---\n")
    assert "관련 계약:" in content
    assert "영향 범위:" in content


def test_generate_does_not_overwrite_existing(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    out = tmp_path / "contracts" / "features" / "QUEUE.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("# 사용자 작성 내용\n중요한 계약\n", encoding="utf-8")
    generate_feature_contract("queue", tmp_path)
    assert "중요한 계약" in out.read_text(encoding="utf-8")


def test_generate_infers_backend_from_name(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    path = generate_feature_contract("api_gateway", tmp_path)
    content = path.read_text(encoding="utf-8")
    assert "backend" in content


def test_generate_dry_run_no_file_created(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    path = generate_feature_contract("retry", tmp_path, dry_run=True)
    assert not path.exists()


def test_generate_feature_name_uppercased(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    path = generate_feature_contract("Queue", tmp_path)
    assert path.name == "QUEUE.md"
