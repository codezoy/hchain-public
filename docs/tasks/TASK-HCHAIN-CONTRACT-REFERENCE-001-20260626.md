Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-contract-workflow-phase2-001
Commit      : a2cb948

Task Summary:
  계약 문서 간 참조 구조 추가.
  YAML 프론트매터(관련 계약/영향 범위/관련 기능/우선순위)를 통해
  Claude/Codex가 필요한 계약만 선택적으로 읽을 수 있도록 구현.

Changes:
  1. install.py
     - parse_contract_header(md_path) 추가 — YAML 프론트매터 파싱
     - select_relevant_contracts(contracts_dir, keywords) 추가 — 키워드 기반 계약 선택
     - CLI --select-contracts KEYWORD 플래그 추가
  2. templates/contracts/features/TEMPLATE.md
     - YAML 프론트매터 헤더 (관련 계약/영향 범위/관련 기능/우선순위) 추가
  3. tests/test_install_contract_reference.py (신규)
     - 10개 테스트 케이스

Files Changed:
  - install.py (수정)
  - templates/contracts/features/TEMPLATE.md (수정)
  - tests/test_install_contract_reference.py (신규)

Validation:
  pytest tests/test_install_contract_reference.py tests/test_install_contracts.py tests/test_install_agents_policy.py -v
  → 27 passed, 0 failed (0.09s)

Known Issues:
  없음

Status      : PASS
