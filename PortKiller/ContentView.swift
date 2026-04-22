import SwiftUI

struct MenuBarContentView: View {
    @State private var monitor = PortMonitor(ports: [
        Port(number: 3000, label: "Next.js / dev"),
        Port(number: 5173, label: "Vite"),
        Port(number: 8080, label: "Generic HTTP"),
    ])

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            portList
            Divider()
            footer
        }
        .frame(width: 320)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
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
            ForEach(monitor.ports) { port in
                PortRowView(
                    port: port,
                    status: monitor.statuses[port.number] ?? .unknown
                )
                if port.id != monitor.ports.last?.id {
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

            if case .occupied = status {
                Button("Kill") {
                    // Phase 3: ProcessKiller 연결
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch status {
        case .free: .green
        case .occupied: .red
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
