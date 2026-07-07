Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-contract-workflow-usability-001

Task Summary:
  Contract Workflow에 사용자 승인 단계 추가.

생성/수정 파일:
  1. install.py (수정)
     - request_workflow_approval(): yes/approve/y → True, cancel/reject/n → False, EOFError → False
     - run_contract_workflow(): _input_fn=input 파라미터 추가 (테스트 주입 가능)
     - Preview 출력 후 승인 대기 → 승인 시 계약 생성, 거부 시 취소 메시지 출력
     - dry_run=True 시 자동 승인 (prompt 없음)
     - 반환 dict에 approved 플래그 포함
  2. tests/test_install_approval_workflow.py (신규, 28개 테스트)
  3. tests/test_install_contract_dryrun.py (수정: _input_fn 인자 추가)
  4. tests/test_install_contract_workflow.py (수정: _input_fn 인자 추가)

흐름:
  Steps 1~4 (분석) → Preview → 승인? → [yes] Step 5 계약 생성 + Step 6 안내
                                     → [no]  취소 메시지 출력 (파일 생성 없음)

Validation:
  pytest tests/ → 162 passed (기존 134 + 신규 28)

Status      : PASS
