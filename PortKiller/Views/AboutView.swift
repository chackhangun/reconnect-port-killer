import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)

            Text("PortKiller")
                .font(.title)
                .fontWeight(.semibold)

            Text("버전 \(version) (build \(buildNumber))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Mac 메뉴바에서 dev 서버를 자동 감지하고\n좀비 프로세스를 즉시 종료하는 앱")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Daegun Choi")
                    .font(.callout)
                Text("daegunchoi@reconnect.red")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Link(destination: URL(string: "https://github.com/chackhangun/reconnect-port-killer")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("github.com/chackhangun/reconnect-port-killer")
                    }
                    .font(.footnote)
                }
                .padding(.top, 2)
            }
        }
        .padding(.top, 28)
        .padding(.bottom, 24)
        .padding(.horizontal, 32)
        .frame(width: 360)
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}

#Preview {
    AboutView()
}
