import SwiftUI
import MapKit
import CoreLocation
import Combine

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - Coordinate helper

private extension OpenRequest {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Map region helpers

private let fallbackCenter = CLLocationCoordinate2D(latitude: 19.3950, longitude: -99.1630)
private let overviewSpan = MKCoordinateSpan(latitudeDelta: 0.055, longitudeDelta: 0.055)
private let detailSpan   = MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)

// MARK: - Main view

struct StudentMapView: View {
    @StateObject private var locationManager = StudentLocationManager()
    @State private var requests: [OpenRequest] = []
    @State private var selectedId: String = ""
    @State private var filterActivity: ActivityType? = nil
    @State private var didCenterOnCurrentLocation = false
    @State private var mapError: String?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(center: fallbackCenter, span: overviewSpan)
    )

    private var filteredRequests: [OpenRequest] {
        guard let f = filterActivity else { return requests }
        return requests.filter { $0.activityType == f }
    }

    private var overviewCenter: CLLocationCoordinate2D {
        if let coord = locationManager.coordinate { return coord }
        if let first = requests.first { return first.coordinate }
        return fallbackCenter
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer

            if let mapError {
                VStack {
                    Spacer()
                    Label(mapError, systemImage: "wifi.slash")
                        .font(.subheadline)
                        .foregroundStyle(Color.acoInk2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 260)
                }
            }

            filterBar
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)

            VStack {
                Spacer()
                MapBottomSheet(
                    filteredRequests: filteredRequests,
                    selectedId: $selectedId,
                    onSelect: { req in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            position = .region(MKCoordinateRegion(center: req.coordinate, span: detailSpan))
                        }
                    }
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            locationManager.requestLocation()
            await loadRequests()
        }
        .onChange(of: locationManager.coordinate) { _, coordinate in
            guard let coordinate, !didCenterOnCurrentLocation else { return }
            didCenterOnCurrentLocation = true
            withAnimation {
                position = .region(MKCoordinateRegion(center: coordinate, span: overviewSpan))
            }
        }
        .onChange(of: filterActivity) { _, _ in
            if filteredRequests.first(where: { $0.id == selectedId }) == nil,
               let first = filteredRequests.first { selectedId = first.id }
            withAnimation { position = .region(MKCoordinateRegion(center: overviewCenter, span: overviewSpan)) }
        }
    }

    // MARK: - Map layer

    private var mapLayer: some View {
        Map(position: $position) {
            UserAnnotation()

            ForEach(filteredRequests) { req in
                Annotation(req.title, coordinate: req.coordinate) {
                    MapPinButton(request: req, isSelected: req.id == selectedId) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedId = req.id
                            position = .region(MKCoordinateRegion(center: req.coordinate, span: detailSpan))
                        }
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([
            .cafe, .hospital, .pharmacy, .park, .publicTransport
        ])))
        .mapControls { MapCompass(); MapScaleView() }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Load from API

    private func loadRequests() async {
        mapError = nil
        do {
            let apiRequests = try await APIClient.shared.fetchOpenRequests()
            let lat = locationManager.coordinate?.latitude
            let lng = locationManager.coordinate?.longitude
            let openRequests = apiRequests.map { $0.toOpenRequest(fromLat: lat, fromLng: lng) }
            requests = openRequests
            if selectedId.isEmpty, let first = openRequests.first {
                selectedId = first.id
            }
        } catch {
            mapError = error.localizedDescription
        }
    }

    // MARK: Filter bar

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text("Cerca de ti")
                    .font(.title2).bold().foregroundStyle(Color.acoInk)
                Spacer()
                Text("^[\(filteredRequests.count) solicitud](inflect: true)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.acoStudent)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.acoStudentSoft)
                    .clipShape(Capsule())
            }
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ChipButton(label: "Todas", tint: .acoStudent, soft: Color.white.opacity(0.95),
                               isActive: filterActivity == nil) {
                        withAnimation(.easeInOut(duration: 0.15)) { filterActivity = nil }
                    }
                    .accessibilityLabel("Todas las actividades")
                    ForEach(ActivityType.allCases, id: \.self) { act in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { filterActivity = act }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: act.symbolName)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(act.label.components(separatedBy: " ").first ?? act.label)
                                    .font(.system(size: 13.5, weight: .semibold))
                            }
                            .foregroundStyle(filterActivity == act ? .white : Color.acoStudent)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(filterActivity == act ? Color.acoStudent : Color.white.opacity(0.95))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(act.label)
                        .accessibilityAddTraits(filterActivity == act ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: Color.acoStudent.opacity(0.12), radius: 14, x: 0, y: 5)
    }
}

// MARK: - Current location

private final class StudentLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            guard manager.authorizationStatus == .authorizedAlways ||
                  manager.authorizationStatus == .authorizedWhenInUse else { return }

            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }

        DispatchQueue.main.async {
            self.coordinate = latestLocation.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the fallback map region if the device cannot provide a location.
    }
}

// MARK: - Custom map pin

private struct MapPinButton: View {
    let request: OpenRequest
    let isSelected: Bool
    let onTap: () -> Void

    private var pinColor: Color { request.isUrgent ? .acoUrgent : .acoMapPin }

