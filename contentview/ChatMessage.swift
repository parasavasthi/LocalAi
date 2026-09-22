import Foundation

struct ResponseStats: Codable {
    let promptTokens: Int
    let generatedTokens: Int
    let totalDuration: Double
    let promptDuration: Double
    let generationDuration: Double
    let loadDuration: Double

    var totalTokens: Int {
        promptTokens + generatedTokens
    }

    var tokensPerSecond: Double {
        guard generationDuration > 0 else { return 0 }
        return Double(generatedTokens) / generationDuration
    }

    var totalSeconds: Double {
        totalDuration
    }

    var promptSeconds: Double {
        promptDuration
    }

    var generationSeconds: Double {
        generationDuration
    }
}

struct ChatMessage: Identifiable, Codable {

    let id: UUID
    let role: Role
    let content: String
    let thinking: String
    let stats: ResponseStats?

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        thinking: String = "",
        stats: ResponseStats? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.thinking = thinking
        self.stats = stats
    }

    enum Role: String, Codable {
        case user
        case assistant
    }
}
