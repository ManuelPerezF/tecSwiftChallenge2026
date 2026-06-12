import SwiftUI
@preconcurrency import CoreLocation

// MARK: - Root del organizador comunitario

enum OrganizerTab: Hashable {
    case events, students
}

struct OrganizerRootView: View {
    let onLogout: () -> Void
    @State private var selectedTab: OrganizerTab = .events
    @State private var showCreateEvent = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Eventos", systemImage: "person.3.fill", value: OrganizerTab.events) {
                NavigationStack {
                    CommunityEventsView(isOrganizer: true)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) { logoutButton }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showCreateEvent = true
                                } label: {
                                    Image(systemName: "plus")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.acoFamily)
                                }
                                .accessibilityLabel("Crear evento")
                            }
                        }
                        .navigationDestination(isPresented: $showCreateEvent) {
                            OrganizerCreateEventView(onPublished: { showCreateEvent = false })
                        }
                }
            }
            Tab("Becarios", systemImage: "graduationcap.fill", value: OrganizerTab.students) {
                NavigationStack {
                    OrganizerStudentsView()
                        .toolbar { ToolbarItem(placement: .topBarLeading) { logoutButton } }
                }
            }
        }
        .tint(.acoFamily)
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

// MARK: - Crear evento comunitario

struct OrganizerCreateEventView: View {
    let onPublished: () -> Void

    // Catálogo de tipos (BD) + opción "Otro"
    @State private var catalog = EventTypeCatalog.shared
    @State private var selectedSlug: String?
    @State private var isOtherSelected = false
    @State private var customLabel = ""
    @State private var customIcon = "star.fill"

    @State private var descriptionText = ""
    @State private var scheduledDate: Date = {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }()
    @State private var maxHelpers = 3
    @State private var maxElderly = 10
    @State private var isLoading = false
    @State private var isPublished = false
    @State private var errorMessage: String?
    @State private var coordinate: CLLocationCoordinate2D?
    private let locationGrabber = EventLocationGrabber()

    /// Subset curado de SF Symbols para tipos custom.
    private let iconOptions = [
        "star.fill", "heart.fill", "theatermasks.fill", "music.note",
        "paintpalette.fill", "book.fill", "leaf.fill", "fork.knife",
        "figure.walk", "hammer.fill", "gamecontroller.fill", "camera.fill",
    ]

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
        .task {
            await catalog.loadIfNeeded()
            if selectedSlug == nil { selectedSlug = catalog.types.first?.slug }
            coordinate = await locationGrabber.grab()
        }
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
                fieldLabel("Tipo de evento").padding(.horizontal, 20)
                typePicker

                if isOtherSelected {
                    customTypeFields
                }

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

                fieldLabel("Cupos").padding(.horizontal, 20).padding(.top, 22)
                VStack(spacing: 0) {
                    Stepper(value: $maxHelpers, in: 1...20) {
                        HStack(spacing: 8) {
                            Image(systemName: "graduationcap.fill")
                                .foregroundStyle(Color.acoStudent)
                                .accessibilityHidden(true)
                            Text("\(maxHelpers) becario\(maxHelpers == 1 ? "" : "s")")
                                .font(.body).fontWeight(.semibold).foregroundStyle(Color.acoInk)
                        }
                    }
                    .tint(.acoFamily)
                    .padding(.horizontal, 16).padding(.vertical, 12)

                    Rectangle().fill(Color.acoHair).frame(height: 1).padding(.horizontal, 16)

                    Stepper(value: $maxElderly, in: 1...100) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.stand")
                                .foregroundStyle(Color.acoElderly)
                                .accessibilityHidden(true)
                            Text("\(maxElderly) adulto\(maxElderly == 1 ? "" : "s") mayor\(maxElderly == 1 ? "" : "es")")
                                .font(.body).fontWeight(.semibold).foregroundStyle(Color.acoInk)
                        }
                    }
                    .tint(.acoFamily)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
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
                    disabled: isLoading || (isOtherSelected && customLabel.trimmingCharacters(in: .whitespaces).count < 2)
                ) { Task { await publish() } }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Picker de tipo (catálogo BD + "Otro")

    private var typePicker: some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
            ForEach(catalog.types) { type in
                typeCell(
                    label: type.label,
                    icon: type.icon,
                    isSelected: !isOtherSelected && selectedSlug == type.slug
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedSlug = type.slug
                        isOtherSelected = false
                    }
                }
            }
            // Opción "Otro" siempre al final
            typeCell(label: "Otro", icon: "plus.circle.fill", isSelected: isOtherSelected) {
                withAnimation(.easeInOut(duration: 0.15)) { isOtherSelected = true }
            }
        }
        .padding(.horizontal, 20)
    }

    private func typeCell(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.acoFamily : Color.acoInk2)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.acoFamily : Color.acoInk2)
                    .multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(isSelected ? Color.acoFamilySoft : Color(acoHex: "FDFBF8"))
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.acoFamily : Color(acoHex: "3C3228").opacity(0.08),
                                  lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var customTypeFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Nombre del nuevo tipo (ej. Club de lectura)", text: $customLabel)
                .font(.body).foregroundStyle(Color.acoInk)
                .padding(14)
                .background(Color(acoHex: "FDFBF8"))
                .clipShape(.rect(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.acoFamily.opacity(0.4), lineWidth: 1) }

            Text("Elige un icono")
                .font(.caption).fontWeight(.semibold).foregroundStyle(Color.acoInk2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) { customIcon = icon }
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundStyle(customIcon == icon ? Color.acoFamily : Color.acoInk3)
                                .frame(width: 46, height: 46)
                                .background(customIcon == icon ? Color.acoFamilySoft : Color(acoHex: "FDFBF8"))
                                .clipShape(.rect(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(customIcon == icon ? Color.acoFamily : Color.acoHair,
                                                      lineWidth: customIcon == icon ? 2 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Icono \(icon)")
                        .accessibilityAddTraits(customIcon == icon ? .isSelected : [])
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption).bold().textCase(.uppercase)
            .tracking(0.4).foregroundStyle(Color.acoFamily)
            .padding(.bottom, 10)
    }

    // MARK: - Publicar

    private func publish() async {
        isLoading = true
        errorMessage = nil
        do {
            // Si es "Otro": primero crear el tipo custom en el catálogo
            var slug = selectedSlug ?? "compania"
            var label = catalog.label(for: slug)
            if isOtherSelected {
                let created = try await APIClient.shared.createEventType(
                    label: customLabel.trimmingCharacters(in: .whitespaces),
                    icon: customIcon
                )
                catalog.register(created)
                slug = created.slug
                label = created.label
            }

            _ = try await APIClient.shared.createCommunityEvent(
                activityTypeSlug: slug,
                details: descriptionText.isEmpty
                    ? "Evento comunitario: \(label.lowercased())."
                    : descriptionText,
                scheduledDate: scheduledDate,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                maxHelpersRequired: maxHelpers,
                maxElderlyAttendees: maxElderly
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
        customLabel = ""
        customIcon = "star.fill"
        isOtherSelected = false
        maxHelpers = 3
        maxElderly = 10
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
