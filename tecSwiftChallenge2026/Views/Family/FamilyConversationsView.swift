import SwiftUI

struct FamilyConversationsView: View {
    @State private var conversations: [APIConversation] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if isLoading && conversations.isEmpty {
                ProgressView("Cargando…").tint(Color.acoFamily)
            } else if conversations.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.acoFamilySoft).frame(width: 88, height: 88)
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.acoFamily)
                    }
                    Text("Sin conversaciones")
                        .font(.title3.bold())
                        .foregroundStyle(Color.acoInk)
                    Text("Cuando envíes un mensaje a un becario, aparecerá aquí.")
                        .font(.body)
                        .foregroundStyle(Color.acoInk3)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            } else {
                List {
                    ForEach(conversations) { conv in
                        NavigationLink(value: conv) {
                            ConversationRow(conversation: conv)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("Mensajes")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        conversations = (try? await APIClient.shared.fetchConversations()) ?? []
        isLoading = false
    }
}

private struct ConversationRow: View {
    let conversation: APIConversation

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: conversation.studentName, tint: .acoStudent, size: 52)
                if conversation.unreadCount > 0 {
                    Circle()
                        .fill(Color.acoFamily)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Text("\(min(conversation.unreadCount, 9))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conversation.studentName)
                        .font(.subheadline.weight(conversation.unreadCount > 0 ? .bold : .semibold))
                        .foregroundStyle(Color.acoInk)
                    Spacer()
                    Text(conversation.lastAtFormatted)
                        .font(.caption2)
                        .foregroundStyle(Color.acoInk3)
                }
                Text(conversation.lastBody)
                    .font(.subheadline)
                    .foregroundStyle(conversation.unreadCount > 0 ? Color.acoInk : Color.acoInk2)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        FamilyConversationsView()
    }
}
