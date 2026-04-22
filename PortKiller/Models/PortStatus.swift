import Foundation

struct PortOccupant: Equatable, Hashable {
    let pid: Int32
    let processName: String
    let command: String?
}

enum PortStatus: Equatable {
    case unknown
    case checking
    case free
    case occupied(PortOccupant)
    case error(String)
}
