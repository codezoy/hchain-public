# 프로젝트 Profile

## 개요

Profile은 프로젝트 유형에 맞는 기능 계약 파일을 자동으로 생성하는 기능이다. 설치 또는 업데이트 시 `--profile` 플래그를 사용한다.

생성된 파일은 `contracts/features/` 디렉터리에 저장된다. 기존 파일은 덮어쓰지 않는다.

---

## ai-video

AI 영상 생성 프로젝트를 위한 프로파일이다.

```bash
python3 ~/hchain/install.py --target /path/to/ai-video --profile ai-video
```

생성 파일:

| 파일 | 내용 |
|------|------|
| `contracts/features/TEMPLATE.md` | 영상 템플릿 계약 |
| `contracts/features/RENDER.md` | 렌더링 파이프라인 계약 |
| `contracts/features/TTS.md` | TTS 서비스 계약 |

### TEMPLATE.md

영상 템플릿 생성·관리 기능의 계약서 초안. 템플릿 구조, 파라미터, 렌더링 연동 방법을 명세한다.

### RENDER.md

렌더링 파이프라인 계약서 초안. 렌더링 요청, 진행 상태, 결과 저장 방법을 명세한다.

### TTS.md

TTS(Text-to-Speech) 서비스 계약서 초안. 음성 합성 요청, 제공자(ElevenLabs 등), 캐싱 정책을 명세한다.

---

## web

웹 서비스 프로젝트를 위한 프로파일이다.

```bash
python3 ~/hchain/install.py --target /path/to/my-web --profile web
```

생성 파일:

| 파일 | 내용 |
|------|------|
| `contracts/features/API.md` | API 계약 |
| `contracts/features/AUTH.md` | 인증/인가 계약 |
| `contracts/features/UI.md` | UI 컴포넌트 계약 |

### API.md

REST API 엔드포인트 설계 계약서 초안. 엔드포인트 목록, 요청/응답 구조, 에러 코드를 명세한다.

### AUTH.md

인증/인가 계약서 초안. 로그인 방식, 토큰 관리, 권한 체계를 명세한다.

### UI.md

UI 컴포넌트 계약서 초안. 주요 화면, 컴포넌트 구조, 상태 관리를 명세한다.

---

## api

API 서버 프로젝트를 위한 프로파일이다.

```bash
python3 ~/hchain/install.py --target /path/to/my-api --profile api
```

생성 파일:

| 파일 | 내용 |
|------|------|
| `contracts/features/API.md` | API 계약 |
| `contracts/features/AUTH.md` | 인증/인가 계약 |

---

## cli

CLI 도구 프로젝트를 위한 프로파일이다.

```bash
python3 ~/hchain/install.py --target /path/to/my-cli --profile cli
```

생성 파일:

| 파일 | 내용 |
|------|------|
| `contracts/features/COMMAND.md` | CLI 명령 계약 |
| `contracts/features/OUTPUT.md` | 출력 형식 계약 |

### COMMAND.md

CLI 명령 계약서 초안. 명령 구조, 플래그, 인자를 명세한다.

### OUTPUT.md

출력 형식 계약서 초안. 표준 출력, 에러 출력, JSON 모드를 명세한다.

---

## 업데이트 시 기존 파일 보호

`--update` 플래그와 함께 사용하면 기존 계약 파일을 보존한다.

```bash
# 기존 계약 파일을 덮어쓰지 않고 누락된 파일만 추가
python3 ~/hchain/install.py --target /path/to/my-web --update --profile web
```

---

## dry-run

실제 파일을 생성하지 않고 어떤 파일이 생성될지 미리 확인한다.

```bash
python3 ~/hchain/install.py --target /path/to/my-web --profile web --dry-run
```
