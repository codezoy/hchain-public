Executor    : Claude (claude-sonnet-4-6)
Branch      : feature/hchain-documentation-validation-001
Commit      : e563a2f

Task Summary:
  계약 필요 여부 판단 기준 문서 작성.

생성 파일:
  - templates/contracts/CONTRACT_REQUIRED.md
    (install 시 target 프로젝트의 contracts/ 에 배포됨)

내용:
  계약 필요 (10가지):
    신규 기능, UI 변경, API 변경, DB 변경, State 변경,
    Queue, Retry 정책, Worker 추가, Scheduler 추가, 예외 정책 변경

  계약 불필요 (6가지):
    버그 수정, 로그 추가, 테스트 추가, 오타 수정,
    단순 리팩토링, 주석 수정

  판단 기준:
    "이 변경이 기존 계약을 위반하는가?" 기준 명시

Validation:
  pytest tests/ → 74 passed
  --init-contracts dry-run 시 CONTRACT_REQUIRED.md 배포 확인

Status      : PASS
