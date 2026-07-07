# HCHAIN 공식 README Demo GIF 녹화 스크립트 (VHS)
#
# 사용법:
#   1. VHS 설치: https://github.com/charmbracelet/vhs (+ ttyd, ffmpeg)
#   2. 레포 루트에서 실행: vhs docs/demo/demo.tape
#   3. 결과물: docs/demo/hchain-demo.gif
#
# 목표 길이: 20~30초
# 구성: Opening(타이틀) → Mission 제출 → Planner → Task Queue
#       → Executor(Task-001~004 ✔) → Reviewer/Validator → Implementation Report
#
# 한글 렌더링: CJK 폰트 필요 (Noto Sans Mono CJK KR)

Output docs/demo/hchain-demo.gif

Set FontFamily "Noto Sans Mono CJK KR"
Set FontSize 15
Set Width 1200
Set Height 720
Set Padding 12
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms

# ── Opening: 데모 명령 입력 ──
Type "DEMO_PAUSE=2 bash scripts/demo.sh"
Sleep 800ms
Enter

# ── Main + Ending: 데모 스크립트가 전체 시퀀스를 출력 ──
# DEMO_PAUSE=2 기준 스크립트 총 실행 시간 ≈ 21초
Sleep 24s

# 마지막 IMPLEMENTATION REPORT 화면 유지
Sleep 4s
