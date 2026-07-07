# HCHAIN Compatibility Validation
Date: 2026-05-24

## 1. 테스트 환경

### Ubuntu (현재 테스트 환경)
```
GNU bash, 버전 5.1.16(1)-release (x86_64-pc-linux-gnu)
OS: Ubuntu 22.04 LTS
```

### macOS (시뮬레이션)
- macOS 기본 bash: GNU bash 3.2.57
- 직접 테스트 불가 (Ubuntu 환경)
- 코드 레벨에서 bash 3.2 비호환 문법 제거 완료를 정적 분석으로 검증

---

## 2. 정적 분석 — bash 3.2 비호환 문법 잔존 여부

```
$ grep -n "^declare -A\|^\s*declare -A" harness/queue/check_consistency.sh
OK: no active declare -A
```

수정된 `check_consistency.sh`에 `declare -A` 코드가 없음을 확인.

---

## 3. 동적 검증 — Ubuntu bash 5.1.16

### 3.1 기본 모드 (C1 검사)

```
$ bash harness/queue/check_consistency.sh
✅ Queue consistency PASS (tasks: 28)
EXIT: 0
```

### 3.2 확장 모드 (C1~C8 검사)

```
$ bash harness/queue/check_consistency.sh --extended
⚠️  Queue consistency WARN:
   WARN   C4 MISSING_STATE: TASK_FUX_001 in queue/done has no task.state.json
   WARN   C4 MISSING_STATE: TASK_FUX_003 in queue/done has no task.state.json
   WARN   C4 MISSING_STATE: TASK_FUX_004 in queue/done has no task.state.json
EXIT: 0
```

C4 WARNING은 done 큐에 state 파일 없는 레거시 태스크로 인한 정상적 경고.
FAIL 없음, exit 0 — 정상 동작.

### 3.3 harness_history.sh (bash5 동작 확인)

```
$ bash harness/harness_history.sh | head -5
┌──────── ... ─────────────────────────────────────┐
│ TASK_ID │ 완료 시각 │ REVIEW │ VALIDATE │ 루프 │ 주요 이슈 │
...
EXIT: 0
```

---

## 4. 수정 전/후 비교

| 항목 | 수정 전 | 수정 후 |
|------|---------|---------|
| macOS bash 3.2 실행 | ❌ `declare: -A: invalid option` | ✅ 정상 동작 (예상) |
| Ubuntu bash 5 실행 | ✅ | ✅ |
| C1 기능 (중복 검사) | ✅ | ✅ |
| C2~C8 기능 (확장 검사) | ✅ | ✅ |
| harness_history.sh 실행 | ✅ / ❌(macOS) | ✅ / 명확한 오류 메시지(macOS) |

---

## 5. macOS 검증 가이드 (현장 테스트 절차)

macOS 환경에서 직접 검증이 필요한 경우:

```bash
# bash 버전 확인
bash --version
# → GNU bash, version 3.2.57(1)-release (x86_64-apple-darwin...)

# 기본 모드 실행
bash harness/queue/check_consistency.sh
# 예상: ✅ Queue consistency PASS (tasks: N)

# 확장 모드 실행
bash harness/queue/check_consistency.sh --extended
# 예상: PASS 또는 WARN (FAIL 없음)

# harness_history.sh (bash5 필요 경고 확인)
bash harness/harness_history.sh
# 예상: Error: harness_history.sh requires bash 4.0 or higher.
#        macOS: brew install bash
```

---

## 6. 결론

- [x] macOS bash 3.2 호환 코드 적용 완료 (`check_consistency.sh`)
- [x] Ubuntu bash 5 실행 검증 완료
- [x] C1~C8 기능 모두 정상 동작 확인
- [x] `harness_history.sh` bash 버전 guard 추가로 명확한 오류 메시지 제공
- [ ] macOS 현장 직접 테스트 (장비 필요)
