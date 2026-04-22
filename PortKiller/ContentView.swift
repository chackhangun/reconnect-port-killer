import SwiftUI

struct MenuBarContentView: View {
    let preferences: UserPreferences
    @State private var monitor: PortMonitor
    @State private var expandedPort: Int?
    @Environment(\.openSettings) private var openSettings

    init(preferences: UserPreferences) {
        self.preferences = preferences
        _monitor = State(initialValue: PortMonitor(preferences: preferences))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if monitor.visiblePorts.isEmpty {
                emptyState
            } else {
                portList
            }
            Divider()
            footer
        }
        .frame(width: 380)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
        // 사용자가 Settings에서 패턴/포트를 바꾸면 다음 5초를 기다리지 말고 즉시 재스캔.
        .onChange(of: preferences.extraProcessPatterns) { _, _ in monitor.refresh() }
        .onChange(of: preferences.extraPortNumbers) { _, _ in monitor.refresh() }
    }

    private var header: some View {
        HStack {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text("PortKiller")
                .font(.headline)
            Spacer()
            Button {
                monitor.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("새로고침")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var portList: some View {
        VStack(spacing: 0) {
            ForEach(monitor.visiblePorts) { port in
                PortRowView(
                    port: port,
                    isKilling: monitor.isKilling(port),
                    isExpanded: expandedPort == port.port,
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            expandedPort = (expandedPort == port.port) ? nil : port.port
                        }
                    },
                    onKill: {
                        Task { await monitor.kill(port) }
                    }
                )
                if port.id != monitor.visiblePorts.last?.id {
                    Divider().padding(.leading, 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("점유 중인 dev 서버 없음")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Text("시스템 전체 LISTEN 포트를 5초마다 자동 감지")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                openSettings()
                // 메뉴바 앱은 LSUIElement=YES 라서 자동으로 앞에 안 옴.
                // Settings 창이 다른 앱 뒤에 가려지지 않도록 명시적으로 활성화.
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Settings…", systemImage: "gear")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",")

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct PortRowView: View {
    let port: ListeningProcess
    let isKilling: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onKill: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
            if isExpanded {
                expandedDetails
            }
        }
        .opacity(isKilling ? 0.6 : 1.0)
    }

    private var mainRow: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isKilling ? Color.yellow : Color.red)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("\(port.port)")
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.semibold)
                        Text(port.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if isKilling {
                        Text("PID \(port.pid) · \(port.processName) — 종료 중…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("PID \(port.pid) · \(port.processName)")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))

                if isKilling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Kill", role: .destructive, action: onKill)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let etime = port.elapsedTime {
                detailRow(label: "실행 시간", value: etime)
            }
            if let cwd = port.workingDirectory {
                detailRow(label: "작업 디렉토리", value: cwd, monospaced: true)
            }
            if let command = port.command {
                detailRow(label: "명령어", value: command, monospaced: true)
            }
            if port.elapsedTime == nil && port.workingDirectory == nil && port.command == nil {
                Text("상세 정보를 불러오지 못함")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 30)
        .padding(.trailing, 12)
        .padding(.bottom, 12)
        .padding(.top, 2)
    }

    private func detailRow(label: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    MenuBarContentView(preferences: UserPreferences())
}
