import Foundation

struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
}

struct OllamaResponse: Codable {
    let message: OllamaMessage
}

final class OllamaService {

    private let url = URL(string: "http://127.0.0.1:11434/api/chat")!

    func sendMessage(_ text: String) async throws -> String {

        let requestBody = OllamaRequest(
            model: "qwen3:8b",
            messages: [
                OllamaMessage(role: "user", content: text)
            ],
            stream: false
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(
            OllamaResponse.self,
            from: data
        )

        return decoded.message.content
    }
}
