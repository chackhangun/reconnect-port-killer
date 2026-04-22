import Foundation

struct Port: Codable, Identifiable, Hashable {
    let id: UUID
    let number: Int
    var label: String

    init(id: UUID = UUID(), number: Int, label: String = "") {
        self.id = id
        self.number = number
        self.label = label
    }

    static func == (lhs: Port, rhs: Port) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
