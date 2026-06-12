import SwiftUI

/// Chat en tiempo real via WebSocket.
/// - Para familia: otherId = studentId, isFamily = true
/// - Para estudiante: otherId = fromUserId (user ID del familiar), isFamily = false
struct ChatThreadView: View {
    let title: String
    let otherId: String
    let tint: Color
    let isFamily: Bool

    @AppStorage("aco_userId")    private var myUserId: String = ""
    @AppStorage("aco_authToken") private var authToken: String = ""

    @State private var messages: [APIMessage] = []
    @State private var isLoading = false
    @State private var draft = ""
    @State private var isSending = false
    @FocusState private var inputFocused: Bool

    private let ws = WebSocketClient.shared

    var body: some View {
        VStack(spacing: 0) {
            messageList
            composeBar
        }
        .background(Color.acoBg.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
            ws.onChatMessage = { [self] incoming in
                let involvedStudent = incoming.toStudentId == (isFamily ? otherId : "")
                let involvedUser   = incoming.fromUserId == otherId || incoming.toUserId == myUserId || incoming.fromUserId == myUserId
                guard involvedStudent || involvedUser else { return }
                if !messages.contains(where: { $0.id == incoming.id }) {
                    messages.append(incoming)
                }
            }
            if !authToken.isEmpty && !ws.isConnected {
                ws.connect(token: authToken)
            }
        }
        .onDisappear {
            ws.onChatMessage = nil
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoading && messages.isEmpty {
                    ProgressView().tint(tint).padding(.top, 40)
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(messages) { message in
                            BubbleRow(
                                message: message,
                                isOutgoing: message.fromUserId == myUserId,
                                tint: tint
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Compose bar

    private var composeBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Escribe un mensaje…", text: $draft, axis: .vertical)
                .font(.body)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 20, style: .continuous))
                .focused($inputFocused)

            Button { send() } label: {
                Image(systemName: isSending ? "clock" : "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        (draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                            ? Color.acoInk3 : tint
                    )
                    .animation(.easeOut(duration: 0.15), value: draft.isEmpty)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        messages = (try? await APIClient.shared.fetchThread(otherId: otherId)) ?? []
        isLoading = false
    }

    private func send() {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        draft = ""
        KuidarHaptic.light()
        Task {
            isSending = true
            do {
                let sent: APIMessage
                if isFamily {
                    sent = try await APIClient.shared.sendMessage(toStudentId: otherId, body: body)
                } else {
                    sent = try await APIClient.shared.replyMessage(toUserId: otherId, body: body)
                }
                // WS broadcast will deliver to recipient; add locally for sender immediately
                if !messages.contains(where: { $0.id == sent.id }) {
                    messages.append(sent)
                }
                KuidarHaptic.success()
            } catch {
                draft = body // restore on error
                KuidarHaptic.error()
            }
            isSending = false
        }
    }
}

// MARK: - Bubble

private struct BubbleRow: View {
    let message: APIMessage
    let isOutgoing: Bool
    let tint: Color

    var body: some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 2) {
            if !isOutgoing {
                Text(message.fromName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.acoInk3)
                    .padding(.leading, 6)
            }
            HStack {
                if isOutgoing { Spacer(minLength: 52) }
                Text(message.body)
                    .font(.body)
                    .foregroundStyle(isOutgoing ? .white : Color.acoInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(isOutgoing ? tint : Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 18, style: .continuous))
                if !isOutgoing { Spacer(minLength: 52) }
            }
            Text(message.createdAtFormatted)
                .font(.caption2)
                .foregroundStyle(Color.acoInk3)
                .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
        .padding(.vertical, 3)
    }
}

#Preview {
    NavigationStack {
        ChatThreadView(
            title: "María García",
            otherId: "preview-id",
            tint: .acoFamily,
            isFamily: true
        )
    }
}
