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

### 3. DMG로 배포 (옵션)

다른 사람에게 전달하거나 GitHub Releases에 올릴 때.

**의존성**: `brew install create-dmg`

```bash
./scripts/build-dmg.sh
```

생성 위치: `build/PortKiller.dmg` (~360KB).

DMG 더블클릭 → 마운트 → 좌측 PortKiller.app을 우측 Applications로 드래그하면 설치 완료. 배경 이미지는 `scripts/make-dmg-background.swift`가 자동 생성함 (그라디언트 + 화살표 + 안내 텍스트).

⚠️ **코드 서명 한계**: 자체 서명("Sign to Run Locally")이라 받은 사람 Mac에서 Gatekeeper가 막음. 받은 사람이 우클릭 → 열기 또는 시스템 설정 → 개인정보 보호 및 보안 → "그래도 열기" 필요. 정식 배포는 Apple Developer Program 가입 후 codesign + notarize 필요.

---

## 사용법

### 메뉴바

- **아이콘**: Reconnect 로고.
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

### 단계 1: 시스템 전체 LISTEN 포트 스캔

폴링 주기마다 (기본 5초) 한 번 호출:

```
lsof -iTCP -sTCP:LISTEN -P -n -F pcn
```

옵션:
- `-iTCP`: TCP 소켓만
- `-sTCP:LISTEN`: LISTEN 상태만 (ESTABLISHED 등 제외)
- `-P`: 포트번호를 서비스명으로 변환 안 함 (속도)
- `-n`: 호스트명 DNS 조회 안 함 (속도)
- `-F pcn`: 머신 파싱 가능한 출력 (p=PID, c=command, n=address:port)

결과를 (포트, PID, 프로세스명) 튜플 리스트로 파싱. 같은 프로세스가 IPv4/IPv6 양쪽으로 LISTEN해도 dedupe.

### 단계 2: 필터 (감지 규칙)

스캔된 모든 LISTEN 포트에 대해 순서대로 검사:

1. **사용자 지정 포트 우선** — Settings의 "항상 보여줄 포트"에 등록된 번호는 무조건 노출 (이름·범위 무시)
2. **포트 1024 미만 제외** — `0~1023`은 시스템 예약 영역 (mDNSResponder, sshd 등)이라 기본 제외
3. **프로세스명 화이트리스트 매칭** — 프로세스 이름을 소문자로 만든 뒤, 아래 패턴 중 하나라도 **substring으로 포함**하면 노출

#### 기본 화이트리스트 (`PortMonitor.defaultProcessPatterns`)

| 카테고리 | 매칭 패턴 |
|---|---|
| JS/TS 런타임 | `node` `deno` `bun` `npm` `pnpm` `yarn` |
| Ruby | `ruby` `rails` `puma` `rake` `thin` |
| Python | `python` `uvicorn` `gunicorn` `flask` `django` |
| JVM | `java` `kotlin` `spring` `gradle` `maven` `tomcat` |
| PHP | `php` `php-fpm` |
| Dart/Flutter | `dart` `flutter` |
| 웹 서버 | `nginx` `apache` `httpd` `caddy` |
| 번들러/dev server | `vite` `webpack` `next` `nuxt` `esbuild` `rspack` |
| DB / 캐시 | `mongod` `redis-server` `mysqld` `postgres` `elasticsearch` |
| 테스트 러너 | `rspec` `jest` `vitest` |

매칭 방식 예시:
- 프로세스명 `python3.11` → `"python"` 패턴이 substring으로 포함 → ✅ 노출
- 프로세스명 `node-exporter` → `"node"` 매칭 → ✅ 노출 (의도와 다를 수 있음, 그땐 Settings에서 제외 못 함 — 한계)
- 프로세스명 `OrbStack` → 어느 패턴도 매칭 안 됨 → ❌ 제외 → Settings에서 `OrbStack` 추가하면 노출됨

#### 사용자 추가 패턴 (`Settings → 프로세스 이름 패턴`)

기본 화이트리스트에 합쳐서 같은 substring 매칭 적용. 예:
- `OrbStack` 추가 → OrbStack이 띄운 컨테이너 포트 (Postgres·Redis 등) 노출
- 빈 문자열은 무시됨

#### 사용자 추가 포트 (`Settings → 항상 보여줄 포트`)

프로세스 이름과 무관하게 노출. 예:
- LM Studio가 1234번에서 도는데 프로세스명이 `LM Studio` (공백 포함, 화이트리스트 미매칭) → `1234` 추가하면 항상 노출

### 단계 3: 상세 정보 enrich

필터를 통과한 포트들의 PID를 모아서 두 번 더 호출 (포트 N개여도 호출 2회):

```
ps -p <PID1>,<PID2>,... -o pid=,etime=,command=
lsof -p <PID1>,<PID2>,... -a -d cwd -F pn
```

- `ps`: 실행 시간(etime) + 전체 명령어
- `lsof -d cwd`: 현재 작업 디렉토리

cwd가 있으면 `package.json`의 `name` 필드 또는 cwd 마지막 폴더명으로 프로젝트명 추론. 명령어로 프레임워크명 추론 (`next dev` → "Next.js", `rails server` → "Rails" 등).

### 단계 4: Kill

```
kill -15 <PID>          # SIGTERM (정상 종료 요청)
                        # 2초 대기
kill -0 <PID>           # 살아있는지만 확인 (실제 신호 안 보냄)
kill -9 <PID>           # SIGKILL (SIGTERM 실패 시)
```

`kill -0`은 신호를 보내지 않고 권한 + 존재 여부만 확인하는 표준 트릭. 종료 확정 후 즉시 단계 1을 재실행해서 UI 갱신.

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
│   │   ├── ProcessKiller.swift       # SIGTERM → SIGKILL 종료 로직
│   │   └── NotificationService.swift # Kill 실패 알림 (UserNotifications)
│   ├── Stores/
│   │   └── UserPreferences.swift     # UserDefaults 영속화
│   ├── Views/
│   │   ├── SettingsView.swift        # 설정 창
│   │   └── AboutView.swift           # About 창
│   └── Assets.xcassets/              # AppIcon, MenuBarIcon (template), AppLogo (color)
├── PortKillerTests/
├── PortKillerUITests/
├── scripts/
│   ├── build-dmg.sh                  # 드래그-앤-드롭 DMG 빌드
│   └── make-dmg-background.swift     # DMG 배경 이미지 생성
├── PLAN.md                           # 초기 기획 문서
└── README.md
```

---

## 라이선스

내부 사용 목적. 별도 라이선스 미적용.

## 만든 사람

Daegun Choi (`<daegunchoi@reconnect.red>`)
