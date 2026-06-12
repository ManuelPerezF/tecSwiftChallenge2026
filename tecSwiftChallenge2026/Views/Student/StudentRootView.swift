import SwiftUI

enum StudentTab: Hashable {
    case map, commitments, inbox
}

struct StudentRootView: View {
    let onLogout: () -> Void
    @State private var selectedTab: StudentTab = .map
    @State private var showProfile = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Mapa al centro de la tab bar (Visitas · Mapa · Mensajes)
            Tab("Visitas", systemImage: "checkmark.circle", value: StudentTab.commitments) {
                NavigationStack {
                    StudentCommitmentsView()
                        .toolbar { studentToolbar }
                }
            }
            Tab("Mapa", systemImage: "map", value: StudentTab.map) {
                NavigationStack {
                    StudentMapView()
                        .navigationDestination(for: OpenRequest.self) { req in
                            StudentDetailView(request: req)
                        }
                        .toolbar { studentToolbar }
                }
            }
            Tab("Mensajes", systemImage: "bubble.left.and.bubble.right", value: StudentTab.inbox) {
                NavigationStack {
                    StudentInboxView()
                        .toolbar { studentToolbar }
                }
            }
        }
        .tint(.acoStudent)
        .sheet(isPresented: $showProfile) {
            StudentProfileView(onLogout: onLogout)
        }
    }

    /// Perfil arriba a la izquierda (patrón común a todos los roles) + campana a la derecha.
    @ToolbarContentBuilder
    private var studentToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showProfile = true
            } label: {
                Image(systemName: "person.circle")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)
                    .foregroundStyle(Color.acoInk2)
            }
            .accessibilityLabel("Mi perfil")
        }
        ToolbarItem(placement: .topBarTrailing) {
            NotificationBellButton(tint: .acoStudent, isStudent: true)
        }
    }
}

#Preview {
    StudentRootView(onLogout: {})
}
