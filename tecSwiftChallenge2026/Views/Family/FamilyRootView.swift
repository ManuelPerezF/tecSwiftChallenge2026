import SwiftUI

enum FamilyTab: Hashable {
    case publish, dashboard, family
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
        Button("Cerrar sesión", action: onLogout)
            .font(.caption)
            .foregroundStyle(Color.acoInk3)
    }
}

#Preview {
    FamilyRootView(onLogout: {})
}
