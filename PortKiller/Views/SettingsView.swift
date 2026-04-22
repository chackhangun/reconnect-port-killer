import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: UserPreferences
    @State private var newPattern: String = ""
    @State private var newPortText: String = ""

    var body: some View {
        Form {
            Section {
                Text("기본 dev 프레임워크 외에 추가로 감지할 프로세스 이름. 대소문자 무시 부분 일치. 예: OrbStack, LMStudio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(preferences.extraProcessPatterns, id: \.self) { pattern in
                    HStack {
                        Text(pattern)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            preferences.extraProcessPatterns.removeAll { $0 == pattern }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("삭제")
                    }
                }

                HStack {
                    TextField("패턴 추가", text: $newPattern)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addPattern() }
                    Button("추가", action: addPattern)
                        .disabled(trimmedPattern.isEmpty)
                }
            } header: {
                Label("프로세스 이름 패턴", systemImage: "text.magnifyingglass")
            }

            Section {
                Text("프로세스 이름과 무관하게 늘 표시할 포트. 알 수 없는 도구가 떠도 잡고 싶을 때 사용.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(preferences.extraPortNumbers, id: \.self) { port in
                    HStack {
                        Text("\(port)")
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            preferences.extraPortNumbers.removeAll { $0 == port }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("삭제")
                    }
                }

                HStack {
                    TextField("포트 번호", text: $newPortText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addPort() }
                    Button("추가", action: addPort)
                        .disabled(parsedNewPort == nil)
                }
            } header: {
                Label("항상 보여줄 포트", systemImage: "number")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("주기")
                        Spacer()
                        Text("\(Int(preferences.pollingInterval))초")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $preferences.pollingInterval,
                        in: 1...30,
                        step: 1
                    ) {
                        Text("주기")
                    } minimumValueLabel: {
                        Text("1초")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } maximumValueLabel: {
                        Text("30초")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text("너무 짧으면 CPU 사용이 늘어남. 기본 5초.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("폴링 주기", systemImage: "timer")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
    }

    private var trimmedPattern: String {
        newPattern.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedNewPort: Int? {
        let trimmed = newPortText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmed), (1...65535).contains(port) else { return nil }
        return port
    }

    private func addPattern() {
        let pattern = trimmedPattern
        guard !pattern.isEmpty,
              !preferences.extraProcessPatterns.contains(pattern) else {
            newPattern = ""
            return
        }
        preferences.extraProcessPatterns.append(pattern)
        newPattern = ""
    }

    private func addPort() {
        guard let port = parsedNewPort,
              !preferences.extraPortNumbers.contains(port) else { return }
        var updated = preferences.extraPortNumbers
        updated.append(port)
        updated.sort()
        preferences.extraPortNumbers = updated
        newPortText = ""
    }
}

#Preview {
    SettingsView(preferences: UserPreferences())
}
