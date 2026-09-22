import Foundation

// MARK: - Ollama Models

struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let keepAlive: String

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case keepAlive = "keep_alive"
    }
}

struct OllamaGenerateRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let keepAlive: String

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case stream
        case keepAlive = "keep_alive"
    }
}

struct OllamaStreamMessage: Codable {
    let role: String?
    let content: String?
    let thinking: String?
}

struct OllamaStreamResponse: Codable {
    let model: String?
    let message: OllamaStreamMessage?
    let done: Bool
}

// MARK: - Ollama Service

final class OllamaService {

    static let defaultModel = "qwen3:8b"

    private let baseURL = URL(
        string: "http://127.0.0.1:11434"
    )!

    private let session: URLSession

    init() {

        let configuration =
            URLSessionConfiguration.default

        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 600

        self.session = URLSession(
            configuration: configuration
        )
    }

    // MARK: - Server Connection

    func checkConnection() async -> Bool {

        let url =
            baseURL.appendingPathComponent(
                "api/tags"
            )

        var request =
            URLRequest(url: url)

        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {

            let (_, response) =
                try await session.data(
                    for: request
                )

            guard
                let httpResponse =
                    response as? HTTPURLResponse
            else {
                return false
            }

            return (200...299).contains(
                httpResponse.statusCode
            )

        } catch {

            return false
        }
    }

    // MARK: - Model Power

    func setModelLoaded(
        _ loaded: Bool
    ) async throws {

        let url =
            baseURL.appendingPathComponent(
                "api/generate"
            )

        let requestBody =
            OllamaGenerateRequest(
                model:
                    Self.defaultModel,

                prompt:
                    "",

                stream:
                    false,

                keepAlive:
                    loaded
                    ? "30m"
                    : "0"
            )

        var request =
            URLRequest(url: url)

        request.httpMethod = "POST"

        request.timeoutInterval =
            loaded
            ? 600
            : 30

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Content-Type"
        )

        request.httpBody =
            try JSONEncoder().encode(
                requestBody
            )

        let (_, response) =
            try await session.data(
                for: request
            )

        guard
            let httpResponse =
                response as? HTTPURLResponse
        else {

            throw NSError(
                domain: "Ollama",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Invalid response from Ollama."
                ]
            )
        }

        guard
            (200...299).contains(
                httpResponse.statusCode
            )
        else {

            throw NSError(
                domain: "Ollama",
                code:
                    httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Ollama returned HTTP \(httpResponse.statusCode)."
                ]
            )
        }
    }

    // MARK: - Streaming

    func streamMessage(
        _ messages: [OllamaMessage]
    ) -> AsyncThrowingStream<
        OllamaStreamResponse,
        Error
    > {

        AsyncThrowingStream { continuation in

            let task = Task {

                do {

                    let requestBody =
                        OllamaRequest(
                            model:
                                Self.defaultModel,

                            messages:
                                messages,

                            stream:
                                true,

                            keepAlive:
                                "30m"
                        )

                    var request =
                        URLRequest(
                            url:
                                baseURL
                                .appendingPathComponent(
                                    "api/chat"
                                )
                        )

                    request.httpMethod = "POST"

                    request.timeoutInterval =
                        600

                    request.setValue(
                        "application/json",
                        forHTTPHeaderField:
                            "Content-Type"
                    )

                    request.httpBody =
                        try JSONEncoder().encode(
                            requestBody
                        )

                    let (
                        bytes,
                        response
                    ) =
                        try await session.bytes(
                            for: request
                        )

                    guard
                        let httpResponse =
                            response
                            as? HTTPURLResponse
                    else {

                        throw NSError(
                            domain: "Ollama",
                            code: -1,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "Ollama returned an invalid HTTP response."
                            ]
                        )
                    }

                    guard
                        (200...299).contains(
                            httpResponse.statusCode
                        )
                    else {

                        throw NSError(
                            domain: "Ollama",
                            code:
                                httpResponse.statusCode,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "Ollama returned HTTP \(httpResponse.statusCode)."
                            ]
                        )
                    }

                    for try await line
                        in bytes.lines {

                        try Task.checkCancellation()

                        guard !line.isEmpty else {
                            continue
                        }

                        guard
                            let data =
                                line.data(
                                    using: .utf8
                                )
                        else {
                            continue
                        }

                        let decoded =
                            try JSONDecoder()
                                .decode(
                                    OllamaStreamResponse.self,
                                    from: data
                                )

                        continuation.yield(
                            decoded
                        )

                        if decoded.done {
                            break
                        }
                    }

                    continuation.finish()

                } catch is CancellationError {

                    continuation.finish()

                } catch {

                    continuation.finish(
                        throwing: error
                    )
                }
            }

            continuation.onTermination =
                { @Sendable _ in

                    task.cancel()
                }
        }
    }
}
