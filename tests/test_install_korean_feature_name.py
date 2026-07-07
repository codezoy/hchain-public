"""Tests for extract_feature_name() — TASK-HCHAIN-KOREAN-FEATURE-NAME-EXTRACTOR-001."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from install import extract_feature_name, _strip_ko_particle


# ── _strip_ko_particle ────────────────────────────────────────────────────────

def test_strip_particle_eseo():
    assert _strip_ko_particle("큐에서") == "큐"


def test_strip_particle_haneun():
    assert _strip_ko_particle("재시도하는") == "재시도"


def test_strip_particle_han():
    assert _strip_ko_particle("실패한") == "실패"


def test_strip_particle_eul():
    assert _strip_ko_particle("아이템을") == "아이템"


def test_strip_particle_no_particle():
    assert _strip_ko_particle("큐") == "큐"


def test_strip_particle_too_short():
    # "이" ends with "이" but length would be 0 after strip → must not strip
    assert _strip_ko_particle("이") == "이"


# ── extract_feature_name — Priority 1: Multiple English tokens ────────────────

def test_english_tokens_queue_retry():
    assert extract_feature_name("Queue Retry 기능") == "QUEUE_RETRY"


def test_english_tokens_multiple():
    assert extract_feature_name("User Auth Login") == "USER_AUTH_LOGIN"


def test_english_tokens_deduped():
    assert extract_feature_name("Queue Queue Retry") == "QUEUE_RETRY"


def test_english_stops_filtered():
    # "add", "new", "feature" are all stop words → fallback
    assert extract_feature_name("add new feature") == "FEATURE"


# ── extract_feature_name — Priority 2: ALL_CAPS tokens ───────────────────────

def test_all_caps_single():
    assert extract_feature_name("AUTH 기능 추가") == "AUTH"


def test_all_caps_multi():
    assert extract_feature_name("QUEUE RETRY 기능") == "QUEUE_RETRY"


# ── extract_feature_name — Priority 3: Korean noun mapping ───────────────────

def test_korean_nouns_failed_job_retry():
    assert extract_feature_name("실패 작업 재시도 기능") == "FAILED_JOB_RETRY"


def test_korean_nouns_shorts_template():
    assert extract_feature_name("쇼츠 템플릿 기능") == "SHORTS_TEMPLATE"


def test_korean_nouns_queue_retry():
    assert extract_feature_name("큐 재시도 기능") == "QUEUE_RETRY"


def test_korean_particle_stripping():
    # "큐에서 재시도하는" → 큐 + 재시도 → QUEUE_RETRY
    result = extract_feature_name("큐에서 재시도하는 기능")
    assert result == "QUEUE_RETRY"


# ── extract_feature_name — Priority 4: Mixed Korean + single English ──────────

def test_mixed_queue_en_ko_particles():
    # "큐에서 실패한 아이템을 재시도하는 Queue 기능 추가"
    # en_tokens = [QUEUE] (1개), ko_parts = [QUEUE, FAILED, RETRY]
    # QUEUE already in ko_parts → combined = [QUEUE, FAILED, RETRY]
    result = extract_feature_name("큐에서 실패한 아이템을 재시도하는 Queue 기능 추가")
    assert "QUEUE" in result
    assert "RETRY" in result


def test_single_english_with_korean_nouns():
    result = extract_feature_name("Auth 인증 로그인 기능")
    assert "AUTH" in result
    assert "LOGIN" in result


# ── extract_feature_name — Priority 5: Fallback ──────────────────────────────

def test_empty_request():
    assert extract_feature_name("") == "FEATURE"


def test_whitespace_only():
    assert extract_feature_name("   ") == "FEATURE"


def test_no_mapping_korean():
    # "아이템" is not in _KO_EN_MAP, "추가" is in _KO_STOP_WORDS
    assert extract_feature_name("아이템 추가") == "FEATURE"


def test_stop_words_only():
    assert extract_feature_name("기능 추가 구현") == "FEATURE"
