import SwiftUI

struct MenuBarContentView: View {
    @State private var monitor = PortMonitor(ports: [
        Port(number: 3000, label: "Next.js / dev"),
        Port(number: 5173, label: "Vite"),
        Port(number: 8080, label: "Generic HTTP"),
    ])

    private var occupiedPorts: [Port] {
        monitor.ports.filter { port in
            switch monitor.statuses[port.number] ?? .unknown {
            case .occupied, .killing: true
            default: false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if occupiedPorts.isEmpty {
                emptyState
            } else {
                portList
            }
            Divider()
            footer
        }
        .frame(width: 320)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("점유 중인 포트 없음")
                    .foregroundStyle(.secondary)
            }
            Text("감시: \(monitor.ports.map { String($0.number) }.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
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
            ForEach(occupiedPorts) { port in
                PortRowView(
                    port: port,
                    status: monitor.statuses[port.number] ?? .unknown,
                    onKill: {
                        Task { await monitor.kill(port) }
                    }
                )
                if port.id != occupiedPorts.last?.id {
                    Divider().padding(.leading, 12)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                // Phase 4: Settings 창
            } label: {
                Label("Settings…", systemImage: "gear")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .disabled(true)

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
    let port: Port
    let status: PortStatus
    let onKill: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(port.number)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                    Text(port.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                statusDescription
            }

            Spacer()

            switch status {
            case .occupied:
                Button("Kill", role: .destructive, action: onKill)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            case .killing:
                ProgressView()
                    .controlSize(.small)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .opacity(isKilling ? 0.6 : 1.0)
    }

    private var isKilling: Bool {
        if case .killing = status { return true }
        return false
    }

    private var statusColor: Color {
        switch status {
        case .free: .green
        case .occupied: .red
        case .killing: .yellow
        case .checking: .yellow
        case .unknown: .gray
        case .error: .orange
        }
    }

    @ViewBuilder
    private var statusDescription: some View {
        switch status {
        case .free:
            Text("사용 가능")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .occupied(let occupant):
            Text("\(occupant.processName) (PID \(occupant.pid))")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .killing(let occupant):
            Text("\(occupant.processName) (PID \(occupant.pid)) — 종료 중…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .checking:
            Text("확인 중…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .unknown:
            Text("대기")
                .font(.caption)
                .foregroundStyle(.tertiary)
        case .error(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }
}

#Preview {
    MenuBarContentView()
}
