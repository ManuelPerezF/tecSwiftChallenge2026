import SwiftUI

enum FamilyTab: Hashable {
    case publish, dashboard, messages, family
}

struct FamilyRootView: View {
    let onLogout: () -> Void
    @State private var selectedTab: FamilyTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Publicar", systemImage: "square.and.pencil", value: FamilyTab.publish) {
                NavigationStack {
                    FamilyPublishView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { logoutButton } }
                }
            }
            Tab("Solicitudes", systemImage: "list.bullet", value: FamilyTab.dashboard) {
                NavigationStack {
                    FamilyDashboardView(onAddTapped: { selectedTab = .publish })
                        .navigationDestination(for: APIRequest.self) { request in
                            FamilyApplicantsView(request: request)
                        }
                        .navigationDestination(for: APIAssignment.self) { assignment in
                            FamilyLiveVisitView(assignment: assignment)
                        }
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { logoutButton } }
                }
            }
            Tab("Mensajes", systemImage: "bubble.left.and.bubble.right", value: FamilyTab.messages) {
                NavigationStack {
                    FamilyConversationsView()
                        .navigationDestination(for: APIConversation.self) { conv in
                            ChatThreadView(
                                title: conv.studentName,
                                otherId: conv.studentId,
                                tint: .acoFamily,
                                isFamily: true
                            )
                        }
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { logoutButton } }
                }
            }
            Tab("Mi familia", systemImage: "person.2.fill", value: FamilyTab.family) {
                NavigationStack {
                    FamilyManageView()
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { logoutButton } }
                }
            }
        }
        .tint(.acoFamily)
    }

    private var logoutButton: some View {
        Menu {
            Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                onLogout()
            }
        } label: {
            Image(systemName: "person.circle")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(Color.acoInk2)
        }
        .accessibilityLabel("Cuenta")
    }
}

#Preview {
    FamilyRootView(onLogout: {})
}
