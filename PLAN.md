# PortKiller 기획 문서

Mac 메뉴바 상주형 포트 점유 프로세스 관리 앱.

---

## 1. 개요

### 한 줄 요약

개발 중 자주 쓰는 포트(3000, 5173 등)의 점유 상태를 메뉴바에서 실시간으로 보고, 좀비 프로세스를 클릭 한 번에 종료하는 macOS 네이티브 앱.

### 배경 및 동기

로컬 개발 서버를 자주 띄우다 보면 정상 종료되지 않은 프로세스가 포트를 계속 점유하는 일이 잦음.

매번 다음 과정을 반복해야 함:
1. 터미널 열기
2. `lsof -i :3000` 입력
3. PID 확인
4. `kill -9 <PID>` 입력

이 흐름을 **메뉴바 클릭 → Kill 버튼** 두 단계로 줄이는 것이 목표임.

### 타겟 사용자

본인(daegunchoi@reconnect.red). 추후 동료에게 공유 가능한 형태로 확장.

---

## 2. 핵심 기능

### MVP 범위 (1차 목표)

1. **메뉴바 상주**
   - 상태바 우측에 아이콘 표시
   - 점유 중인 포트가 있으면 아이콘 색상 변경 (녹색 → 빨강)
   - 점유 포트 개수를 아이콘 옆 숫자로 표시 (옵션)

2. **포트 감시**
   - 사용자가 등록한 포트 리스트를 주기적으로 확인 (기본 5초)
   - `lsof -i :PORT -P -n -sTCP:LISTEN` 호출로 점유 여부 판단
   - 점유 시 PID, 프로세스명, 실행 명령어 추출

3. **드롭다운 UI**
   - 메뉴바 아이콘 클릭 시 점유 상태 리스트 표시
   - 각 포트별 행:
     - 포트 번호
     - 상태 (점유/대기)
     - 프로세스명 + PID (점유 시)
     - Kill 버튼 (점유 시)

4. **프로세스 종료**
   - SIGTERM (`kill -15`) 우선 시도
   - 일정 시간(예: 2초) 내 종료 안 되면 SIGKILL (`kill -9`)
   - 종료 결과를 알림으로 표시

5. **포트 등록 관리**
   - Settings 창에서 포트 추가/삭제
   - 포트별 라벨 부여 가능 (예: 3000 → "Next.js 메인")
   - `UserDefaults`로 영구 저장

### 2차 확장 (시간 여유 시)

- 폴링 주기 사용자 설정
- 로그인 시 자동 시작 (LaunchAgent)
- 좀비 프로세스 감지 시 macOS 시스템 알림
- 포트 점유 이력 로그 (최근 10건)
- 포트 범위 감시 (예: 3000-3010 일괄)
- 다크모드 대응

### 명시적 비포함

- 네트워크 트래픽 모니터링 (Activity Monitor 영역)
- 원격 서버 포트 감시 (로컬 한정)
- 윈도우/리눅스 지원

---

## 3. UI / UX 흐름

### 메뉴바 드롭다운 레이아웃 (예시)

```
┌─────────────────────────────────────┐
│ PortKiller                          │
├─────────────────────────────────────┤
│ ● 3000  Next.js 메인                │
│   node (PID 47291)        [ Kill ]  │
├─────────────────────────────────────┤
│ ○ 5173  Vite                        │
│   (사용 가능)                       │
├─────────────────────────────────────┤
│ ● 8080  로컬 API                    │
│   java (PID 12044)        [ Kill ]  │
├─────────────────────────────────────┤
│ ⚙ Settings…                         │
│ ⏻ Quit                              │
└─────────────────────────────────────┘
```

- `●` 빨강: 점유 중
- `○` 회색: 사용 가능

### 인터랙션

- **Kill 버튼**: 클릭 시 확인 다이얼로그 없이 즉시 종료 (속도 우선). 종료 실패 시에만 알림.
- **포트 행 클릭**: 해당 프로세스의 상세 정보(실행 경로, 시작 시각) 펼침.
- **Settings**: 별도 윈도우로 열림. 포트 추가/삭제, 폴링 주기 설정.

---

