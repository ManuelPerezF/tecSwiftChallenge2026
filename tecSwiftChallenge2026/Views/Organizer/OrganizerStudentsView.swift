import SwiftUI

// MARK: - Becarios (organizador): lista, filtros y perfiles bloqueados

struct OrganizerStudentsView: View {
    private enum Filter: String, CaseIterable {
        case all = "Todos"
        case blocked = "Bloqueados"
    }

    @State private var filter: Filter = .all
    @State private var students: [OrganizerStudent] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var filtered: [OrganizerStudent] {
        let base = filter == .blocked ? students.filter(\.isBlocked) : students
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter {
            $0.name.lowercased().contains(q)
                || $0.universityName.lowercased().contains(q)
                || $0.career.lowercased().contains(q)
                || $0.tags.contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("Filtro", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                if isLoading && students.isEmpty {
                    Spacer()
                    ProgressView("Cargando…").tint(Color.acoFamily)
                    Spacer()
                } else if filtered.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    list
                }
            }
        }
        .navigationTitle("Becarios")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Nombre, universidad, carrera o interés")
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(for: OrganizerStudent.self) { student in
            OrganizerStudentDetailView(studentId: student.id)
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Color.acoUrgent)
                }

                if filter == .all {
                    Text("Ordenados por mejor calificación")
                        .font(.caption).foregroundStyle(Color.acoInk3)
                }

                ForEach(filtered) { student in
                    NavigationLink(value: student) {
                        StudentRowCard(student: student)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: filter == .blocked ? "checkmark.shield.fill" : "graduationcap")
                .font(.system(size: 40))
                .foregroundStyle(Color.acoInk3)
                .accessibilityHidden(true)
            Text(filter == .blocked ? "No hay becarios bloqueados" : "Aún no hay becarios registrados")
                .font(.body).foregroundStyle(Color.acoInk2)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            students = try await APIClient.shared.fetchOrganizerStudents()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Card de becario

private struct StudentRowCard: View {
    let student: OrganizerStudent

    var body: some View {
        AcoCard {
            HStack(spacing: 12) {
                AvatarView(name: student.name, tint: student.isBlocked ? .acoUrgent : .acoStudent, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(student.name)
                            .font(.headline).foregroundStyle(Color.acoInk)
                        if student.isBlocked {
                            BadgeLabel(text: "Bloqueado", color: .acoUrgent)
                        }
                    }
                    Text("\(student.universityName)\(student.career.isEmpty ? "" : " · \(student.career)")")
                        .font(.caption).foregroundStyle(Color.acoInk2)
                    HStack(spacing: 10) {
                        Label(student.averageRating > 0 ? String(format: "%.1f", student.averageRating) : "Nuevo",
                              systemImage: "star.fill")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(Color.acoStar)
                        Label(String(format: "%.0f h", student.totalHours), systemImage: "clock.fill")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(Color.acoInk2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.acoInk3)
            }
        }
    }
}

// MARK: - Detalle de becario (organizador) — perfil completo + bloqueos

struct OrganizerStudentDetailView: View {
    let studentId: String

    @State private var detail: OrganizerStudentDetail?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if let detail {
                content(detail)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(Color.acoUrgent)
            } else {
                ProgressView("Cargando…").tint(Color.acoFamily)
            }
        }
        .navigationTitle("Perfil de becario")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func content(_ detail: OrganizerStudentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                AcoCard {
                    HStack(spacing: 14) {
                        AvatarView(name: detail.name, tint: detail.isBlocked ? .acoUrgent : .acoStudent, size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(detail.name)
                                .font(.title3).bold().foregroundStyle(Color.acoInk)
                            Text("\(detail.universityName)\(detail.career.isEmpty ? "" : " · \(detail.career)")")
                                .font(.caption).foregroundStyle(Color.acoInk2)
                            HStack(spacing: 10) {
                                StarRating(value: detail.averageRating, size: 13)
                                Text(String(format: "%.0f h de servicio", detail.totalHours))
                                    .font(.caption).foregroundStyle(Color.acoInk2)
                            }
                        }
                        Spacer()
                    }
                }

                if detail.isBlocked {
                    blocksSection(detail.blocks)
                }

                if !detail.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Intereses")
                        FlowTags(tags: detail.tags)
                    }
                }

                if !detail.ratings.isEmpty {
                    SectionLabel(text: "Reseñas de familias")
                    ForEach(detail.ratings) { rating in
                        AcoCard(padding: 13) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    StarRating(value: Double(rating.stars), size: 13)
                                    Spacer()
                                    Text(rating.authorName)
                                        .font(.caption).foregroundStyle(Color.acoInk3)
                                }
                                if !rating.comment.isEmpty {
                                    Text(rating.comment)
                                        .font(.caption).foregroundStyle(Color.acoInk2)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    private func blocksSection(_ blocks: [StudentBlock]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Historial de bloqueo")

            ForEach(blocks) { block in
                AcoCard(padding: 13) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(block.reason, systemImage: "hand.raised.fill")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color.acoUrgent)
                            Spacer()
                            if block.active {
                                BadgeLabel(text: "Activo", color: .acoUrgent)
                            }
                        }
                        if !block.comment.isEmpty {
                            Text("\u{201C}\(block.comment)\u{201D}")
                                .font(.caption).foregroundStyle(Color.acoInk2)
                        }
                        HStack {
                            Text("Reportado por \(block.familyName)")
                                .font(.caption2).foregroundStyle(Color.acoInk3)
                            Spacer()
                            Text(formatDate(block.createdAt))
                                .font(.caption2).foregroundStyle(Color.acoInk3)
                        }
                    }
                }
            }
        }
    }

    private func formatDate(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
        parser.timeZone = TimeZone(identifier: "UTC")
        guard let date = parser.date(from: iso) else { return iso }
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_MX")
        df.dateFormat = "d MMM yyyy"
        return df.string(from: date)
    }

    private func load() async {
        errorMessage = nil
        do {
            detail = try await APIClient.shared.fetchOrganizerStudent(id: studentId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { OrganizerStudentsView() }
}
