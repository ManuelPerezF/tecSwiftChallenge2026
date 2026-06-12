import SwiftUI

// MARK: - Notificaciones in-app (compartida por los 4 roles)

struct NotificationsView: View {
    /// Tinte por rol (teal familia/organizador, verde becario, naranja adulto mayor)
    var tint: Color = .acoFamily
    /// true cuando la abre un becario: "Sí" navega al detalle de la solicitud
    var isStudent: Bool = false

    @AppStorage("aco_authToken") private var authToken: String = ""
    @Environment(\.dismiss) private var dismiss

    @State private var notifications: [APINotification] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var openRequest: OpenRequest?
    @State private var ws = WebSocketClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.acoBg.ignoresSafeArea()

                if isLoading && notifications.isEmpty {
                    ProgressView("Cargando…").tint(tint)
                } else if notifications.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Notificaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.acoInk3)
                }
            }
            .navigationDestination(item: $openRequest) { request in
                StudentDetailView(request: request)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .onAppear {
            ws.onNotification = { incoming in
                withAnimation(.easeInOut(duration: 0.2)) {
                    notifications.insert(incoming, at: 0)
                }
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Color.acoUrgent)
                }

                ForEach(notifications) { notification in
                    NotificationCard(
                        notification: notification,
                        tint: tint,
                        onYes: yesAction(for: notification),
                        onNo: noAction(for: notification),
                        onTap: { Task { await markRead(notification) } }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell")
                .font(.system(size: 40))
                .foregroundStyle(Color.acoInk3)
                .accessibilityHidden(true)
            Text("Sin notificaciones por ahora")
                .font(.body).foregroundStyle(Color.acoInk2)
        }
    }

    // MARK: - Actions

    /// Tipos explícitos para evitar la ambigüedad de `Task.init` dentro de ternarios.
    private func yesAction(for notification: APINotification) -> (() -> Void)? {
        guard notification.requiresConfirmation && isStudent else { return nil }
        return { Task { await confirmYes(notification) } }
    }

    private func noAction(for notification: APINotification) -> (() -> Void)? {
        guard notification.requiresConfirmation else { return nil }
        return { Task { await markRead(notification) } }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            notifications = try await APIClient.shared.fetchNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// "Sí, estoy disponible" → marca leída y abre el detalle para postularse.
    private func confirmYes(_ notification: APINotification) async {
        await markRead(notification)
        guard let requestId = notification.requestId,
              let request = try? await APIClient.shared.fetchRequest(id: requestId) else { return }
        openRequest = request.toOpenRequest()
    }

    private func markRead(_ notification: APINotification) async {
        guard !notification.read else { return }
        try? await APIClient.shared.markNotificationRead(id: notification.id)
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            let updated = APINotification(
                id: notification.id, type: notification.type, title: notification.title,
                body: notification.body, data: notification.data, read: true,
                createdAt: notification.createdAt
            )
            withAnimation(.easeInOut(duration: 0.15)) { notifications[index] = updated }
        }
    }
}

// MARK: - Card

private struct NotificationCard: View {
    let notification: APINotification
    let tint: Color
    let onYes: (() -> Void)?
    let onNo: (() -> Void)?
    let onTap: () -> Void

    private var symbol: String {
        switch notification.type {
        case "request_nearby":          "mappin.and.ellipse"
        case "event_nearby",
             "event_nearby_family",
             "event_nearby_elderly":    "person.3.fill"
        case "assignment_cancelled":    "xmark.circle.fill"
        case "change_proposal":         "clock.arrow.2.circlepath"
        case "completion_pending":      "checkmark.seal"
        case "match_found":             "heart.circle.fill"
        case "schedule_matches":        "calendar.badge.clock"
        case "chat_unlocked":           "bubble.left.and.bubble.right.fill"
        default:                        "bell.fill"
        }
    }

    var body: some View {
        Button(action: onTap) {
            AcoCard(padding: 13) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(notification.read ? Color(acoHex: "F0EBE3") : tint.opacity(0.13))
                                .frame(width: 36, height: 36)
                            Image(systemName: symbol)
                                .font(.subheadline)
                                .foregroundStyle(notification.read ? Color.acoInk3 : tint)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(notification.title)
                                .font(.subheadline).fontWeight(notification.read ? .medium : .bold)
                                .foregroundStyle(Color.acoInk)
                            Text(notification.body)
                                .font(.caption).foregroundStyle(Color.acoInk2)
                        }
                        Spacer()
                        if !notification.read {
                            Circle().fill(tint).frame(width: 8, height: 8)
                                .accessibilityLabel("No leída")
                        }
                    }

                    if !notification.read, onYes != nil || onNo != nil {
                        HStack(spacing: 10) {
                            if let onNo {
                                Button(action: onNo) {
                                    Text("No puedo")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.acoInk2)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color(acoHex: "F0EBE3"))
                                        .clipShape(.rect(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                            if let onYes {
                                Button(action: onYes) {
                                    Text("Sí, estoy cerca")
                                        .font(.subheadline).fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(tint)
                                        .clipShape(.rect(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Botón campana reutilizable (toolbar)

struct NotificationBellButton: View {
    var tint: Color = .acoFamily
    var isStudent: Bool = false

    @State private var showNotifications = false
    @State private var unreadCount = 0

    var body: some View {
        Button {
            showNotifications = true
        } label: {
            Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell")
                .symbolRenderingMode(unreadCount > 0 ? .multicolor : .monochrome)
                .font(.title3)
                .foregroundStyle(Color.acoInk2)
        }
        .accessibilityLabel(unreadCount > 0 ? "Notificaciones, \(unreadCount) sin leer" : "Notificaciones")
        .sheet(isPresented: $showNotifications, onDismiss: { Task { await refreshCount() } }) {
            NotificationsView(tint: tint, isStudent: isStudent)
        }
        .task { await refreshCount() }
    }

    private func refreshCount() async {
        unreadCount = (try? await APIClient.shared.fetchUnreadNotificationsCount()) ?? 0
    }
}
