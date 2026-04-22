import Foundation

struct ListeningProcess: Identifiable, Equatable, Hashable {
    var id: Int { port }
    let port: Int
    let pid: Int32
    let processName: String
    /// `ps -o command=` 결과. 전체 실행 명령어. (lsof만으로는 못 얻음)
    let command: String?
    /// `lsof -d cwd` 결과. 프로세스의 현재 작업 디렉토리.
    let workingDirectory: String?
    /// `ps -o etime=` 결과를 사람이 읽기 쉽게 변환. 예: "3시간 12분".
    let elapsedTime: String?
    /// 프로젝트 이름. package.json의 "name" 또는 cwd 마지막 폴더명.
    let projectName: String?
    /// 명령어에서 추출한 프레임워크 이름. 예: "Next.js", "Vite", "Rails".
    let frameworkName: String?

    /// 메인 행에 보여줄 친화적 이름.
    /// 우선순위:
    ///   1. "프레임워크 · 프로젝트"  (둘 다 있을 때, 가장 정보량 많음)
    ///   2. "프레임워크" 또는 "프로젝트" (한쪽만 있을 때)
    ///   3. processName 폴백 (예: "node", "python")
    var displayName: String {
        let parts = [frameworkName, projectName].compactMap { name -> String? in
            guard let name, !name.isEmpty else { return nil }
            return name
        }
        return parts.isEmpty ? processName : parts.joined(separator: " · ")
    }
}
