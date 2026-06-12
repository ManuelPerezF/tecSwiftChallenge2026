import SwiftUI

struct StudentInboxView: View {
    @AppStorage("aco_userId") private var myUserId: String = ""

    @State private var messages: [APIMessage] = []
    @State private var isLoading = false

    // Group by the OTHER party (family sender). Ignore own sent replies as conversation starters.
    private var conversations: [(fromUserId: String, fromName: String, lastMessage: APIMessage, unread: Int)] {
        var groups: [String: [APIMessage]] = [:]
        for msg in messages {
            // Key = the family member's user ID (always the non-student side)
            let key = msg.fromUserId == myUserId ? (msg.toUserId ?? msg.fromUserId) : msg.fromUserId
            groups[key, default: []].append(msg)
        }
        return groups.compactMap { (key, msgs) -> (String, String, APIMessage, Int)? in
            // Only show if there's at least one received message (to get the sender name)
            guard let received = msgs.first(where: { $0.fromUserId != myUserId }) else { return nil }
            let last = msgs.max(by: { $0.createdAt < $1.createdAt }) ?? received
            let unread = msgs.filter { $0.isUnread && $0.fromUserId != myUserId }.count
            return (key, received.fromName, last, unread)
        }
        .sorted { $0.2.createdAt > $1.2.createdAt }
    }

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if isLoading && messages.isEmpty {
                ProgressView("Cargando…").tint(Color.acoStudent)
            } else if conversations.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.acoStudentSoft).frame(width: 88, height: 88)
                        Image(systemName: "tray")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.acoStudent)
                    }
                    Text("Sin mensajes")
                        .font(.title3.bold()).foregroundStyle(Color.acoInk)
                    Text("Cuando una familia te escriba, aparecerá aquí.")
                        .font(.body).foregroundStyle(Color.acoInk3)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            } else {
                List {
                    ForEach(conversations, id: \.fromUserId) { conv in
                        NavigationLink {
                            ChatThreadView(
                                title: conv.fromName,
                                otherId: conv.fromUserId,
                                tint: .acoStudent,
                                isFamily: false
                            )
                        } label: {
                            InboxConversationRow(
                                name: conv.fromName,
                                lastBody: conv.lastMessage.body,
                                lastAt: conv.lastMessage.createdAtFormatted,
                                unread: conv.unread
                            )
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
        messages = (try? await APIClient.shared.fetchInbox()) ?? []
        isLoading = false
    }
}

private struct InboxConversationRow: View {
    let name: String
    let lastBody: String
    let lastAt: String
    let unread: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: name, tint: .acoFamily, size: 52)
                if unread > 0 {
                    Circle()
                        .fill(Color.acoStudent)
                        .frame(width: 14, height: 14)
                        .offset(x: 2, y: 2)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(name)
                        .font(.subheadline.weight(unread > 0 ? .bold : .semibold))
                        .foregroundStyle(Color.acoInk)
                    Spacer()
                    Text(lastAt)
                        .font(.caption2)
                        .foregroundStyle(Color.acoInk3)
                }
                Text(lastBody)
                    .font(.subheadline)
                    .foregroundStyle(unread > 0 ? Color.acoInk : Color.acoInk2)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack { StudentInboxView() }
}
