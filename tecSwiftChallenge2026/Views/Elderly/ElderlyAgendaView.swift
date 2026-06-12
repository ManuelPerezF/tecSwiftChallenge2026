import SwiftUI
import MapKit

// MARK: - Agenda del adulto mayor (pantalla 1 de 2)

struct ElderlyAgendaView: View {
    var onGoToFamily: () -> Void = {}

    @AppStorage("aco_joinedFamily") private var joinedFamily: Bool = false
    @AppStorage("aco_userName") private var userName: String = ""

    @State private var assignments: [APIAssignment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var confirmingId: String?
    // confirmingId kept for confirmStartBanner only

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if !joinedFamily {
                notLinkedState
            } else if isLoading && assignments.isEmpty {
                ProgressView("Cargando…").tint(Color.acoElderly)
            } else if upcoming.isEmpty {
                emptyState
            } else {
                agenda
            }
        }
        .navigationTitle("Mis visitas")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if joinedFamily { await load() }
            else { await refreshJoinStatus() }
        }
        .refreshable {
            if joinedFamily { await load() }
            else { await refreshJoinStatus() }
        }
    }

    private var notLinkedState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.acoElderlySoft).frame(width: 110, height: 110)
                Text("🔗").font(.system(size: 48)).accessibilityHidden(true)
            }
            Text("Aún no estás vinculado")
                .font(.title2).bold().foregroundStyle(Color.acoInk)
            Text("Ve a la pestaña **Mi familia** e ingresa el código que te compartió tu familiar.")
                .font(.title3).foregroundStyle(Color.acoInk3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            CTAButton(label: "Ir a Mi familia", tint: .acoElderly) {
                onGoToFamily()
            }
            .padding(.horizontal, 40)
        }
    }

    private func refreshJoinStatus() async {
        do {
            _ = try await APIClient.shared.fetchMyFamily()
            joinedFamily = true
            await load()
        } catch {
            joinedFamily = false
        }
    }

    private var upcoming: [APIAssignment] {
        assignments.filter { $0.statusEnum.isActive }
    }

    private var activeVisit: APIAssignment? {
        assignments.first {
            $0.statusEnum == .enCamino
                || $0.statusEnum == .esperandoConfirmacion
                || $0.statusEnum == .iniciada
        }
    }

    private var pendingConfirmation: APIAssignment? {
        assignments.first { $0.statusEnum == .esperandoConfirmacion }
    }

    // MARK: - Agenda

    private var agenda: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let pending = pendingConfirmation {
                    confirmStartBanner(pending)
                }

                if let active = activeVisit {
                    NavigationLink(value: active) {
                        activeVisitBanner(active)
                    }
                    .buttonStyle(.plain)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.body).foregroundStyle(Color.acoUrgent)
                }

                ForEach(upcoming) { visit in
                    NavigationLink(value: ElderlyDestination.visitDetail(visit)) {
                        ElderlyVisitCard(visit: visit)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
    }

    private func activeVisitBanner(_ visit: APIAssignment) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.2)).frame(width: 52, height: 52)
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(visit.statusEnum == .esperandoConfirmacion
                     ? "\(visit.studentName) quiere iniciar la visita"
                     : visit.statusEnum == .enCamino
                     ? "\(visit.studentName) viene en camino"
                     : "\(visit.studentName) está contigo")
                    .font(.title3).fontWeight(.bold).foregroundStyle(.white)
                Text("Toca para ver el mapa")
                    .font(.body).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.body.bold()).foregroundStyle(.white.opacity(0.7))
        }
        .padding(18)
        .background(Color.acoElderly)
        .clipShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el mapa en vivo")
    }

    private func confirmStartBanner(_ visit: APIAssignment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(visit.studentName) llegó y quiere iniciar", systemImage: "hand.wave.fill")
                .font(.title3).fontWeight(.bold).foregroundStyle(Color.acoInk)
            Text("Confirma para empezar a contar las horas de servicio.")
                .font(.body).foregroundStyle(Color.acoInk2)
            Button {
                Task { await confirmStart(visit) }
            } label: {
                HStack {
                    if confirmingId == visit.id {
                        ProgressView().tint(.white)
                    } else {
                        Label("Confirmar inicio", systemImage: "checkmark.circle.fill")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.acoElderly)
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(confirmingId == visit.id)
        }
        .padding(18)
        .background(Color.acoElderlySoft)
        .clipShape(.rect(cornerRadius: 20))
    }

    private func confirmStart(_ visit: APIAssignment) async {
        confirmingId = visit.id
        errorMessage = nil
        do {
            let updated = try await APIClient.shared.confirmarInicio(assignmentId: visit.id)
            withAnimation(.easeInOut(duration: 0.22)) {
                if let idx = assignments.firstIndex(where: { $0.id == updated.id }) {
                    assignments[idx] = updated
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        confirmingId = nil
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.acoElderlySoft).frame(width: 110, height: 110)
                Text("🗓️").font(.system(size: 48)).accessibilityHidden(true)
            }
            Text("Sin visitas programadas")
                .font(.title2).bold().foregroundStyle(Color.acoInk)
            Text("Cuando tu familia agende una visita\naparecerá aquí.")
                .font(.title3).foregroundStyle(Color.acoInk3)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            assignments = try await APIClient.shared.fetchElderlyAssignments()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Card de visita (tipografía grande)

private struct ElderlyVisitCard: View {
    let visit: APIAssignment
    var isConfirming: Bool = false
    var onConfirmStart: (() -> Void)?

    var body: some View {
        AcoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.acoElderlySoft)
                            .frame(width: 56, height: 56)
                        Image(systemName: visit.activityTypeEnum.symbolName)
                            .font(.system(size: 26))
                            .foregroundStyle(Color.acoElderly)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(visit.activityTypeEnum.label)
                            .font(.title3).fontWeight(.bold).foregroundStyle(Color.acoInk)
                        Text(visit.studentName)
                            .font(.body).foregroundStyle(Color.acoInk2)
                    }
                }

                Label(scheduledLabel, systemImage: "calendar")
                    .font(.body).foregroundStyle(Color.acoInk2)

                if let onConfirmStart {
                    Button(action: onConfirmStart) {
                        HStack {
                            if isConfirming {
                                ProgressView().tint(.white)
                            } else {
                                Label("Confirmar inicio", systemImage: "checkmark.circle.fill")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.acoElderly)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isConfirming)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(visit.activityTypeEnum.label) con \(visit.studentName), \(scheduledLabel)")
    }

    private var scheduledLabel: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        guard let date = iso.date(from: visit.scheduledDate) else { return visit.scheduledDate }
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_MX")
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            df.dateFormat = "'Hoy a las' HH:mm"
        } else if cal.isDateInTomorrow(date) {
            df.dateFormat = "'Mañana a las' HH:mm"
        } else {
            df.dateFormat = "EEEE d 'de' MMMM, HH:mm"
        }
        return df.string(from: date)
    }
}

