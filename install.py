#!/usr/bin/env python3
"""HCHAIN installer — Python-based entry point replacing install.sh awk logic."""

import argparse
import json
import os
import shutil
import stat
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HCHAIN_ROOT = Path(__file__).resolve().parent
TEMPLATE_HARNESS = HCHAIN_ROOT / "templates" / "harness"
TEMPLATE_CONTRACTS = HCHAIN_ROOT / "templates" / "contracts"

POLICY_START = "<!-- HCHAIN_POLICY_START -->"
POLICY_END = "<!-- HCHAIN_POLICY_END -->"
POLICY_BLOCK = """\
<!-- HCHAIN_POLICY_START -->
# HCHAIN Mandatory Execution Policy

이 프로젝트의 모든 코드/문서 수정은 HCHAIN Task를 통해서만 수행한다.

금지:
- TASK.md 없이 코드 수정 금지
- queue/pending 등록 없이 작업 시작 금지
- REVIEWER/VALIDATOR 로그 없이 완료 보고 금지
- 하네스 실행 상태 확인 없이 작업 완료 보고 금지

필수:
- TASK 생성
- queue 등록
- PLAN → RESEARCH → ACTION → REVIEW → VALIDATE → DONE 기록
- logs 생성
- queue/done 이동
- 최종 보고서에 task_id, logs, validation 결과 포함

<!-- HCHAIN_POLICY_END -->"""

CONTRACT_FIRST_START = "<!-- HCHAIN_CONTRACT_FIRST_START -->"
CONTRACT_FIRST_END = "<!-- HCHAIN_CONTRACT_FIRST_END -->"
CONTRACT_FIRST_BLOCK = """\
<!-- HCHAIN_CONTRACT_FIRST_START -->
## HCHAIN Contract First Workflow

작업 시작 전 관련 계약 문서를 먼저 읽는다.

모든 계약을 읽지 않는다. 현재 작업에 필요한 계약만 읽는다.

계약이 없으면 구현을 시작하지 않는다.

불명확한 요구사항은 질문하거나 확인 필요 항목으로 남긴다.

구현 완료 후 계약과 구현이 일치하는지 검증한다.
<!-- HCHAIN_CONTRACT_FIRST_END -->"""

CODEX_POLICY_START = "<!-- HCHAIN_CODEX_DONE_POLICY_START -->"
CODEX_POLICY_END = "<!-- HCHAIN_CODEX_DONE_POLICY_END -->"
CODEX_POLICY_BLOCK = """\
<!-- HCHAIN_CODEX_DONE_POLICY_START -->
## HCHAIN / Codex Execution Rule

When Codex performs any code, documentation, configuration, test, debugging,
or repository maintenance work in this repository, it MUST leave a task report under:

    harness/queue/done/

Report filename format:

    TASK-<PROJECT>-<SHORT-TITLE>-<YYYYMMDD-HHMMSS>.md

Each report MUST include:

    Executor    : Codex
    Branch      : <current git branch>
    Git Status  : <before/after summary>
    Task Summary:
    Root Cause  :
    Changes     :
    Files Changed:
    Validation  :
    Known Issues:
    Status      : PASS | PASS_WITH_ISSUES | FAIL

Rules:

    - Do not mark PASS without validation.
    - If validation is partial, use PASS_WITH_ISSUES.
    - Do not hide failed commands.
    - Prefer minimal changes.
    - Do not refactor unrelated files.
    - Always include exact commands used for validation.
    - Preserve existing HCHAIN queue structure.
    - Do not delete user-authored AGENTS.md content.

<!-- HCHAIN_CODEX_DONE_POLICY_END -->"""

# Paths that must NOT be overwritten during --update
PRESERVED_PATTERNS = {
    "active_state.json",
    "tasks",
    "logs",
    "findings",
    "missions",
    "queue/pending",
    "queue/running",
    "queue/done",
    "queue/blocked",
}


def _is_preserved(rel: str) -> bool:
    """Return True if rel path should never be overwritten on --update."""
    parts = Path(rel).parts
    if not parts:
        return False
    # top-level preserved dirs/files
    if parts[0] in ("tasks", "logs", "findings", "missions", "active_state.json"):
        return True
    # queue subdirs
    if len(parts) >= 2 and parts[0] == "queue" and parts[1] in (
        "pending", "running", "done", "blocked"
    ):
        return True
    return False


def _log(msg: str, dry_run: bool = False, verbose: bool = False) -> None:
    prefix = "[dry-run]" if dry_run else "[hchain]"
    print(f"{prefix} {msg}")


