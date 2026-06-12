import SwiftUI
import MapKit

// MARK: - Postulantes de una solicitud

struct FamilyApplicantsView: View {
    let request: APIRequest

    @State private var applicants: [APIApplication] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var busyId: String?
    @State private var approvedAssignmentId: String?

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if isLoading && applicants.isEmpty {
                ProgressView("Cargando…").tint(Color.acoFamily)
            } else if approvedAssignmentId != nil {
                approvedConfirmation
            } else if applicants.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Postulantes")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private var pending: [APIApplication] {
        applicants.filter { $0.status == "pending" }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                requestSummary

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Color.acoUrgent)
                }

                ForEach(pending) { applicant in
                    ApplicantCard(
                        applicant: applicant,
                        isBusy: busyId == applicant.id,
                        onApprove: { Task { await approve(applicant) } },
                        onReject: { Task { await reject(applicant) } }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    private var requestSummary: some View {
        HStack(spacing: 10) {
            Text(request.activityTypeEnum.emoji).font(.title3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(request.activityTypeEnum.label)
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.acoInk)
                Text("\(request.elderlyName) · \(request.scheduledDateFormatted)")
                    .font(.caption).foregroundStyle(Color.acoInk2)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.acoFamilySoft)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.acoFamilySoft).frame(width: 88, height: 88)
                Text("📭").font(.system(size: 38)).accessibilityHidden(true)
            }
            Text("Aún no hay postulantes")
                .font(.title3).bold().foregroundStyle(Color.acoInk)
            Text("Los becarios cercanos verán tu solicitud\nen su mapa y podrán postularse.")
                .font(.body).foregroundStyle(Color.acoInk3)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private var approvedConfirmation: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.acoFamilySoft).frame(width: 96, height: 96)
                Text("🤝").font(.system(size: 44)).accessibilityHidden(true)
            }
            Text("¡Becario aprobado!")
                .font(.title2).bold().foregroundStyle(Color.acoInk)
            Text("Cuando vaya en camino podrás\nseguir su ubicación en el mapa.")
                .font(.body).foregroundStyle(Color.acoInk2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            applicants = try await APIClient.shared.fetchApplicants(requestId: request.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func approve(_ applicant: APIApplication) async {
        busyId = applicant.id
        errorMessage = nil
        do {
            let result = try await APIClient.shared.approveApplication(id: applicant.id)
            withAnimation(.easeInOut(duration: 0.22)) {
                approvedAssignmentId = result["assignmentId"]
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        busyId = nil
    }

    private func reject(_ applicant: APIApplication) async {
        busyId = applicant.id
        errorMessage = nil
        do {
            try await APIClient.shared.rejectApplication(id: applicant.id)
            withAnimation(.easeInOut(duration: 0.22)) {
                applicants.removeAll { $0.id == applicant.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        busyId = nil
    }
}

// MARK: - Card de postulante

private struct ApplicantCard: View {
    let applicant: APIApplication
    let isBusy: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        AcoCard(padding: 0) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        AvatarView(name: applicant.studentName, tint: .acoStudent, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(applicant.studentName)
                                .font(.headline).foregroundStyle(Color.acoInk)
                            Text("\(applicant.universityName)\(applicant.career.isEmpty ? "" : " · \(applicant.career)")")
                                .font(.caption).foregroundStyle(Color.acoInk2)
                        }
                        Spacer()
                    }

                    HStack(spacing: 14) {
                        statBadge(emoji: "⏱️", text: hoursText)
                        statBadge(emoji: "⭐️", text: ratingText)
                    }

                    if !applicant.message.isEmpty {
                        Text("\u{201C}\(applicant.message)\u{201D}")
                            .font(.subheadline).foregroundStyle(Color.acoInk2)
                            .lineLimit(2)
                    }
                }
                .padding(14)

                Rectangle().fill(Color.acoHair).frame(height: 1)

                HStack(spacing: 10) {
                    Button(action: onReject) {
                        Text("Rechazar")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.acoInk2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(acoHex: "F0EBE3"))
                            .clipShape(.rect(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)

                    Button(action: onApprove) {
                        HStack(spacing: 6) {
                            if isBusy {
                                ProgressView().tint(.white)
                            } else {
                                Text("Aprobar").fontWeight(.bold)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.acoFamily)
                        .clipShape(.rect(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                }
                .padding(12)
            }
        }
    }

    private var hoursText: String {
        let h = applicant.totalHours
        return h.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f h servicio", h)
            : String(format: "%.1f h servicio", h)
    }

    private var ratingText: String {
        applicant.averageRating > 0
            ? String(format: "%.1f", applicant.averageRating)
            : "Nuevo"
    }

    private func statBadge(emoji: String, text: String) -> some View {
        HStack(spacing: 5) {
            Text(emoji).font(.caption).accessibilityHidden(true)
            Text(text).font(.caption).fontWeight(.semibold).foregroundStyle(Color.acoInk)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(acoHex: "F8F5F1"))
        .clipShape(.capsule)
    }
}

// MARK: - Visita en vivo (mapa + estado + calificación)

struct FamilyLiveVisitView: View {
    let assignment: APIAssignment

    @AppStorage("aco_authToken") private var authToken: String = ""

    @State private var current: APIAssignment
    @State private var studentLocation: CLLocationCoordinate2D?
    @State private var position: MapCameraPosition
    @State private var ws = WebSocketClient()

    // Rating
    @State private var stars = 0
    @State private var comment = ""
    @State private var ratingSent = false
    @State private var errorMessage: String?

    init(assignment: APIAssignment) {
        self.assignment = assignment
        _current = State(initialValue: assignment)
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: assignment.latitude, longitude: assignment.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )))
    }

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statusHeader

                    if current.statusEnum == .enCamino || current.statusEnum == .iniciada {
                        liveMap
                    }

                    if current.statusEnum == .completada {
                        completedSection
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Color.acoUrgent)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Visita")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startLive() }
        .onDisappear { ws.disconnect() }
    }

    // MARK: - Live

    private func startLive() {
        ws.onLocation = { broadcast in
            guard broadcast.assignmentId == current.id, let student = broadcast.student else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                studentLocation = CLLocationCoordinate2D(latitude: student.lat, longitude: student.lng)
            }
        }
        ws.onStatus = { status in
            guard status.assignmentId == current.id else { return }
            Task { await refresh() }
        }
        ws.connect(token: authToken)
        ws.subscribe(assignmentId: current.id)
    }

    private func refresh() async {
        if let updated = try? await APIClient.shared.fetchFamilyAssignments()
            .first(where: { $0.id == current.id }) {
            withAnimation(.easeInOut(duration: 0.22)) { current = updated }
        }
    }

    // MARK: - Secciones

    private var statusHeader: some View {
        AcoCard {
            HStack(spacing: 12) {
                AvatarView(name: current.studentName, tint: .acoStudent, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(current.studentName)
                        .font(.headline).foregroundStyle(Color.acoInk)
                    Text("\(current.activityTypeEnum.emoji) \(current.activityTypeEnum.label) para \(current.elderlyName)")
                        .font(.caption).foregroundStyle(Color.acoInk2)
                }
                Spacer()
                BadgeLabel(text: current.statusEnum.label, color: statusColor)
            }
        }
    }

    private var statusColor: Color {
        switch current.statusEnum {
        case .approved:   .acoFamily
        case .enCamino:   Color(acoHex: "D98E04")
        case .iniciada:   .acoStudent
        case .completada: .acoDone
        case .cancelada:  .acoUrgent
        }
    }

    private var liveMap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Map(position: $position) {
                Annotation(current.elderlyName, coordinate: CLLocationCoordinate2D(
                    latitude: current.latitude, longitude: current.longitude
                )) {
                    mapPin(emoji: "🏠", color: .acoElderly)
                }
                if let studentLocation {
                    Annotation(current.studentName, coordinate: studentLocation) {
                        mapPin(emoji: "🎓", color: .acoStudent)
                    }
                }
            }
            .frame(height: 320)
            .clipShape(.rect(cornerRadius: 18))

            HStack(spacing: 6) {
                Circle().fill(ws.isConnected ? Color.acoDone : Color.acoInk3).frame(width: 7, height: 7)
                Text(ws.isConnected
                     ? (studentLocation == nil ? "Esperando ubicación del becario…" : "Ubicación en tiempo real")
                     : "Conectando…")
                    .font(.caption).foregroundStyle(Color.acoInk3)
            }
        }
    }

    private func mapPin(emoji: String, color: Color) -> some View {
        ZStack {
            Circle().fill(.white).frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
            Circle().strokeBorder(color, lineWidth: 2.5).frame(width: 40, height: 40)
            Text(emoji).font(.system(size: 19))
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        AcoCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Visita completada · \(String(format: "%.2f", current.hoursLogged)) h", systemImage: "checkmark.circle.fill")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(Color.acoDone)

                if ratingSent {
                    Text("¡Gracias por calificar a \(current.studentName)!")
                        .font(.subheadline).foregroundStyle(Color.acoInk2)
                } else {
                    Text("¿Cómo le fue a \(current.elderlyName)?")
                        .font(.headline).foregroundStyle(Color.acoInk)

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.easeInOut(duration: 0.12)) { stars = star }
                            } label: {
                                Image(systemName: star <= stars ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(star <= stars ? Color(acoHex: "F2B33D") : Color.acoInk3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(star) estrellas")
                        }
                    }

                    TextField("Comentario (opcional)", text: $comment, axis: .vertical)
                        .lineLimit(2...)
                        .font(.subheadline)
                        .padding(10)
                        .background(Color(acoHex: "F8F5F1"))
                        .clipShape(.rect(cornerRadius: 10))

                    CTAButton(label: "Enviar calificación", tint: .acoFamily, disabled: stars == 0) {
                        Task { await sendRating() }
                    }
                }
            }
        }
    }

    private func sendRating() async {
        errorMessage = nil
        do {
            _ = try await APIClient.shared.submitRating(
                assignmentId: current.id,
                stars: stars,
                tags: [],
                comment: comment
            )
            withAnimation(.easeInOut(duration: 0.22)) { ratingSent = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
