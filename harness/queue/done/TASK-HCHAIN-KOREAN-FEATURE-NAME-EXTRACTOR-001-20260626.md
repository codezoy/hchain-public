Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-contract-workflow-usability-001
Commit      : (see below)

Task Summary:
  한국어 자연어에서 적절한 기능명을 추출하는 extract_feature_name() 구현.

생성/수정 파일:
  1. install.py (수정)
     - 상수 추가: _KO_PARTICLES, _KO_EN_MAP (40개 매핑), _KO_STOP_WORDS, _EN_STOP_WORDS
     - 함수 추가: _strip_ko_particle() — 한국어 조사/접미사 제거
     - 함수 추가: extract_feature_name() — 우선순위 5단계 추출
     - run_contract_workflow() 수정: 첫 단어 추출 → extract_feature_name() 교체
  2. tests/test_install_korean_feature_name.py (신규, 22개 테스트)

추출 우선순위:
  1. 영문 토큰 2개 이상 → QUEUE_RETRY
  2. 대문자 토큰 → AUTH
  3. 한국어 명사 매핑 → FAILED_JOB_RETRY
  4. 영문 1개 + 한국어 명사 → QUEUE_FAILED_RETRY
  5. Fallback → FEATURE

핵심 수정: 원본 토큰 먼저 확인 후 조사 제거 (복합어 오분리 방지)
  "재시도" → 직접 매핑 → RETRY (기존: "도" 조사 잘림 → "재시" → 매핑 실패)

Validation:
  pytest tests/ → 96 passed (기존 74 + 신규 22)

Status      : PASS
