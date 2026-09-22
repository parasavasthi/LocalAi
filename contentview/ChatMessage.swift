import Foundation

struct ChatMessage: Identifiable, Codable {

    let id: UUID
    let role: Role
    let content: String
    let thinking: String

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        thinking: String = ""
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.thinking = thinking
    }

    enum Role: String, Codable {
        case user
        case assistant
    }
}
