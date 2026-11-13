---
name: team-setup
description: 현재 프로젝트 폴더에 안티(팀장), 클로드, 코덱스 3인 AI 팀 세션을 herdr에 배치하고 신뢰 확인, hc 통신 테스트, 각자 지침 문서(GEMINI.md, CLAUDE.md, AGENTS.md) 생성까지 초기 셋팅을 수행하는 프로젝트 전용 에이전트/스킬.
---

# Team Setup Agent (프로젝트 전용 초기 셋팅)

이 스킬은 **현재 열려 있는 프로젝트 폴더(작업 디렉터리)**를 기준으로 3인 AI 팀(안티, 클로드, 코덱스)을 `herdr`에 초기 셋팅하고 종료한다. 다른 프로젝트로 복사해 사용할 수 있도록 특정 경로를 하드코딩하지 않는다.

## 실행 절차

### 1. 환경 및 현재 세션 확인
- 현재 작업 디렉터리(`$PWD`)를 프로젝트 루트로 삼는다.
- `$env:HC_TERMINAL_ID` (또는 `hc ls`에서 현재 `working` 중인 `antigravity` 세션)로 안티(팀장)의 세션 ID를 확인한다.

### 2. herdr 앱 창 배치 (왼쪽: 안티, 오른쪽 상단: 클로드, 오른쪽 하단: 코덱스)
아래 명령으로 현재 프로젝트 폴더에 클로드와 코덱스를 연다.
```powershell
$herdrApp = "$env:LOCALAPPDATA\Programs\herdr-app\herdr-app.exe"
& $herdrApp do terminal.open --argv '["claude"]' --folder "$PWD" --place right
Start-Sleep -Seconds 2
& $herdrApp do terminal.open --argv '["codex","--no-daemon"]' --folder "$PWD" --place down
Start-Sleep -Seconds 3
```
- `hc ls`로 방금 열린 클로드(`claude`)와 코덱스(`codex`)의 세션 ID(`address`)를 확인한다.

### 3. 프로젝트 폴더 신뢰(Trust) 사용자 확인 대기
- 클로드와 코덱스 첫 실행 시 프로젝트 폴더 신뢰 프롬프트가 뜰 수 있다.
- **즉시 멈추고 사용자에게 안내한다**:
  > "오른쪽 상단(클로드)과 오른쪽 하단(코덱스) 화면에 신뢰(Trust) 프롬프트가 떴다면 직접 승인해 주세요. 확인이 끝나고 문제가 없으면 **'문제없다'**라고 말씀해 주세요."
- 사용자가 **"문제없다"**고 응답할 때까지 다음 단계로 넘어가지 않는다.

### 4. 이름 명명 및 `hc` 통신 여부 확인
- 각 세션에 `hc send`로 이름(안티, 클로드, 코덱스)을 알리고 짧은 응답(`OK`)을 요청한다.
- **중요**: `hc send` 후 반드시 `hc read --lines 0 <대상ID>`로 화면을 확인하고, 입력창에 작성만 되고 실행이 안 되었으면 `hc keys <대상ID> enter`를 전송한다.
- **통신 실패 시**: 즉시 작업을 중단하고 어느 세션과 통신이 실패했는지 사용자에게 보고한 뒤 종료한다.
- **통신 정상 시**: 5단계로 진행한다.

### 5. 팀 운영 지침 전달 및 각자 지침 문서 작성
1. **안티 (`GEMINI.md`)**: 현재 폴더에 `GEMINI.md`를 작성한다. (첫 줄: `이 문서는 안티 전용 문서입니다.`)
2. **클로드 (`CLAUDE.md`)**: `hc send <클로드ID>`로 `CLAUDE.md` 작성을 지시한다. (첫 줄: `이 문서는 클로드 전용 문서입니다.`, 코드/문서 작업 위주, GitHub 브랜치/PR, 별도 워크스페이스, 병렬 세션/모델 변경, 컨텍스트 포화 시 문서화 후 자동 compact, `hc send` 후 화면 확인 및 미실행 시 엔터 규칙 포함)
3. **코덱스 (`AGENTS.md`)**: `hc send <코덱스ID>`로 `AGENTS.md` 작성을 지시한다. (첫 줄: `이 문서는 코덱스 전용 문서입니다.`, 이미지/영상/음성 작업 위주 및 동일 협업·통신 규칙 포함)
- 각자 지침 문서는 서로 공유하지 않는다.
- `hc read --lines 0`으로 미실행 여부를 확인하고, 필요 시 `hc keys <대상ID> enter`로 실행한다.

### 6. 종료
- `GEMINI.md`, `CLAUDE.md`, `AGENTS.md` 3개 파일이 모두 생성되었는지 확인한 뒤, 사용자에게 셋팅 완료를 보고하고 에이전트를 종료한다.
