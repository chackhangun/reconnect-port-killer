import Foundation

enum ProcessKiller {
    enum Result: Equatable {
        case terminatedGracefully
        case forciblyKilled
        case failed(String)
    }

    /// SIGTERM 우선 시도, gracePeriod 후에도 살아있으면 SIGKILL.
    /// 둘 다 실패하면 .failed 반환.
    nonisolated static func kill(
        pid: Int32,
        gracePeriod: Duration = .seconds(2)
    ) async -> Result {
        let termSent = sendSignal(15, to: pid)

        try? await Task.sleep(for: gracePeriod)

        if !isAlive(pid: pid) {
            return termSent ? .terminatedGracefully : .forciblyKilled
        }

        let killSent = sendSignal(9, to: pid)
        if !killSent {
            return .failed("SIGKILL 전송 실패")
        }

        try? await Task.sleep(for: .milliseconds(300))

        if isAlive(pid: pid) {
            return .failed("프로세스가 SIGKILL 후에도 살아있음 (권한 부족 가능성)")
        }
        return .forciblyKilled
    }

    /// kill -<signal> 호출. 성공 시 true.
    private nonisolated static func sendSignal(_ signal: Int, to pid: Int32) -> Bool {
        guard let result = try? ShellRunner.run(
            "/bin/kill",
            ["-\(signal)", String(pid)]
        ) else {
            return false
        }
        return result.exitCode == 0
    }

    /// kill -0 으로 프로세스 존재 여부만 확인 (실제 신호 안 보냄).
    private nonisolated static func isAlive(pid: Int32) -> Bool {
        guard let result = try? ShellRunner.run(
            "/bin/kill",
            ["-0", String(pid)]
        ) else {
            return false
        }
        return result.exitCode == 0
    }
}
