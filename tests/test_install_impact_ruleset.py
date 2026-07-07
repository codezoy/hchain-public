"""Tests for impact ruleset — TASK-HCHAIN-IMPACT-RULESET-001."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import (
    _load_impact_rules,
    _infer_impacts_from_ruleset,
    _IMPACT_RULES_PATH,
)


# ── _load_impact_rules ────────────────────────────────────────────────────────

def test_load_impact_rules_file_exists():
    assert _IMPACT_RULES_PATH.exists(), f"impact_rules.yaml not found at {_IMPACT_RULES_PATH}"


def test_load_impact_rules_returns_dict():
    rules = _load_impact_rules(_IMPACT_RULES_PATH)
    assert isinstance(rules, dict)
    assert len(rules) > 0


def test_load_impact_rules_has_expected_areas():
    rules = _load_impact_rules(_IMPACT_RULES_PATH)
    for area in ["frontend", "backend", "database", "worker", "auth"]:
        assert area in rules, f"Area '{area}' missing from impact_rules.yaml"


def test_load_impact_rules_area_has_keywords():
    rules = _load_impact_rules(_IMPACT_RULES_PATH)
    for area, keywords in rules.items():
        assert len(keywords) > 0, f"Area '{area}' has no keywords"


def test_load_impact_rules_worker_has_queue_keyword():
    rules = _load_impact_rules(_IMPACT_RULES_PATH)
    assert "queue" in rules.get("worker", []) or "큐" in rules.get("worker", [])


def test_load_impact_rules_nonexistent_path():
    rules = _load_impact_rules(Path("/nonexistent/path/impact_rules.yaml"))
    assert rules == {}


def test_load_impact_rules_comments_and_blanks_skipped(tmp_path):
    yaml_content = """\
# comment
rules:
  frontend:
    # another comment
    - ui

    - web
  backend:
    - api
"""
    f = tmp_path / "impact_rules.yaml"
    f.write_text(yaml_content, encoding="utf-8")
    rules = _load_impact_rules(f)
    assert rules == {"frontend": ["ui", "web"], "backend": ["api"]}


# ── _infer_impacts_from_ruleset ───────────────────────────────────────────────

def test_ruleset_worker_detected_from_queue_keyword():
    rules = _load_impact_rules(_IMPACT_RULES_PATH)
    result = _infer_impacts_from_ruleset("큐에서 실패한 아이템을 재시도하는 Queue 기능", rules)
    assert "worker" in result


def test_ruleset_auth_detected():
    rules = _load_impact_rules(_IMPACT_RULES_PATH)
    result = _infer_impacts_from_ruleset("JWT 토큰 인증 기능 추가", rules)
    assert "auth" in result


def test_ruleset_backend_detected_from_api():
    rules = _load_impact_rules(_IMPACT_RULES_PATH)
    result = _infer_impacts_from_ruleset("REST API 엔드포인트 추가", rules)
    assert "backend" in result


def test_ruleset_multiple_areas():
    rules = _load_impact_rules(_IMPACT_RULES_PATH)
    result = _infer_impacts_from_ruleset("로그인 화면 UI 및 JWT 토큰 auth 기능", rules)
    assert "frontend" in result
    assert "auth" in result


def test_ruleset_no_match_returns_empty():
    rules = {"frontend": ["react"], "backend": ["api"]}
    result = _infer_impacts_from_ruleset("알 수 없는 기능 설명", rules)
    assert result == []


def test_ruleset_empty_rules():
    result = _infer_impacts_from_ruleset("Queue retry job", {})
    assert result == []


def test_ruleset_case_insensitive():
    rules = {"worker": ["queue", "retry"]}
    result = _infer_impacts_from_ruleset("QUEUE RETRY 기능", rules)
    assert "worker" in result
