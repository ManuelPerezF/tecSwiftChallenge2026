import SwiftUI

enum StudentTab: Hashable {
    case map, commitments, hours
}

struct StudentRootView: View {
    let onSwitchRole: () -> Void
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
                                roleButton
                            }
                        }
                }
            }
            Tab("Visitas", systemImage: "checkmark.circle", value: StudentTab.commitments) {
                NavigationStack {
                    StudentCommitmentsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                roleButton
                            }
                        }
                }
            }
            Tab("Horas", systemImage: "timer", value: StudentTab.hours) {
                NavigationStack {
                    StudentHoursView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                roleButton
                            }
                        }
                }
            }
        }
        .tint(.acoStudent)
    }

    private var roleButton: some View {
        Button("Cambiar rol", action: onSwitchRole)
            .font(.caption)
            .foregroundStyle(Color.acoInk3)
    }
}

#Preview {
    StudentRootView(onSwitchRole: {})
}
