import Foundation

// MARK: - Ollama Models

struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaOptions: Codable {
    var temperature: Double
    var topP: Double
    var topK: Int

    static let defaultOptions = OllamaOptions(
        temperature: 0.7,
        topP: 0.9,
        topK: 40
    )

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case topK = "top_k"
    }
}

struct OllamaRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let keepAlive: String
    let options: OllamaOptions

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case keepAlive = "keep_alive"
        case options
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
    let totalDuration: Double?
    let loadDuration: Double?
    let promptEvalCount: Int?
    let promptEvalDuration: Double?
    let evalCount: Int?
    let evalDuration: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case message
        case done
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case promptEvalDuration = "prompt_eval_duration"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }
}

struct OllamaRunningModel: Codable {
    let name: String?
    let model: String?
    let size: Int64?
    let sizeVRAM: Int64?
    let contextLength: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case model
        case size
        case sizeVRAM = "size_vram"
        case contextLength = "context_length"
    }
}

struct OllamaPSResponse: Codable {
    let models: [OllamaRunningModel]
}

struct OllamaRuntimeInfo {
    let isLoaded: Bool
    let memoryBytes: Int64
    let vramBytes: Int64
    let contextLength: Int
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

    func fetchRuntimeInfo() async -> OllamaRuntimeInfo {
        let url = baseURL.appendingPathComponent("api/ps")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return OllamaRuntimeInfo(isLoaded: false, memoryBytes: 0, vramBytes: 0, contextLength: 0)
            }

            let decoded = try JSONDecoder().decode(OllamaPSResponse.self, from: data)
            guard let model = decoded.models.first(where: {
                ($0.name ?? $0.model ?? "") == Self.defaultModel
            }) ?? decoded.models.first else {
                return OllamaRuntimeInfo(isLoaded: false, memoryBytes: 0, vramBytes: 0, contextLength: 0)
            }

            return OllamaRuntimeInfo(
                isLoaded: true,
                memoryBytes: model.size ?? 0,
                vramBytes: model.sizeVRAM ?? 0,
                contextLength: model.contextLength ?? 0
            )
        } catch {
            return OllamaRuntimeInfo(isLoaded: false, memoryBytes: 0, vramBytes: 0, contextLength: 0)
        }
    }

    // MARK: - Streaming

    func streamMessage(
        _ messages: [OllamaMessage],
        options: OllamaOptions = .defaultOptions
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
                                "30m",
                            options:
                                options
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
