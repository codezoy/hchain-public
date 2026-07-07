# HCHAIN Compatibility Report — macOS / Ubuntu
Date: 2026-05-24

## 1. 분석 대상

| 경로 | 비고 |
|------|------|
| `hchain/install.sh` | HCHAIN Core 설치 스크립트 |
| `itemlabs_v3/harness/queue/check_consistency.sh` | queue 정합성 검증 (핵심 harness 스크립트) |
| `itemlabs_v3/harness/harness_history.sh` | 작업 이력 표시 (보조 스크립트) |
| `itemlabs_v3/harness/harness_runner.sh` | harness 실행 진입점 |
| `itemlabs_v3/harness/lib/*.sh` | harness 공통 라이브러리 |
| `itemlabs_v3/harness/queue/move.sh` | queue 마커 이동 |

---

## 2. 발견된 bash 4+ 의존 코드

### 2.1 `declare -A` (Associative Array) — **bash 4.0+**

macOS 기본 bash(GNU bash 3.2.57)에서 `declare -A` 실행 시:
```
declare: -A: invalid option
```

| 파일 | 라인 | 내용 |
|------|------|------|
| `harness/queue/check_consistency.sh` | 31 | `declare -A task_locations` |
| `harness/harness_history.sh` | 146 | `declare -A task_last_ts` |
| `harness/harness_history.sh` | 147 | `declare -A task_reviewer_file task_reviewer_ts` |
| `harness/harness_history.sh` | 148 | `declare -A task_validator_file task_validator_ts` |
| `harness/harness_history.sh` | 149 | `declare -A task_loop_count` |

### 2.2 Associative Array 참조 연산 — **bash 4.0+**

`declare -A` 에 종속된 연산들:

| 파일 | 라인 | 패턴 | 설명 |
|------|------|------|------|
| `check_consistency.sh` | 43 | `${task_locations[$task_id]:-}` | 값 참조 |
| `check_consistency.sh` | 44 | `${task_locations[$task_id]}=...` | 값 갱신 |
| `check_consistency.sh` | 51 | `${!task_locations[@]}` | 키 목록 순회 |
| `harness_history.sh` | 189~199 | `${task_last_ts[$tid]}` 외 | 값 참조/갱신 |

---

## 3. bash 3.2 호환 기능 (오해 없도록 명시)

아래 구문은 bash 3.2에서 **정상 동작**하므로 수정 불필요:

| 구문 | 상태 |
|------|------|
| `[[ ]]` 조건문 | ✅ bash 3.2 이상 지원 |
| `=~` 정규표현식 매칭 | ✅ bash 3.2 이상 지원 |
| `< <()` 프로세스 치환 | ✅ bash 3.2 이상 지원 |
| `read -ra` 배열 읽기 | ✅ 일반 배열은 bash 3.2 지원 |
| `set -euo pipefail` | ✅ bash 3.2 이상 지원 |
| `BASH_VERSINFO` 변수 | ✅ bash 3.0 이상 지원 |

---

## 4. 영향도 평가

| 스크립트 | 심각도 | 이유 |
|----------|--------|------|
| `check_consistency.sh` | **HIGH** | harness 정합성 검증 핵심 기능. macOS에서 즉시 실패 |
| `harness_history.sh` | **MEDIUM** | 이력 조회 보조 도구. 운영 필수 경로 아님 |
| `install.sh` (hchain core) | **LOW** | bash 4+ 문법 없음. bash 버전 검증 로직 부재 |

---

## 5. 결론

- **수정 필수**: `check_consistency.sh` — `declare -A` 제거, bash 3.2 호환 코드로 대체
- **수정 권장**: `harness_history.sh` — bash 버전 guard 추가 (전면 재작성은 불필요)
- **추가 권장**: `install.sh` — 설치 시 bash 버전 경고 출력

---

## 6. 테스트 환경 정보

| 항목 | Ubuntu (현재 환경) | macOS (예상) |
|------|-------------------|--------------|
| bash 버전 | GNU bash 5.1.16 | GNU bash 3.2.57 |
| `declare -A` | ✅ | ❌ |
| 수정 후 예상 | ✅ | ✅ |
