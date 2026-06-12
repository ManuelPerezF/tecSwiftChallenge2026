import SwiftUI
@preconcurrency import CoreLocation

enum ElderlyDestination: Hashable {
    case visitDetail(APIAssignment)
    case rating(assignmentId: String, studentName: String)
}

struct ElderlyVisitView: View {
    let assignment: APIAssignment

    @State private var currentStatus: AssignmentStatus
    @State private var isConfirming = false
    @State private var confirmError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(assignment: APIAssignment) {
        self.assignment = assignment
        _currentStatus = State(initialValue: assignment.statusEnum)
    }

    private var firstName: String {
        assignment.studentName.components(separatedBy: " ").first ?? assignment.studentName
    }

    private var initials: String {
        assignment.studentName.components(separatedBy: " ")
            .prefix(2).compactMap(\.first).map(String.init).joined()
    }

    private var isOnWay: Bool {
        currentStatus == .enCamino || currentStatus == .esperandoConfirmacion
    }

    private var hasConfirmed: Bool {
        currentStatus == .iniciada || currentStatus == .completada
    }

    private var canConfirm: Bool {
        currentStatus == .esperandoConfirmacion
    }

    /// 3.15: el becario marcó "Terminé" — falta la confirmación del adulto mayor/familia
    private var needsEndConfirmation: Bool {
        currentStatus == .esperandoConfirmacionFin
    }

    /// 3.15: actividades con traslado — el adulto mayor también transmite ubicación
    private var isTransferActivity: Bool {
        assignment.activityTypeEnum == .mandados || assignment.activityTypeEnum == .citas
    }

    @State private var tripTracker = ElderlyTripTracker()

