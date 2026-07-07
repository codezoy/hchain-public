Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-contract-workflow-phase2-001
Commit      : 3cf10d2

Task Summary:
  프로젝트 프로파일 지원 구현.
  ai-video / web / api / cli 4개 프로파일.
  기존 파일 보호, dry-run 지원.

Changes:
  1. install.py
     - PROFILES 상수 추가 (ai-video, web, api, cli)
     - apply_profile(target, profile, update, dry_run) 추가
     - CLI --profile 플래그 추가
     - cmd_install(), cmd_update() profile 파라미터 추가
  2. skills/hchain/SKILL.md
     - 프로파일 사용 방법 문서 추가
  3. tests/test_install_contract_profile.py (신규)
     - 11개 테스트 케이스

Files Changed:
  - install.py (수정)
  - skills/hchain/SKILL.md (수정)
  - tests/test_install_contract_profile.py (신규)

Validation:
  pytest tests/test_install_contract_profile.py -v
  → 11 passed, 0 failed
  pytest tests/ -v
  → 74 passed, 0 failed (0.18s)

Known Issues:
  없음

Status      : PASS
