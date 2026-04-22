import Foundation
import Observation

@Observable
final class PortMonitor {
    private(set) var ports: [Port]
    var statuses: [Int: PortStatus] = [:]

    private var pollingTask: Task<Void, Never>?
    private let pollingInterval: TimeInterval

    init(ports: [Port], pollingInterval: TimeInterval = 5.0) {
        self.ports = ports
        self.pollingInterval = pollingInterval
        for port in ports {
            statuses[port.number] = .unknown
        }
    }

    func start() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refresh()
                try? await Task.sleep(for: .seconds(self.pollingInterval))
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() {
        for port in ports {
            check(port, showChecking: false)
        }
    }

    @discardableResult
    func kill(_ port: Port) async -> ProcessKiller.Result? {
        guard case .occupied(let occupant) = statuses[port.number] else {
            return nil
        }
        // 종료가 확정되기 전까지는 원래 점유자 정보를 유지한 채 .killing 표시.
        // 이렇게 해야 행이 즉시 사라지지 않고, 사용자가 진행 상황을 볼 수 있음.
        statuses[port.number] = .killing(occupant)
        let result = await ProcessKiller.kill(pid: occupant.pid)
        check(port, showChecking: false)
        return result
    }

    // showChecking: 사용자 액션이 진행 중임을 보여줄 때만 true.
    // 백그라운드 폴링은 false로 호출해서 깜빡임 방지.
    private func check(_ port: Port, showChecking: Bool) {
        if showChecking {
            statuses[port.number] = .checking
        }
        let portNumber = port.number
        Task.detached(priority: .userInitiated) {
            let newStatus = Self.queryStatus(portNumber: portNumber)
            await MainActor.run { [weak self] in
                guard let self else { return }
                // 실제로 바뀐 경우에만 대입 → SwiftUI 불필요한 리렌더링 방지
                if self.statuses[portNumber] != newStatus {
                    self.statuses[portNumber] = newStatus
                }
            }
        }
    }

    private nonisolated static func queryStatus(portNumber: Int) -> PortStatus {
        do {
            let output = try ShellRunner.run(
                "/usr/sbin/lsof",
                ["-i", ":\(portNumber)", "-P", "-n", "-sTCP:LISTEN", "-F", "pcn"]
            )
            // lsof exit code: 0 = found, 1 = no match
            if output.exitCode == 1 {
                return .free
            }
            if output.exitCode != 0 {
                let stderr = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                return .error("lsof exit \(output.exitCode): \(stderr)")
            }
            return parseLsofOutput(output.stdout) ?? .free
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // -F pcn 형식의 lsof 출력 파싱:
    //   p18531    ← pid
    //   cnode     ← command name
    //   f16       ← (무시)
    //   n*:3000   ← (무시)
    // 첫 번째 LISTEN 프로세스 한 건만 반환.
    private nonisolated static func parseLsofOutput(_ output: String) -> PortStatus? {
        var pid: Int32?
        var name: String?
        for line in output.split(separator: "\n") {
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())
            switch prefix {
            case "p": pid = Int32(value)
            case "c": name = value
            default: break
            }
            if let pid, let name {
                return .occupied(PortOccupant(pid: pid, processName: name, command: nil))
            }
        }
        return nil
    }
}
