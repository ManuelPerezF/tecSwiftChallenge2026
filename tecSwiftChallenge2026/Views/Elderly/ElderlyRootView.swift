import SwiftUI
@preconcurrency import CoreLocation

enum ElderlyTab: Hashable {
    case agenda, family
}

struct ElderlyRootView: View {
    let onLogout: () -> Void
    @State private var selectedTab: ElderlyTab = .agenda
    @State private var locationManager = ElderlyLocationUpdater()
    @State private var showProfile = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Mis visitas", systemImage: "calendar", value: ElderlyTab.agenda) {
                NavigationStack {
                    ElderlyAgendaView(onGoToFamily: { selectedTab = .family })
                        .navigationDestination(for: APIAssignment.self) { assignment in
                            ElderlyLiveMapView(assignment: assignment)
                        }
                        .navigationDestination(for: ElderlyDestination.self) { dest in
                            switch dest {
                            case .visitDetail(let assignment):
                                ElderlyVisitView(assignment: assignment)
                            case .rating(let assignmentId, let studentName):
                                ElderlyRatingView(assignmentId: assignmentId, studentName: studentName)
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) { profileButton }
                            ToolbarItem(placement: .topBarTrailing) { NotificationBellButton(tint: .acoElderly) }
                        }
                }
            }
            Tab("Mi familia", systemImage: "person.2.fill", value: ElderlyTab.family) {
                NavigationStack {
                    ElderlyFamilyView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) { profileButton }
                            ToolbarItem(placement: .topBarTrailing) { NotificationBellButton(tint: .acoElderly) }
                        }
                }
            }
        }
        .tint(.acoElderly)
        .task { locationManager.requestOnce() }
        .sheet(isPresented: $showProfile) {
            ElderlyProfileView(onLogout: onLogout)
        }
    }

    /// Perfil arriba a la izquierda (patrón común a todos los roles).
    private var profileButton: some View {
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
}

@MainActor
private final class ElderlyLocationUpdater: NSObject, CLLocationManagerDelegate, Sendable {
    private let manager = CLLocationManager()
    private var didSend = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestOnce() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude
        let lng = loc.coordinate.longitude
        DispatchQueue.main.async {
            guard !self.didSend else { return }
            self.didSend = true
            Task { await APIClient.shared.updateElderlyLocation(latitude: lat, longitude: lng) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

#Preview {
    ElderlyRootView(onLogout: {})
}