def _utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _make_executable(path: Path) -> None:
    """Add executable bit for owner/group/other."""
    current = path.stat().st_mode
    path.chmod(current | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def _grant_exec_recursive(directory: Path) -> None:
    """Make all .sh files under directory executable."""
    for sh in directory.rglob("*.sh"):
        if sh.is_file():
            _make_executable(sh)


# ── CLAUDE.md policy block ────────────────────────────────────────────────────

def inject_claude_policy(target: Path, dry_run: bool = False) -> None:
    claude_md = target / "CLAUDE.md"

    if not claude_md.exists():
        if dry_run:
            _log(f"CREATE {claude_md} (new file with policy block)", dry_run=True)
            return
        _log(f"Creating {claude_md} with policy block")
        claude_md.write_text(POLICY_BLOCK + "\n", encoding="utf-8")
        return

    content = claude_md.read_text(encoding="utf-8")

    # Count existing markers
    start_count = content.count(POLICY_START)
    end_count = content.count(POLICY_END)

    if start_count == 0:
        # No block — append
        if dry_run:
            _log(f"APPEND {claude_md} (add HCHAIN policy block at end)", dry_run=True)
            return
        _log(f"Appending policy block to {claude_md}")
        sep = "" if content.endswith("\n") else "\n"
        claude_md.write_text(content + sep + "\n" + POLICY_BLOCK + "\n", encoding="utf-8")
    else:
        # Replace (handles 1 or multiple blocks — keeps exactly one)
        if dry_run:
            action = "replace" if start_count == 1 else f"deduplicate ({start_count} blocks → 1)"
            _log(f"UPDATE {claude_md} ({action})", dry_run=True)
            return
        _log(f"Updating policy block in {claude_md} (found {start_count} block(s))")
        lines = content.splitlines(keepends=True)
        new_lines = []
        inside = False
        inserted = False
        for line in lines:
            stripped = line.rstrip("\n").rstrip("\r")
            if stripped == POLICY_START:
                if not inserted:
                    new_lines.append(POLICY_BLOCK + "\n")
                    inserted = True
                inside = True
                continue
            if inside:
                if stripped == POLICY_END:
                    inside = False
                continue
            new_lines.append(line)
        claude_md.write_text("".join(new_lines), encoding="utf-8")


# ── AGENTS.md Codex done-policy block ────────────────────────────────────────

def ensure_codex_agents_policy(target: Path, dry_run: bool = False) -> None:
    agents_md = target / "AGENTS.md"

    if not agents_md.exists():
        if dry_run:
            _log(f"CREATE {agents_md} (new file with Codex done policy)", dry_run=True)
            return
        _log(f"Creating {agents_md} with Codex done policy")
        agents_md.write_text(CODEX_POLICY_BLOCK + "\n", encoding="utf-8")
        return

    content = agents_md.read_text(encoding="utf-8")
    start_count = content.count(CODEX_POLICY_START)
    end_count = content.count(CODEX_POLICY_END)

    if start_count == 0:
        if dry_run:
            _log(f"APPEND {agents_md} (add Codex done policy at end)", dry_run=True)
            return
        _log(f"Appending Codex done policy to {agents_md}")
        sep = "" if content.endswith("\n") else "\n"
        agents_md.write_text(content + sep + "\n" + CODEX_POLICY_BLOCK + "\n", encoding="utf-8")
    elif start_count == 1 and end_count == 1:
        if dry_run:
            _log(f"UPDATE {agents_md} (replace Codex done policy block)", dry_run=True)
            return
        _log(f"Updating Codex done policy block in {agents_md}")
        lines = content.splitlines(keepends=True)
        new_lines = []
        inside = False
        inserted = False
        for line in lines:
            stripped = line.rstrip("\n").rstrip("\r")
            if stripped == CODEX_POLICY_START:
                if not inserted:
                    new_lines.append(CODEX_POLICY_BLOCK + "\n")
                    inserted = True
                inside = True
                continue
            if inside:
                if stripped == CODEX_POLICY_END:
                    inside = False
                continue
            new_lines.append(line)
        agents_md.write_text("".join(new_lines), encoding="utf-8")
    else:
        # Broken marker state: backup and safe-append
        backup = agents_md.with_suffix(".md.hchain_bak")
        if dry_run:
            _log(f"WARN {agents_md} broken markers (start={start_count} end={end_count}) — would backup and append", dry_run=True)
            return
        _log(f"WARN: broken markers in {agents_md} (start={start_count} end={end_count}) — creating backup {backup.name}")
        shutil.copy2(agents_md, backup)
        sep = "" if content.endswith("\n") else "\n"
        agents_md.write_text(content + sep + "\n" + CODEX_POLICY_BLOCK + "\n", encoding="utf-8")


# ── Contract First policy injection ──────────────────────────────────────────

def inject_contract_first_policy(target: Path, dry_run: bool = False) -> None:
    claude_md = target / "CLAUDE.md"

    if not claude_md.exists():
        if dry_run:
            _log(f"SKIP {claude_md} (not found — contract policy not injected)", dry_run=True)
            return
        _log(f"SKIP {claude_md} (not found — contract policy not injected)")
        return

    content = claude_md.read_text(encoding="utf-8")
    start_count = content.count(CONTRACT_FIRST_START)

    if start_count == 0:
        if dry_run:
            _log(f"APPEND {claude_md} (add Contract First policy block)", dry_run=True)
            return
        _log(f"Appending Contract First policy to {claude_md}")
        sep = "" if content.endswith("\n") else "\n"
        claude_md.write_text(content + sep + "\n" + CONTRACT_FIRST_BLOCK + "\n", encoding="utf-8")
    else:
        if dry_run:
            action = "replace" if start_count == 1 else f"deduplicate ({start_count} → 1)"
            _log(f"UPDATE {claude_md} ({action})", dry_run=True)
            return
        _log(f"Updating Contract First policy in {claude_md} (found {start_count} block(s))")
        lines = content.splitlines(keepends=True)
        new_lines = []
        inside = False
        inserted = False
        for line in lines:
            stripped = line.rstrip("\n").rstrip("\r")
            if stripped == CONTRACT_FIRST_START:
                if not inserted:
                    new_lines.append(CONTRACT_FIRST_BLOCK + "\n")
                    inserted = True
                inside = True
                continue
            if inside:
                if stripped == CONTRACT_FIRST_END:
                    inside = False
                continue
            new_lines.append(line)
        claude_md.write_text("".join(new_lines), encoding="utf-8")


# ── contract reference parsing ────────────────────────────────────────────────

def parse_contract_header(md_path: Path) -> dict:
    """Parse YAML-like front-matter block from a contract file.

    Returns dict with keys: 관련_계약, 영향_범위, 관련_기능, 우선순위.
    Returns empty dict if no front-matter is found.
    """
    try:
        text = md_path.read_text(encoding="utf-8")
    except OSError:
        return {}

    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}

    header_lines = []
    for line in lines[1:]:
        if line.strip() == "---":
            break
        header_lines.append(line)

    result: dict = {
        "관련_계약": [],
        "영향_범위": [],
        "관련_기능": [],
        "우선순위": "보통",
        "status": "draft",
    }

    current_key: str | None = None
    for line in header_lines:
        # Key line: "key:"  or  "key: value"
        if line and not line[0].isspace() and ":" in line:
            raw_key, _, raw_val = line.partition(":")
            key = raw_key.strip()
            val = raw_val.strip()
            # Normalize key to internal name
            key_map = {
                "관련 계약": "관련_계약",
                "영향 범위": "영향_범위",
                "관련 기능": "관련_기능",
                "우선순위": "우선순위",
                "status": "status",
            }
            internal = key_map.get(key)
            if internal is None:
                current_key = None
                continue
            current_key = internal
            if val and val != "[]":
                if isinstance(result[current_key], list):
                    result[current_key].append(val)
                else:
                    result[current_key] = val
        elif line.startswith("  - ") or line.startswith("- "):
            # list item
            item = line.lstrip("- ").strip()
            if current_key and isinstance(result[current_key], list):
                result[current_key].append(item)

    return result


def select_relevant_contracts(contracts_dir: Path, keywords: list[str]) -> list[Path]:
    """Return contract files relevant to the given keywords.

    Relevance is determined by:
    1. The file's YAML front-matter 영향_범위 / 관련_기능 fields
    2. Keyword occurrence in the file name
    3. Base contracts are always included

    Always includes the 5 base contracts if they exist.
    """
    base_names = {"PROJECT.md", "ARCHITECTURE.md", "RULES.md", "VALIDATION.md", "DONE.md"}
    selected: list[Path] = []

    # Base contracts always first
    for name in ("PROJECT.md", "ARCHITECTURE.md", "RULES.md", "VALIDATION.md", "DONE.md"):
        p = contracts_dir / name
        if p.exists():
            selected.append(p)

    lower_kw = [k.lower() for k in keywords]
    features_dir = contracts_dir / "features"
    if not features_dir.exists():
        return selected

    for md_path in sorted(features_dir.glob("*.md")):
        if md_path.name == "TEMPLATE.md":
            continue
        # Name match
        stem_lower = md_path.stem.lower()
        if any(kw in stem_lower for kw in lower_kw):
            if md_path not in selected:
                selected.append(md_path)
            continue
        # Front-matter match
        header = parse_contract_header(md_path)
        combined = " ".join(
            header.get("영향_범위", []) + header.get("관련_기능", [])
        ).lower()
        if any(kw in combined for kw in lower_kw):
            if md_path not in selected:
                selected.append(md_path)

    return selected


