Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-contract-workflow-phase2-001
Commit      : f398242

Task Summary:
  계약-코드 차이 분석 기능 구현.
  읽기 전용, 자동 수정 없음.
  5개 카테고리 분석 출력.

Changes:
  1. install.py
     - _extract_api_names_from_contract(content) 추가
     - _scan_code_identifiers(target) 추가
     - cmd_contract_review_diff(target) 추가
     - CLI --contract-review-diff 플래그 추가
  2. tests/test_install_contract_review_diff.py (신규)
     - 11개 테스트 케이스

Files Changed:
  - install.py (수정)
  - tests/test_install_contract_review_diff.py (신규)

Validation:
  pytest tests/test_install_contract_review_diff.py ... -v
  → 63 passed, 0 failed (0.16s)

Known Issues:
  없음

Status      : PASS
