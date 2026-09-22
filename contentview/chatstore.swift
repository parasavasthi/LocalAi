import Foundation
import Combine

@MainActor
final class ChatStore: ObservableObject {

    @Published var chats: [Chat] = []

    private let fileURL: URL

    init() {

        let fileManager = FileManager.default

        let applicationSupport =
            fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]

        let localAI =
            applicationSupport.appendingPathComponent(
                "LocalAI",
                isDirectory: true
            )

        try? fileManager.createDirectory(
            at: localAI,
            withIntermediateDirectories: true
        )

        fileURL = localAI
            .appendingPathComponent(
                "chats.json"
            )

        load()
    }

    // MARK: - Create

    @discardableResult
    func createChat() -> UUID {

        let chat = Chat()

        chats.insert(
            chat,
            at: 0
        )

        save()

        return chat.id
    }

    // MARK: - Delete

    func deleteChat(
        id: UUID
    ) {

        chats.removeAll {
            $0.id == id
        }

        save()
    }

    // MARK: - Rename

    func renameChat(
        id: UUID,
        title: String
    ) {

        guard let index =
            chats.firstIndex(
                where: {
                    $0.id == id
                }
            )
        else {
            return
        }

        let trimmed =
            title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmed.isEmpty else {
            return
        }

        chats[index].title = trimmed
        chats[index].updatedAt = Date()

        sortChats()

        save()
    }

    // MARK: - Messages

    func updateMessages(
        id: UUID,
        messages: [ChatMessage]
    ) {

        guard let index =
            chats.firstIndex(
                where: {
                    $0.id == id
                }
            )
        else {
            return
        }

        chats[index].messages = messages
        chats[index].updatedAt = Date()

        if chats[index].title == "New Chat",
           let firstUserMessage =
                messages.first(
                    where: {
                        $0.role == .user
                    }
                ) {

            chats[index].title =
                makeTitle(
                    from:
                        firstUserMessage.content
                )
        }

        sortChats()

        save()
    }

    // MARK: - Persistence

    private func save() {

        do {

            let encoder =
                JSONEncoder()

            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys
            ]

            let data =
                try encoder.encode(
                    chats
                )

            try data.write(
                to: fileURL,
                options: .atomic
            )

        } catch {

            print(
                "Failed to save chats:",
                error
            )
        }
    }

    private func load() {

        guard
            let data =
                try? Data(
                    contentsOf: fileURL
                )
        else {
            return
        }

        do {

            let decoder =
                JSONDecoder()

            chats =
                try decoder.decode(
                    [Chat].self,
                    from: data
                )

            sortChats()

        } catch {

            print(
                "Failed to load chats:",
                error
            )
        }
    }

    // MARK: - Helpers

    private func sortChats() {

        chats.sort {
            $0.updatedAt >
            $1.updatedAt
        }
    }

    private func makeTitle(
        from text: String
    ) -> String {

        let cleaned =
            text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let words =
            cleaned.split(
                whereSeparator: {
                    $0.isWhitespace
                }
            )

        let title =
            words
                .prefix(7)
                .joined(
                    separator: " "
                )

        if title.count > 45 {

            return String(
                title.prefix(45)
            ) + "..."
        }

        return title
    }
}
