# HCHAIN 시작하기

## 설치

### 요구사항

| 항목 | 요구사항 |
|------|----------|
| Python | 3.6+ (외부 의존성 없음) |
| bash | 4.0+ |
| jq | 필수 |
| Codex CLI | RESEARCH / REVIEW 단계 |

### 1. HCHAIN 클론

```bash
git clone <hchain-repo> ~/hchain
```

### 2. 대상 프로젝트에 설치

```bash
python3 ~/hchain/install.py --target /path/to/your-project
```

설치 후 생성되는 항목:

```
your-project/
├── harness/                  ← 실행 런타임
│   ├── harness_runner.sh
│   ├── queue/
│   │   ├── pending/
│   │   ├── running/
│   │   ├── done/
│   │   └── blocked/
│   ├── tasks/
│   └── logs/
├── contracts/                ← 계약 디렉터리
│   ├── PROJECT.md
│   ├── ARCHITECTURE.md
│   ├── RULES.md
│   ├── VALIDATION.md
│   ├── DONE.md
│   └── features/
├── CLAUDE.md                 ← HCHAIN 정책 주입
└── .hchain/
    └── meta.json
```

---

## init

이미 설치된 프로젝트를 업데이트한다. 런타임 데이터(tasks, logs, queue)는 보존된다.

```bash
python3 ~/hchain/install.py --target /path/to/your-project --update
```

contracts만 초기화:

```bash
python3 ~/hchain/install.py --target /path/to/your-project --init-contracts
```

---

## contract

기능 개발 전 계약서를 작성한다. **계약 없이 코드 작성 금지**가 HCHAIN의 핵심 규칙이다.

### Contract Workflow 실행 (권장)

자연어 요청을 입력하면 관련 계약 선택, 영향 범위 분석, 질문 생성, 계약 초안 생성이 자동으로 이루어진다.

```bash
python3 ~/hchain/install.py \
  --target /path/to/your-project \
  --workflow "큐에서 실패한 아이템을 재시도하는 기능"
```

### 직접 계약 생성

```bash
python3 ~/hchain/install.py \
  --target /path/to/your-project \
  --generate-contract QUEUE_RETRY
```

### 계약 상태 확인

```bash
python3 ~/hchain/install.py \
  --target /path/to/your-project \
  --contract-check
```

---

## task

계약서를 참조하여 Task를 작성하고 실행한다.

### Task 파일 작성

```bash
cat > /path/to/your-project/harness/tasks/TASK_20260626_001.md <<'EOF'
---
task_id: TASK_20260626_001
title: 큐 재시도 기능 구현
retry_limit: 3
severity_stop: MAJOR
validate:
  - pytest tests/
---

## 목표
contracts/features/QUEUE_RETRY.md 계약에 따라 재시도 기능 구현

## 계약 참조
- contracts/features/QUEUE_RETRY.md
EOF
```

### 큐 등록 및 실행

```bash
touch /path/to/your-project/harness/queue/pending/TASK_20260626_001
bash /path/to/your-project/harness/harness_runner.sh --task TASK_20260626_001
```

---

## review

구현 후 계약과 코드 사이의 차이를 확인한다.

```bash
python3 ~/hchain/install.py \
  --target /path/to/your-project \
  --contract-review-diff
```

출력 예:

```
[계약에는 있으나 코드에 없음]
  - QUEUE_RETRY.md: retry_count 필드

[검증 누락]
  - QUEUE_RETRY.md: ## 검증 섹션 없음
```

Harness가 자동으로 REVIEW → VALIDATE → DONE 단계를 거친다.

---

## 실수하지 않으려면

### 정상 작업 흐름

```
버그 발견
 ↓
원인 파악
 ↓
수정
 ↓
REVIEW → VALIDATE
 ↓
PASS → DONE
```

### Major Issue 발생 시 (즉시 수정 금지)

```
버그 발견
 ↓
수정
 ↓
새 Root Cause 발견  ← 여기서 멈춘다
 ↓
🚨 PLAN LOOP REQUIRED
 ↓
PLAN LOOP 10단계 완료 후 DONE
```

다음 상황에서 즉시 멈추고 PLAN LOOP에 진입한다:

- 수정했는데 새로운 원인이 또 나왔다
- PASS_WITH_ISSUES가 떴다
- "일단 동작"이라는 말이 나왔다
- E2E를 실제로 실행하지 않았다
- 재발방지 정책을 안 썼다

### PASS_WITH_ISSUES 발생 시

```
Health Score 9
Remaining Issues 있음

↓

PASS 선언 금지
DONE 선언 금지
PLAN LOOP 재진입
```

PASS_WITH_ISSUES는 PASS가 아니다. 하나라도 남아 있으면 재진입이다.
