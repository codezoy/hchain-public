Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-documentation-validation-001
Commit      : 9000082

Task Summary:
  기능 계약 Lifecycle 도입 및 Contract Workflow 통합.

생성/수정 파일:
  1. templates/contracts/CONTRACT_LIFECYCLE.md (신규)
     - 5단계 상태: draft → review → approved → implemented → deprecated
     - Feature Contract YAML front-matter 필드 (status, created, updated, owner)
     - 상태 전환 규칙 및 예시
  2. install.py (수정)
     - parse_contract_header(): 'status' 필드 파싱 추가 (기본값: 'draft')
     - run_contract_workflow(): Step 5에 lifecycle 검사 통합
       기존 계약의 status에 따라 안내 메시지 출력

Lifecycle 메시지:
  draft       → "기존 초안이 있습니다. 계속 작성하세요."
  review      → "검토 중인 계약이 있습니다. approved로 변경하세요."
  approved    → "승인된 계약이 있습니다. Task를 생성하세요."
  implemented → "이미 구현된 계약입니다. 신규 기능이면 새 계약서를 작성하세요."
  deprecated  → "폐기된 계약입니다. 새 계약서를 작성하세요."

Validation:
  pytest tests/ → 74 passed

Status      : PASS
