import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    /// 권한이 아직 결정되지 않았을 때만 사용자에게 묻고, 거부됐으면 다시 안 묻음.
    /// 처음 Kill 실패가 발생했을 때 호출되어 즉석에서 권한 요청.
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    /// Kill 실패 시 시스템 알림 표시. 권한 없으면 조용히 무시.
    static func showKillFailure(
        port: Int,
        processName: String,
        pid: Int32,
        reason: String
    ) async {
        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Kill 실패"
        content.body = "포트 \(port) (\(processName), PID \(pid))\n\(reason)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
