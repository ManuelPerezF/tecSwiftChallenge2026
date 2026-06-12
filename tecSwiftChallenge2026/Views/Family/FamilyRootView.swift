import SwiftUI
import SwiftData

enum FamilyTab: Hashable {
    case publish, dashboard
}

struct FamilyRootView: View {
    let onSwitchRole: () -> Void
    @State private var selectedTab: FamilyTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Publicar", systemImage: "square.and.pencil", value: FamilyTab.publish) {
                NavigationStack {
                    FamilyPublishView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                roleMenuButton
                            }
                        }
                }
            }
            Tab("Solicitudes", systemImage: "list.bullet", value: FamilyTab.dashboard) {
                NavigationStack {
                    FamilyDashboardView(onAddTapped: { selectedTab = .publish })
                        .navigationDestination(for: FamilyRequestItem.self) { item in
                            FamilyStudentProfileView(request: item)
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                roleMenuButton
                            }
                        }
                }
            }
        }
        .tint(.acoFamily)
    }

    private var roleMenuButton: some View {
        Button("Cambiar rol", action: onSwitchRole)
            .font(.caption)
            .foregroundStyle(Color.acoInk3)
    }
}

#Preview {
    FamilyRootView(onSwitchRole: {})
        .modelContainer(ModelContainer.acompana)
}
