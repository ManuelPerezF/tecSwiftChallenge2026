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
    @State private var isLoadingRequests: Bool = false
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
                    isLoading: isLoadingRequests,
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
        isLoadingRequests = true
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
        isLoadingRequests = false
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 5)
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
    let isLoading: Bool
    let onSelect: (OpenRequest) -> Void

    @State private var listAppeared: Bool = false

    private var sorted: [OpenRequest] {
        filteredRequests.sorted { distanceMeters(for: $0) < distanceMeters(for: $1) }
    }

    private func distanceMeters(for request: OpenRequest) -> Double {
        let d = request.distance
        if d.hasSuffix(" km"), let km = Double(d.dropLast(3).trimmingCharacters(in: .whitespaces)) {
            return km * 1_000
        }
        if d.hasSuffix(" m"), let m = Double(d.dropLast(2).trimmingCharacters(in: .whitespaces)) {
            return m
        }
        return .infinity
    }
    private var selected: OpenRequest? {
        filteredRequests.first { $0.id == selectedId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(acoHex: "3C3228").opacity(0.15))
                .frame(width: 36, height: 4)
                .padding(.top, 12).padding(.bottom, 6)

            // Selected callout
            if let req = selected, !isLoading {
                NavigationLink(value: req) { SelectedRequestCallout(request: req) }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Text("Ordenado por distancia")
                .font(.footnote)
                .foregroundStyle(Color.acoInk3)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            // List
            ScrollView {
                VStack(spacing: 8) {
                    if isLoading {
                        ForEach(0..<4, id: \.self) { _ in SkeletonRow() }
                    } else if sorted.isEmpty {
                        EmptyRequestsState()
                    } else {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, req in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                                    selectedId = req.id
                                }
                                onSelect(req)
                            } label: {
                                RankedRow(request: req, isSelected: req.id == selectedId)
                            }
                            .buttonStyle(.plain)
                            .offset(y: listAppeared ? 0 : 28)
                            .opacity(listAppeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.42, dampingFraction: 0.78)
                                .delay(Double(index) * 0.055),
                                value: listAppeared
                            )
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 240)
        }
        .glassEffect(
            .regular,
            in: UnevenRoundedRectangle(
                topLeadingRadius: 26, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 26
            )
        )
        .shadow(color: .black.opacity(0.08), radius: 20, y: -8)
        .onChange(of: isLoading) { _, loading in
            if !loading {
                listAppeared = false
                withAnimation { listAppeared = true }
            }
        }
        .onAppear {
            if !isLoading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation { listAppeared = true }
                }
            }
        }
    }
}

// MARK: - Empty state

private struct EmptyRequestsState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map.circle")
                .font(.system(size: 36))
                .foregroundStyle(Color.acoStudent.opacity(0.4))
                .accessibilityHidden(true)
            Text("Sin solicitudes en esta área")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color.acoInk2)
            Text("Prueba quitando el filtro o regresa más tarde.")
                .font(.caption).foregroundStyle(Color.acoInk3)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Skeleton row

private struct SkeletonRow: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.acoStudentSoft)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.acoStudentSoft)
                    .frame(height: 12).frame(maxWidth: .infinity)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(acoHex: "E8E0D6"))
                    .frame(height: 10).frame(maxWidth: 140, alignment: .leading)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.acoStudentSoft)
                .frame(width: 36, height: 28)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(Color.white.opacity(0.55), in: .rect(cornerRadius: 14))
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

// MARK: - Selected callout card

private struct SelectedRequestCallout: View {
    let request: OpenRequest

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(request.isUrgent ? Color.acoUrgent.opacity(0.12) : Color.acoStudentSoft)
                    .frame(width: 52, height: 52)
                Image(systemName: request.activityType.symbolName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(request.isUrgent ? Color.acoUrgent : Color.acoStudent)
                    .accessibilityHidden(true)
            }

            // Info
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(request.title)
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.acoInk)
                        .lineLimit(1)
                    if request.isUrgent { BadgeLabel(text: "Urgente", color: .acoUrgent) }
                }
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10)).foregroundStyle(Color.acoInk3)
                        .accessibilityHidden(true)
                    Text(request.neighborhood)
                        .font(.caption).foregroundStyle(Color.acoInk2)
                    if !request.distance.isEmpty {
                        Text("·").font(.caption).foregroundStyle(Color.acoInk3)
                        Text(request.distance)
                            .font(.caption).fontWeight(.semibold).foregroundStyle(Color.acoStudent)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 10)).foregroundStyle(Color.acoInk3)
                        .accessibilityHidden(true)
                    Text(request.scheduledDateFormatted)
                        .font(.caption).foregroundStyle(Color.acoInk2)
                    Text("·").font(.caption).foregroundStyle(Color.acoInk3)
                    Text(request.duration)
                        .font(.caption).foregroundStyle(Color.acoInk2)
                }
            }

            Spacer()

            Text("+\(hoursFormatted(request.hours)) h")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.acoStudent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.acoStudentSoft)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(.thinMaterial, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.acoStudent.opacity(0.22), lineWidth: 1.5)
        }
        .shadow(color: Color.acoStudent.opacity(0.06), radius: 10, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.title) en \(request.neighborhood)\(request.distance.isEmpty ? "" : ", a \(request.distance)"), \(request.scheduledDateFormatted), \(hoursFormatted(request.hours)) horas de servicio\(request.isUrgent ? ", urgente" : "")")
        .accessibilityHint("Toca para ver detalles")
    }
}

// MARK: - Ranked row

private struct RankedRow: View {
    let request: OpenRequest
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(isSelected ? Color.acoStudent.opacity(0.13) : Color.acoStudentSoft)
                    .frame(width: 44, height: 44)
                Image(systemName: request.activityType.symbolName)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(isSelected ? Color.acoStudent : Color.acoStudent.opacity(0.75))
                    .accessibilityHidden(true)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(request.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(isSelected ? Color.acoInk : Color.acoInk)
                        .lineLimit(1)
                    if request.isUrgent {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 11))
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
                            .font(.caption).fontWeight(.medium).foregroundStyle(Color.acoStudent)
                    }
                    Text("·").font(.caption).foregroundStyle(Color.acoInk3)
                    Text(request.scheduledDateFormatted)
                        .font(.caption).foregroundStyle(Color.acoInk2)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Text("+\(hoursFormatted(request.hours)) h")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.acoStudent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.acoStudentSoft)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .frame(minHeight: 66)
        .background(
            isSelected
                ? Color.acoStudent.opacity(0.10)
                : Color.white.opacity(0.55),
            in: .rect(cornerRadius: 15)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(
                    isSelected ? Color.acoStudent.opacity(0.40) : Color.white.opacity(0.35),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .shadow(color: isSelected ? Color.acoStudent.opacity(0.06) : .clear, radius: 6, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.title) en \(request.neighborhood)\(request.distance.isEmpty ? "" : ", a \(request.distance)"), \(request.scheduledDateFormatted), \(hoursFormatted(request.hours)) horas\(request.isUrgent ? ", urgente" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Util

private func hoursFormatted(_ h: Double) -> String {
    h.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", h)
        : String(format: "%.1f", h)
}

// MARK: - Shimmer modifier (skeleton loading)

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear,                              location: max(0, phase - 0.25)),
                            .init(color: Color.white.opacity(0.55),           location: phase),
                            .init(color: .clear,                              location: min(1, phase + 0.25)),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

private extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

#Preview {
    NavigationStack { StudentMapView() }
}
