import SwiftUI

struct StudentHoursView: View {
    @AppStorage("student_goal_hours") private var goalHours: Int = 0
    @AppStorage("aco_authToken") private var authToken: String = ""

    @AppStorage("aco_studentTags") private var savedTags: String = ""

    @State private var assignments: [APIAssignment] = []
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
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if isLoading && assignments.isEmpty {
                ProgressView("Cargando…").tint(Color.acoStudent)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroSection
                            .padding(.bottom, 8)

                        if !breakdown.isEmpty {
                            SectionLabel(text: "Por tipo de actividad").padding(.top, 22)
                            breakdownCard
                        }

                        SectionLabel(text: "Mis intereses").padding(.top, 22)
                        tagsCard

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("Mis horas")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
        }
        .sheet(isPresented: $showGoalSheet) { goalSheet }
        .sheet(isPresented: $showTagsSheet) { tagsSheet }
        .task { await load() }
        .refreshable { await load() }
        .onAppear {
            if goalHours == 0 { showGoalSheet = true }
        }
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
                    Text("horas")
                        .font(.title2).foregroundStyle(Color.acoInk3)
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

    // MARK: - Helpers

    private func load() async {
        isLoading = true
        if let loaded = try? await APIClient.shared.fetchMyAssignments() {
            assignments = loaded
        }
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
    NavigationStack {
        StudentHoursView()
    }
}
