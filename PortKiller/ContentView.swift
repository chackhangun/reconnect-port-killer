import SwiftUI

struct MenuBarContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            emptyState
            Divider()
            footer
        }
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Image(systemName: "bolt.shield")
                .foregroundStyle(.tint)
            Text("PortKiller")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("감시 중인 포트 없음")
                .foregroundStyle(.secondary)
            Text("Settings에서 포트를 추가하세요.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                // Phase 4에서 Settings 창 열기 구현
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

#Preview {
    MenuBarContentView()
}
