# VALIDATION_RULES — 검증 규칙 상세

> Reviewer (정적 리뷰) 와 Validator (런타임 검증) 의 책임 범위와 판정 기준을 정의한다.
> CLAUDE.md §2.1, §6, §8 의 구현 기준이다.

---

## 1. Reviewer 책임 (정적 리뷰)

**수행 항목:**
- 코드 로직 검토
- 보안 취약점 탐지 (OWASP Top 10 등)
- 타입·런타임 위험 분석
- 컨벤션·가독성 감사
- 정책서(CLAUDE.md) 위반 여부

**금지 항목:**
- build / test / E2E 실행
- 서비스 접근 (curl, health check 등)
- 코드 수정

**출력 형식:**
```json
{
  "status": "PASS|FAIL",
  "issues": [
    {"severity": "CRITICAL|MAJOR|MINOR|NIT", "message": "...", "file": "...", "line": 0}
  ]
}
```

## 2. Validator 책임 (런타임 검증)

**수행 항목:**
- build / typecheck / lint / test
- API health check (`curl`)
- Web 라우트 접근 확인
- Worker 프로세스 상태 (`ps`, `pgrep`)
- Redis / PostgreSQL 연결 확인
- Queue / job 상태 확인
- restart.sh 실행
- Playwright E2E (해당 시)

**금지 항목:**
- 코드 수정
- 코드 리뷰 (그것은 Reviewer 의 역할)

**출력 형식:**
```json
{
  "status": "PASS|FAIL",
  "checks": [
    {"name": "...", "result": "PASS|FAIL", "detail": "..."}
  ],
  "blocking_issues": [
    {"severity": "CRITICAL|MAJOR|MINOR|NIT", "message": "..."}
  ]
}
```

## 3. DONE 판정 기준

| Reviewer + Validator | 처리 |
|---|---|
| 둘 다 PASS | DONE |
| PASS + FAIL (MINOR/NIT만) | DONE (PASS 간주) |
| FAIL (MINOR/NIT만) + 무관 | DONE (PASS 간주) |
| FAIL + CRITICAL/MAJOR 존재 | loop_count++ → ACTION 재진입 |
| loop_count == 3 | Safety Break |

## 4. 이슈 등급 카운트 명령

```bash
# Reviewer CRITICAL/MAJOR 카운트
jq '[.issues[]?.severity] | map(select(.=="CRITICAL" or .=="MAJOR")) | length' "$REVIEWER_LOG"

# Validator CRITICAL/MAJOR 카운트
jq '[.blocking_issues[]?.severity] | map(select(.=="CRITICAL" or .=="MAJOR")) | length' "$VALIDATOR_LOG"
```

## 5. CLI 호출 패턴 (공통)

```bash
LOG_PATH="harness/logs/$(date -u +%Y%m%d_%H%M%S)_REVIEWER_${TASK_ID}.json"
timeout 300 [CLI 명령] > "$LOG_PATH" && cat "$LOG_PATH"
jq -e . "$LOG_PATH" || echo "JSON PARSE FAIL"
```

- `&&` 체이닝 필수
- exit code 0 아닌 경우 즉시 FAIL 처리
- log 파일명: `TIMESTAMP_AGENTNAME_TASKID.json`