    var body: some View {
        Button(action: onTap) {
            AcoMapMarker(
                symbol: request.activityType.symbolName,
                color: pinColor,
                isSelected: isSelected,
                pulse: request.isUrgent || isSelected,
                size: isSelected ? 48 : 42
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(request.activityType.label), \(request.neighborhood), \(request.isUrgent ? "urgente" : "normal")")
    }
}

// MARK: - Bottom sheet

private struct MapBottomSheet: View {
    let filteredRequests: [OpenRequest]
    @Binding var selectedId: String
    let onSelect: (OpenRequest) -> Void

    private var selected: OpenRequest? {
        filteredRequests.first { $0.id == selectedId }
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 999)
                .fill(Color(acoHex: "3C3228").opacity(0.18))
                .frame(width: 40, height: 5)
                .padding(.top, 10).padding(.bottom, 4)

            if let req = selected {
                NavigationLink(value: req) { SelectedRequestCallout(request: req) }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
            }

            HStack(spacing: 5) {
                Image(systemName: "sparkles").font(.caption).foregroundStyle(Color.acoStudent)
                Text("Ordenado por distancia y afinidad contigo")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(Color.acoInk3)
            }
            .padding(.horizontal, 18).padding(.top, 6)

            ScrollView {
                VStack(spacing: 9) {
                    ForEach(filteredRequests.sorted { $0.matchScore > $1.matchScore }) { req in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedId = req.id }
                            onSelect(req)
                        } label: {
                            RankedRow(request: req, isSelected: req.id == selectedId)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 220)
        }
        .background(Color.acoBg)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0,
                                          bottomTrailingRadius: 0, topTrailingRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
    }
}

// MARK: - Selected callout card

private struct SelectedRequestCallout: View {
    let request: OpenRequest

    var body: some View {
        AcoCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Color.acoStudentSoft).frame(width: 48, height: 48)
                    Image(systemName: request.activityType.symbolName)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.acoStudent)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(request.title)
                            .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.acoInk)
                        if request.isUrgent { BadgeLabel(text: "Urgente", color: .acoUrgent) }
                    }
                    HStack(spacing: 4) {
                        Label(request.neighborhood, systemImage: "mappin.circle.fill")
                            .font(.caption).foregroundStyle(Color.acoInk2)
                        if !request.distance.isEmpty {
                            Text("·").font(.caption).foregroundStyle(Color.acoInk3)
                            Text(request.distance)
                                .font(.caption).fontWeight(.semibold).foregroundStyle(Color.acoInk2)
                        }
                    }
                    Label("\(request.timeWindow.shortLabel) · \(request.duration)", systemImage: "clock")
                        .font(.caption).foregroundStyle(Color.acoInk3)
                }
                Spacer()
                VStack(spacing: 1) {
                    Text("+\(hoursFormatted(request.hours))")
                        .font(.title3).fontWeight(.heavy).foregroundStyle(Color.acoStudent)
                    Text("horas").font(.caption2).fontWeight(.semibold).foregroundStyle(Color.acoInk3)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.title) en \(request.neighborhood)\(request.distance.isEmpty ? "" : ", a \(request.distance)"), \(request.timeWindow.shortLabel), \(hoursFormatted(request.hours)) horas de servicio\(request.isUrgent ? ", urgente" : "")")
        .accessibilityHint("Toca para ver detalles")
    }
}

// MARK: - Ranked row

private struct RankedRow: View {
    let request: OpenRequest
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.acoStudent.opacity(0.12) : Color.acoStudentSoft)
                    .frame(width: 40, height: 40)
                Image(systemName: request.activityType.symbolName)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.acoStudent)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(request.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.acoInk).lineLimit(1)
                    if request.isUrgent {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.acoUrgent)
                            .accessibilityHidden(true)
                    }
                }
                HStack(spacing: 3) {
                    Text(request.neighborhood)
                        .font(.caption).foregroundStyle(Color.acoInk2)
                    if !request.distance.isEmpty {
                        Text("·").font(.caption).foregroundStyle(Color.acoInk3)
                        Text(request.distance)
                            .font(.caption).fontWeight(.medium).foregroundStyle(Color.acoInk2)
                    }
                    Text("·").font(.caption).foregroundStyle(Color.acoInk3)
                    Text(request.timeWindow.shortLabel)
                        .font(.caption).foregroundStyle(Color.acoInk2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(hoursFormatted(request.hours)) h")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.acoStudent)
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.acoStudent)
                        .accessibilityHidden(true)
                    Text("\(request.matchScore)%")
                        .font(.caption2).fontWeight(.bold).foregroundStyle(Color.acoStudent)
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Color.acoStudentSoft).clipShape(.rect(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .frame(minHeight: 64)
        .background(isSelected ? Color.acoStudentSoft : Color.white)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Color.acoStudent : Color(acoHex: "3C3228").opacity(0.05),
                              lineWidth: isSelected ? 1.5 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.title) en \(request.neighborhood)\(request.distance.isEmpty ? "" : ", a \(request.distance)"), \(request.timeWindow.shortLabel), \(hoursFormatted(request.hours)) horas, \(request.matchScore) por ciento de compatibilidad\(request.isUrgent ? ", urgente" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Util

private func hoursFormatted(_ h: Double) -> String {
    h.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", h)
        : String(format: "%.1f", h)
}

#Preview {
    NavigationStack { StudentMapView() }
}
