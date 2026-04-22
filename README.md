# PortKiller

Mac 메뉴바에서 dev 서버를 자동 감지하고, 좀비 프로세스를 클릭 한 번에 종료하는 macOS 네이티브 앱.

> 매번 `lsof -i :3000` → PID 확인 → `kill -9` 반복하던 흐름을 **메뉴바 클릭 → Kill** 두 단계로 줄임.

---

## 주요 기능

### 자동 감지

시스템 전체의 LISTEN TCP 포트를 5초마다 스캔. 알려진 dev 프레임워크/도구 프로세스만 자동으로 노출. 직접 포트 등록 안 해도 됨.

기본 인식 대상:
- **JS/TS**: node, deno, bun, npm, pnpm, yarn
- **Python**: python, uvicorn, gunicorn, flask, django
- **Ruby**: ruby, rails, puma, rake
- **JVM**: java, kotlin, spring, gradle, tomcat
- **번들러/dev server**: vite, webpack, next, nuxt, esbuild, rspack
- **DB/캐시**: postgres, mysqld, mongod, redis-server, elasticsearch
- **웹 서버**: nginx, apache, caddy
- 기타: php, dart, flutter, rspec, jest, vitest

화이트리스트에 없는 프로세스(OrbStack의 컨테이너, LM Studio 등)는 Settings에서 패턴이나 포트를 직접 추가하면 됨.

### 메뉴바 배지

점유 중인 dev 서버 개수가 메뉴바 아이콘 옆에 숫자로 표시. 드롭다운 열지 않아도 상태 파악 가능.

### 친화적 표시

각 포트 행에 다음 정보 노출:
- 포트 번호 + 식별 가능한 이름 (`Next.js · my-project`)
- PID + 원본 프로세스명
- (펼침 시) 실행 시간, 작업 디렉토리, 전체 명령어

프로젝트 이름은 `package.json`의 `name` 또는 작업 디렉토리 마지막 폴더명에서 가져옴. 프레임워크 이름은 명령어 패턴 매칭으로 추론.

### 안전한 Kill

SIGTERM(`kill -15`)을 먼저 보내고, 2초 안에 정상 종료 안 되면 SIGKILL(`kill -9`). Kill이 확정되기 전까지 행이 사라지지 않아서 진행 상황 명확.

---

## 시스템 요구사항

- **macOS 13.0 (Ventura)** 이상 (`MenuBarExtra` API 필요)
- 빌드용: **Xcode 15+**, Swift 5.9+

> `lsof`, `ps`, `kill` 같은 시스템 기본 도구만 사용함. 외부 의존성 없음.

---

## 설치

### 1. 빌드

```bash
git clone git@github.com:reconnectkr/reconnect-port-killer.git
cd reconnect-port-killer
open PortKiller.xcodeproj
```

Xcode에서 **⌘R**로 실행하거나, 커맨드라인:

```bash
xcodebuild -project PortKiller.xcodeproj \
  -scheme PortKiller \
  -configuration Release \
  build
```

빌드된 `PortKiller.app`은 다음 경로에 생김:

```
~/Library/Developer/Xcode/DerivedData/PortKiller-<hash>/Build/Products/Release/PortKiller.app
```

### 2. 정식 위치로 복사

자동 시작(로그인 시 실행) 기능을 사용하려면 `/Applications/`에 둬야 함:

```bash
cp -R "<위 경로>/PortKiller.app" /Applications/
open /Applications/PortKiller.app
```

> 처음 실행 시 macOS Gatekeeper가 경고할 수 있음. **시스템 설정 → 개인정보 보호 및 보안 → "그래도 열기"**.

---

## 사용법

### 메뉴바

- **아이콘**: Reconnect 로고. 점유 중인 dev 서버 개수가 옆에 숫자로 표시됨.
- **클릭**: 드롭다운 열림.

### 드롭다운

- **포트 행 클릭**: 펼쳐서 상세 정보(실행 시간, cwd, 명령어) 확인. 다시 클릭하면 닫힘.
- **Kill 버튼**: 해당 프로세스 종료.
- **새로고침 버튼** (헤더 우측): 즉시 재스캔.
- **⌘,**: Settings 창 열기.
- **⌘Q**: 앱 종료.

### Settings (⌘,)

| 항목 | 설명 |
|---|---|
| **프로세스 이름 패턴** | 기본 화이트리스트에 추가할 프로세스 이름. 부분 일치, 대소문자 무시. 예: `OrbStack`, `LMStudio` |
| **항상 보여줄 포트** | 프로세스 이름과 무관하게 늘 표시할 포트 번호 |
| **폴링 주기** | 1~30초. 기본 5초. 짧을수록 즉각 반응하지만 CPU 사용 ↑ |
| **로그인 시 자동 시작** | macOS 로그인 시 자동 실행. (앱이 `/Applications/`에 있어야 동작) |

설정은 즉시 반영되며 `UserDefaults`에 영구 저장됨.

---

## 동작 원리

### 포트 감지

```
lsof -iTCP -sTCP:LISTEN -P -n -F pcn
```

시스템 전체의 LISTEN 소켓을 한 번에 가져옴. 결과를 (포트, PID, 프로세스명) 튜플로 파싱.

### 상세 정보

포트별로 추가 호출:

```
ps -p <PIDs> -o pid=,etime=,command=
lsof -p <PIDs> -a -d cwd -F pn
```

PID 묶어서 한 번에 호출하므로 N개 포트라도 호출은 2회 추가.

### Kill

```
kill -15 <PID>          # SIGTERM (정상 종료 요청)
kill -0 <PID>           # 살아있는지 확인
kill -9 <PID>           # SIGKILL (강제 종료, SIGTERM 실패 시)
```

---

## 알려진 한계

- **macOS 전용**. 다른 OS 지원 안 함.
- **샌드박스 미사용**. `lsof`, `kill` 같은 임의 실행파일을 호출해야 해서 App Sandbox를 비활성화함. 결과적으로 App Store 배포는 불가.
- **타 사용자 프로세스는 종료 못 함**. `kill` 권한이 없는 프로세스(예: root 소유)는 Kill 실패.
- **프로세스명 매칭의 한계**. Go 같은 단일 바이너리 언어는 임의 이름이라 화이트리스트에 안 잡힘 → Settings에서 수동 추가 필요.

---

## 폴더 구조

```
reconnect-port-killer/
├── PortKiller.xcodeproj/
├── PortKiller/
│   ├── PortKillerApp.swift           # 앱 진입점, MenuBarExtra + Settings scene
│   ├── ContentView.swift             # 메뉴바 드롭다운 (MenuBarContentView, PortRowView)
│   ├── Models/
│   │   └── ListeningProcess.swift    # 발견된 LISTEN 포트 모델
│   ├── Services/
│   │   ├── ShellRunner.swift         # Process 래퍼
│   │   ├── PortMonitor.swift         # lsof 폴링 + 필터 + 상세 정보 enrich
│   │   └── ProcessKiller.swift       # SIGTERM → SIGKILL 종료 로직
│   ├── Stores/
│   │   └── UserPreferences.swift     # UserDefaults 영속화
│   ├── Views/
│   │   └── SettingsView.swift        # 설정 창
│   └── Assets.xcassets/              # AppIcon, MenuBarIcon (template), AppLogo (color)
├── PortKillerTests/
├── PortKillerUITests/
├── PLAN.md                           # 초기 기획 문서
└── README.md
```

---

## 라이선스

내부 사용 목적. 별도 라이선스 미적용.

## 만든 사람

Daegun Choi (`<daegunchoi@reconnect.red>`)
