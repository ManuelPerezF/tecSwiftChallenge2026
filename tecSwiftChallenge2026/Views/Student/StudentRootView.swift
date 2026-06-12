import SwiftUI

enum StudentTab: Hashable {
    case map, commitments, hours
}

struct StudentRootView: View {
    let onLogout: () -> Void
    @State private var selectedTab: StudentTab = .map

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Mapa", systemImage: "map", value: StudentTab.map) {
                NavigationStack {
                    StudentMapView()
                        .navigationDestination(for: OpenRequest.self) { req in
                            StudentDetailView(request: req)
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                logoutButton
                            }
                        }
                }
            }
            Tab("Visitas", systemImage: "checkmark.circle", value: StudentTab.commitments) {
                NavigationStack {
                    StudentCommitmentsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                logoutButton
                            }
                        }
                }
            }
            Tab("Horas", systemImage: "timer", value: StudentTab.hours) {
                NavigationStack {
                    StudentHoursView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                logoutButton
                            }
                        }
                }
            }
        }
        .tint(.acoStudent)
    }

    private var logoutButton: some View {
        Button("Cerrar sesión", action: onLogout)
            .font(.caption)
            .foregroundStyle(Color.acoInk3)
    }
}

#Preview {
    StudentRootView(onLogout: {})
}
