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
            check(port)
        }
    }

    private func check(_ port: Port) {
        statuses[port.number] = .checking
        let portNumber = port.number
        Task.detached(priority: .userInitiated) {
            let status = Self.queryStatus(portNumber: portNumber)
            await MainActor.run { [weak self] in
                self?.statuses[portNumber] = status
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