# ── feature contract generator ───────────────────────────────────────────────

_IMPACT_KEYWORDS: dict[str, list[str]] = {
    "frontend": ["ui", "frontend", "web", "html", "css", "react", "vue", "svelte", "template"],
    "backend": ["api", "backend", "server", "route", "endpoint", "handler", "service"],
    "database": ["db", "database", "model", "schema", "migration", "sql", "mongo", "redis"],
    "worker": ["worker", "queue", "job", "task", "celery", "background", "async"],
    "auth": ["auth", "login", "token", "jwt", "session", "permission", "role"],
    "logging": ["log", "logging", "audit", "trace", "monitor"],
    "validation": ["valid", "check", "test", "assert", "constraint"],
}

# ── Korean feature name extractor ────────────────────────────────────────────

_KO_PARTICLES: list[str] = [
    "에서의", "에서는", "하는", "하여", "하고", "되는", "해서",
    "에서", "으로", "에도", "이며", "이고", "을로", "를로",
    "한", "이", "가", "는", "은", "을", "를", "로", "에", "의", "도", "와", "과",
]

_KO_EN_MAP: dict[str, str] = {
    "큐": "QUEUE",
    "재시도": "RETRY",
    "실패": "FAILED",
    "작업": "JOB",
    "템플릿": "TEMPLATE",
    "쇼츠": "SHORTS",
    "인증": "AUTH",
    "로그인": "LOGIN",
    "회원가입": "REGISTER",
    "검색": "SEARCH",
    "업로드": "UPLOAD",
    "다운로드": "DOWNLOAD",
    "알림": "NOTIFICATION",
    "권한": "PERMISSION",
    "결제": "PAYMENT",
    "이메일": "EMAIL",
    "사용자": "USER",
    "계정": "ACCOUNT",
    "파일": "FILE",
    "이미지": "IMAGE",
    "영상": "VIDEO",
    "렌더링": "RENDER",
    "스케줄": "SCHEDULE",
    "배치": "BATCH",
    "캐시": "CACHE",
    "설정": "CONFIG",
    "통계": "STATS",
    "리포트": "REPORT",
    "대시보드": "DASHBOARD",
    "메시지": "MESSAGE",
    "채팅": "CHAT",
    "프로필": "PROFILE",
    "구독": "SUBSCRIPTION",
    "스트림": "STREAM",
    "배포": "DEPLOY",
    "빌드": "BUILD",
    "테스트": "TEST",
    "로그": "LOG",
    "모니터": "MONITOR",
    "백업": "BACKUP",
    "복구": "RESTORE",
}

_KO_STOP_WORDS: set[str] = {
    "기능", "추가", "구현", "개발", "제작", "추가하기", "만들기",
    "아이템", "항목", "데이터", "관련", "위한", "수정", "변경",
}

_EN_STOP_WORDS: set[str] = {
    "feature", "add", "new", "create", "implement", "update", "modify",
    "the", "a", "an", "and", "or", "for", "to", "of", "in", "with",
}


def analyze_project_structure(target: Path) -> dict:
    """Scan target directory to infer project tech stack and impact areas.

    Returns dict with keys: detected_impacts, has_api, has_db, has_worker, has_ui.
    """
    detected: set[str] = set()

    # File-extension heuristics
    try:
        all_files = list(target.rglob("*"))
    except Exception:
        all_files = []

    extensions: set[str] = set()
    dir_names: set[str] = set()
    for p in all_files:
        if p.is_file():
            extensions.add(p.suffix.lower())
        elif p.is_dir():
            dir_names.add(p.name.lower())

    if ".py" in extensions:
        detected.add("backend")
    if {".js", ".ts", ".tsx", ".jsx"} & extensions:
        detected.add("frontend")
    if {".html", ".css", ".vue", ".svelte"} & extensions:
        detected.add("frontend")
    if {"models", "migrations", "schemas", "db"} & dir_names:
        detected.add("database")
    if {"workers", "jobs", "tasks", "queue"} & dir_names:
        detected.add("worker")
    if {"templates", "static", "public", "assets"} & dir_names:
        detected.add("frontend")
    if {"routes", "api", "endpoints", "handlers"} & dir_names:
        detected.add("backend")

    return {
        "detected_impacts": sorted(detected),
        "has_api": "backend" in detected,
        "has_db": "database" in detected,
        "has_worker": "worker" in detected,
        "has_ui": "frontend" in detected,
    }


def _infer_impacts_from_name(feature_name: str) -> list[str]:
    """Infer likely impact areas from the feature name."""
    name_lower = feature_name.lower()
    impacts: list[str] = []
    for area, keywords in _IMPACT_KEYWORDS.items():
        if any(kw in name_lower for kw in keywords):
            impacts.append(area)
    return impacts


def request_workflow_approval(feature_name: str, _input_fn=input) -> bool:
    """Ask the user whether to proceed with contract creation.

    Returns True if user answers yes/approve/y, False for cancel/reject/n or EOF.
    """
    try:
        answer = _input_fn(
            f"\n[hchain] '{feature_name}' 계약을 생성하고 진행하시겠습니까? "
            "[yes/approve/cancel/reject]: "
        ).strip().lower()
    except EOFError:
        return False
    return answer in ("yes", "approve", "y")


def build_contract_preview(
    feature_name: str,
    impacts: list[str],
    contract_path: Path,
    question_count: int,
    target: Path,
) -> dict:
    """Build a preview summary dict for the contract workflow result."""
    estimated_files = 1 + len(impacts)
    try:
        rel_path = str(contract_path.relative_to(target))
    except ValueError:
        rel_path = str(contract_path)
    return {
        "feature_name": feature_name,
        "impacts": impacts,
        "estimated_files": estimated_files,
        "contract_path": rel_path,
        "question_count": question_count,
    }


def print_contract_preview(preview: dict) -> None:
    """Print the contract preview summary block."""
    sep = "─" * 40
    impacts_str = ", ".join(preview["impacts"]) if preview["impacts"] else "(없음)"
    print(f"[Preview] 계약 요약")
    print(f"  {sep}")
    print(f"  기능명      : {preview['feature_name']}")
    print(f"  영향 범위   : {impacts_str}")
    print(f"  예상 파일   : {preview['estimated_files']}개")
    print(f"  계약 경로   : {preview['contract_path']}")
    print(f"  질문 수     : {preview['question_count']}개")
    print(f"  {sep}")


