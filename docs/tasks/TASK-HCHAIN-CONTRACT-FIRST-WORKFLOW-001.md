# TASK-HCHAIN-CONTRACT-FIRST-WORKFLOW-001: Contract First Workflow 도입

## Goal

HCHAIN에 Contract First Workflow를 도입한다.
신규 기능 추가 시 구현보다 계약(Contract)을 먼저 정의하고,
구현 전 누락 사항을 발견하여 시행착오를 줄인다.
기존 HCHAIN Workflow에 자연스럽게 통합되며, 과도한 문서 생성을 지양한다.

## Scope

포함:
- `install.py` — contract 구조 생성/검토 함수 추가
- `templates/contracts/` — 기본 계약 템플릿 7개 신규 생성
- `skills/hchain/SKILL.md` — `/hchain contract` 명령 핸들러 추가
- `tests/test_install_contracts.py` — pytest 신규 작성
- `harness/tasks/` — 이 파일

제외:
- 기존 harness 구조 변경 없음
- 기존 install/update 동작 변경 없음 (하위 호환)
- 외부 런타임 의존성 추가 없음

## Done Criteria

- [ ] `templates/contracts/` 하위 5개 기본 계약 + TEMPLATE.md 생성
- [ ] `install.py` — create_contracts_structure(), inject_contract_first_policy(), cmd_contract_check() 추가
- [ ] `install.py --init-contracts` 플래그 동작
- [ ] `install.py --contract-check` 플래그 동작 (읽기 전용)
- [ ] `install.py --contract-check --write` 누락 섹션 자동 추가
- [ ] `SKILL.md` — `/hchain contract` 핸들러 등록
- [ ] pytest 전체 통과
- [ ] 기존 테스트(test_install_agents_policy.py) 회귀 없음

## Steps

1. [PLAN] 기존 구조 분석 완료
2. [RESEARCH] install.py 패턴, 테스트 패턴 분석 완료
3. [ACTION] 구현 완료
4. [REVIEW] 코드 감사
5. [VALIDATE] pytest 실행
6. [DONE] Done 파일 생성

## Final Report

harness/queue/done/TASK-HCHAIN-CONTRACT-FIRST-WORKFLOW-001.md 에 기록