// MARK: - Mapa en vivo (pantalla 2 de 2)

struct ElderlyLiveMapView: View {
    let assignment: APIAssignment

    @AppStorage("aco_authToken") private var authToken: String = ""

    @State private var studentLocation: CLLocationCoordinate2D?
    @State private var position: MapCameraPosition
    @State private var ws = WebSocketClient()
    @State private var status: AssignmentStatus
    @State private var isConfirming = false

    init(assignment: APIAssignment) {
        self.assignment = assignment
        _status = State(initialValue: assignment.statusEnum)
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: assignment.latitude, longitude: assignment.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )))
    }

    var body: some View {
        VStack(spacing: 0) {
            statusBanner

            Map(position: $position) {
                Annotation("Tu casa", coordinate: CLLocationCoordinate2D(
                    latitude: assignment.latitude, longitude: assignment.longitude
                )) {
                    mapPin(symbol: "house.fill", color: .acoElderly)
                }
                if let studentLocation {
                    Annotation(assignment.studentName, coordinate: studentLocation) {
                        mapPin(symbol: "graduationcap.fill", color: .acoStudent)
                    }
                }
            }
        }
        .background(Color.acoBg)
        .navigationTitle(assignment.studentName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startLive() }
        .onDisappear { ws.disconnect() }
    }

    private var statusBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(Color.acoElderly)
                    .accessibilityHidden(true)
                Text(statusMessage)
                    .font(.title3).fontWeight(.bold).foregroundStyle(Color.acoInk)
                Spacer()
            }

            if status == .esperandoConfirmacion {
                Button {
                    Task { await confirmStart() }
                } label: {
                    HStack {
                        if isConfirming {
                            ProgressView().tint(.white)
                        } else {
                            Label("Confirmar inicio", systemImage: "checkmark.circle.fill")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.acoElderly)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isConfirming)
            }
        }
        .padding(16)
        .background(Color.acoElderlySoft)
    }

    private var statusIcon: String {
        switch status {
        case .iniciada: "hands.and.sparkles.fill"
        case .esperandoConfirmacion: "hand.wave.fill"
        default: "figure.walk"
        }
    }

    private var statusMessage: String {
        switch status {
        case .iniciada: "\(assignment.studentName) está contigo"
        case .esperandoConfirmacion: "\(assignment.studentName) quiere iniciar la visita"
        default: "\(assignment.studentName) viene en camino"
        }
    }

    private func confirmStart() async {
        isConfirming = true
        do {
            let updated = try await APIClient.shared.confirmarInicio(assignmentId: assignment.id)
            withAnimation(.easeInOut(duration: 0.22)) { status = updated.statusEnum }
        } catch { /* silencioso en mapa; agenda muestra errores */ }
        isConfirming = false
    }

    private func mapPin(symbol: String, color: Color) -> some View {
        ZStack {
            Circle().fill(.white).frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
            Circle().strokeBorder(color, lineWidth: 3).frame(width: 48, height: 48)
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(color)
        }
    }

    private func startLive() {
        ws.onLocation = { broadcast in
            guard broadcast.assignmentId == assignment.id, let student = broadcast.student else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                studentLocation = CLLocationCoordinate2D(latitude: student.lat, longitude: student.lng)
            }
        }
        ws.onStatus = { update in
            guard update.assignmentId == assignment.id,
                  let newStatus = AssignmentStatus(rawValue: update.status) else { return }
            withAnimation(.easeInOut(duration: 0.22)) { status = newStatus }
        }
        ws.connect(token: authToken)
        ws.subscribe(assignmentId: assignment.id)
    }
}