## 4. 기술 스택

| 항목 | 선택 | 이유 |
|---|---|---|
| 언어 | Swift 5.9+ | 네이티브 macOS, TS와 문법 유사 |
| UI 프레임워크 | SwiftUI | `MenuBarExtra` API로 메뉴바 앱 간결하게 구현 |
| 최소 macOS | 13.0 (Ventura) | `MenuBarExtra` 요구 버전 |
| 빌드 도구 | Xcode 15+ | 표준 |
| 외부 명령 | `lsof`, `kill` (시스템 기본) | 추가 의존성 없음 |
| 영구 저장 | `UserDefaults` + `Codable` | 가벼움, 포트 리스트 정도엔 충분 |
| 의존성 관리 | Swift Package Manager | 외부 라이브러리 거의 안 씀 |

### 외부 라이브러리

기본적으로 없음. 필요 시 검토:
- 알림 커스터마이징이 필요하면 `UserNotifications` (시스템 내장)
- 로그인 시 자동 시작은 `ServiceManagement` 프레임워크 (시스템 내장)

---

## 5. 아키텍처

### 폴더 구조 (예정)

```
reconnect-port-killer/
├── PortKiller.xcodeproj/
├── PortKiller/
│   ├── PortKillerApp.swift           # 앱 진입점, MenuBarExtra 정의
│   ├── Models/
│   │   ├── Port.swift                # 포트 데이터 모델 (번호, 라벨)
│   │   └── PortStatus.swift          # 점유 상태 (PID, 프로세스명 등)
│   ├── Services/
│   │   ├── PortMonitor.swift         # 폴링 + lsof 호출 + 결과 파싱
│   │   ├── ProcessKiller.swift       # SIGTERM → SIGKILL 종료 로직
│   │   └── ShellRunner.swift         # Process 클래스 래퍼
│   ├── Stores/
│   │   └── PortStore.swift           # 등록 포트 영속 (UserDefaults)
│   ├── Views/
│   │   ├── MenuBarContentView.swift  # 드롭다운 UI
│   │   ├── PortRowView.swift         # 포트 한 줄 컴포넌트
│   │   └── SettingsView.swift        # 설정 창
│   └── Assets.xcassets/              # 메뉴바 아이콘 (점유/대기 두 종)
├── PLAN.md
├── README.md
└── .gitignore
```

### 레이어 책임 분리

```
[PortKillerApp]  ─ 앱 진입점, MenuBarExtra
        │
        ▼
[Views]          ─ SwiftUI 뷰, 사용자 입력만 처리
        │
        ▼
[Stores]         ─ 상태 보유 (@Observable / @Published)
        │
        ▼
[Services]       ─ PortMonitor, ProcessKiller (비즈니스 로직)
        │
        ▼
[ShellRunner]    ─ Process 호출 추상화 (테스트 용이성)
```

### 데이터 흐름

폴링 사이클 (5초마다):

```
Timer 발화
   ↓
PortMonitor.checkAll()
   ↓
등록된 각 포트에 대해 lsof 실행
   ↓
결과 파싱 → [Port: PortStatus] 맵 생성
   ↓
PortStore.statuses 업데이트 (@Published)
   ↓
SwiftUI 자동 리렌더링
   ↓
메뉴바 아이콘 색상 + 드롭다운 갱신
```

Kill 액션:

```
사용자가 Kill 버튼 클릭
   ↓
ProcessKiller.kill(pid:)
   ↓
SIGTERM 전송
   ↓
2초 대기 후 재확인
   ↓
여전히 살아있으면 SIGKILL
   ↓
PortMonitor.checkOne(port:) 즉시 재실행
   ↓
UI 즉시 갱신
```

---

## 6. 데이터 모델

### `Port` (사용자 등록 포트)

```swift
struct Port: Codable, Identifiable, Hashable {
    let id: UUID
    let number: Int        // 예: 3000
    var label: String      // 예: "Next.js 메인"
}
```

### `PortStatus` (현재 상태, 메모리 only)

