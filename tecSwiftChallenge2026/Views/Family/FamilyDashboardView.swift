import SwiftUI

struct FamilyDashboardView: View {
    let onAddTapped: () -> Void

    @State private var requests: [APIRequest] = []
    @State private var assignments: [APIAssignment] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if isLoading && requests.isEmpty {
                ProgressView("Cargando…")
                    .tint(Color.acoFamily)
            } else if let err = errorMessage, requests.isEmpty {
                serverError(err)
            } else if requests.isEmpty {
                emptyState
            } else {
                list
            }
        }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(requests) { req in
                    if let asg = assignment(for: req) {
                        NavigationLink(value: asg) {
                            LiveRequestCard(request: req, assignment: asg)
                        }
                        .buttonStyle(.plain)
                    } else if req.statusEnum == .open {
                        NavigationLink(value: req) {
                            LiveRequestCard(request: req, assignment: nil)
                        }
                        .buttonStyle(.plain)
                    } else {
                        LiveRequestCard(request: req, assignment: nil)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.acoFamilySoft).frame(width: 96, height: 96)
                Image(systemName: "heart.text.clipboard")
                    .font(.system(size: 38)).foregroundStyle(Color.acoFamily)
            }
            Text("Sin solicitudes aún")
                .font(.title3).bold().foregroundStyle(Color.acoInk)
            Text("Publica tu primera solicitud\npara conectar con un becario.")
                .font(.body).foregroundStyle(Color.acoInk3)
                .multilineTextAlignment(.center)
            CTAButton(label: "Publicar solicitud", leadingEmoji: "➕", tint: .acoFamily) {
                onAddTapped()
            }
            .padding(.horizontal, 40)
        }
        .padding(.horizontal, 32)
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

// MARK: - Card de solicitud real

private struct LiveRequestCard: View {
    let request: APIRequest
    let assignment: APIAssignment?

    var body: some View {
        AcoCard(padding: 0) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.acoFamilySoft).frame(width: 48, height: 48)
                        Text(request.activityTypeEnum.emoji)
                            .font(.system(size: 24)).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(request.activityTypeEnum.label)
                                .font(.headline).foregroundStyle(Color.acoInk)
                            if request.isUrgent { BadgeLabel(text: "Urgente", color: .acoUrgent) }
                        }
                        if request.elderlyName != "Tu familiar" {
                            Label(request.elderlyName, systemImage: "person.fill")
                                .font(.subheadline).foregroundStyle(Color.acoInk2)
                        }
                        Label(request.scheduledDateFormatted, systemImage: "calendar")
                            .font(.subheadline).foregroundStyle(Color.acoInk2)
                        if let assignment {
                            Label("Becario: \(assignment.studentName) · \(assignment.statusEnum.label)", systemImage: "graduationcap.fill")
                                .font(.subheadline).foregroundStyle(Color.acoStudent)
                        } else if request.statusEnum == .open {
                            Label("Ver postulantes", systemImage: "person.2.fill")
                                .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.acoFamily)
                        }
                        StatusRow(status: request.statusEnum, eta: nil).padding(.top, 4)
                    }
                }
                .padding(14)

                if !request.details.isEmpty && request.details != "Ayuda con \(request.activityTypeEnum.label.lowercased())." {
                    Rectangle().fill(Color.acoHair).frame(height: 1)
                    Text(request.details)
                        .font(.caption).foregroundStyle(Color.acoInk2).lineLimit(2)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(acoHex: "F8F5F1"))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.activityTypeEnum.label), \(request.statusEnum.label), \(request.scheduledDateFormatted)")
    }
}

#Preview {
    NavigationStack {
        FamilyDashboardView(onAddTapped: {})
    }
}
