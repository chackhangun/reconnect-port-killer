import Foundation
import Observation

/// 사용자가 Settings에서 편집하는 값들을 UserDefaults로 영구 저장.
/// SwiftUI에서 @Bindable로 양방향 바인딩 가능하도록 @Observable.
@Observable
@MainActor
final class UserPreferences {
    /// 기본 화이트리스트에 더해 추가로 매칭할 프로세스 이름 패턴.
    /// 부분 일치 (소문자 비교). 예: "OrbStack", "LMStudio".
    var extraProcessPatterns: [String] {
        didSet {
            UserDefaults.standard.set(extraProcessPatterns, forKey: Keys.patterns)
        }
    }

    /// 프로세스 이름과 무관하게 항상 노출할 포트 번호들.
    var extraPortNumbers: [Int] {
        didSet {
            UserDefaults.standard.set(extraPortNumbers, forKey: Keys.ports)
        }
    }

    /// 폴링 주기 (초). 1.0 ~ 30.0 권장.
    var pollingInterval: Double {
        didSet {
            UserDefaults.standard.set(pollingInterval, forKey: Keys.interval)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        self.extraProcessPatterns = defaults.stringArray(forKey: Keys.patterns) ?? []
        self.extraPortNumbers = (defaults.array(forKey: Keys.ports) as? [Int]) ?? []
        let storedInterval = defaults.double(forKey: Keys.interval)
        // double(forKey:)는 미설정 시 0.0 반환 → 기본값으로 5초 사용
        self.pollingInterval = storedInterval > 0 ? storedInterval : 5.0
    }

    private enum Keys {
        static let patterns = "com.reconnect.portkiller.extraProcessPatterns"
        static let ports = "com.reconnect.portkiller.extraPortNumbers"
        static let interval = "com.reconnect.portkiller.pollingInterval"
    }
}