```swift
enum PortStatus {
    case free
    case occupied(ProcessInfo)
    case checking
    case error(String)
}

struct ProcessInfo {
    let pid: Int32
    let processName: String   // 예: "node"
    let command: String?      // 예: "/usr/bin/node /app/server.js"
    let startedAt: Date?
}
```

### 영속 저장 (UserDefaults)

키: `com.reconnect.portkiller.ports`
값: `[Port]`를 JSON 인코딩한 `Data`

설정값:

키: `com.reconnect.portkiller.settings`
값: `Settings { pollingInterval, autoStartOnLogin, showBadgeCount }` JSON

---

## 7. 외부 명령 사용 방식

### `lsof` 호출

```bash
lsof -i :3000 -P -n -sTCP:LISTEN -F pcn
```

옵션:
- `-i :3000`: 특정 포트
- `-P`: 포트 번호를 서비스명으로 변환 안 함
- `-n`: 호스트명 DNS 조회 안 함 (속도)
- `-sTCP:LISTEN`: LISTEN 상태만
- `-F pcn`: 머신 파싱 가능한 출력 (p=PID, c=command, n=name)

### 결과 파싱 예시

입력:
```
p47291
cnode
n*:3000
```

→ `ProcessInfo(pid: 47291, processName: "node", ...)`

### 추가 정보 조회

`ps -p <PID> -o command=` 으로 실행 경로 보강.

### `kill` 호출

```bash
kill -15 47291    # SIGTERM, 정상 종료 시도
kill -9 47291     # SIGKILL, 강제 종료
```

Swift `Process` API:
```swift
let task = Process()
task.launchPath = "/bin/kill"
task.arguments = ["-15", String(pid)]
try task.run()
task.waitUntilExit()
```

---

## 8. 개발 마일스톤

### Phase 1: 골격 (Day 1)

- Xcode 프로젝트 생성 (App template, SwiftUI, macOS)
- `MenuBarExtra` 기본 동작 확인 (메뉴바에 아이콘 + 텍스트 메뉴)
- `ShellRunner`로 임의 셸 명령 실행 결과를 콘솔 출력
- Git 초기화 + GitHub 푸시

### Phase 2: 포트 감시 (Day 2)

- `Port`, `PortStatus` 모델 정의
- `PortMonitor` 구현: lsof 호출 + 결과 파싱
- 하드코딩 포트 리스트(3000, 5173)로 5초 폴링 작동 확인
- 메뉴바 드롭다운에 결과 표시

### Phase 3: Kill 기능 (Day 3)

- `ProcessKiller` 구현 (SIGTERM → SIGKILL 폴백)
- Kill 버튼 UI 연결
- 종료 후 즉시 재폴링으로 UI 반영

### Phase 4: 설정 UI (Day 4)

- Settings 창 추가
- 포트 추가/삭제/라벨 편집
- `PortStore`에서 `UserDefaults` 영속화
- 메뉴바 아이콘 상태별 색상 변경

### Phase 5: 마감 (Day 5)

- 앱 아이콘 디자인
- 알림 (종료 실패 시)
- 로그인 시 자동 시작 옵션
- README 작성

---

## 9. 검토 필요 사항

다음은 사용자(본인) 결정이 필요한 항목.

1. **앱 번들 ID**: `com.reconnect.PortKiller`로 갈지, 다른 prefix 쓸지
2. **아이콘 디자인**: SF Symbols 활용 (예: `bolt.shield`) vs 커스텀 디자인
3. **Kill 확인 다이얼로그**: 즉시 실행 vs 한 번 더 묻기
4. **공유 범위**: 본인만 사용 vs 동료 배포 (배포 시 코드 서명 필요)
5. **GitHub 레포 가시성**: public vs private

---

## 10. 향후 확장 아이디어

- **포트 그룹**: 프로젝트별로 포트 묶어서 일괄 종료
- **Docker 컨테이너 연동**: Docker가 점유 중인 포트는 `docker stop`으로 종료
- **단축키**: 글로벌 핫키로 메뉴바 즉시 열기 (예: ⌘⇧K)
- **Spotlight/Raycast 확장**: 포트 번호 입력하면 바로 종료
- **CLI 동반**: `portkiller kill 3000` 같은 명령행 도구 동봉
