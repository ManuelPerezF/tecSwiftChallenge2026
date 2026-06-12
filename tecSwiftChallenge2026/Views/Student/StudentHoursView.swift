import SwiftUI

/// Perfil del becario (icono arriba a la izquierda): horas y meta, intereses,
/// disponibilidad, insignias, calificaciones y cierre de sesión.
struct StudentProfileView: View {
    let onLogout: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("student_goal_hours") private var goalHours: Int = 0
    @AppStorage("aco_studentId") private var studentId: String = ""
    @AppStorage("aco_userName") private var userName: String = ""

    @AppStorage("aco_studentTags") private var savedTags: String = ""

    @State private var assignments: [APIAssignment] = []
    @State private var studentProfile: StudentProfile? = nil
    @State private var isLoading = false
    @State private var showGoalSheet = false
    @State private var goalInput: String = ""
    @State private var showTagsSheet = false
    @State private var tagsInput: String = ""
    @State private var tagsError: String?

    private var myTags: [String] {
        savedTags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var completedAssignments: [APIAssignment] {
        assignments.filter { $0.statusEnum == .completada }
    }

    private var totalHours: Double {
        completedAssignments.reduce(0) { $0 + $1.hoursLogged }
    }

    private var progress: Double {
        guard goalHours > 0 else { return 0 }
        return min(totalHours / Double(goalHours), 1.0)
    }

    private var breakdown: [(type: ActivityType, hours: Double)] {
        var totals: [ActivityType: Double] = [:]
        for a in completedAssignments {
            totals[a.activityTypeEnum, default: 0] += a.hoursLogged
        }
        return totals.map { (type: $0.key, hours: $0.value) }
            .sorted { $0.hours > $1.hours }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.acoBg.ignoresSafeArea()

                if isLoading && assignments.isEmpty {
                    ProgressView("Cargando…").tint(Color.acoStudent)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            profileHeader
                                .padding(.bottom, 18)

                            SectionLabel(text: "Mis horas de servicio")
                            heroSection
                                .padding(.bottom, 8)

                            if !breakdown.isEmpty {
                                SectionLabel(text: "Por tipo de actividad").padding(.top, 22)
                                breakdownCard
                            }

                            SectionLabel(text: "Mis intereses").padding(.top, 22)
                            tagsCard

                            SectionLabel(text: "Mi disponibilidad").padding(.top, 22)
                            availabilityCard

                            if let profile = studentProfile {
                                reputationSection(profile)
                            }

                            logoutSection
                                .padding(.top, 30)

                            Spacer().frame(height: 40)
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Mi perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        goalInput = goalHours > 0 ? "\(goalHours)" : ""
                        showGoalSheet = true
                    } label: {
                        Image(systemName: "target")
                            .font(.body)
                            .foregroundStyle(Color.acoStudent)
                    }
                    .accessibilityLabel("Cambiar meta de horas")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.acoInk3)
                }
            }
            .sheet(isPresented: $showGoalSheet) { goalSheet }
            .sheet(isPresented: $showTagsSheet) { tagsSheet }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Header del perfil

    private var profileHeader: some View {
        VStack(spacing: 8) {
            AvatarView(name: studentProfile?.name ?? userName, tint: .acoStudent, size: 76)
            Text(studentProfile?.name ?? userName)
                .font(.title2).bold()
                .foregroundStyle(Color.acoInk)
            if let profile = studentProfile {
                HStack(spacing: 6) {
                    if !profile.universityName.isEmpty {
                        UniversityBadge(university: profile.universityName, color: .acoStudent)
                    }
                    if !profile.career.isEmpty {
                        BadgeLabel(text: profile.career, color: .acoInk2)
                    }
                }
                if profile.averageRating > 0 {
                    Text(String(format: "%.1f ★ promedio", profile.averageRating))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.acoStar)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
    }

    private var logoutSection: some View {
        Button(role: .destructive) {
            dismiss()
            onLogout()
        } label: {
            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.body).fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(hoursFormatted(totalHours))
                    .font(.system(size: 76, weight: .heavy))
                    .foregroundStyle(Color.acoStudent)
                    .tracking(-2)
                Text("h")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.acoStudent.opacity(0.55))
                Spacer()
            }

            if goalHours > 0 {
                Text("de \(goalHours) h · tu meta")
                    .font(.subheadline)
                    .foregroundStyle(Color.acoInk2)
                    .padding(.top, 2)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(acoHex: "E7DECF"))
                        Capsule()
                            .fill(Color.acoStudent)
                            .frame(width: geo.size.width * progress)
                            .animation(.easeOut(duration: 0.6), value: progress)
                    }
                    .frame(height: 6)
                }
                .frame(height: 6)
                .padding(.top, 16)

                HStack {
                    Text("\(Int(progress * 100))% completado")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(Color.acoStudent)
                    Spacer()
                    Text("\(max(0, goalHours - Int(totalHours))) h restantes")
                        .font(.caption).foregroundStyle(Color.acoInk3)
                }
                .padding(.top, 8)
            } else {
                Button {
                    showGoalSheet = true
                } label: {
                    Label("Establece tu meta de horas", systemImage: "target")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.acoStudent)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }

            if !completedAssignments.isEmpty {
                inlineStat(symbol: "checkmark.circle.fill",
                           value: "\(completedAssignments.count)",
                           label: "visitas completadas")
                    .padding(.top, 20)
            }
        }
    }

    // MARK: - Breakdown

    private var breakdownCard: some View {
        AcoCard {
            VStack(spacing: 0) {
                let maxH = breakdown.map(\.hours).max() ?? 1
                ForEach(Array(breakdown.enumerated()), id: \.element.type) { index, item in
                    HStack(alignment: .center, spacing: 11) {
                        Image(systemName: item.type.symbolName)
                            .font(.body)
                            .foregroundStyle(Color.acoStudent)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(item.type.label)
                                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.acoInk)
                                Spacer()
                                Text("\(hoursFormatted(item.hours)) h")
                                    .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.acoStudent)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(acoHex: "EFE8DC"))
                                    Capsule()
                                        .fill(Color.acoStudent)
                                        .frame(width: geo.size.width * (item.hours / maxH))
                                }
                                .frame(height: 7)
                            }
                            .frame(height: 7)
                        }
                    }
                    .padding(.vertical, index == 0 ? 0 : 7)
                    if index < breakdown.count - 1 {
                        Divider().padding(.vertical, 7)
                    }
                }
            }
        }
    }

    // MARK: - Disponibilidad (3.6: rango horario real para notificaciones)

    @AppStorage("aco_studentWindows") private var savedWindows: String = ""
    @State private var availStart: Date = StudentProfileView.defaultTime(hour: 16)
    @State private var availEnd: Date = StudentProfileView.defaultTime(hour: 20)
    @State private var scheduleEnabled = false
    @State private var didLoadSchedule = false
    @State private var availabilityError: String?

    private static func defaultTime(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private static let hourFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

    private var availabilityCard: some View {
        AcoCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $scheduleEnabled) {
                    Text("Avisarme solo en mi horario")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.acoInk)
                }
                .tint(Color.acoStudent)
                .onChange(of: scheduleEnabled) { _, enabled in
                    guard didLoadSchedule else { return }
                    if !enabled { Task { await saveAvailability(windows: []) } }
                }

                if scheduleEnabled {
                    Text("Te notificaremos solicitudes y eventos cercanos cuya cita caiga dentro de este horario.")
                        .font(.caption).foregroundStyle(Color.acoInk2)

                    HStack(spacing: 12) {
                        DatePicker("Desde", selection: $availStart, displayedComponents: .hourAndMinute)
                            .font(.subheadline)
                        DatePicker("Hasta", selection: $availEnd, displayedComponents: .hourAndMinute)
                            .font(.subheadline)
                    }
                    .tint(Color.acoStudent)

                    Button {
                        let window = "\(Self.hourFormatter.string(from: availStart))-\(Self.hourFormatter.string(from: availEnd))"
                        Task { await saveAvailability(windows: [window]) }
                    } label: {
                        Label("Guardar horario", systemImage: "checkmark.circle.fill")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.acoStudent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Sin horario definido: te avisaremos de todas las solicitudes cercanas.")
                        .font(.caption).foregroundStyle(Color.acoInk3)
                }

                if let availabilityError {
                    Label(availabilityError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Color.acoUrgent)
                }
            }
        }
        .onAppear { loadScheduleFromStorage() }
    }

    private func loadScheduleFromStorage() {
        guard !didLoadSchedule else { return }
        if let range = savedWindows.split(separator: ",").map(String.init)
            .first(where: { $0.contains("-") }),
           let dash = range.firstIndex(of: "-"),
           let start = Self.hourFormatter.date(from: String(range[..<dash])),
           let end = Self.hourFormatter.date(from: String(range[range.index(after: dash)...])) {
            availStart = start
            availEnd = end
            scheduleEnabled = true
        } else {
            scheduleEnabled = false
        }
        DispatchQueue.main.async { didLoadSchedule = true }
    }

    private func saveAvailability(windows: [String]) async {
        availabilityError = nil
        do {
            let saved = try await APIClient.shared.updateMyAvailability(windows)
            savedWindows = saved.joined(separator: ",")
            KuidarHaptic.success()
        } catch {
            availabilityError = error.localizedDescription
        }
    }

    // MARK: - Tags (intereses para el recomendador de afinidad)

    private var tagsCard: some View {
        AcoCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Las familias verán primero a los becarios con intereses afines a su familiar.")
                    .font(.caption).foregroundStyle(Color.acoInk2)

                if myTags.isEmpty {
                    Text("Aún no agregas intereses.")
                        .font(.subheadline).foregroundStyle(Color.acoInk3)
                } else {
                    FlowTags(tags: myTags)
                }

                Button {
                    tagsInput = myTags.joined(separator: ", ")
                    showTagsSheet = true
                } label: {
                    Label(myTags.isEmpty ? "Agregar intereses" : "Editar intereses", systemImage: "tag.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.acoStudent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tagsSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Escribe tus intereses separados por comas. Ej. cocina, dominó, jardinería, fútbol")
                    .font(.body).foregroundStyle(Color.acoInk2)

                TextField("cocina, dominó, plantas…", text: $tagsInput, axis: .vertical)
                    .lineLimit(2...)
                    .font(.body)
                    .padding(14)
                    .background(Color(acoHex: "F8F5F1"))
                    .clipShape(.rect(cornerRadius: 12))

                if let tagsError {
                    Label(tagsError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Color.acoUrgent)
                }

                CTAButton(label: "Guardar intereses", tint: .acoStudent) {
                    Task { await saveTags() }
                }

                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .navigationTitle("Mis intereses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancelar") { showTagsSheet = false }
                        .foregroundStyle(Color.acoInk3)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveTags() async {
        tagsError = nil
        let tags = tagsInput
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        do {
            let saved = try await APIClient.shared.updateMyTags(tags)
            savedTags = saved.joined(separator: ",")
            showTagsSheet = false
            KuidarHaptic.success()
        } catch {
            tagsError = error.localizedDescription
        }
    }

    // MARK: - Goal sheet

    private var goalSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("¿Cuántas horas de servicio social necesitas completar?")
                    .font(.body).foregroundStyle(Color.acoInk2)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    TextField("120", text: $goalInput)
                        .font(.system(size: 52, weight: .heavy))
                        .foregroundStyle(Color.acoStudent)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 160)
                    Text(horasWord(Int(goalInput) ?? 0))
                        .font(.title2).foregroundStyle(Color.acoInk3)
                        .animation(.none, value: goalInput)
                }

                CTAButton(label: "Guardar meta", tint: .acoStudent) {
                    if let n = Int(goalInput), n > 0 {
                        goalHours = n
                        showGoalSheet = false
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .navigationTitle("Mi meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancelar") { showGoalSheet = false }
                        .foregroundStyle(Color.acoInk3)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Reputation

    @ViewBuilder
    private func reputationSection(_ profile: StudentProfile) -> some View {
        if !profile.badges.isEmpty {
            SectionLabel(text: "Insignias").padding(.top, 22)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(profile.badges) { badge in
                        BadgeCard(badge: badge)
                    }
                }
                .padding(.vertical, 2)
            }
        }

        if !profile.ratings.isEmpty {
            SectionLabel(text: "Calificaciones recibidas").padding(.top, 22)
            AcoCard {
                VStack(spacing: 0) {
                    ForEach(Array(profile.ratings.enumerated()), id: \.element.id) { index, rating in
                        RatingRow(rating: rating)
                        if index < profile.ratings.count - 1 {
                            Divider().padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func load() async {
        isLoading = true
        async let assignmentsTask = APIClient.shared.fetchMyAssignments()
        async let profileTask = APIClient.shared.fetchMyStudentProfile()
        assignments = (try? await assignmentsTask) ?? []
        studentProfile = try? await profileTask
        isLoading = false
    }

    private func inlineStat(symbol: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3).foregroundStyle(Color.acoStudent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.headline).fontWeight(.heavy).foregroundStyle(Color.acoInk)
                Text(label).font(.caption2).foregroundStyle(Color.acoInk2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hoursFormatted(_ h: Double) -> String {
        h.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", h)
            : String(format: "%.1f", h)
    }
}

// MARK: - Chips de tags (wrap simple)

struct FlowTags: View {
    let tags: [String]
    var tint: Color = .acoStudent

    var body: some View {
        // Wrap manual sencillo: filas de chips
        let columns = [GridItem(.adaptive(minimum: 80), spacing: 6, alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(tint.opacity(0.11))
                    .clipShape(.capsule)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    StudentProfileView(onLogout: {})
}