def _load_impact_rules(rules_path: Path) -> dict[str, list[str]]:
    """Parse impact_rules.yaml without external dependencies.

    Expected format:
        rules:
          area_name:
            - keyword
    """
    if not rules_path.exists():
        return {}
    result: dict[str, list[str]] = {}
    current_area: str | None = None
    in_rules = False
    for raw_line in rules_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        if line == "rules:":
            in_rules = True
            continue
        if not in_rules:
            continue
        # area header: "  area_name:"
        if line.startswith("  ") and not line.startswith("    ") and line.endswith(":"):
            current_area = line.strip().rstrip(":")
            result[current_area] = []
        # list item: "    - keyword"
        elif line.startswith("    - ") and current_area is not None:
            kw = line.strip().lstrip("- ").strip()
            if kw:
                result[current_area].append(kw)
    return result


def _infer_impacts_from_ruleset(text: str, rules: dict[str, list[str]]) -> list[str]:
    """Match impact areas using keyword ruleset. Returns matched areas."""
    text_lower = text.lower()
    matched: list[str] = []
    for area, keywords in rules.items():
        if any(kw in text_lower for kw in keywords):
            matched.append(area)
    return matched


_IMPACT_RULES_PATH = Path(__file__).parent / "templates" / "contracts" / "impact_rules.yaml"


def _strip_ko_particle(token: str) -> str:
    """Strip trailing Korean particles/suffixes from a token."""
    for p in sorted(_KO_PARTICLES, key=len, reverse=True):
        if token.endswith(p) and len(token) > len(p):
            return token[:-len(p)]
    return token


def extract_feature_name(request: str) -> str:
    """Extract a normalized UPPER_SNAKE_CASE feature name from a natural language request.

    Priority:
    1. Multiple English word sequences (e.g., "Queue Retry") → QUEUE_RETRY
    2. ALL_CAPS tokens (e.g., "AUTH")
    3. Korean nouns mapped through _KO_EN_MAP with particle stripping
    4. Single English token combined with Korean noun mappings
    5. Fallback: "FEATURE"
    """
    if not request.strip():
        return "FEATURE"

    tokens = request.strip().split()

    # Collect English tokens (ASCII alpha only, excluding stop words)
    en_tokens: list[str] = []
    for token in tokens:
        clean = "".join(c for c in token if c.isalpha() and ord(c) < 128)
        if not clean:
            continue
        if clean.lower() in _EN_STOP_WORDS:
            continue
        en_tokens.append(clean.upper())

    # Priority 1: Multiple English tokens
    if len(en_tokens) >= 2:
        seen: list[str] = []
        for t in en_tokens:
            if t not in seen:
                seen.append(t)
        return "_".join(seen)

    # Priority 2: ALL_CAPS tokens (may include underscore)
    caps_tokens = [
        t for t in tokens
        if t.isupper() and len(t) > 1 and all(c.isalpha() or c == "_" for c in t)
    ]
    if caps_tokens:
        seen = []
        for t in caps_tokens:
            if t not in seen:
                seen.append(t)
        return "_".join(seen)

    # Priority 3 & 4: Korean noun extraction
    # Try original token first to avoid stripping particles that are part of compound words.
    ko_parts: list[str] = []
    for token in tokens:
        if token in _KO_EN_MAP and token not in _KO_STOP_WORDS:
            ko_parts.append(_KO_EN_MAP[token])
            continue
        bare = _strip_ko_particle(token)
        if bare != token and bare in _KO_EN_MAP and bare not in _KO_STOP_WORDS:
            ko_parts.append(_KO_EN_MAP[bare])

    single_en = en_tokens[0] if en_tokens else None

    if single_en and ko_parts:
        combined: list[str] = []
        if single_en not in ko_parts:
            combined.append(single_en)
        for p in ko_parts:
            if p not in combined:
                combined.append(p)
        return "_".join(combined) if combined else single_en

    if ko_parts:
        seen = []
        for p in ko_parts:
            if p not in seen:
                seen.append(p)
        return "_".join(seen)

    if single_en:
        return single_en

    return "FEATURE"


def generate_feature_contract(
    feature_name: str,
    target: Path,
    dry_run: bool = False,
) -> Path:
    """Generate contracts/features/<FEATURE_NAME>.md from template + project analysis.

    If the file already exists it is NOT overwritten — existing user content preserved.
    Returns the path to the contract file.
    """
    contracts_dir = target / "contracts"
    features_dir = contracts_dir / "features"
    out_path = features_dir / f"{feature_name.upper()}.md"

    if out_path.exists():
        _log(f"SKIP generate — {out_path.relative_to(target)} already exists", dry_run=dry_run)
        return out_path

    if dry_run:
        _log(f"CREATE contracts/features/{feature_name.upper()}.md (dry-run)", dry_run=True)
        return out_path

    # Analyze project for auto-fill
    proj = analyze_project_structure(target)
    name_impacts = _infer_impacts_from_name(feature_name)
    all_impacts = sorted(set(proj["detected_impacts"] + name_impacts)) or ["backend"]

    # Build YAML front-matter
    base_refs = ["PROJECT.md", "ARCHITECTURE.md", "RULES.md"]
    ref_lines = "\n".join(f"- {r}" for r in base_refs)
    impact_lines = "\n".join(f"- {i}" for i in all_impacts)

    # Build section bodies with auto-inferred hints
    api_hint = "작성 필요" if not proj["has_api"] else "REST API 또는 내부 함수 시그니처 작성"
    db_hint = "작성 필요" if not proj["has_db"] else "관련 테이블/컬렉션 및 필드 정의"
    worker_hint = "작성 필요" if not proj["has_worker"] else "비동기 작업 정의 (큐, 재시도 정책 포함)"
    ui_hint = "작성 필요" if not proj["has_ui"] else "화면 흐름 및 컴포넌트 정의"

    content = f"""\
---
관련 계약:
{ref_lines}

영향 범위:
{impact_lines}

관련 기능: []

우선순위: 보통
---

# {feature_name}

## 목적

작성 필요

## 범위

포함:
-

제외:
-

## 영향 범위

{chr(10).join(f'- {i}' for i in all_impacts)}

## 상태

미착수

## 입력

작성 필요

## 출력

작성 필요

## UI

{ui_hint}

## API

{api_hint}

## DB

{db_hint}

## Worker

{worker_hint}

## 실패 처리

작성 필요

## 검증

작성 필요

## 완료 기준

- [ ] 계약과 구현 일치 확인
- [ ] 테스트 PASS

## 확인 필요

-
"""

    features_dir.mkdir(parents=True, exist_ok=True)
    out_path.write_text(content, encoding="utf-8")
    _log(f"CREATE contracts/features/{feature_name.upper()}.md")
    return out_path


# ── project profiles ─────────────────────────────────────────────────────────

