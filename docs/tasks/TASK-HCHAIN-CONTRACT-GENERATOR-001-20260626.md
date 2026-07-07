Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-contract-workflow-phase2-001
Commit      : 73f5858

Task Summary:
  기능 계약 자동 생성 구현.
  프로젝트 구조 분석(파일 확장자, 디렉토리명 기반)으로 영향 범위 자동 추론.
  기능명 기반 키워드 매칭으로 추가 영향 범위 보강.
  기존 파일 존재 시 덮어쓰기 금지.

Changes:
  1. install.py
     - analyze_project_structure(target) 추가 — 프로젝트 분석
     - _infer_impacts_from_name(feature_name) 추가 — 기능명 기반 영향 추론
     - generate_feature_contract(feature_name, target, dry_run) 추가
     - CLI --generate-contract FEATURE_NAME 플래그 추가
  2. tests/test_install_contract_generator.py (신규)
     - 12개 테스트 케이스

Files Changed:
  - install.py (수정)
  - tests/test_install_contract_generator.py (신규)

Validation:
  pytest tests/test_install_contract_generator.py ... -v
  → 39 passed, 0 failed (0.11s)

Known Issues:
  없음

Status      : PASS
