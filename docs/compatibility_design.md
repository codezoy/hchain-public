# HCHAIN Compatibility Design — macOS bash 호환성
Date: 2026-05-24

## 1. 목표

macOS 기본 bash(3.2)와 Ubuntu bash(5.x)에서 모두 동작하는 harness 스크립트 구현

---

## 2. 방법 비교

| 방법 | 장점 | 단점 |
|------|------|------|
| **A. bash 3.2 호환 코드로 전면 변경** | 별도 설치 불필요, OS 기본 셸로 동작 | associative array 대체 코드 필요 |
| **B. bash5 자동 탐지 후 실행** | 기존 코드 유지 | brew bash 설치 필수, 경로 탐지 복잡 |
| **C. bootstrap에서 bash 버전 확인** | 진입 시점 차단 가능 | 사용자에게 설치 강제 |

---

## 3. 선택: **A. bash 3.2 호환 코드로 변경** (check_consistency.sh)

### 이유
- `check_consistency.sh`는 harness의 핵심 안전 검증 스크립트
- 실행 환경에 Homebrew가 없을 수 있음 (CI, fresh macOS)
- 의존성 없이 동작해야 이식성이 높음
- 변경 범위가 명확하고 제한적 (C1 체크의 associative array 1개)

### `harness_history.sh`에 대한 보완 조치
- 복수의 associative array를 사용하는 이력 표시 도구
- 전면 재작성은 위험 — bash 버전 guard 추가로 명확한 오류 메시지 제공

---

## 4. `declare -A` 대체 방법

### 문제
```bash
declare -A task_locations          # bash 4+ 전용
task_locations[$task_id]="$dir"   # bash 4+ 전용
${!task_locations[@]}             # bash 4+ 전용 (키 목록)
```

### 대체: 임시 파일 기반 key:value 저장소

```bash
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# set:  printf '%s\t%s\n' "$key" "$value" >> "$TMPFILE"
# get:  awk -v k="$key" -F'\t' '$1==k{print $2}' "$TMPFILE"
# keys: awk -F'\t' '{print $1}' "$TMPFILE" | sort -u
```

#### 선택 이유
- bash 3.2에서 완전 동작
- `awk`, `sort`는 macOS/Ubuntu 공통 POSIX 도구
- 파일 I/O 오버헤드 최소 (queue 파일 수는 수십 개 이하)
- 코드 의도가 명확하고 읽기 쉬움

---

## 5. 수정 파일 목록

| 파일 | 수정 내용 |
|------|----------|
| `itemlabs_v3/harness/queue/check_consistency.sh` | `declare -A` → tmpfile 방식으로 C1 검사 재구현 |
| `itemlabs_v3/harness/harness_history.sh` | bash 버전 guard 추가 (bash < 4 시 명확한 오류 출력) |
| `hchain/install.sh` | bash 버전 경고 추가 (non-blocking, 정보 제공용) |

---

## 6. 비수정 파일

| 파일 | 이유 |
|------|------|
| `harness_runner.sh` | `declare -A` 없음, bash 3.2 호환 |
| `harness/lib/*.sh` | `declare -A` 없음, bash 3.2 호환 |
| `harness/queue/move.sh` | `declare -A` 없음, bash 3.2 호환 |

---

## 7. 호환성 보장 원칙

- 수정 후 Ubuntu bash5에서도 동일하게 동작해야 함
- 기존 기능(C1~C8 검사) 완전 유지
- 테스트: `bash --version` 확인 후 `check_consistency.sh` 실행
