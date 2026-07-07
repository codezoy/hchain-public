# TASK-HARNESS-MISSION-MANAGER-INSTALL-001: mission_manager.sh install.sh 설치 반영

## Status: DONE

## Goal

mission_manager.sh가 install.sh를 통해 다른 프로젝트의 harness/scripts/로 이식될 수 있도록
설치 반영 및 검증 절차를 추가한다.

## 변경 내용

### install.sh

- `cmd_verify`에 `harness/scripts/mission_manager.sh` 존재 및 실행 권한 체크 추가

### 자동 설치 동작 (변경 없음)

`cmd_install_harness`는 `templates/harness/` 전체를 `find`로 탐색하여 설치한다.
`templates/harness/scripts/mission_manager.sh`는 이미 자동으로 설치 대상에 포함되어 있다.
`_copy_harness_file`의 `chmod +x` 로직이 `.sh` 파일에 자동으로 실행 권한을 부여한다.

## 설치 경로

```
templates/harness/scripts/mission_manager.sh
    → <target>/harness/scripts/mission_manager.sh (chmod +x 자동 적용)
```

## 검증 명령

```bash
bash -n install.sh
bash -n templates/harness/scripts/mission_manager.sh
./install.sh --dry-run --target /tmp/hchain-test
./install.sh --target /tmp/hchain-test
test -x /tmp/hchain-test/harness/scripts/mission_manager.sh
./install.sh --verify /tmp/hchain-test
/tmp/hchain-test/harness/scripts/mission_manager.sh dry-run /tmp/hchain-test/harness/templates/mission_state.json
```

## 결과

모든 검증 통과. 기존 `--install-skill`, `--verify-skill` 동작 영향 없음.
