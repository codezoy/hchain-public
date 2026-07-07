# HCHAIN Public Repository Checklist

공개 저장소로 전환하기 전 완료해야 할 항목 목록.

---

## Repository

- [x] README (Why HCHAIN, Architecture, Core Concepts, Example Workflow, Design Philosophy, Roadmap 포함)
- [x] GitHub Actions (CI workflow)
- [ ] Demo GIF (실제 파이프라인 실행 화면)
- [ ] Architecture image (ASCII 외 다이어그램 이미지)
- [ ] CONTRIBUTING (기여 가이드)
- [ ] CODE_OF_CONDUCT (행동 강령)

---

## Documentation

- [ ] PROJECT (프로젝트 목적·기술 스택 계약)
- [ ] ARCHITECTURE (전체 아키텍처 상세 문서)
- [ ] INVENTORY (파일·모듈 인벤토리)
- [ ] FEATURES (지원 기능 목록)

---

## Security

- [ ] Secret scan (API 키·토큰·비밀번호 검사)
- [ ] API key audit (하드코딩 키 제거 확인)
- [ ] Internal path audit (`/home/username/`, Tailscale IP 등 제거 또는 익명화)
- [ ] Personal information audit (이메일·전화번호·사용자명 제거)

### Secret Scan 결과 (2026-07-05)

| 항목 | 결과 | 파일 |
|------|------|------|
| API Key (sk-*) | SAFE — false positive (Codex CLI flags) | reviewer.md |
| Tailscale IP (100.x.x.x) | WARNING — 내부 IP 노출 | USER_GUIDE.md, INSTALL_GUIDE.md, GLOBAL_SKILL_DEPLOYMENT.md, harness_runner.sh |
| SSH username (<username>@) | WARNING — 개인 사용자명 노출 | GLOBAL_SKILL_DEPLOYMENT.md |
| Absolute path (/home/<username>/) | WARNING — 개인 경로 노출 | 다수 docs/ 파일 |
| Password / JWT / Bearer | SAFE — 없음 | — |
| .env / .pem / .key | SAFE — 없음 (.venv 제외) | — |
| Personal email | SAFE — 없음 | — |

---

## Portfolio

- [ ] Blog article links (HCHAIN 관련 글 링크)
- [ ] Demo screenshots (파이프라인 실행 스크린샷)
- [ ] Example workflow (실제 사용 사례)
- [ ] Showcase project (HCHAIN으로 구축한 프로젝트 소개)

---

## 다음 우선 작업

1. `docs/` 파일에서 `/home/<username>/` 절대 경로를 `~/hchain` 형식으로 교체
2. `templates/harness/harness_runner.sh`에서 `<TAILSCALE_IP>` 하드코딩 제거 (환경변수로 대체)
3. `docs/HCHAIN_GLOBAL_SKILL_DEPLOYMENT.md`에서 `<username>@` 사용자명 익명화
4. CONTRIBUTING.md 작성
5. Demo GIF 촬영
