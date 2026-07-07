Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-contract-workflow-usability-001

Task Summary:
  Contract Workflow 실행 결과 Preview 블록 추가.

생성/수정 파일:
  1. install.py (수정)
     - build_contract_preview(): 미리보기 dict 생성 (기능명, 영향범위, 예상파일수, 계약경로, 질문수)
     - print_contract_preview(): 미리보기 출력 함수
     - run_contract_workflow(): Step 6 전에 Preview 출력 추가, 반환 dict에 preview 포함
  2. tests/test_install_contract_preview.py (신규, 14개 테스트)

Preview 출력 형태:
  [Preview] 계약 요약
    ────────────────────────────────────────
    기능명      : QUEUE_RETRY
    영향 범위   : backend, worker
    예상 파일   : 3개
    계약 경로   : contracts/features/QUEUE_RETRY.md
    질문 수     : 3개
    ────────────────────────────────────────

예상 파일 수 계산: 1(계약 파일) + len(impacts)

Validation:
  pytest tests/ → 124 passed (기존 110 + 신규 14)

Status      : PASS
