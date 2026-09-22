import SwiftUI

// MARK: - Scroll Position Tracking

private struct ScrollBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = nextValue()
    }
}

// MARK: - Content View

struct ContentView: View {

    @StateObject private var chatStore = ChatStore()

    @State private var selectedChatID: UUID?
    @State private var inputText = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var generationTask: Task<Void, Never>?

    @State private var expandedThinking: Set<UUID> = []

    @State private var renamingChatID: UUID?
    @State private var renameText = ""

    // MARK: Ollama State

    @State private var ollamaOnline = false
    @State private var modelStatus: ModelStatus = .starting
    @State private var modelEnabled = true

    // MARK: UI State

    @State private var modelPanelExpanded = true

    // MARK: Smart Scroll State

    @State private var isFollowingScroll = true
    @State private var showLatestButton = false
    @State private var isProgrammaticScroll = false

    private let ollamaService = OllamaService()

    enum ModelStatus {
        case starting
        case loading
        case on
        case off
        case unavailable
    }

    // MARK: - Current Chat

    private var currentMessages: [ChatMessage] {

        guard let selectedChatID else {
            return []
        }

        return chatStore.chats.first {
            $0.id == selectedChatID
        }?.messages ?? []
    }

    // MARK: - Body

    var body: some View {

        NavigationSplitView {

            // MARK: Sidebar

            VStack(
                alignment: .leading,
                spacing: 14
            ) {

                HStack {

                    Text("Local AI")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()
                }

                Button {

                    newChat()

                } label: {

                    Label(
                        "New Chat",
                        systemImage: "plus"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Divider()

                Text("Chats")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if chatStore.chats.isEmpty {

                    Text("No conversations yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                } else {

                    ScrollView {

                        LazyVStack(
                            spacing: 4
                        ) {

                            ForEach(
                                chatStore.chats
                            ) { chat in

                                chatRow(chat)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 220)

        } detail: {

            VStack(spacing: 0) {

                // MARK: Header

                VStack(spacing: 0) {

                    HStack {

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {

                            Text("Qwen3 8B")
                                .font(.headline)

                            if !modelPanelExpanded {

                                HStack(spacing: 8) {

                                    ollamaStatusPill

                                    Text("•")
                                        .foregroundStyle(.tertiary)

                                    Text(modelStatusText)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                        }

                        Spacer()

                        Button {

                            withAnimation(
                                .easeInOut(duration: 0.2)
                            ) {

                                modelPanelExpanded.toggle()
                            }

                        } label: {

                            Image(
                                systemName:
                                    modelPanelExpanded
                                    ? "chevron.up"
                                    : "chevron.down"
                            )
                            .font(
                                .subheadline.weight(
                                    .semibold
                                )
                            )
                            .frame(
                                width: 28,
                                height: 28
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(
                            modelPanelExpanded
                            ? "Collapse model panel"
                            : "Expand model panel"
                        )
                    }
                    .padding(
                        .horizontal,
                        20
                    )
                    .padding(
                        .vertical,
                        10
                    )

                    if modelPanelExpanded {

                        modelControlPanel
                            .padding(
                                .horizontal,
                                20
                            )
                            .padding(
                                .bottom,
                                12
                            )
                            .transition(
                                .opacity.combined(
                                    with: .move(
                                        edge: .top
                                    )
                                )
                            )
                    }
                }

                Divider()

                // MARK: Messages

                if selectedChatID == nil {

                    emptyChatView()

                } else if currentMessages.isEmpty {

                    emptyChatView()

                } else {

                    ScrollViewReader { proxy in

                        GeometryReader { viewport in

                            ZStack(
                                alignment: .bottomTrailing
                            ) {

                                ScrollView {

                                    LazyVStack(
                                        alignment: .leading,
                                        spacing: 18
                                    ) {

                                        ForEach(
                                            currentMessages
                                        ) { message in

                                            MessageBubble(
                                                message: message,
                                                isThinkingExpanded:
                                                    expandedThinking
                                                    .contains(
                                                        message.id
                                                    ),
                                                isGenerating:
                                                    isLoading &&
                                                    message.id ==
                                                    currentMessages
                                                        .last?
                                                        .id,
                                                toggleThinking: {

                                                    toggleThinking(
                                                        for:
                                                            message.id
                                                    )
                                                }
                                            )
                                            .id(message.id)
                                        }

                                        if let errorMessage {

                                            HStack(
                                                alignment: .top,
                                                spacing: 8
                                            ) {

                                                Image(
                                                    systemName:
                                                        "exclamationmark.triangle"
                                                )

                                                Text(
                                                    errorMessage
                                                )

                                                Spacer()
                                            }
                                            .foregroundStyle(
                                                .red
                                            )
                                            .padding(
                                                .horizontal,
                                                20
                                            )
                                        }

                                        // Bottom sentinel.
                                        Color.clear
                                            .frame(height: 1)
                                            .background(
                                                GeometryReader {
                                                    geometry in

                                                    Color.clear
                                                        .preference(
                                                            key:
                                                                ScrollBottomPreferenceKey.self,
                                                            value:
                                                                geometry
                                                                .frame(
                                                                    in:
                                                                        .named(
                                                                            "chatScroll"
                                                                        )
                                                                )
                                                                .minY
                                                        )
                                                }
                                            )
                                            .id(
                                                "chatBottom"
                                            )
                                    }
                                    .padding(
                                        .vertical,
                                        20
                                    )
                                }
                                .coordinateSpace(
                                    name: "chatScroll"
                                )

                                // MARK: Bottom Detection

                                .onPreferenceChange(
                                    ScrollBottomPreferenceKey.self
                                ) { bottomY in

                                    guard !isProgrammaticScroll else {
                                        return
                                    }

                                    let threshold: CGFloat = 50

                                    let atBottom =
                                        bottomY <=
                                        viewport.size.height +
                                        threshold

                                    if atBottom {

                                        isFollowingScroll = true
                                        showLatestButton = false

                                    } else {

                                        isFollowingScroll = false

                                        if isLoading {
                                            showLatestButton = true
                                        }
                                    }
                                }

                                // MARK: New Message

                                .onChange(
                                    of: currentMessages.count
                                ) {

                                    guard
                                        !currentMessages.isEmpty
                                    else {
                                        return
                                    }

                                    if isFollowingScroll {

                                        scrollToBottom(
                                            proxy,
                                            animated: true
                                        )
                                    }
                                }

                                // MARK: Streaming Content

                                .onChange(
                                    of:
                                        currentMessages
                                        .last?
                                        .content ?? ""
                                ) {

                                    followLatestIfNeeded(
                                        proxy
                                    )
                                }

                                .onChange(
                                    of:
                                        currentMessages
                                        .last?
                                        .thinking ?? ""
                                ) {

                                    followLatestIfNeeded(
                                        proxy
                                    )
                                }

                                // MARK: Latest Button

                                if showLatestButton &&
                                    isLoading {

                                    Button {

                                        isFollowingScroll = true
                                        showLatestButton = false

                                        scrollToBottom(
                                            proxy,
                                            animated: true
                                        )

                                    } label: {

                                        HStack(
                                            spacing: 6
                                        ) {

                                            Image(
                                                systemName:
                                                    "arrow.down"
                                            )

                                            Text("Latest")
                                        }
                                        .font(
                                            .subheadline.weight(
                                                .medium
                                            )
                                        )
                                        .padding(
                                            .horizontal,
                                            12
                                        )
                                        .padding(
                                            .vertical,
                                            8
                                        )
                                    }
                                    .buttonStyle(.bordered)
                                    .background(
                                        .regularMaterial
                                    )
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 10
                                        )
                                    )
                                    .padding(
                                        .trailing,
                                        24
                                    )
                                    .padding(
                                        .bottom,
                                        14
                                    )
                                    .transition(
                                        .opacity.combined(
                                            with: .move(
                                                edge: .bottom
                                            )
                                        )
                                    )
                                }
                            }
                        }
                    }
                }

                Divider()

                // MARK: Input

                HStack(
                    alignment: .bottom,
                    spacing: 10
                ) {

                    TextField(
                        "Ask anything...",
                        text: $inputText,
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .padding(
                        .horizontal,
                        14
                    )
                    .padding(
                        .vertical,
                        10
                    )
                    .background(
                        RoundedRectangle(
                            cornerRadius: 10
                        )
                        .fill(.quaternary)
                    )
                    .lineLimit(1...6)
                    .onSubmit {

                        if !isLoading {
                            sendMessage()
                        }
                    }

                    Button {

                        if isLoading {

                            stopGeneration()

                        } else {

                            sendMessage()
                        }

                    } label: {

                        Image(
                            systemName:
                                isLoading
                                ? "stop.fill"
                                : "arrow.up"
                        )
                        .fontWeight(.semibold)
                        .frame(
                            width: 36,
                            height: 36
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .disabled(
                        !isLoading &&
                        (
                            !ollamaOnline ||
                            modelStatus != .on ||
                            selectedChatID == nil ||
                            inputText
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )
                                .isEmpty
                        )
                    )
                }
                .padding(12)
            }
        }

        // MARK: Startup

        .task {

            if selectedChatID == nil,
               let firstChat =
                    chatStore.chats.first {

                selectedChatID =
                    firstChat.id
            }

            await monitorOllama()
        }

        // MARK: Rename Sheet

        .sheet(
            isPresented:
                Binding(
                    get: {
                        renamingChatID != nil
                    },
                    set: { value in

                        if !value {
                            renamingChatID = nil
                        }
                    }
                )
        ) {

            renameSheet
        }
    }

    // MARK: - Model Control Panel

    @ViewBuilder
    private var modelControlPanel: some View {

        HStack(spacing: 16) {

            HStack(spacing: 10) {

                Image(systemName: "cpu")
                    .font(.title3)
                    .frame(
                        width: 34,
                        height: 34
                    )
                    .background(
                        RoundedRectangle(
                            cornerRadius: 8
                        )
                        .fill(.quaternary)
                    )

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(
                        OllamaService.defaultModel
                    )
                    .font(.subheadline)
                    .fontWeight(.medium)

                    Text("Local model")
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }

            Spacer()

            ollamaStatusPill

            Divider()
                .frame(height: 30)

            VStack(
                alignment: .trailing,
                spacing: 2
            ) {

                Text(modelStatusText)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(modelStatusDescription)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }

            if modelStatus == .loading ||
                modelStatus == .starting {

                ProgressView()
                    .controlSize(.small)

            } else {

                Toggle(
                    "",
                    isOn:
                        Binding(
                            get: {
                                modelEnabled
                            },
                            set: { newValue in

                                Task {
                                    await setModelPower(
                                        newValue
                                    )
                                }
                            }
                        )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!ollamaOnline)
            }
        }
        .padding(
            .horizontal,
            14
        )
        .padding(
            .vertical,
            10
        )
        .background(
            RoundedRectangle(
                cornerRadius: 12
            )
            .fill(
                .quaternary.opacity(
                    0.45
                )
            )
        )
    }

    // MARK: - Ollama Status Pill

    private var ollamaStatusPill: some View {

        HStack(spacing: 8) {

            Circle()
                .fill(
                    ollamaOnline
                    ? .green
                    : .red
                )
                .frame(
                    width: 9,
                    height: 9
                )

            Text(
                ollamaOnline
                ? "Ollama Online"
                : "Ollama Offline"
            )
            .font(.subheadline)
            .fontWeight(.medium)
        }
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            6
        )
        .background(
            Capsule()
                .fill(
                    ollamaOnline
                    ? Color.green.opacity(0.12)
                    : Color.red.opacity(0.12)
                )
        )
    }

    // MARK: - Model Status

    private var modelStatusText: String {

        switch modelStatus {

        case .starting:
            return "Starting..."

        case .loading:
            return "Loading..."

        case .on:
            return "ON"

        case .off:
            return "OFF"

        case .unavailable:
            return "Unavailable"
        }
    }

    private var modelStatusDescription: String {

        switch modelStatus {

        case .starting:
            return "Preparing model"

        case .loading:
            return "Waking Qwen3 8B"

        case .on:
            return "Ready to generate"

        case .off:
            return "Model unloaded"

        case .unavailable:
            return "Model unavailable"
        }
    }

    // MARK: - Ollama Monitor

    private func monitorOllama() async {

        var firstConnection = true

        while !Task.isCancelled {

            let available =
                await ollamaService.checkConnection()

            await MainActor.run {

                ollamaOnline =
                    available
            }

            if available {

                if firstConnection {

                    firstConnection = false

                    if modelEnabled {

                        await MainActor.run {

                            modelStatus =
                                .loading
                        }

                        do {

                            try await ollamaService
                                .setModelLoaded(
                                    true
                                )

                            await MainActor.run {

                                modelStatus =
                                    .on
                            }

                        } catch {

                            await MainActor.run {

                                modelStatus =
                                    .unavailable

                                errorMessage =
                                    "Could not load Qwen3 8B: " +
                                    error.localizedDescription
                            }
                        }

                    } else {

                        await MainActor.run {

                            modelStatus =
                                .off
                        }
                    }

                } else {

                    let currentStatus =
                        await MainActor.run {

                            modelStatus
                        }

                    if modelEnabled &&
                        currentStatus == .unavailable {

                        await MainActor.run {

                            modelStatus =
                                .loading
                        }

                        do {

                            try await ollamaService
                                .setModelLoaded(
                                    true
                                )

                            await MainActor.run {

                                modelStatus =
                                    .on
                            }

                        } catch {

                            await MainActor.run {

                                modelStatus =
                                    .unavailable
                            }
                        }
                    }
                }

            } else {

                await MainActor.run {

                    modelStatus =
                        .unavailable

                    if isLoading {
                        stopGeneration()
                    }
                }

                firstConnection = true
            }

            do {

                try await Task.sleep(
                    nanoseconds:
                        5_000_000_000
                )

            } catch {

                break
            }
        }
    }

    // MARK: - Model Power

    private func setModelPower(
        _ enabled: Bool
    ) async {

        guard ollamaOnline else {
            return
        }

        if enabled {

            await MainActor.run {

                modelEnabled = true
                modelStatus = .loading
                errorMessage = nil
            }

            do {

                try await ollamaService
                    .setModelLoaded(
                        true
                    )

                await MainActor.run {

                    modelStatus =
                        .on
                }

            } catch {

                await MainActor.run {

                    modelEnabled =
                        false

                    modelStatus =
                        .unavailable

                    errorMessage =
                        "Could not load Qwen3 8B: " +
                        error.localizedDescription
                }
            }

        } else {

            await MainActor.run {

                modelEnabled =
                    false

                stopGeneration()

                modelStatus =
                    .off

                errorMessage =
                    nil
            }

            do {

                try await ollamaService
                    .setModelLoaded(
                        false
                    )

            } catch {

                await MainActor.run {

                    errorMessage =
                        "Could not unload Qwen3 8B: " +
                        error.localizedDescription
                }
            }
        }
    }

    // MARK: - Chat Row

    private func chatRow(
        _ chat: Chat
    ) -> some View {

        Button {

            selectChat(
                chat.id
            )

        } label: {

            HStack(spacing: 8) {

                Image(
                    systemName:
                        "bubble.left"
                )

                Text(chat.title)
                    .lineLimit(1)

                Spacer()
            }
            .padding(
                .horizontal,
                10
            )
            .padding(
                .vertical,
                8
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .background {

                if selectedChatID ==
                    chat.id {

                    RoundedRectangle(
                        cornerRadius: 8
                    )
                    .fill(.quaternary)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {

            Button {

                startRenaming(
                    chat
                )

            } label: {

                Label(
                    "Rename",
                    systemImage:
                        "pencil"
                )
            }

            Divider()

            Button(
                role:
                    .destructive
            ) {

                deleteChat(
                    chat.id
                )

            } label: {

                Label(
                    "Delete",
                    systemImage:
                        "trash"
                )
            }
        }
    }

    // MARK: - Empty Chat

    private func emptyChatView()
        -> some View {

        VStack(
            spacing: 14
        ) {

            Spacer()

            Image(
                systemName:
                    "cpu"
            )
            .font(
                .system(
                    size: 48
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text("Local AI")
                .font(.largeTitle)
                .fontWeight(
                    .semibold
                )

            if !ollamaOnline {

                Text(
                    "Ollama is offline."
                )
                .foregroundStyle(
                    .red
                )

            } else if modelStatus ==
                        .loading ||
                      modelStatus ==
                        .starting {

                Text(
                    "Loading Qwen3 8B..."
                )
                .foregroundStyle(
                    .secondary
                )

            } else if modelStatus ==
                        .off {

                Text(
                    "Qwen3 8B is turned off."
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                Text(
                    "Ask Qwen3 8B anything."
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
    }

    // MARK: - New Chat

    private func newChat() {

        stopGeneration()

        errorMessage =
            nil

        expandedThinking
            .removeAll()

        isFollowingScroll =
            true

        showLatestButton =
            false

        let id =
            chatStore.createChat()

        selectedChatID =
            id

        inputText =
            ""
    }

    // MARK: - Select Chat

    private func selectChat(
        _ id: UUID
    ) {

        if id != selectedChatID {

            stopGeneration()
        }

        errorMessage =
            nil

        expandedThinking
            .removeAll()

        isFollowingScroll =
            true

        showLatestButton =
            false

        selectedChatID =
            id

        inputText =
            ""
    }

    // MARK: - Delete Chat

    private func deleteChat(
        _ id: UUID
    ) {

        if id ==
            selectedChatID {

            stopGeneration()
        }

        chatStore.deleteChat(
            id: id
        )

        if id ==
            selectedChatID {

            selectedChatID =
                chatStore
                .chats
                .first?
                .id
        }
    }

    // MARK: - Rename

    private func startRenaming(
        _ chat: Chat
    ) {

        renameText =
            chat.title

        renamingChatID =
            chat.id
    }

    private var renameSheet:
        some View {

        VStack(
            spacing: 16
        ) {

            Text(
                "Rename Chat"
            )
            .font(
                .headline
            )

            TextField(
                "Chat name",
                text:
                    $renameText
            )
            .textFieldStyle(
                .roundedBorder
            )

            HStack {

                Button(
                    "Cancel"
                ) {

                    renamingChatID =
                        nil
                }

                Spacer()

                Button(
                    "Save"
                ) {

                    if let id =
                        renamingChatID {

                        chatStore
                            .renameChat(
                                id: id,
                                title:
                                    renameText
                            )
                    }

                    renamingChatID =
                        nil
                }
                .buttonStyle(
                    .borderedProminent
                )
            }
        }
        .padding(24)
        .frame(
            width: 350
        )
    }

    // MARK: - Send Message

    private func sendMessage() {

        guard ollamaOnline else {

            errorMessage =
                "Ollama is offline."

            return
        }

        guard modelStatus ==
                .on else {

            errorMessage =
                "Qwen3 8B is turned off."

            return
        }

        guard let chatID =
            selectedChatID else {

            return
        }

        let text =
            inputText
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !text.isEmpty else {
            return
        }

        guard !isLoading else {
            return
        }

        guard let chatIndex =
            chatStore
            .chats
            .firstIndex(
                where: {
                    $0.id ==
                    chatID
                }
            )
        else {
            return
        }

        errorMessage =
            nil

        // A newly sent message always starts
        // the conversation at the newest point.
        isFollowingScroll =
            true

        showLatestButton =
            false

        let userMessage =
            ChatMessage(
                role:
                    .user,
                content:
                    text
            )

        chatStore
            .chats[
                chatIndex
            ]
            .messages
            .append(
                userMessage
            )

        inputText =
            ""

        chatStore
            .updateMessages(
                id:
                    chatID,
                messages:
                    chatStore
                    .chats[
                        chatIndex
                    ]
                    .messages
            )

        guard let updatedIndex =
            chatStore
            .chats
            .firstIndex(
                where: {
                    $0.id ==
                    chatID
                }
            )
        else {
            return
        }

        let assistantMessageID =
            UUID()

        chatStore
            .chats[
                updatedIndex
            ]
            .messages
            .append(
                ChatMessage(
                    id:
                        assistantMessageID,
                    role:
                        .assistant,
                    content:
                        "",
                    thinking:
                        ""
                )
            )

        isLoading =
            true

        generationTask =
            Task {

                do {

                    guard let currentIndex =
                        await MainActor.run(
                            body: {

                                chatStore
                                    .chats
                                    .firstIndex(
                                        where: {
                                            $0.id ==
                                            chatID
                                        }
                                    )
                            }
                        )
                    else {
                        return
                    }

                    let conversation =
                        await MainActor.run {

                            chatStore
                                .chats[
                                    currentIndex
                                ]
                                .messages
                                .dropLast()
                                .map {
                                    message in

                                    OllamaMessage(
                                        role:
                                            message.role ==
                                            .user
                                            ? "user"
                                            : "assistant",

                                        content:
                                            message.content
                                    )
                                }
                        }

                    let stream =
                        ollamaService
                        .streamMessage(
                            conversation
                        )

                    var content =
                        ""

                    var thinking =
                        ""

                    for try await chunk
                        in stream {

                        try Task
                            .checkCancellation()

                        if let value =
                            chunk
                            .message?
                            .thinking,
                           !value.isEmpty {

                            thinking +=
                                value
                        }

                        if let value =
                            chunk
                            .message?
                            .content,
                           !value.isEmpty {

                            content +=
                                value
                        }

                        await MainActor.run {

                            guard let currentIndex =
                                chatStore
                                .chats
                                .firstIndex(
                                    where: {
                                        $0.id ==
                                        chatID
                                    }
                                )
                            else {
                                return
                            }

                            guard let messageIndex =
                                chatStore
                                .chats[
                                    currentIndex
                                ]
                                .messages
                                .firstIndex(
                                    where: {
                                        $0.id ==
                                        assistantMessageID
                                    }
                                )
                            else {
                                return
                            }

                            chatStore
                                .chats[
                                    currentIndex
                                ]
                                .messages[
                                    messageIndex
                                ] =
                                ChatMessage(
                                    id:
                                        assistantMessageID,

                                    role:
                                        .assistant,

                                    content:
                                        content,

                                    thinking:
                                        thinking
                                )

                            chatStore
                                .chats[
                                    currentIndex
                                ]
                                .updatedAt =
                                Date()
                        }
                    }

                    await MainActor.run {

                        if let currentIndex =
                            chatStore
                            .chats
                            .firstIndex(
                                where: {
                                    $0.id ==
                                    chatID
                                }
                            ) {

                            chatStore
                                .updateMessages(
                                    id:
                                        chatID,

                                    messages:
                                        chatStore
                                        .chats[
                                            currentIndex
                                        ]
                                        .messages
                                )
                        }

                        isLoading =
                            false

                        generationTask =
                            nil
                    }

                } catch is CancellationError {

                    await MainActor.run {

                        if let currentIndex =
                            chatStore
                            .chats
                            .firstIndex(
                                where: {
                                    $0.id ==
                                    chatID
                                }
                            ) {

                            chatStore
                                .updateMessages(
                                    id:
                                        chatID,

                                    messages:
                                        chatStore
                                        .chats[
                                            currentIndex
                                        ]
                                        .messages
                                )
                        }

                        isLoading =
                            false

                        generationTask =
                            nil
                    }

                } catch {

                    await MainActor.run {

                        if let currentIndex =
                            chatStore
                            .chats
                            .firstIndex(
                                where: {
                                    $0.id ==
                                    chatID
                                }
                            ) {

                            chatStore
                                .chats[
                                    currentIndex
                                ]
                                .messages
                                .removeAll {
                                    $0.id ==
                                    assistantMessageID
                                }
                        }

                        errorMessage =
                            """
                            Ollama request failed:

                            \(error.localizedDescription)
                            """

                        isLoading =
                            false

                        generationTask =
                            nil
                    }
                }
            }
    }

    // MARK: - Stop Generation

    private func stopGeneration() {

        guard isLoading else {
            return
        }

        generationTask?
            .cancel()

        generationTask =
            nil

        isLoading =
            false
    }

    // MARK: - Thinking

    private func toggleThinking(
        for id: UUID
    ) {

        if expandedThinking
            .contains(id) {

            expandedThinking
                .remove(id)

        } else {

            expandedThinking
                .insert(id)
        }
    }

    // MARK: - Smart Scrolling

    private func followLatestIfNeeded(
        _ proxy: ScrollViewProxy
    ) {

        guard isFollowingScroll else {
            return
        }

        DispatchQueue.main.async {

            guard isFollowingScroll else {
                return
            }

            scrollToBottom(
                proxy,
                animated: false
            )
        }
    }

    private func scrollToBottom(
        _ proxy: ScrollViewProxy,
        animated: Bool
    ) {

        guard !currentMessages.isEmpty else {
            return
        }

        isProgrammaticScroll =
            true

        if animated {

            withAnimation(
                .easeOut(
                    duration: 0.18
                )
            ) {

                proxy.scrollTo(
                    "chatBottom",
                    anchor:
                        .bottom
                )
            }

        } else {

            proxy.scrollTo(
                "chatBottom",
                anchor:
                    .bottom
            )
        }

        // Give SwiftUI time to finish the
        // programmatic scroll before we start
        // interpreting geometry changes again.
        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.12
        ) {

            isProgrammaticScroll =
                false
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {

    let message: ChatMessage

    let isThinkingExpanded: Bool

    let isGenerating: Bool

    let toggleThinking: () -> Void

    var body: some View {

        HStack(
            alignment: .top
        ) {

            if message.role ==
                .assistant {

                Image(
                    systemName:
                        "cpu"
                )
                .frame(
                    width: 30,
                    height: 30
                )
                .background(
                    Circle()
                        .fill(
                            .quaternary
                        )
                )

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text("Qwen3")
                        .font(
                            .caption
                        )
                        .fontWeight(
                            .semibold
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    if !message
                        .thinking
                        .isEmpty {

                        Button {

                            toggleThinking()

                        } label: {

                            HStack(
                                spacing: 6
                            ) {

                                Image(
                                    systemName:
                                        "brain"
                                )

                                Text(
                                    isGenerating
                                    ? "Thinking..."
                                    : "Thoughts"
                                )
                                .font(
                                    .caption
                                )
                                .fontWeight(
                                    .medium
                                )

                                Image(
                                    systemName:
                                        isThinkingExpanded
                                        ? "chevron.down"
                                        : "chevron.right"
                                )
                                .font(
                                    .caption2
                                )

                                Spacer()
                            }
                            .foregroundStyle(
                                .secondary
                            )
                        }
                        .buttonStyle(
                            .plain
                        )

                        if isThinkingExpanded {

                            Text(
                                message.thinking
                            )
                            .font(
                                .system(
                                    size: 12
                                )
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            .textSelection(
                                .enabled
                            )
                            .padding(
                                .leading,
                                8
                            )
                            .overlay(
                                Rectangle()
                                    .frame(
                                        width: 2
                                    )
                                    .foregroundStyle(
                                        .quaternary
                                    ),
                                alignment:
                                    .leading
                            )
                        }
                    }

                    if !message
                        .content
                        .isEmpty {

                        Text(
                            message.content
                        )
                        .textSelection(
                            .enabled
                        )
                    }
                }

                Spacer()

            } else {

                Spacer()

                VStack(
                    alignment:
                        .trailing,
                    spacing: 5
                ) {

                    Text("You")
                        .font(
                            .caption
                        )
                        .fontWeight(
                            .semibold
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    Text(
                        message.content
                    )
                    .textSelection(
                        .enabled
                    )
                    .padding(
                        .horizontal,
                        14
                    )
                    .padding(
                        .vertical,
                        10
                    )
                    .background(
                        RoundedRectangle(
                            cornerRadius:
                                14
                        )
                        .fill(
                            .blue.opacity(
                                0.15
                            )
                        )
                    )
                }
            }
        }
        .padding(
            .horizontal,
            20
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
