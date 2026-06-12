import SwiftUI

struct StudentHoursView: View {
    @AppStorage("student_goal_hours") private var goalHours: Int = 0
    @AppStorage("aco_authToken") private var authToken: String = ""

    @State private var assignments: [APIAssignment] = []
    @State private var isLoading = false
    @State private var showGoalSheet = false
    @State private var goalInput: String = ""

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
        Group {
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

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .acoScreenBackground()
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
        .task { await load() }
        .refreshable { await load() }
        .onAppear {
            if goalHours == 0 { showGoalSheet = true }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: AcoSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(hoursFormatted(totalHours)) horas")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.acoInk)
                    .monospacedDigit()
                Text("Servicio social registrado")
                    .font(.subheadline)
                    .foregroundStyle(Color.acoInk2)
            }

            if goalHours > 0 {
                VStack(alignment: .leading, spacing: AcoSpacing.xs) {
                    HStack {
                        Text("Meta: \(goalHours) h")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.acoInk2)
                        Spacer()
                        Text("\(max(0, goalHours - Int(totalHours))) h restantes")
                            .font(.footnote)
                            .foregroundStyle(Color.acoInk3)
                            .monospacedDigit()
                    }
                    ProgressView(value: progress)
                        .tint(.acoStudent)
                        .animation(.easeOut(duration: 0.25), value: progress)
                }
                .padding(AcoSpacing.md)
                .acoGroupedSurface()
            } else {
                Button {
                    showGoalSheet = true
                } label: {
                    Label("Establece tu meta de horas", systemImage: "target")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(.acoStudent)
            }

            if !completedAssignments.isEmpty {
                Label("\(completedAssignments.count) visitas completadas", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.acoInk2)
            }
        }
        .padding(.top, AcoSpacing.sm)
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

#Preview {
    NavigationStack {
        StudentHoursView()
    }
}
