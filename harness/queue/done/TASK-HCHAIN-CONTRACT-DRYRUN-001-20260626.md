Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-contract-workflow-usability-001

Task Summary:
  --workflow --dry-run 지원 추가.

생성/수정 파일:
  1. install.py (수정)
     - run_contract_workflow(): 헤더에 [dry-run]/[hchain] prefix 표시
     - run_contract_workflow(): 반환 dict에 dry_run 플래그 포함
     - dry_run=True 시 generate_feature_contract()가 파일 생성 안 함 (기존 구현 활용)
  2. tests/test_install_contract_dryrun.py (신규, 10개 테스트)

검증된 동작:
  - dry-run: 계약 파일 생성 없음, 기존 파일 수정 없음
  - dry-run: 출력에 "[dry-run]" prefix 포함
  - dry-run: 분석 결과(feature_name, impacts, questions) 정상 반환
  - 일반 모드: 계약 파일 정상 생성, "[hchain]" prefix

Validation:
  pytest tests/ → 134 passed (기존 124 + 신규 10)

Status      : PASS
