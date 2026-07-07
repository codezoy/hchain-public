Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-contract-workflow-usability-001

Task Summary:
  룰셋 기반 영향 범위 분석 추가 (impact_rules.yaml).

생성/수정 파일:
  1. templates/contracts/impact_rules.yaml (신규)
     - 7개 영역: frontend, backend, database, worker, auth, logging, validation
     - 한국어 + 영어 키워드 포함
  2. install.py (수정)
     - _load_impact_rules(): YAML 파싱 (외부 의존성 없음, 줄 파싱)
     - _infer_impacts_from_ruleset(): 룰셋 매핑 기반 영향 탐지
     - _IMPACT_RULES_PATH: 룰셋 파일 경로 상수
     - run_contract_workflow() Step 2: 룰셋 우선 사용, 폴백 AI 추론
  3. tests/test_install_impact_ruleset.py (신규, 14개 테스트)

우선순위 로직:
  1. impact_rules.yaml 로드 성공 → _infer_impacts_from_ruleset()
  2. 룰셋 매칭 없음 → _infer_impacts_from_name() 폴백
  3. 룰셋 파일 없음 → _infer_impacts_from_name() 폴백

출력 예: "[2] 영향 범위 분석 (ruleset):"

Validation:
  pytest tests/ → 110 passed (기존 96 + 신규 14)

Status      : PASS
