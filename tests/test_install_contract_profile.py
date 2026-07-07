"""Tests for project profile support (TASK-HCHAIN-CONTRACT-PROFILE-001)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import apply_profile, PROFILES, create_contracts_structure


# ── PROFILES dict ─────────────────────────────────────────────────────────────

def test_all_profiles_defined():
    for name in ("ai-video", "web", "api", "cli"):
        assert name in PROFILES, f"Profile '{name}' must be defined"


def test_ai_video_profile_files():
    assert "RENDER.md" in PROFILES["ai-video"]
    assert "TTS.md" in PROFILES["ai-video"]


def test_web_profile_files():
    assert "API.md" in PROFILES["web"]
    assert "AUTH.md" in PROFILES["web"]
    assert "UI.md" in PROFILES["web"]


def test_cli_profile_files():
    assert "COMMAND.md" in PROFILES["cli"]
    assert "OUTPUT.md" in PROFILES["cli"]


# ── apply_profile ─────────────────────────────────────────────────────────────

def test_apply_profile_creates_files(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    apply_profile(tmp_path, "web")
    features = tmp_path / "contracts" / "features"
    assert (features / "API.md").exists()
    assert (features / "AUTH.md").exists()
    assert (features / "UI.md").exists()


def test_apply_profile_ai_video(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    apply_profile(tmp_path, "ai-video")
    features = tmp_path / "contracts" / "features"
    assert (features / "RENDER.md").exists()
    assert (features / "TTS.md").exists()


def test_apply_profile_cli(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    apply_profile(tmp_path, "cli")
    features = tmp_path / "contracts" / "features"
    assert (features / "COMMAND.md").exists()
    assert (features / "OUTPUT.md").exists()


def test_apply_profile_unknown_warns(tmp_path, capsys):
    create_contracts_structure(tmp_path, update=False)
    apply_profile(tmp_path, "nonexistent-profile")
    out = capsys.readouterr().out
    assert "알 수 없는 프로파일" in out or "WARN" in out


def test_apply_profile_update_preserves_existing(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    features = tmp_path / "contracts" / "features"
    features.mkdir(parents=True, exist_ok=True)
    api_file = features / "API.md"
    api_file.write_text("# 사용자 작성 API 계약\n중요한 내용\n", encoding="utf-8")
    apply_profile(tmp_path, "web", update=True)
    assert "중요한 내용" in api_file.read_text(encoding="utf-8")


def test_apply_profile_dry_run_no_files_created(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    apply_profile(tmp_path, "cli", dry_run=True)
    features = tmp_path / "contracts" / "features"
    assert not (features / "COMMAND.md").exists()
    assert not (features / "OUTPUT.md").exists()


def test_apply_profile_content_has_required_sections(tmp_path):
    create_contracts_structure(tmp_path, update=False)
    apply_profile(tmp_path, "web")
    content = (tmp_path / "contracts" / "features" / "API.md").read_text(encoding="utf-8")
    assert "## 목적" in content
    assert "## 검증" in content
    assert "## 완료 기준" in content
