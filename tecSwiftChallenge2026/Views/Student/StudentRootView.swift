import SwiftUI

enum StudentTab: Hashable {
    case map, commitments, hours, inbox
}

struct StudentRootView: View {
    let onLogout: () -> Void
    @State private var selectedTab: StudentTab = .map

    var body: some View {
        TabView(selection: $selectedTab) {
            // Mapa al centro de la tab bar (Visitas · Mapa · Horas · Mensajes)
            Tab("Visitas", systemImage: "checkmark.circle", value: StudentTab.commitments) {
                NavigationStack {
                    StudentCommitmentsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NotificationBellButton(tint: .acoStudent, isStudent: true)
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                logoutButton
                            }
                        }
                }
            }
            Tab("Mapa", systemImage: "map", value: StudentTab.map) {
                NavigationStack {
                    StudentMapView()
                        .navigationDestination(for: OpenRequest.self) { req in
                            StudentDetailView(request: req)
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NotificationBellButton(tint: .acoStudent, isStudent: true)
                            }
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
                                NotificationBellButton(tint: .acoStudent, isStudent: true)
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                logoutButton
                            }
                        }
                }
            }
            Tab("Mensajes", systemImage: "bubble.left.and.bubble.right", value: StudentTab.inbox) {
                NavigationStack {
                    StudentInboxView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NotificationBellButton(tint: .acoStudent, isStudent: true)
                            }
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
    StudentRootView(onLogout: {})
}
