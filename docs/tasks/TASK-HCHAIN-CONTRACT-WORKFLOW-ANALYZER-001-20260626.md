Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-contract-workflow-phase2-001
Commit      : ce25e2e

Task Summary:
  Contract Workflow 내부 단계 구현.
  사용자 자연어 요청 → 6단계 자동 수행.
  별도 "Impact Analyzer" 명령 없음 — Contract Workflow 내부 단계로 통합.

Changes:
  1. install.py
     - _detect_missing_policies(contracts_dir) 추가
     - _generate_questions(feature_name, impacts, missing_policies) 추가
     - run_contract_workflow(request, target, dry_run) 추가
     - CLI --workflow REQUEST 플래그 추가
  2. skills/hchain/SKILL.md
     - Contract Workflow 자동 수행 규칙 섹션 추가
     - 6단계 파이프라인 문서화
  3. tests/test_install_contract_workflow.py (신규)
     - 13개 테스트 케이스

Files Changed:
  - install.py (수정)
  - skills/hchain/SKILL.md (수정)
  - tests/test_install_contract_workflow.py (신규)

Validation:
  pytest tests/test_install_contract_workflow.py ... -v
  → 52 passed, 0 failed (0.14s)

Known Issues:
  없음

Status      : PASS
