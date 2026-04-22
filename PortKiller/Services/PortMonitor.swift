import Foundation
import Observation

@Observable
final class PortMonitor {
    /// 마지막 스캔으로 발견된 포트들 (포트번호 → 정보)
    private var discovered: [Int: ListeningProcess] = [:]
    /// kill 진행 중인 포트 스냅샷 (포트번호 → 직전 정보).
    /// kill이 확정되기 전까지 행이 사라지지 않게 유지.
    private var killing: [Int: ListeningProcess] = [:]

    var visiblePorts: [ListeningProcess] {
        var byPort = discovered
        for (port, snapshot) in killing where byPort[port] == nil {
            byPort[port] = snapshot
        }
        return byPort.values.sorted { $0.port < $1.port }
    }

    func isKilling(_ port: ListeningProcess) -> Bool {
        killing[port.port] != nil
    }

    let preferences: UserPreferences
    private var pollingTask: Task<Void, Never>?

    init(preferences: UserPreferences) {
        self.preferences = preferences
    }

    func start() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.performScan()
                try? await Task.sleep(for: .seconds(self.preferences.pollingInterval))
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() {
        Task { await performScan() }
    }

    @discardableResult
    func kill(_ port: ListeningProcess) async -> ProcessKiller.Result? {
        killing[port.port] = port
        let result = await ProcessKiller.kill(pid: port.pid)
        await performScan()
        killing.removeValue(forKey: port.port)
        return result
    }

    private func performScan() async {
        let extras = preferences.extraProcessPatterns
        let extraPorts = Set(preferences.extraPortNumbers)
        let scanned = await Task.detached(priority: .userInitiated) {
            let basics = Self.scanListeningBasics()
            let visible = basics.filter {
                Self.isVisible($0, extraPatterns: extras, extraPorts: extraPorts)
            }
            return Self.enrich(visible)
        }.value

        var newDiscovered: [Int: ListeningProcess] = [:]
        for proc in scanned {
            newDiscovered[proc.port] = proc
        }
        if newDiscovered != discovered {
            discovered = newDiscovered
        }
    }

    // MARK: - lsof scan (1차: 기본 정보)

    /// 1차 스캔에서만 쓰이는 중간 타입.
    /// lsof만으로는 command 전체 / cwd / etime을 못 얻기 때문에 분리.
    private struct BasicListening {
        let port: Int
        let pid: Int32
        let processName: String
    }

    private nonisolated static func scanListeningBasics() -> [BasicListening] {
        guard let output = try? ShellRunner.run(
            "/usr/sbin/lsof",
            ["-iTCP", "-sTCP:LISTEN", "-P", "-n", "-F", "pcn"]
        ) else {
            return []
        }
        // exit 0: 결과 있음, 1: 매칭 없음 (시스템 전체 스캔이라 보통 0)
        guard output.exitCode == 0 || output.exitCode == 1 else {
            return []
        }
        return parseLsofListening(output.stdout)
    }