PROFILES: dict[str, dict[str, str]] = {
    "ai-video": {
        "TEMPLATE.md": "# AI Video Template\n\n## 목적\n\n## 입력\n\n## 출력\n\n## 실패 처리\n\n## 검증\n\n## 완료 기준\n\n## 확인 필요\n",
        "RENDER.md": "# Render Contract\n\n## 목적\n\n## 렌더링 파이프라인\n\n## 입력 포맷\n\n## 출력 포맷\n\n## 실패 처리\n\n## 검증\n\n## 완료 기준\n\n## 확인 필요\n",
        "TTS.md": "# TTS Contract\n\n## 목적\n\n## TTS 엔진\n\n## 입력\n\n## 출력\n\n## 실패 처리\n\n## 검증\n\n## 완료 기준\n\n## 확인 필요\n",
    },
    "web": {
        "API.md": "# API Contract\n\n## 목적\n\n## 엔드포인트 목록\n\n## 인증\n\n## 에러 코드\n\n## 검증\n\n## 완료 기준\n\n## 확인 필요\n",
        "AUTH.md": "# Auth Contract\n\n## 목적\n\n## 인증 방식\n\n## 세션/토큰\n\n## 권한 정의\n\n## 실패 처리\n\n## 검증\n\n## 완료 기준\n\n## 확인 필요\n",
        "UI.md": "# UI Contract\n\n## 목적\n\n## 화면 목록\n\n## 컴포넌트 정의\n\n## 상태 관리\n\n## 에러 표시\n\n## 검증\n\n## 완료 기준\n\n## 확인 필요\n",
    },
    "api": {
        "API.md": "# API Contract\n\n## 목적\n\n## 엔드포인트 목록\n\n## 인증\n\n## 에러 코드\n\n## 검증\n\n## 완료 기준\n\n## 확인 필요\n",
        "AUTH.md": "# Auth Contract\n\n## 목적\n\n## 인증 방식\n\n## 세션/토큰\n\n## 권한 정의\n\n## 실패 처리\n\n## 검증\n\n## 완료 기준\n\n## 확인 필요\n",
    },
    "cli": {
        "COMMAND.md": "# CLI Command Contract\n\n## 목적\n\n## 명령어 목록\n\n## 옵션/플래그\n\n## 출력 포맷\n\n## 에러 처리\n\n## 검증\n\n## 완료 기준\n\n## 확인 필요\n",
        "OUTPUT.md": "# Output Contract\n\n## 목적\n\n## 출력 형식\n\n## 성공/에러 출력\n\n## 색상/포맷\n\n## 검증\n\n## 완료 기준\n\n## 확인 필요\n",
    },
}


def apply_profile(target: Path, profile: str, update: bool = False, dry_run: bool = False) -> None:
    """Create profile-specific contract files in contracts/features/.

    Skips existing files when update=True (same rule as create_contracts_structure).
    Prints a warning if the profile name is unknown.
    """
    if profile not in PROFILES:
        known = ", ".join(sorted(PROFILES.keys()))
        _log(f"WARN: 알 수 없는 프로파일 '{profile}'. 사용 가능: {known}", dry_run=dry_run)
        return

    features_dir = target / "contracts" / "features"
    profile_files = PROFILES[profile]

    for filename, content in profile_files.items():
        dst = features_dir / filename
        if update and dst.exists():
            _log(f"SKIP (preserved) contracts/features/{filename}", dry_run=dry_run)
            continue
        if dry_run:
            action = "OVERWRITE" if dst.exists() else "CREATE"
            _log(f"{action} contracts/features/{filename} [profile={profile}]", dry_run=True)
            continue
        features_dir.mkdir(parents=True, exist_ok=True)
        dst.write_text(content, encoding="utf-8")
        _log(f"CREATE contracts/features/{filename} [profile={profile}]")


# ── contracts/ structure ──────────────────────────────────────────────────────

_FEATURE_CONTRACT_SECTIONS = [
    "## 목적", "## 범위", "## 영향 범위", "## 상태",
    "## 입력", "## 출력", "## UI", "## API",
    "## 데이터", "## 실패 처리", "## 검증", "## 완료 기준", "## 확인 필요",
]


def create_contracts_structure(target: Path, update: bool = False, dry_run: bool = False) -> None:
    if not TEMPLATE_CONTRACTS.exists():
        _log("SKIP contracts — template source not found", dry_run=dry_run)
        return

    contracts_dst = target / "contracts"

    for src_path in sorted(TEMPLATE_CONTRACTS.rglob("*")):
        if src_path.is_dir():
            continue
        rel = src_path.relative_to(TEMPLATE_CONTRACTS)
        dst_path = contracts_dst / rel

        if update and dst_path.exists():
            continue

        if dry_run:
            action = "OVERWRITE" if dst_path.exists() else "CREATE"
            _log(f"{action} contracts/{rel}", dry_run=True)
            continue

        dst_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_path, dst_path)

    if not dry_run:
        (contracts_dst / "features").mkdir(parents=True, exist_ok=True)


def cmd_contract_check(target: Path, write: bool = False, dry_run: bool = False) -> None:
    contracts_dir = target / "contracts"
    if not contracts_dir.exists():
        print(f"[hchain] 계약 없음: {contracts_dir}\n  먼저 install 또는 --init-contracts 를 실행하세요.")
        return

    issues: list[str] = []

    for md_path in sorted(contracts_dir.rglob("*.md")):
        if md_path.name == "TEMPLATE.md":
            continue
        content = md_path.read_text(encoding="utf-8")
        rel = md_path.relative_to(contracts_dir)

        # Feature contracts require all standard sections
        if md_path.parent.name == "features":
            missing = [s for s in _FEATURE_CONTRACT_SECTIONS if s not in content]
            if missing:
                issues.append(f"[{rel}] 누락 섹션: {', '.join(missing)}")
                if write and not dry_run:
                    additions = "\n".join(f"\n{s}\n\n작성 필요\n" for s in missing)
                    md_path.write_text(content.rstrip() + "\n" + additions + "\n", encoding="utf-8")
                    _log(f"WRITE {rel} — 누락 섹션 {len(missing)}개 추가")

        # All contracts: flag truly empty files (no section headers at all)
        has_sections = any(l.startswith("## ") for l in content.splitlines())
        if not has_sections:
            issues.append(f"[{rel}] 내용 없음 — 작성 필요")

    if issues:
        print("[hchain] 계약 검토 결과 — 이슈 발견:")
        for issue in issues:
            print(f"  {issue}")
        if write:
            print(f"[hchain] --write 모드: 자동 보강 완료")
    else:
        print("[hchain] 계약 검토 완료 — 이슈 없음")


# ── contract workflow analyzer ───────────────────────────────────────────────

_BASE_CONTRACT_SECTIONS = {
    "PROJECT.md": ["## 프로젝트명", "## 목적", "## 기술 스택"],
    "ARCHITECTURE.md": ["## 구조 개요", "## 레이어 정의"],
    "RULES.md": ["## Contract First Rule"],
    "VALIDATION.md": ["## 검증 범위"],
    "DONE.md": ["## 완료 기준"],
}


