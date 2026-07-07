# HCHAIN Update Project Task Template

Use this template when applying a HCHAIN update to an existing project that already has HCHAIN installed.

This task updates the Harness runtime files (scripts, agents, lib) while preserving all task/log/queue data.

---

## Template

`````markdown
# TASK_YYYYMMDD_NNN: HCHAIN Update — [Project Name]

## Goal

[Project Name]에 설치된 HCHAIN Harness를 최신 버전으로 업데이트한다.

기존 태스크, 로그, findings, 큐 데이터는 보존한다.
업데이트 후 정상 동작을 검증한다.

## Scope

포함:
- `bash install.sh --target [PROJECT_PATH] --update` 실행
- 업데이트 후 `--verify` 로 설치 확인
- `harness_runner.sh --list` 정상 동작 확인
- dry-run으로 변경 범위 사전 확인

제외:
- `harness/tasks/` 파일 삭제 금지
- `harness/logs/` 파일 삭제 금지
- `harness/findings/` 파일 삭제 금지
- `harness/queue/` 파일 삭제 금지
- `harness/active_state.json` 변경 금지
- 프로젝트 소스 코드 수정 금지

## Pre-conditions

- [ ] HCHAIN Core 최신 버전 확인 (`cat /path/to/hchain/VERSION`)
- [ ] 대상 프로젝트에 `.hchain/meta.json` 존재 확인
- [ ] 현재 실행 중인 Task 없음 확인 (`harness_runner.sh --list`)
- [ ] 대상 프로젝트 git status clean (optional but recommended)

## Done Criteria

- [ ] dry-run 완료 및 변경 범위 확인
- [ ] `bash install.sh --target [PROJECT_PATH] --update` 성공
- [ ] `bash install.sh --verify [PROJECT_PATH]` → "installed" 출력
- [ ] `bash harness/harness_runner.sh --list` 정상 동작
- [ ] 기존 tasks/ logs/ findings/ queue/ 데이터 보존 확인
- [ ] `.hchain/meta.json` 버전 필드 업데이트 확인
- [ ] 최종 보고서 생성

## Steps

1. [PLAN] 현재 설치 버전 확인
   ```bash
   cat [PROJECT_PATH]/.hchain/meta.json
   cat /path/to/hchain/VERSION
   ```

2. [PLAN] 보존 대상 파일 목록 스냅샷
   ```bash
   ls [PROJECT_PATH]/harness/tasks/
   ls [PROJECT_PATH]/harness/queue/pending/
   ls [PROJECT_PATH]/harness/queue/done/
   ```

3. [ACTION] Dry-run으로 변경 범위 확인
   ```bash
   bash /path/to/hchain/install.sh --target [PROJECT_PATH] --update --dry-run
   ```

4. [ACTION] 업데이트 실행
   ```bash
   bash /path/to/hchain/install.sh --target [PROJECT_PATH] --update
   ```

5. [REVIEW] 업데이트된 파일 정적 검토
   - 덮어쓴 파일 목록 확인
   - 보존 대상 파일 미수정 확인

6. [VALIDATE] 설치 확인
   ```bash
   bash /path/to/hchain/install.sh --verify [PROJECT_PATH]
   ```

7. [VALIDATE] Harness 정상 동작 확인
   ```bash
   cd [PROJECT_PATH]
   bash harness/harness_runner.sh --list
   ```

8. [VALIDATE] 데이터 보존 확인
   ```bash
   ls [PROJECT_PATH]/harness/tasks/
   ls [PROJECT_PATH]/harness/logs/
   ls [PROJECT_PATH]/harness/queue/done/
   ```

9. [DONE] 최종 보고서 작성

## Final Report (필수)

다음 항목을 backtick 5개 코드박스로 출력한다:

1. Step 진행표 (PLAN/REVIEW/VALIDATE/DONE)
2. 업데이트 전 버전 → 업데이트 후 버전
3. 변경된 파일 목록 (install.sh 출력 기반)
4. 보존 확인 항목
   - tasks/ 파일 수
   - logs/ 파일 수
   - queue/done/ 마커 수
5. REVIEWER 검토 결과
6. Harness 정상 동작 여부
7. 남은 리스크

## Execution

```bash
bash /path/to/hchain/install.sh --target [PROJECT_PATH] --update
```
`````

---

## Usage Notes

- Replace `[PROJECT_PATH]` with the absolute path to the target project
- Replace `[Project Name]` with the project name
- Always run dry-run BEFORE the actual update
- If a task is currently running, wait for it to complete before updating
- After update, run `--list` to confirm existing tasks are still accessible
