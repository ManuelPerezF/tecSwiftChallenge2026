import SwiftUI
@preconcurrency import CoreLocation

// MARK: - Root del organizador comunitario

enum OrganizerTab: Hashable {
    case events, create
}

struct OrganizerRootView: View {
    let onLogout: () -> Void
    @State private var selectedTab: OrganizerTab = .events

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Eventos", systemImage: "person.3.fill", value: OrganizerTab.events) {
                NavigationStack {
                    CommunityEventsView(isOrganizer: true)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { logoutButton } }
                }
            }
            Tab("Crear evento", systemImage: "square.and.pencil", value: OrganizerTab.create) {
                NavigationStack {
                    OrganizerCreateEventView(onPublished: { selectedTab = .events })
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

// MARK: - Crear evento comunitario

struct OrganizerCreateEventView: View {
    let onPublished: () -> Void

    @State private var selectedActivity: ActivityType = .compania
    @State private var descriptionText = ""
    @State private var scheduledDate: Date = {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }()
    @State private var maxHelpers = 3
    @State private var isLoading = false
    @State private var isPublished = false
    @State private var errorMessage: String?
    @State private var coordinate: CLLocationCoordinate2D?
    private let locationGrabber = EventLocationGrabber()

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            if isPublished {
                publishedConfirmation
            } else {
                form
            }
        }
        .navigationTitle("Nuevo evento")
        .navigationBarTitleDisplayMode(.inline)
        .task { coordinate = await locationGrabber.grab() }
    }

    private var publishedConfirmation: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Color.acoFamilySoft).frame(width: 96, height: 96)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.acoFamily)
                    .accessibilityHidden(true)
            }
            Text("¡Evento publicado!")
                .font(.title2).bold().foregroundStyle(Color.acoInk)
                .padding(.top, 22)
            Text("Los becarios podrán postularse hasta\nllenar los \(maxHelpers) cupos.")
                .font(.body).foregroundStyle(Color.acoInk2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36).padding(.top, 10)
            CTAButton(label: "Ver eventos", tint: .acoFamily) {
                resetForm()
                onPublished()
            }
            .padding(.horizontal, 24).padding(.top, 32)
            Spacer()
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                fieldLabel("Tipo de actividad").padding(.horizontal, 20)
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
                    ForEach(ActivityType.allCases, id: \.self) { act in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedActivity = act }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: act.symbolName)
                                    .font(.system(size: 24))
                                    .foregroundStyle(selectedActivity == act ? Color.acoFamily : Color.acoInk2)
                                    .accessibilityHidden(true)
                                Text(act.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(selectedActivity == act ? Color.acoFamily : Color.acoInk2)
                                    .multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(selectedActivity == act ? Color.acoFamilySoft : Color(acoHex: "FDFBF8"))
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(selectedActivity == act ? Color.acoFamily : Color(acoHex: "3C3228").opacity(0.08),
                                                  lineWidth: selectedActivity == act ? 2 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(act.label)
                        .accessibilityAddTraits(selectedActivity == act ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 20)

                fieldLabel("Descripción del evento").padding(.horizontal, 20).padding(.top, 22)
                TextField("Ej. Jornada de acompañamiento en el parque…", text: $descriptionText, axis: .vertical)
                    .lineLimit(3...)
                    .font(.body).foregroundStyle(Color.acoInk)
                    .padding(14)
                    .background(Color(acoHex: "FDFBF8"))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(acoHex: "3C3228").opacity(0.10), lineWidth: 1) }
                    .padding(.horizontal, 20)

                fieldLabel("¿Cuándo?").padding(.horizontal, 20).padding(.top, 22)
                VStack(spacing: 0) {
                    DatePicker("Día", selection: $scheduledDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact).tint(.acoFamily)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    Rectangle().fill(Color.acoHair).frame(height: 1).padding(.horizontal, 16)
                    DatePicker("Hora", selection: $scheduledDate, in: Date()..., displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact).tint(.acoFamily)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .background(Color(acoHex: "FDFBF8"))
                .clipShape(.rect(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(acoHex: "3C3228").opacity(0.10), lineWidth: 1) }
                .padding(.horizontal, 20)

                fieldLabel("¿Cuántos becarios necesitas?").padding(.horizontal, 20).padding(.top, 22)
                HStack {
                    Stepper(value: $maxHelpers, in: 2...20) {
                        HStack(spacing: 8) {
                            Image(systemName: "graduationcap.fill")
                                .foregroundStyle(Color.acoStudent)
                                .accessibilityHidden(true)
                            Text("\(maxHelpers) becarios")
                                .font(.body).fontWeight(.semibold).foregroundStyle(Color.acoInk)
                        }
                    }
                    .tint(.acoFamily)
                }
                .padding(14)
                .background(Color(acoHex: "FDFBF8"))
                .clipShape(.rect(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(acoHex: "3C3228").opacity(0.10), lineWidth: 1) }
                .padding(.horizontal, 20)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Color.acoUrgent)
                        .padding(.horizontal, 20).padding(.top, 10)
                }

                CTAButton(
                    label: isLoading ? "Publicando…" : "Publicar evento",
                    leadingSymbol: "person.3.fill",
                    tint: .acoFamily,
                    disabled: isLoading
                ) { Task { await publish() } }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption).bold().textCase(.uppercase)
            .tracking(0.4).foregroundStyle(Color.acoFamily)
            .padding(.bottom, 10)
    }

    private func publish() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.createRequest(
                elderlyProfileId: nil,
                activityType: selectedActivity,
                details: descriptionText.isEmpty
                    ? "Evento comunitario: \(selectedActivity.label.lowercased())."
                    : descriptionText,
                scheduledDate: scheduledDate,
                isUrgent: false,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                isCommunityEvent: true,
                maxHelpersRequired: maxHelpers
            )
            withAnimation(.easeInOut(duration: 0.22)) { isPublished = true }
            KuidarHaptic.success()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func resetForm() {
        isPublished = false
        descriptionText = ""
        selectedActivity = .compania
        maxHelpers = 3
        scheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
}

// MARK: - One-shot location helper (evento)

private final class EventLocationGrabber: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func grab() async -> CLLocationCoordinate2D? {
        return await withCheckedContinuation { cont in
            continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            default:
                cont.resume(returning: nil)
                continuation = nil
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last?.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}

#Preview {
    OrganizerRootView(onLogout: {})
}