def _detect_missing_policies(contracts_dir: Path) -> list[str]:
    """Return list of missing required policy items across base contracts."""
    missing: list[str] = []
    for fname, required_sections in _BASE_CONTRACT_SECTIONS.items():
        p = contracts_dir / fname
        if not p.exists():
            missing.append(f"{fname}: 파일 없음")
            continue
        content = p.read_text(encoding="utf-8")
        for sec in required_sections:
            if sec not in content:
                missing.append(f"{fname}: '{sec}' 섹션 없음")
    return missing


def _generate_questions(feature_name: str, impacts: list[str], missing_policies: list[str]) -> list[str]:
    """Generate clarification questions based on impact areas and missing policies."""
    questions: list[str] = []
    if "database" in impacts:
        questions.append(f"[DB] {feature_name}: 관련 테이블/컬렉션과 필드 정의가 있나요?")
    if "worker" in impacts:
        questions.append(f"[Worker] {feature_name}: 재시도 정책 및 실패 처리 방식이 정의되어 있나요?")
    if "frontend" in impacts:
        questions.append(f"[UI] {feature_name}: 화면 흐름과 에러 상태 표시 방법이 정의되어 있나요?")
    if "auth" in impacts:
        questions.append(f"[Auth] {feature_name}: 권한 검증 방식과 실패 시 동작이 정의되어 있나요?")
    if not questions:
        questions.append(f"[일반] {feature_name}: 입력/출력 인터페이스와 실패 처리가 정의되어 있나요?")
    if missing_policies:
        questions.append(f"[정책] 기본 계약에 누락된 항목이 있습니다 — 작성이 필요합니다.")
    return questions


def run_contract_workflow(
    request: str,
    target: Path,
    dry_run: bool = False,
    _input_fn=input,
) -> dict:
    """Execute the full Contract Workflow pipeline for a feature request.

    Steps:
      1. 관련 계약 읽기 (select_relevant_contracts)
      2. 영향 범위 분석 (analyze_project_structure + ruleset/inference)
      3. 빠진 정책 탐지 (_detect_missing_policies)
      4. 사용자 질문 생성 (_generate_questions)
      [Preview] 계약 요약 출력
      [Approval] 사용자 승인 대기 (yes/approve → 진행, cancel/reject → 중단)
      5. 기능 계약 초안 생성 (승인 후)
      6. Task 생성 안내 출력

    Returns dict with all analysis results.
    """
    contracts_dir = target / "contracts"

    feature_name = extract_feature_name(request)

    prefix = "[dry-run]" if dry_run else "[hchain]"
    print(f"{prefix} Contract Workflow 시작: '{request}'")
    print()

    # Step 1: 관련 계약 읽기
    keywords = request.lower().split()
    relevant = select_relevant_contracts(contracts_dir, keywords)
    print("[1] 관련 계약:")
    for p in relevant:
        try:
            rel = p.relative_to(target)
        except ValueError:
            rel = p
        print(f"    {rel}")
    print()

    # Step 2: 영향 범위 분석 (룰셋 우선, 폴백: AI 키워드 추론)
    proj = analyze_project_structure(target)
    impact_rules = _load_impact_rules(_IMPACT_RULES_PATH)
    if impact_rules:
        name_impacts = _infer_impacts_from_ruleset(request, impact_rules)
        impact_source = "ruleset"
    else:
        name_impacts = _infer_impacts_from_name(request)
        impact_source = "inference"
    if not name_impacts:
        name_impacts = _infer_impacts_from_name(request)
        impact_source = "inference(fallback)"
    all_impacts = sorted(set(proj["detected_impacts"] + name_impacts))
    print(f"[2] 영향 범위 분석 ({impact_source}):")
    for area in all_impacts or ["(분석 결과 없음)"]:
        print(f"    - {area}")
    print()

    # Step 3: 빠진 정책 탐지
    missing_policies: list[str] = []
    if contracts_dir.exists():
        missing_policies = _detect_missing_policies(contracts_dir)
    print("[3] 누락 정책:")
    if missing_policies:
        for mp in missing_policies:
            print(f"    ⚠️  {mp}")
    else:
        print("    이슈 없음")
    print()

    # Step 4: 사용자 질문 생성
    questions = _generate_questions(feature_name, all_impacts, missing_policies)
    print("[4] 확인 필요 항목:")
    for q in questions:
        print(f"    ? {q}")
    print()

    # Preview: 계약 요약 출력 (승인 전, 파일 생성 전)
    expected_contract_path = target / "contracts" / "features" / f"{feature_name.upper()}.md"
    preview = build_contract_preview(
        feature_name=feature_name,
        impacts=all_impacts,
        contract_path=expected_contract_path,
        question_count=len(questions),
        target=target,
    )
    print_contract_preview(preview)
    print()

    # Approval: 사용자 승인 (dry-run이면 자동 진행)
    approved: bool
    if dry_run:
        approved = True
    else:
        approved = request_workflow_approval(feature_name, _input_fn=_input_fn)

    if not approved:
        print("[hchain] 취소되었습니다. 계약이 생성되지 않았습니다.")
        return {
            "feature_name": feature_name,
            "relevant_contracts": [str(p) for p in relevant],
            "all_impacts": all_impacts,
            "missing_policies": missing_policies,
            "questions": questions,
            "contract_path": str(expected_contract_path),
            "preview": preview,
            "dry_run": dry_run,
            "approved": False,
        }

    # Step 5: Lifecycle 검사 후 기능 계약 초안 생성
    existing_contract = expected_contract_path
    if existing_contract.exists():
        header = parse_contract_header(existing_contract)
        existing_status = header.get("status", "draft")
        _LIFECYCLE_MESSAGES = {
            "draft": f"    기존 초안이 있습니다 ({existing_contract.name}, status: draft). 계속 작성하세요.",
            "review": f"    검토 중인 계약이 있습니다 ({existing_contract.name}, status: review). 검토 완료 후 approved로 변경하세요.",
            "approved": f"    승인된 계약이 있습니다 ({existing_contract.name}, status: approved). Task를 생성하세요.",
            "implemented": f"    이미 구현된 계약입니다 ({existing_contract.name}, status: implemented). 신규 기능이 필요하면 새 계약서를 작성하세요.",
            "deprecated": f"    폐기된 계약입니다 ({existing_contract.name}, status: deprecated). 새 계약서를 작성하세요.",
        }
        msg = _LIFECYCLE_MESSAGES.get(existing_status, f"    기존 계약 있음 ({existing_contract.name}, status: {existing_status})")
        print(f"[5] Lifecycle 검사:")
        print(msg)
        print()
    contract_path = generate_feature_contract(feature_name, target, dry_run=dry_run)
    print(f"[5] 기능 계약 초안:")
    try:
        print(f"    {contract_path.relative_to(target)}")
    except ValueError:
        print(f"    {contract_path}")
    print()

    # Step 6: Task 생성 안내
    print("[6] 다음 단계:")
    print(f"    contracts/features/{feature_name.upper()}.md 를 작성한 후")
    print(f"    /hchain task {request} 로 Task를 생성하세요.")

    return {
        "feature_name": feature_name,
        "relevant_contracts": [str(p) for p in relevant],
        "all_impacts": all_impacts,
        "missing_policies": missing_policies,
        "questions": questions,
        "contract_path": str(contract_path),
        "preview": preview,
        "dry_run": dry_run,
        "approved": True,
    }


