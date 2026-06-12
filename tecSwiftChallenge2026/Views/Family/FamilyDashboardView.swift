import SwiftUI

struct FamilyDashboardView: View {
    let onAddTapped: () -> Void

    @State private var requests: [APIRequest] = []
    @State private var assignments: [APIAssignment] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if isLoading && requests.isEmpty {
                ProgressView("Cargando…")
                    .tint(Color.acoFamily)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage, requests.isEmpty {
                serverError(err)
            } else if requests.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .acoScreenBackground()
        .navigationTitle("Mis solicitudes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddTapped) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3).foregroundStyle(Color.acoFamily)
                }
                .accessibilityLabel("Nueva solicitud")
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let reqs = APIClient.shared.fetchFamilyRequests()
            async let asgs = APIClient.shared.fetchFamilyAssignments()
            let (r, a) = try await (reqs, asgs)
            requests = r
            assignments = a
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func assignment(for request: APIRequest) -> APIAssignment? {
        assignments.first { $0.requestId == request.id && $0.statusEnum != .cancelada }
    }

    // MARK: - Subviews

    private var list: some View {
        List {
            ForEach(requests) { req in
                if let asg = assignment(for: req) {
                    NavigationLink(value: asg) {
                        LiveRequestRow(request: req, assignment: asg)
                    }
                } else if req.statusEnum == .open {
                    NavigationLink(value: req) {
                        LiveRequestRow(request: req, assignment: nil)
                    }
                } else {
                    LiveRequestRow(request: req, assignment: nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        AcoEmptyState(
            symbol: "heart.text.clipboard",
            title: "Sin solicitudes aún",
            message: "Publica tu primera solicitud para conectar con un becario.",
            tint: .acoFamily,
            actionLabel: "Publicar solicitud",
            action: onAddTapped
        )
    }

    private func serverError(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44)).foregroundStyle(Color.acoInk3)
            Text("Sin conexión al servidor")
                .font(.headline).foregroundStyle(Color.acoInk)
            Text(message)
                .font(.caption).foregroundStyle(Color.acoInk3)
                .multilineTextAlignment(.center)
            Button("Reintentar") { Task { await load() } }
                .font(.subheadline.bold()).foregroundStyle(Color.acoFamily)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Fila de solicitud

private struct LiveRequestRow: View {
    let request: APIRequest
    let assignment: APIAssignment?

    var body: some View {
        VStack(alignment: .leading, spacing: AcoSpacing.xs) {
            HStack(spacing: 12) {
                Image(systemName: request.activityTypeEnum.symbolName)
                    .font(.title3)
                    .foregroundStyle(Color.acoFamily)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(request.activityTypeEnum.label)
                            .font(.headline)
                            .foregroundStyle(Color.acoInk)
                        if request.isUrgent { BadgeLabel(text: "Urgente", color: .acoUrgent) }
                    }
                    if request.elderlyName != "Tu familiar" {
                        Text(request.elderlyName)
                            .font(.subheadline)
                            .foregroundStyle(Color.acoInk2)
                    }
                }
            }

            Label(request.scheduledDateFormatted, systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(Color.acoInk2)

            if let assignment {
                Label("\(assignment.studentName) · \(assignment.statusEnum.label)", systemImage: "graduationcap")
                    .font(.subheadline)
                    .foregroundStyle(Color.acoStudent)
            } else if request.statusEnum == .open {
                Text("Ver postulantes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.acoFamily)
            }

            StatusRow(status: request.statusEnum, eta: nil)

            if !request.details.isEmpty,
               request.details != "Ayuda con \(request.activityTypeEnum.label.lowercased())." {
                Text(request.details)
                    .font(.caption)
                    .foregroundStyle(Color.acoInk3)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.activityTypeEnum.label), \(request.statusEnum.label), \(request.scheduledDateFormatted)")
    }
}

#Preview {
    NavigationStack {
        FamilyDashboardView(onAddTapped: {})
    }
}
