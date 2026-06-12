import SwiftUI

// MARK: - Lista de eventos comunitarios
// Usada por el organizador (gestión) y por familias/adultos mayores (registro como asistentes).

struct CommunityEventsView: View {
    /// true cuando la abre el organizador (muestra cupo y postulantes, no botón de asistir)
    let isOrganizer: Bool

    @State private var events: [APIRequest] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if isLoading && events.isEmpty {
                ProgressView("Cargando…").tint(Color.acoFamily)
            } else if events.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Eventos comunitarios")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Color.acoUrgent)
                }

                ForEach(events) { event in
                    NavigationLink(value: event) {
                        EventCard(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(for: APIRequest.self) { event in
            CommunityEventDetailView(event: event, isOrganizer: isOrganizer)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.acoFamilySoft).frame(width: 88, height: 88)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.acoFamily)
                    .accessibilityHidden(true)
            }
            Text("Aún no hay eventos")
                .font(.title3).bold().foregroundStyle(Color.acoInk)
            Text(isOrganizer
                 ? "Crea un evento comunitario para\nconvocar a varios becarios."
                 : "Cuando un organizador publique un evento\ncomunitario aparecerá aquí.")
                .font(.body).foregroundStyle(Color.acoInk3)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            events = try await APIClient.shared.fetchCommunityEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Card de evento

private struct EventCard: View {
    let event: APIRequest

    var body: some View {
        AcoCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: event.activityTypeEnum.symbolName)
                        .font(.title3)
                        .foregroundStyle(Color.acoFamily)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.activityTypeEnum.label)
                            .font(.headline).foregroundStyle(Color.acoInk)
                        Text(event.scheduledDateFormatted)
                            .font(.caption).foregroundStyle(Color.acoInk2)
                    }
                    Spacer()
                    BadgeLabel(
                        text: event.statusEnum == .open ? "Cupo abierto" : "Cupo lleno",
                        color: event.statusEnum == .open ? .acoFamily : .acoInk3
                    )
                }

                if !event.details.isEmpty {
                    Text(event.details)
                        .font(.subheadline).foregroundStyle(Color.acoInk2)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                        .font(.caption)
                        .foregroundStyle(Color.acoStudent)
                        .accessibilityHidden(true)
                    Text(event.helpersLabel)
                        .font(.caption).fontWeight(.semibold).foregroundStyle(Color.acoInk)
                    if !event.neighborhood.isEmpty {
                        Text("· \(event.neighborhood)")
                            .font(.caption).foregroundStyle(Color.acoInk3)
                    }
                }
            }
        }
    }
}

// MARK: - Detalle: cupo + asistentes (+ registro)

struct CommunityEventDetailView: View {
    let event: APIRequest
    let isOrganizer: Bool

    @State private var attendees: [EventAttendee] = []
    @State private var isRegistered = false
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if isOrganizer {
                        NavigationLink {
                            FamilyApplicantsView(request: event)
                        } label: {
                            AcoCard {
                                HStack {
                                    Label("Ver postulantes", systemImage: "person.crop.circle.badge.checkmark")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.acoFamily)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold()).foregroundStyle(Color.acoInk3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    attendeesSection

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Color.acoUrgent)
                    }

                    if !isOrganizer {
                        CTAButton(
                            label: isRegistered ? "¡Asistencia registrada!" : "Asistiré a este evento",
                            leadingSymbol: isRegistered ? "checkmark.circle.fill" : "hand.raised.fill",
                            tint: .acoFamily,
                            disabled: isRegistered || isBusy
                        ) { Task { await register() } }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Evento")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAttendees() }
        .refreshable { await loadAttendees() }
    }

    private var header: some View {
        AcoCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: event.activityTypeEnum.symbolName)
                        .font(.title2)
                        .foregroundStyle(Color.acoFamily)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.activityTypeEnum.label)
                            .font(.title3).bold().foregroundStyle(Color.acoInk)
                        Text(event.scheduledDateFormatted)
                            .font(.subheadline).foregroundStyle(Color.acoInk2)
                    }
                    Spacer()
                }

                if !event.details.isEmpty {
                    Text(event.details)
                        .font(.body).foregroundStyle(Color.acoInk2)
                }

                HStack(spacing: 14) {
                    statChip(symbol: "graduationcap.fill", text: event.helpersLabel)
                    statChip(symbol: "person.2.fill", text: "\(attendees.count) asistentes")
                }
            }
        }
    }

    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Asistentes registrados")
                .font(.caption).bold().textCase(.uppercase)
                .tracking(0.4).foregroundStyle(Color.acoInk3)

            if attendees.isEmpty {
                Text("Nadie se ha registrado todavía.")
                    .font(.subheadline).foregroundStyle(Color.acoInk3)
            } else {
                ForEach(attendees) { attendee in
                    HStack(spacing: 12) {
                        AvatarView(
                            name: attendee.name,
                            tint: attendee.role == "elderly" ? .acoElderly : .acoFamily,
                            size: 36
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(attendee.name)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color.acoInk)
                            Text(attendee.role == "elderly" ? "Adulto mayor" : "Familia")
                                .font(.caption).foregroundStyle(Color.acoInk2)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(acoHex: "FDFBF8"))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
    }

    private func statChip(symbol: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(Color.acoInk2)
                .accessibilityHidden(true)
            Text(text).font(.caption).fontWeight(.semibold).foregroundStyle(Color.acoInk)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(acoHex: "F8F5F1"))
        .clipShape(.capsule)
    }

    // MARK: - Actions

    private func loadAttendees() async {
        do {
            attendees = try await APIClient.shared.fetchAttendees(requestId: event.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func register() async {
        isBusy = true
        errorMessage = nil
        do {
            try await APIClient.shared.registerAttendee(requestId: event.id)
            withAnimation(.easeInOut(duration: 0.22)) { isRegistered = true }
            KuidarHaptic.success()
            await loadAttendees()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}

#Preview {
    NavigationStack { CommunityEventsView(isOrganizer: false) }
}