# ── contract review diff ─────────────────────────────────────────────────────

def _extract_api_names_from_contract(content: str) -> list[str]:
    """Extract API endpoint/function names from the ## API section of a contract."""
    names: list[str] = []
    in_api = False
    for line in content.splitlines():
        if line.strip() == "## API":
            in_api = True
            continue
        if in_api and line.startswith("## "):
            break
        if in_api:
            stripped = line.strip()
            # Capture lines that look like endpoint definitions
            if stripped and not stripped.startswith("#") and stripped not in ("작성 필요", ""):
                names.append(stripped)
    return names


def _scan_code_identifiers(target: Path) -> set[str]:
    """Scan source code files for function/endpoint definitions."""
    identifiers: set[str] = set()
    code_extensions = {".py", ".js", ".ts", ".go", ".java"}
    try:
        for p in target.rglob("*"):
            if p.suffix.lower() not in code_extensions:
                continue
            if any(part.startswith(".") or part == "node_modules" or part == "__pycache__"
                   for part in p.parts):
                continue
            try:
                for line in p.read_text(encoding="utf-8", errors="ignore").splitlines():
                    stripped = line.strip()
                    # Python def / async def
                    if stripped.startswith("def ") or stripped.startswith("async def "):
                        fname = stripped.split("(")[0].split()[-1]
                        identifiers.add(fname)
                    # @app.route / @router.get etc.
                    if "@" in stripped and "route" in stripped.lower():
                        identifiers.add(stripped)
            except Exception:
                pass
    except Exception:
        pass
    return identifiers


def cmd_contract_review_diff(target: Path) -> dict:
    """Compare contracts/ against source code and report discrepancies.

    Analysis categories:
    - 계약에는 있으나 코드에 없음
    - 코드에는 있으나 계약에 없음 (API identifiers not mentioned in contracts)
    - API 불일치
    - 검증 누락
    - 상태 정의 불일치

    Read-only — no auto-fix.
    Returns dict with all findings.
    """
    contracts_dir = target / "contracts"
    if not contracts_dir.exists():
        print(f"[hchain] 계약 없음: {contracts_dir}\n  먼저 install 또는 --init-contracts 를 실행하세요.")
        return {}

    # Collect contract-declared identifiers
    contract_api_items: list[tuple[str, str]] = []  # (file_rel, item)
    contract_validation_files: list[str] = []
    contract_states: list[tuple[str, str]] = []  # (file_rel, state_line)
    contract_all_content = ""

    for md_path in sorted(contracts_dir.rglob("*.md")):
        if md_path.name == "TEMPLATE.md":
            continue
        content = md_path.read_text(encoding="utf-8")
        contract_all_content += content + "\n"
        rel = str(md_path.relative_to(contracts_dir))

        # API items
        for item in _extract_api_names_from_contract(content):
            contract_api_items.append((rel, item))

        # Validation section present?
        if "## 검증" in content:
            contract_validation_files.append(rel)

        # State definitions
        in_state = False
        for line in content.splitlines():
            if line.strip() == "## 상태":
                in_state = True
                continue
            if in_state and line.startswith("## "):
                break
            if in_state:
                s = line.strip()
                if s and s not in ("작성 필요",):
                    contract_states.append((rel, s))

    # Scan source code
    code_identifiers = _scan_code_identifiers(target)

    # ── Analysis ──────────────────────────────────────────────────────────────
    findings: dict[str, list[str]] = {
        "계약에는 있으나 코드에 없음": [],
        "코드에는 있으나 계약에 없음": [],
        "API 불일치": [],
        "검증 누락": [],
        "상태 정의 불일치": [],
    }

    # Contract items not found in code
    for rel, item in contract_api_items:
        # Normalize: extract just function/endpoint name
        clean = item.split("(")[0].strip().lstrip("/").replace("-", "_").lower()
        if clean and not any(clean in idf.lower() for idf in code_identifiers):
            findings["계약에는 있으나 코드에 없음"].append(f"[{rel}] {item}")

    # Code identifiers not mentioned in any contract (only public functions)
    for idf in sorted(code_identifiers):
        if idf.startswith("_") or idf.startswith("test_"):
            continue
        if idf.lower() not in contract_all_content.lower():
            findings["코드에는 있으나 계약에 없음"].append(idf)

    # Feature contracts without validation section
    features_dir = contracts_dir / "features"
    if features_dir.exists():
        for md_path in sorted(features_dir.glob("*.md")):
            if md_path.name == "TEMPLATE.md":
                continue
            content = md_path.read_text(encoding="utf-8")
            if "## 검증" not in content:
                findings["검증 누락"].append(str(md_path.relative_to(contracts_dir)))
            if "## 상태" not in content:
                findings["상태 정의 불일치"].append(
                    f"{md_path.relative_to(contracts_dir)}: '## 상태' 섹션 없음"
                )

    # Print report
    print("## 계약-코드 차이 분석 결과\n")
    any_issue = False
    for category, items in findings.items():
        print(f"### {category}")
        if items:
            any_issue = True
            for item in items:
                print(f"  - {item}")
        else:
            print("  이슈 없음")
        print()

    if not any_issue:
        print("전체 이슈 없음 — 계약과 코드가 일치합니다.")

    return findings


# ── harness copy logic ────────────────────────────────────────────────────────

def copy_harness(target: Path, update: bool, dry_run: bool = False, verbose: bool = False) -> None:
    harness_dst = target / "harness"

    if not TEMPLATE_HARNESS.exists():
        print(f"[hchain] ERROR: template source not found at {TEMPLATE_HARNESS}", file=sys.stderr)
        sys.exit(1)

    for src_path in sorted(TEMPLATE_HARNESS.rglob("*")):
        if src_path.is_dir():
            continue
        rel = src_path.relative_to(TEMPLATE_HARNESS)
        rel_str = str(rel)
        dst_path = harness_dst / rel

        if update and _is_preserved(rel_str):
            if verbose:
                _log(f"SKIP (preserved) harness/{rel_str}")
            continue

        if dry_run:
            action = "OVERWRITE" if dst_path.exists() else "CREATE"
            _log(f"{action} harness/{rel_str}", dry_run=True)
            continue

        dst_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_path, dst_path)
        if verbose:
            _log(f"{'UPDATE' if dst_path.exists() else 'COPY'} harness/{rel_str}")

    if not dry_run:
        # Ensure queue subdirs exist
        for subdir in ("pending", "running", "done", "blocked"):
            (harness_dst / "queue" / subdir).mkdir(parents=True, exist_ok=True)
        # Ensure other runtime dirs
        for d in ("tasks", "logs", "findings", "missions"):
            (harness_dst / d).mkdir(parents=True, exist_ok=True)
        # Grant execute permissions to all .sh files
        _grant_exec_recursive(harness_dst)


