import SwiftUI

private let visitSteps = ["En camino", "Iniciar", "Confirmar", "Terminé"]

struct StudentCommitmentsView: View {
    @State private var assignments: [APIAssignment] = []
    @State private var applications: [APIApplication] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var busyAssignmentId: String?

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if isLoading && assignments.isEmpty && applications.isEmpty {
                ProgressView("Cargando…").tint(Color.acoStudent)
            } else if assignments.isEmpty && pendingApplications.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Mis visitas")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    private var pendingApplications: [APIApplication] {
        applications.filter { $0.status == "pending" }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Color.acoUrgent)
                }

                ForEach(assignments.filter { $0.statusEnum.isActive }) { assignment in
                    AssignmentCard(
                        assignment: assignment,
                        isBusy: busyAssignmentId == assignment.id,
                        onAdvance: { Task { await advance(assignment) } }
                    )
                }

                if !pendingApplications.isEmpty {
                    sectionLabel("POSTULACIONES PENDIENTES")
                    ForEach(pendingApplications) { app in
                        PendingApplicationRow(application: app)
                    }
                }

                let history = assignments.filter { !$0.statusEnum.isActive }
                if !history.isEmpty {
                    sectionLabel("HISTORIAL")
                    ForEach(history) { assignment in
                        AssignmentCard(assignment: assignment, isBusy: false, onAdvance: {})
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Color.acoInk3)
            .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.acoStudentSoft).frame(width: 96, height: 96)
                Image(systemName: "figure.walk")
                    .font(.system(size: 38)).foregroundStyle(Color.acoStudent)
            }
            Text("Sin visitas aún")
                .font(.title3).bold().foregroundStyle(Color.acoInk)
            Text("Explora el mapa y postúlate\na tu primera actividad.")
                .font(.body).foregroundStyle(Color.acoInk3)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let asg = APIClient.shared.fetchMyAssignments()
            async let apps = APIClient.shared.fetchMyApplications()
            let (a, p) = try await (asg, apps)
            assignments = a
            applications = p
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func advance(_ assignment: APIAssignment) async {
        busyAssignmentId = assignment.id
        errorMessage = nil
        do {
            let updated: APIAssignment
            switch assignment.statusEnum {
            case .approved:
                updated = try await APIClient.shared.markEnCamino(assignmentId: assignment.id)
                // Primera ubicación simulada cerca del destino (sin permisos GPS en demo)
                try? await APIClient.shared.sendLocation(
                    assignmentId: assignment.id,
                    latitude: assignment.latitude + 0.008,
                    longitude: assignment.longitude - 0.005
                )
            case .enCamino:
                updated = try await APIClient.shared.markIniciada(assignmentId: assignment.id)
            case .esperandoConfirmacion:
                busyAssignmentId = nil
                return
            case .iniciada:
                updated = try await APIClient.shared.markCompletada(assignmentId: assignment.id)
            default:
                busyAssignmentId = nil
                return
            }
            withAnimation(.easeInOut(duration: 0.22)) {
                if let idx = assignments.firstIndex(where: { $0.id == updated.id }) {
                    assignments[idx] = updated
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        busyAssignmentId = nil
    }
}

// MARK: - Card de visita real

private struct AssignmentCard: View {
    let assignment: APIAssignment
    let isBusy: Bool
    let onAdvance: () -> Void

    private var currentStep: Int {
        switch assignment.statusEnum {
        case .approved:              0
        case .enCamino:              1
        case .esperandoConfirmacion: 2
        case .iniciada:              3
        case .completada:            4
        case .cancelada:             0
        }
    }

    private var isWaitingConfirm: Bool { assignment.statusEnum == .esperandoConfirmacion }

    private var isDone: Bool { assignment.statusEnum == .completada }
    private var isCancelled: Bool { assignment.statusEnum == .cancelada }

    var body: some View {
        AcoCard(padding: 0) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.acoStudentSoft)
                                .frame(width: 46, height: 46)
                            Image(systemName: assignment.activityTypeEnum.symbolName)
                                .font(.system(size: 22))
                                .foregroundStyle(Color.acoStudent)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(assignment.activityTypeEnum.label)
                                .font(.headline)
                                .foregroundStyle(Color.acoInk)
                            Text(assignment.elderlyName)
                                .font(.subheadline)
                                .foregroundStyle(Color.acoInk2)
                        }
                        Spacer()
                        if isCancelled {
                            BadgeLabel(text: "Cancelada", color: .acoUrgent)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.acoStudent)
                            .accessibilityHidden(true)
                        Text("\(assignment.address) · \(assignment.neighborhood)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.acoInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                    .background(Color.acoStudentSoft)
                    .clipShape(.rect(cornerRadius: 10))

                    if !isCancelled {
                        StepProgressBar(steps: visitSteps, currentStep: currentStep)
                    }
                }
                .padding(14)

                if !isCancelled {
                    Rectangle().fill(Color.acoHair).frame(height: 1)
                    actionFooter
                        .padding(14)
                        .background(isDone ? Color(acoHex: "F3F7EC") : Color(acoHex: "FDFAF6"))
                }
            }
        }
    }

    @ViewBuilder
    private var actionFooter: some View {
        if isDone {
            Label("Visita completada · +\(hoursLabel) registrada", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.acoDone)
                .frame(maxWidth: .infinity, alignment: .center)
        } else if isWaitingConfirm {
            Label("Esperando que \(assignment.elderlyName) confirme el inicio", systemImage: "clock.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color(acoHex: "D98E04"))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 8) {
                Button(action: onAdvance) {
                    HStack(spacing: 8) {
                        if isBusy {
                            ProgressView().tint(.white)
                        } else {
                            Label(stepActionLabel, systemImage: stepActionIcon)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.acoStudent)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isBusy)

                if assignment.statusEnum == .enCamino {
                    Text("La familia ve tu ubicación en tiempo real")
                        .font(.caption2)
                        .foregroundStyle(Color.acoInk3)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var hoursLabel: String {
        let h = assignment.hoursLogged
        return h.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f h", h)
            : String(format: "%.2f h", h)
    }

    private var stepActionLabel: String {
        switch assignment.statusEnum {
        case .approved: "Voy en camino"
        case .enCamino: "Llegué · solicitar inicio"
        case .iniciada: "Ya terminé"
        default: "Avanzar"
        }
    }

    private var stepActionIcon: String {
        switch assignment.statusEnum {
        case .approved: "figure.walk"
        case .enCamino: "location.fill"
        case .iniciada: "party.popper"
        default: "arrow.right"
        }
    }
}

// MARK: - Postulación pendiente

private struct PendingApplicationRow: View {
    let application: APIApplication

    var body: some View {
        AcoCard(padding: 13) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(acoHex: "FFF4E0")).frame(width: 38, height: 38)
                    Image(systemName: "clock.fill")
                        .font(.body)
                        .foregroundStyle(Color(acoHex: "D98E04"))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Esperando aprobación")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.acoInk)
                    if !application.message.isEmpty {
                        Text(application.message)
                            .font(.caption).foregroundStyle(Color.acoInk3).lineLimit(1)
                    }
                }
                Spacer()
            }
        }
    }
}

private struct StepProgressBar: View {
    let steps: [String]
    let currentStep: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(index < currentStep ? Color.acoStudent : Color(acoHex: "E7DECF"))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.22), value: currentStep)
                    Text(step)
                        .font(.system(size: 10))
                        .fontWeight(index == currentStep ? .bold : .regular)
                        .foregroundStyle(
                            index < currentStep ? Color.acoStudent
                            : index == currentStep ? Color.acoInk
                            : Color.acoInk3
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    NavigationStack { StudentCommitmentsView() }
}