    var body: some View {
        VStack(spacing: 0) {
            studentHeader
            scrollContent
            actionZone
        }
        .background(Color.acoBg.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { updateTripTracking() }
        .onChange(of: currentStatus) { _, _ in updateTripTracking() }
        .onDisappear { tripTracker.stop() }
    }

    /// Durante 'iniciada' en actividades de traslado, transmite la ubicación del adulto mayor.
    private func updateTripTracking() {
        if currentStatus == .iniciada && isTransferActivity {
            tripTracker.start(assignmentId: assignment.id)
        } else {
            tripTracker.stop()
        }
    }

    // MARK: - Header

    private var studentHeader: some View {
        ZStack(alignment: .bottom) {
            Color.acoElderly.ignoresSafeArea(edges: .top)
            VStack(spacing: 10) {
                ZStack {
                    if isOnWay && !hasConfirmed && !reduceMotion {
                        PulseRing(color: .white.opacity(0.45))
                    }
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 86, height: 86)
                    Text(initials)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
                .frame(width: 106, height: 106)

                VStack(spacing: 6) {
                    Text(firstName)
                        .font(.system(size: 44, weight: .heavy))
                        .foregroundStyle(.white)
                        .tracking(-0.5)
                    Text(assignment.studentName)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Becario: \(assignment.studentName)")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 64)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                activityCard

                if isOnWay && !hasConfirmed {
                    onWayStatus
                } else if currentStatus == .approved {
                    scheduledTimeView
                }

                if let confirmError {
                    Label(confirmError, systemImage: "exclamationmark.triangle.fill")
                        .font(.body)
                        .foregroundStyle(Color.acoUrgent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private var activityCard: some View {
        VStack(spacing: 10) {
            Image(systemName: assignment.activityTypeEnum.symbolName)
                .font(.system(size: 42))
                .foregroundStyle(Color.acoElderly)
                .accessibilityHidden(true)
            Text("Te va a ayudar con\n\(assignment.activityTypeEnum.label.lowercased())")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(Color.acoInk)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            if !assignment.details.isEmpty {
                Text(assignment.details)
                    .font(.body)
                    .foregroundStyle(Color.acoInk2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color.acoElderlySoft)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var onWayStatus: some View {
        HStack(spacing: 12) {
            PulsingDot(color: .acoElderly, pulse: true, size: 13)
            Text(canConfirm
                 ? "\(firstName) llegó y quiere iniciar"
                 : "\(firstName) va en camino")
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(Color.acoElderly)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color(acoHex: "FBEDE2"))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var scheduledTimeView: some View {
        VStack(spacing: 4) {
            Text("Llega a las")
                .font(.title3)
                .foregroundStyle(Color.acoInk2)
            Text(scheduledTimeLabel)
                .font(.system(size: 58, weight: .heavy))
                .foregroundStyle(Color.acoInk)
                .tracking(-2)
            Text(ampmLabel)
                .font(.title3)
                .foregroundStyle(Color.acoInk2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var scheduledTimeLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_MX")
        df.dateFormat = "HH:mm"
        return df.string(from: assignment.scheduledDateParsed)
    }

    private var ampmLabel: String {
        let hour = Calendar.current.component(.hour, from: assignment.scheduledDateParsed)
        if hour < 12 { return "de la mañana" }
        if hour < 18 { return "de la tarde" }
        return "de la noche"
    }

    // MARK: - Zona de acción

    private var actionZone: some View {
        VStack(spacing: 14) {
            Rectangle().fill(Color.acoHair).frame(height: 1)

            if needsEndConfirmation {
                confirmEndButton
                Text("\(firstName) dice que la visita terminó.\nConfirma para que cuenten sus horas.")
                    .font(.body)
                    .foregroundStyle(Color.acoInk3)
                    .multilineTextAlignment(.center)
            } else if hasConfirmed {
                arrivedConfirmation
            } else {
                confirmButton
                Text(canConfirm
                     ? "Confirma que \(firstName) ya llegó para iniciar la visita"
                     : "Toca el botón cuando \(firstName) toque la puerta")
                    .font(.body)
                    .foregroundStyle(Color.acoInk3)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .background(Color.acoBg)
    }

    private var confirmButton: some View {
        Button {
            guard canConfirm || currentStatus == .enCamino else { return }
            Task { await confirmArrival() }
        } label: {
            HStack(spacing: 16) {
                if isConfirming {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                    Text("Ya llegó")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(canConfirm ? Color.acoElderly : Color(acoHex: "E0D6C9"))
            .clipShape(.rect(cornerRadius: 20))
            .shadow(color: canConfirm ? Color.acoElderly.opacity(0.4) : .clear, radius: 14, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(isConfirming || !canConfirm)
        .accessibilityLabel("Ya llegó \(firstName)")
        .sensoryFeedback(.impact, trigger: hasConfirmed)
    }

    private var arrivedConfirmation: some View {
        VStack(spacing: 16) {
            Label("¡Llegada confirmada!", systemImage: "checkmark.circle.fill")
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(Color.acoDone)

            NavigationLink(value: ElderlyDestination.rating(
                assignmentId: assignment.id,
                studentName: assignment.studentName
            )) {
                Text("Al terminar, calificar a \(firstName) →")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(Color.acoElderly)
                    .underline()
            }
            .accessibilityLabel("Calificar a \(firstName) al terminar la visita")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var confirmEndButton: some View {
        Button {
            Task { await confirmEnd() }
        } label: {
            HStack(spacing: 16) {
                if isConfirming {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                    Text("Sí, ya terminó")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color.acoElderly)
            .clipShape(.rect(cornerRadius: 20))
            .shadow(color: Color.acoElderly.opacity(0.4), radius: 14, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(isConfirming)
        .accessibilityLabel("Confirmar que la visita terminó")
    }

    // MARK: - API

    private func confirmEnd() async {
        isConfirming = true
        confirmError = nil
        do {
            let updated = try await APIClient.shared.confirmCompletion(assignmentId: assignment.id)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentStatus = updated.statusEnum
            }
            KuidarHaptic.success()
        } catch {
            confirmError = error.localizedDescription
        }
        isConfirming = false
    }

    private func confirmArrival() async {
        isConfirming = true
        confirmError = nil
        do {
            let updated = try await APIClient.shared.confirmarInicio(assignmentId: assignment.id)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentStatus = updated.statusEnum
            }
        } catch {
            confirmError = error.localizedDescription
        }
        isConfirming = false
    }
}

// MARK: - Tracking del adulto mayor durante traslados (3.15)

/// Transmite la ubicación del adulto mayor durante actividades de traslado
/// (mandados, citas médicas) mientras la visita está 'iniciada'.
@MainActor
final class ElderlyTripTracker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var assignmentId: String?
    private var lastSentAt = Date.distantPast

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 25 // metros
    }

    func start(assignmentId: String) {
        guard self.assignmentId == nil else { return }
        self.assignmentId = assignmentId
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        assignmentId = nil
        manager.stopUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude
        let lng = loc.coordinate.longitude
        Task { @MainActor in
            guard let assignmentId, Date().timeIntervalSince(lastSentAt) > 10 else { return }
            lastSentAt = Date()
            try? await APIClient.shared.sendLocation(assignmentId: assignmentId, latitude: lat, longitude: lng)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

// MARK: - Pulse ring

private struct PulseRing: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 4)
            .frame(width: 102, height: 102)
            .scaleEffect(animating ? 1.20 : 1)
            .opacity(animating ? 0 : 0.65)
            .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: animating)
            .onAppear { animating = true }
    }
}

#Preview {
    NavigationStack {
        ElderlyVisitView(assignment: APIAssignment(
            id: "preview", requestId: "r1", studentId: "s1",
            studentName: "Carlos Méndez",
            status: "esperando_confirmacion",
            approvedAt: "", enCaminoAt: nil, inicioSolicitadoAt: nil,
            checkinAt: nil, checkoutAt: nil,
            hoursLogged: 0,
            activityType: "mandados", details: "Ayuda cargando las bolsas del supermercado.",
            scheduledDate: ISO8601DateFormatter().string(from: Date()),
            isUrgent: false, latitude: 19.4, longitude: -99.1,
            elderlyName: "Carmen", neighborhood: "Narvarte",
            address: "Av. Insurgentes 123", familyId: "f1"
        ))
    }
}
