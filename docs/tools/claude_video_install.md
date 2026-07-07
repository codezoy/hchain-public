# Claude Video (/watch) 설치 가이드

## 개요

Claude Video는 Claude Code에서 `/watch` slash command를 제공하는 skill이다.
yt-dlp로 영상을 다운로드하고, ffmpeg로 프레임을 추출하여 Claude가 영상 내용을 분석할 수 있게 한다.

- Repository: https://github.com/bradautomates/claude-video
- Author: bradautomates
- License: MIT

---

## 설치 경로

| 항목 | 경로 |
|------|------|
| Skill 디렉토리 | `~/.claude/skills/watch/` |
| 설정 파일 | `~/.config/watch/.env` |
| ffmpeg | `~/.local/bin/ffmpeg` (imageio-ffmpeg 심링크) |
| ffprobe | `~/.local/bin/ffprobe` (static-ffmpeg 심링크) |
| yt-dlp | `~/.local/bin/yt-dlp` (pip 설치) |

---

## 설치 방법

### 1. Skill 클론

```bash
git clone https://github.com/bradautomates/claude-video.git ~/.claude/skills/watch
```

### 2. 의존성 설치

```bash
# yt-dlp
pip install yt-dlp

# ffmpeg (sudo 없이)
pip install imageio-ffmpeg
FFMPEG_BIN=$(python3 -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
ln -sf "$FFMPEG_BIN" ~/.local/bin/ffmpeg

# ffprobe (sudo 없이)
pip install static-ffmpeg
python3 -c "import static_ffmpeg; static_ffmpeg.add_paths()"
FFPROBE_BIN=$(python3 -c "import static_ffmpeg; static_ffmpeg.add_paths(); import shutil; print(shutil.which('ffprobe'))" 2>/dev/null | tail -1)
ln -sf "$FFPROBE_BIN" ~/.local/bin/ffprobe
```

### 3. Setup 실행

```bash
python3 ~/.claude/skills/watch/scripts/setup.py
```

---

## 의존성

| 패키지 | 버전 | 설치 방법 | 필수 여부 |
|--------|------|-----------|-----------|
| yt-dlp | 2026.03.17+ | `pip install yt-dlp` | 필수 |
| ffmpeg | 7.0.2 (static) | imageio-ffmpeg via pip | 필수 |
| ffprobe | n8.0.1 (static) | static-ffmpeg via pip | 필수 |
| GROQ_API_KEY | - | `~/.config/watch/.env` | 선택 (Whisper용) |
| OPENAI_API_KEY | - | `~/.config/watch/.env` | 선택 (Whisper fallback) |

> **API 키 없이도 동작 가능**: 자막(caption)이 있는 YouTube 영상은 API 키 없이 분석 가능.
> 자막이 없는 경우 프레임만 추출 (Whisper 전사 없음).

---

## 사용 가능한 명령

### Slash Command

```
/watch <URL 또는 로컬 경로> [질문]
```

### 옵션

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--max-frames N` | 80 | 최대 프레임 수 (최대 100) |
| `--resolution W` | 512 | 프레임 너비 (픽셀) |
| `--fps F` | auto | 초당 프레임 수 override |
| `--start TIME` | - | 분석 시작 시간 (SS, MM:SS, HH:MM:SS) |
| `--end TIME` | - | 분석 종료 시간 |
| `--out-dir DIR` | tmp | 작업 디렉토리 |
| `--no-whisper` | - | Whisper 비활성화 (프레임만) |
| `--whisper groq\|openai` | groq | Whisper 백엔드 선택 |

---

## 사용 예시

```bash
# YouTube 영상 분석
/watch https://youtu.be/VIDEO_ID 이 영상에서 무슨 일이 일어나나요?

# 특정 구간 분석
/watch https://youtu.be/VIDEO_ID --start 1:30 --end 2:00

# 로컬 파일 분석
/watch ~/video.mp4 주요 내용을 요약해줘

# 자막 없는 영상 (Whisper 없이)
/watch https://youtu.be/VIDEO_ID --no-whisper
```

---

## 설정 파일

`~/.config/watch/.env`:

```
GROQ_API_KEY=your_key_here      # Groq Whisper (권장, 저렴)
OPENAI_API_KEY=your_key_here    # OpenAI Whisper (fallback)
```

---

## 상태 확인

```bash
# JSON으로 현재 상태 확인
python3 ~/.claude/skills/watch/scripts/setup.py --json

# 무결성 체크 (exit 0 = 정상)
python3 ~/.claude/skills/watch/scripts/setup.py --check
```

---

## Skill 구조

```
~/.claude/skills/watch/
├── SKILL.md              # Skill 정의 및 파이프라인
├── commands/
│   └── watch.md          # Slash command 핸들러
├── scripts/
│   ├── watch.py          # 메인 실행 스크립트
│   ├── download.py       # yt-dlp 다운로드 모듈
│   ├── frames.py         # ffmpeg 프레임 추출
│   ├── transcribe.py     # 자막/Whisper 전사
│   ├── whisper.py        # Whisper API 클라이언트
│   └── setup.py          # 설치 및 preflight 체크
└── hooks/
    └── hooks.json        # Claude Code hook 설정
```

---

## 제한 사항

- 영상 다운로드가 필요하므로 네트워크 연결 필수
- 자막 없는 영상의 전사는 Groq 또는 OpenAI API 키 필요
- ffmpeg/ffprobe는 sudo 없이 pip 기반으로 설치됨 (시스템 패키지와 별도)
- `~/.local/bin`이 PATH에 포함되어 있어야 함

---

## 설치 날짜

2026-06-01
