# TASK_CORE_002 - install.sh 런타임 분리 및 이식성 강화

## 목표

`install.sh`가 생성하는 `meta.json`에서 `hchain_path`(Core 절대경로) 필드의
이식성 문제를 해결하고, 설치 검증 함수를 추가하여 다중 환경 설치를 안전하게 지원한다.

## 문제 배경

현재 `install.sh`는 `meta.json`에 `hchain_path: "$HCHAIN_ROOT"` 를 기록한다.
이 값은 Core가 설치된 머신의 절대경로이다.

```json
"hchain_path": "~/workspace/hchain"
```

문제 상황:
- Core가 다른 경로로 이동하면 `meta.json`의 경로가 stale 해진다.
- Mac mini에서 설치하면 `/Volumes/ExternalSSD/...` 가 기록된다.
- Target 프로젝트가 다른 머신으로 복사되면 경로가 무의미해진다.
- Core 자체에 절대경로가 하드코딩된 것은 아니지만, 설치 결과물에
  머신 종속 경로가 남는다.

## 범위

- `install.sh`에 `--verify` 옵션 추가 (이미 설치된 프로젝트의 meta.json 유효성 검사)
- `meta.json`의 `hchain_path` 를 상대경로 또는 심볼릭 참조로 대체하는 방안 검토
- 또는 `hchain_path` 를 Optional 필드로 명시하고 경고 문구를 install.sh에 추가
- `install.sh` 에 `--version` 출력 기능 추가

## 제외 범위

- `meta.json` 스키마 전면 변경 (하위호환성 유지)
- 런타임 실행 엔진 구현 (별도 Task)
- `target/.hchain/` 내부 구조 설계 (별도 Task)

## 실행 절차

1. `install.sh` 상단에 `--version`, `--verify <target>`, `--help` 옵션 파싱 추가
2. `hchain_path` 필드 처리 방침 결정:
   - 옵션 A: 필드 제거 (Core 경로는 실행 시점에 $0 으로 판단)
   - 옵션 B: `"hchain_path": "$(pwd)"` 유지하되 `# NOTE: machine-specific` 주석 추가
3. 설치 후 `meta.json` 검증 로직 추가 (`jq` 없이 grep 기반으로 구현)
4. `git add` → `git commit` (feat: add verify option and portability note to install.sh)

## 완료 조건

- [ ] `./install.sh --version` 실행 시 버전 출력
- [ ] `./install.sh --verify <path>` 실행 시 기설치 여부 확인
- [ ] `hchain_path` 필드에 대한 처리 방침이 코드에 명시됨
- [ ] `/tmp/hchain-test-project` 에 오류 없이 설치 가능

## 검증 방법

```bash
mkdir -p /tmp/hchain-test-project
./install.sh /tmp/hchain-test-project
cat /tmp/hchain-test-project/.hchain/meta.json
./install.sh --verify /tmp/hchain-test-project
./install.sh --version
```

## 오염 방지 규칙

- `install.sh` 내부에 특정 프로젝트 경로(`itemlabs`, `ai-video` 등)를 절대 하드코딩하지 않는다.
- Core 저장소 내 `$HCHAIN_ROOT` 하위에 런타임 파일을 생성하지 않는다.
- 테스트는 반드시 `/tmp/` 아래 임시 경로에서 수행한다.