# ── meta.json ────────────────────────────────────────────────────────────────

def _read_version() -> str:
    v = HCHAIN_ROOT / "VERSION"
    return v.read_text(encoding="utf-8").strip() if v.exists() else "unknown"


def _read_commit() -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(HCHAIN_ROOT), "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout.strip() if result.returncode == 0 else "unknown"
    except Exception:
        return "unknown"


def write_meta(target: Path, dry_run: bool = False) -> None:
    meta_path = target / ".hchain" / "meta.json"
    now = _utcnow()
    version = _read_version()
    commit = _read_commit()

    if dry_run:
        action = "UPDATE" if meta_path.exists() else "CREATE"
        _log(f"{action} .hchain/meta.json", dry_run=True)
        return

    existing = {}
    if meta_path.exists():
        try:
            existing = json.loads(meta_path.read_text(encoding="utf-8"))
        except Exception:
            pass

    meta = {
        **existing,
        "hchain_version": version,
        "hchain_commit": commit,
        "updated_at": now,
    }
    if "installed_at" not in meta:
        meta["installed_at"] = now

    meta_path.parent.mkdir(parents=True, exist_ok=True)
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    _log(f"meta.json written → {meta_path}")


# ── install / update commands ─────────────────────────────────────────────────

def cmd_install(target: Path, dry_run: bool = False, verbose: bool = False,
                with_contracts: bool = True, profile: str | None = None) -> None:
    _log(f"Installing HCHAIN into {target}" + (" [dry-run]" if dry_run else ""))

    if not dry_run:
        target.mkdir(parents=True, exist_ok=True)

    copy_harness(target, update=False, dry_run=dry_run, verbose=verbose)
    write_meta(target, dry_run=dry_run)
    inject_claude_policy(target, dry_run=dry_run)
    ensure_codex_agents_policy(target, dry_run=dry_run)
    if with_contracts:
        create_contracts_structure(target, update=False, dry_run=dry_run)
        inject_contract_first_policy(target, dry_run=dry_run)
        if profile:
            apply_profile(target, profile, update=False, dry_run=dry_run)

    if dry_run:
        _log("dry-run complete — no changes made", dry_run=True)
    else:
        _log(f"Install complete ✓  target={target}")


def cmd_update(target: Path, dry_run: bool = False, verbose: bool = False,
               with_contracts: bool = True, profile: str | None = None) -> None:
    harness = target / "harness"
    if not harness.exists() and not dry_run:
        print(f"[hchain] ERROR: harness not found at {harness}. Run without --update first.", file=sys.stderr)
        sys.exit(1)

    _log(f"Updating HCHAIN at {target}" + (" [dry-run]" if dry_run else ""))

    copy_harness(target, update=True, dry_run=dry_run, verbose=verbose)
    write_meta(target, dry_run=dry_run)
    inject_claude_policy(target, dry_run=dry_run)
    ensure_codex_agents_policy(target, dry_run=dry_run)
    if with_contracts:
        create_contracts_structure(target, update=True, dry_run=dry_run)
        inject_contract_first_policy(target, dry_run=dry_run)
        if profile:
            apply_profile(target, profile, update=True, dry_run=dry_run)

    if dry_run:
        _log("dry-run complete — no changes made", dry_run=True)
    else:
        _log(f"Update complete ✓  target={target}")


# ── CLI entry ─────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        prog="install.py",
        description="HCHAIN installer — Python-based",
    )
    parser.add_argument("--target", required=True, help="Target project path")
    parser.add_argument("--update", action="store_true", help="Update mode (preserve runtime data)")
    parser.add_argument("--dry-run", action="store_true", dest="dry_run", help="Preview only, no changes")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")
    parser.add_argument("--no-contracts", action="store_true", dest="no_contracts",
                        help="Skip contracts/ structure creation")
    parser.add_argument("--init-contracts", action="store_true", dest="init_contracts",
                        help="Initialize contracts/ structure only (no harness copy)")
    parser.add_argument("--contract-check", action="store_true", dest="contract_check",
                        help="Check contracts/ for completeness (read-only)")
    parser.add_argument("--write", action="store_true",
                        help="With --contract-check: auto-add missing section headers")
    parser.add_argument("--select-contracts", nargs="+", dest="select_contracts",
                        metavar="KEYWORD",
                        help="Print relevant contracts for given keywords")
    parser.add_argument("--generate-contract", dest="generate_contract",
                        metavar="FEATURE_NAME",
                        help="Generate feature contract file for FEATURE_NAME")
    parser.add_argument("--workflow", dest="workflow",
                        metavar="REQUEST",
                        help="Run full Contract Workflow for a feature request")
    parser.add_argument("--contract-review-diff", action="store_true", dest="contract_review_diff",
                        help="Analyze diff between contracts and source code (read-only)")
    parser.add_argument("--profile", dest="profile",
                        metavar="PROFILE",
                        help="Apply a project profile (ai-video, web, api, cli)")
    args = parser.parse_args()

    target = Path(args.target).resolve()
    with_contracts = not args.no_contracts

    if args.contract_review_diff:
        cmd_contract_review_diff(target)
    elif args.workflow:
        run_contract_workflow(args.workflow, target, dry_run=args.dry_run)
    elif args.generate_contract:
        generate_feature_contract(args.generate_contract, target, dry_run=args.dry_run)
    elif args.select_contracts:
        contracts_dir = target / "contracts"
        paths = select_relevant_contracts(contracts_dir, args.select_contracts)
        print("[hchain] 관련 계약 목록:")
        for p in paths:
            try:
                rel = p.relative_to(target)
            except ValueError:
                rel = p
            print(f"  {rel}")
    elif args.contract_check:
        cmd_contract_check(target, write=args.write, dry_run=args.dry_run)
    elif args.init_contracts:
        create_contracts_structure(target, update=False, dry_run=args.dry_run)
        inject_contract_first_policy(target, dry_run=args.dry_run)
        if args.profile:
            apply_profile(target, args.profile, update=False, dry_run=args.dry_run)
    elif args.update:
        cmd_update(target, dry_run=args.dry_run, verbose=args.verbose,
                   with_contracts=with_contracts, profile=args.profile)
    else:
        cmd_install(target, dry_run=args.dry_run, verbose=args.verbose,
                    with_contracts=with_contracts, profile=args.profile)


if __name__ == "__main__":
    main()
