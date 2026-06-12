import SwiftUI

enum ElderlyTab: Hashable {
    case agenda, family
}

struct ElderlyRootView: View {
    let onLogout: () -> Void
    @State private var selectedTab: ElderlyTab = .agenda

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Mis visitas", systemImage: "calendar", value: ElderlyTab.agenda) {
                NavigationStack {
                    ElderlyAgendaView(onGoToFamily: { selectedTab = .family })
                        .navigationDestination(for: APIAssignment.self) { assignment in
                            ElderlyLiveMapView(assignment: assignment)
                        }
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { logoutButton } }
                }
            }
            Tab("Mi familia", systemImage: "person.2.fill", value: ElderlyTab.family) {
                NavigationStack {
                    ElderlyFamilyView()
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { logoutButton } }
                }
            }
        }
        .tint(.acoElderly)
    }

    private var logoutButton: some View {
        Button("Cerrar sesión", action: onLogout)
            .font(.caption)
            .foregroundStyle(Color.acoInk3)
    }
}

#Preview {
    ElderlyRootView(onLogout: {})
}