    // -F pcn 출력 (한 프로세스 단위로 묶인 레코드들):
    //   p47291    ← PID
    //   cnode     ← command name (9자로 잘림)
    //   n*:3000   ← 주소:포트
    //   n*:3001
    //   p47292    ← 다음 PID
    private nonisolated static func parseLsofListening(_ output: String) -> [BasicListening] {
        var results: [BasicListening] = []
        var seenPorts: Set<Int> = []
        var currentPid: Int32?
        var currentName: String?
        var currentPorts: Set<Int> = []

        func flush() {
            if let pid = currentPid, let name = currentName {
                for port in currentPorts where !seenPorts.contains(port) {
                    results.append(BasicListening(port: port, pid: pid, processName: name))
                    seenPorts.insert(port)
                }
            }
            currentPid = nil
            currentName = nil
            currentPorts.removeAll()
        }

        for line in output.split(separator: "\n") {
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())
            switch prefix {
            case "p":
                flush()
                currentPid = Int32(value)
            case "c":
                currentName = value
            case "n":
                if let port = parsePortFromAddress(value) {
                    currentPorts.insert(port)
                }
            default:
                break
            }
        }
        flush()
        return results.sorted { $0.port < $1.port }
    }

    // 예시 입력:
    //   "*:3000"          → 3000
    //   "127.0.0.1:5432"  → 5432
    //   "[::1]:8080"      → 8080
    private nonisolated static func parsePortFromAddress(_ address: String) -> Int? {
        guard let lastColon = address.lastIndex(of: ":") else { return nil }
        let portStr = String(address[address.index(after: lastColon)...])
        return Int(portStr)
    }

    // MARK: - 2차: ps + lsof cwd로 상세 정보 채움

    private nonisolated static func enrich(_ basics: [BasicListening]) -> [ListeningProcess] {
        let pids = Set(basics.map { $0.pid })
        guard !pids.isEmpty else { return [] }

        let psInfo = fetchPsInfo(pids: pids)
        let cwdInfo = fetchCwdInfo(pids: pids)

        return basics.map { basic in
            let ps = psInfo[basic.pid]
            let cwd = cwdInfo[basic.pid]
            return ListeningProcess(
                port: basic.port,
                pid: basic.pid,
                processName: basic.processName,
                command: ps?.command,
                workingDirectory: cwd,
                elapsedTime: ps.flatMap { humanizeEtime($0.etime) },
                projectName: detectProjectName(workingDirectory: cwd),
                frameworkName: detectFramework(processName: basic.processName, command: ps?.command)
            )
        }
    }

    // MARK: - 프로젝트명 / 프레임워크 추론

    /// cwd가 있으면 `package.json`의 "name" 필드를 우선 시도, 없으면 cwd의 마지막 폴더명 폴백.
    private nonisolated static func detectProjectName(workingDirectory: String?) -> String? {
        guard let cwd = workingDirectory, !cwd.isEmpty else { return nil }

        // package.json 시도 (Node 프로젝트)
        let packageJsonURL = URL(fileURLWithPath: cwd).appendingPathComponent("package.json")
        if let data = try? Data(contentsOf: packageJsonURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = json["name"] as? String,
           !name.isEmpty {
            return name
        }

        // 폴더명 폴백 ("/" 같은 비정상 케이스 제외)
        let basename = URL(fileURLWithPath: cwd).lastPathComponent
        guard !basename.isEmpty, basename != "/" else { return nil }
        return basename
    }

    /// 명령어 문자열을 보고 알려진 프레임워크/도구 이름 추출.
    /// 매칭 순서:
    ///   1. 프로세스명 자체로 식별되는 경우 (nginx, mongod 등)
    ///   2. 명령어 substring 매칭 (next dev, vite, rails server 등)
    private nonisolated static func detectFramework(processName: String, command: String?) -> String? {
        let proc = processName.lowercased()

        // 프로세스명만으로 식별되는 케이스
        let processOnly: [(String, String)] = [
            ("nginx", "Nginx"),
            ("httpd", "Apache"),
            ("apache", "Apache"),
            ("caddy", "Caddy"),
            ("mongod", "MongoDB"),
            ("redis-server", "Redis"),
            ("postgres", "PostgreSQL"),
            ("mysqld", "MySQL"),
            ("elasticsearch", "Elasticsearch"),
            ("php-fpm", "PHP-FPM"),
        ]
        for (needle, name) in processOnly where proc.contains(needle) {
            return name
        }

        // 명령어 기반 추론
        guard let cmd = command?.lowercased(), !cmd.isEmpty else { return nil }

        let cmdPatterns: [(String, String)] = [
            // JS/TS
            ("next dev", "Next.js"),
            ("next start", "Next.js"),
            ("next-dev", "Next.js"),
            ("vite", "Vite"),
            ("nuxt dev", "Nuxt"),
            ("nuxt start", "Nuxt"),
            ("webpack-dev-server", "Webpack"),
            ("webpack serve", "Webpack"),
            ("gatsby develop", "Gatsby"),
            ("remix dev", "Remix"),
            ("astro dev", "Astro"),
            ("parcel", "Parcel"),
            ("nest start", "NestJS"),
            ("expo start", "Expo"),
            ("metro", "Metro"),
            ("nodemon", "Nodemon"),
            ("ts-node", "ts-node"),
            ("tsx ", "tsx"),
            // Python
            ("manage.py runserver", "Django"),
            ("flask run", "Flask"),
            ("uvicorn", "Uvicorn"),
            ("gunicorn", "Gunicorn"),
            ("python -m http.server", "Python HTTP"),
            ("python3 -m http.server", "Python HTTP"),
            // Ruby
            ("rails server", "Rails"),
            ("rails s ", "Rails"),
            ("puma", "Puma"),
            ("rackup", "Rack"),
            // JVM
            ("spring-boot", "Spring Boot"),
            ("gradle ", "Gradle"),
            ("mvn ", "Maven"),
            // PHP
            ("php -s", "PHP"),
            // Go / Rust / .NET / Elixir
            ("air ", "Air (Go)"),
            ("cargo run", "Rust"),
            ("dotnet run", ".NET"),
            ("mix phx.server", "Phoenix"),
        ]
        for (needle, name) in cmdPatterns where cmd.contains(needle) {
            return name
        }

        return nil
    }

    /// `ps -p <pids> -o pid=,etime=,command=` 한 번에 호출.
    /// 출력 한 줄당:
    ///   "47291  03:12:45 /usr/local/bin/node next dev"
    /// → (pid, etime, command) 분리.
    private nonisolated static func fetchPsInfo(pids: Set<Int32>) -> [Int32: (command: String, etime: String)] {
        let pidArg = pids.map(String.init).joined(separator: ",")
        guard let output = try? ShellRunner.run(
            "/bin/ps",
            ["-p", pidArg, "-o", "pid=,etime=,command="]
        ), output.exitCode == 0 else {
            return [:]
        }

        var result: [Int32: (command: String, etime: String)] = [:]
        for line in output.stdout.split(separator: "\n") {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(maxSplits: 2, omittingEmptySubsequences: true) { $0.isWhitespace }
            guard parts.count == 3, let pid = Int32(parts[0]) else { continue }
            result[pid] = (command: String(parts[2]), etime: String(parts[1]))
        }
        return result
    }

    /// `lsof -p <pids> -a -d cwd -F pn`로 각 PID의 cwd 한 번에 조회.
    private nonisolated static func fetchCwdInfo(pids: Set<Int32>) -> [Int32: String] {
        let pidArg = pids.map(String.init).joined(separator: ",")
        guard let output = try? ShellRunner.run(
            "/usr/sbin/lsof",
            ["-p", pidArg, "-a", "-d", "cwd", "-F", "pn"]
        ), output.exitCode == 0 || output.exitCode == 1 else {
            return [:]
        }

        var result: [Int32: String] = [:]
        var currentPid: Int32?
        for line in output.stdout.split(separator: "\n") {
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())
            switch prefix {
            case "p":
                currentPid = Int32(value)
            case "n":
                if let pid = currentPid {
                    result[pid] = value
                }
            default:
                break
            }
        }
        return result
    }

    /// BSD ps etime 형식: `[[DD-]HH:]MM:SS`.
    /// 예시 변환:
    ///   "30:45"      → "30분 45초"
    ///   "1:23:45"    → "1시간 23분"
    ///   "2-03:45:12" → "2일 3시간"
    private nonisolated static func humanizeEtime(_ etime: String) -> String {
        let dayParts = etime.split(separator: "-", maxSplits: 1)
        let days: Int
        let timePart: Substring
        if dayParts.count == 2 {
            days = Int(dayParts[0]) ?? 0
            timePart = dayParts[1]
        } else {
            days = 0
            timePart = Substring(etime)
        }

        let timeParts = timePart.split(separator: ":").compactMap { Int($0) }
        let hours: Int
        let minutes: Int
        let seconds: Int
        switch timeParts.count {
        case 3:
            hours = timeParts[0]
            minutes = timeParts[1]
            seconds = timeParts[2]
        case 2:
            hours = 0
            minutes = timeParts[0]
            seconds = timeParts[1]
        default:
            return etime
        }

        if days > 0 {
            return "\(days)일 \(hours)시간"
        }
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        if minutes > 0 {
            return "\(minutes)분 \(seconds)초"
        }
        return "\(seconds)초"
    }

    // MARK: - 필터 (전략 B: 프로세스 이름 화이트리스트)

    /// 기본 dev 프레임워크/서버 이름 패턴.
    /// 소문자 substring 매칭이라 "node", "python3" 등에 모두 잡힘.
    private nonisolated static let defaultProcessPatterns: [String] = [
        // JS/TS 런타임
        "node", "deno", "bun", "npm", "pnpm", "yarn",
        // Ruby
        "ruby", "rails", "puma", "rake", "thin",
        // Python
        "python", "uvicorn", "gunicorn", "flask", "django",
        // JVM
        "java", "kotlin", "spring", "gradle", "maven", "tomcat",
        // PHP
        "php", "php-fpm",
        // Dart/Flutter
        "dart", "flutter",
        // 웹 서버
        "nginx", "apache", "httpd", "caddy",
        // 번들러/dev server
        "vite", "webpack", "next", "nuxt", "esbuild", "rspack",
        // DB / 캐시
        "mongod", "redis-server", "mysqld", "postgres", "elasticsearch",
        // 테스트 러너
        "rspec", "jest", "vitest",
    ]

    private nonisolated static func isVisible(
        _ port: BasicListening,
        extraPatterns: [String],
        extraPorts: Set<Int>
    ) -> Bool {
        // 사용자가 명시한 포트는 무조건 노출
        if extraPorts.contains(port.port) { return true }

        // 시스템 예약 포트 (< 1024)는 기본 제외
        guard port.port >= 1024 else { return false }

        let name = port.processName.lowercased()
        let allPatterns = defaultProcessPatterns + extraPatterns.map { $0.lowercased() }
        return allPatterns.contains { !$0.isEmpty && name.contains($0) }
    }
}
