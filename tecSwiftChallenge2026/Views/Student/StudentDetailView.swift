import SwiftUI

struct StudentDetailView: View {
    let request: OpenRequest
    @State private var arrivalTime: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 10; comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()
    @State private var isClaimed: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var aiTip: String? = nil
    @State private var isLoadingTip: Bool = false

    private var arrivalTimeFormatted: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_MX")
        df.dateFormat = "HH:mm"
        return df.string(from: arrivalTime)
    }

    var body: some View {
        Group {
            if isClaimed {
                claimedConfirmation
            } else {
                detailContent
            }
        }
        .acoScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard FoundationModelClient.shared.isAvailable, aiTip == nil else { return }
            isLoadingTip = true
            aiTip = try? await FoundationModelClient.shared.visitTip(
                activityType: request.activityType,
                description: request.description,
                elderlyName: request.elderlyName,
                neighborhood: request.neighborhood
            )
            isLoadingTip = false
        }
    }

    // MARK: - Confirmación

    private var claimedConfirmation: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 48)
                ZStack {
                    Circle().fill(Color.acoStudentSoft).frame(width: 88, height: 88)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.acoDone)
                        .accessibilityHidden(true)
                }
                Text("¡Postulación enviada!")
                    .font(.title2).fontWeight(.bold).foregroundStyle(Color.acoInk)
                    .padding(.top, 20)

                Text("La familia de \(request.elderlyName) revisará tu perfil. Cuando te aprueben, la visita aparecerá en \u{201C}Mis visitas\u{201D} con la dirección exacta.")
                    .font(.body).foregroundStyle(Color.acoInk2)
                    .multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 10)
                    .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Detalle

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Label(request.activityType.label, systemImage: request.activityType.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.acoStudent)
                        if request.isUrgent { BadgeLabel(text: "Urgente", color: .acoUrgent) }
                    }
                    Text(request.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.acoInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 16)
                .accessibilityElement(children: .combine)

                AcoCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(request.description)
                            .font(.body)
                            .foregroundStyle(Color.acoInk)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        HStack(spacing: 12) {
                            AvatarView(name: request.elderlyName, tint: .acoElderly, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.elderlyName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.acoInk)
                                Label(request.neighborhood, systemImage: "mappin.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.acoInk2)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(request.elderlyName), \(request.neighborhood)")
                    }
                }
                .padding(.bottom, 12)

                factsRow
                    .padding(.bottom, 16)

                if isLoadingTip || aiTip != nil {
                    Group {
                        if isLoadingTip {
                            Label("Preparando consejo…", systemImage: "text.bubble")
                                .font(.subheadline)
                                .foregroundStyle(Color.acoInk2)
                                .redacted(reason: .placeholder)
                        } else if let tip = aiTip {
                            Label(tip, systemImage: "text.bubble")
                                .font(.subheadline)
                                .foregroundStyle(Color.acoInk2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, 16)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(aiTip.map { "Consejo: \($0)" } ?? "Cargando consejo")
                }

                AcoTypography.sectionHeader("Propón tu hora de llegada")

                DatePicker("Hora de llegada", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .tint(.acoStudent)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    .padding(.bottom, 20)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Color.acoUrgent)
                        .padding(.bottom, 10)
                }

                CTAButton(
                    label: isLoading ? "Enviando…" : "Postularme a esta actividad",
                    tint: .acoStudent,
                    big: true,
                    disabled: isLoading
                ) { Task { await apply() } }

                Text("Llegada propuesta: \(request.timeWindow.shortLabel.lowercased()), \(arrivalTimeFormatted)")
                    .font(.caption).foregroundStyle(Color.acoInk3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10).padding(.bottom, 40)
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var factsRow: some View {
        HStack(spacing: 0) {
            factCell(symbol: "clock", value: request.scheduledDateFormatted, label: "Horario")
            Divider().frame(height: 36)
            factCell(symbol: "timer", value: request.duration, label: "Duración")
            Divider().frame(height: 36)
            factCell(symbol: "clock.badge.checkmark", value: "+\(hoursFormatted(request.hours)) h", label: "Servicio")
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func factCell(symbol: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(Color.acoStudent)
                .accessibilityHidden(true)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.acoInk)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.acoInk3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func apply() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.applyToRequest(
                requestId: request.id,
                message: "Puedo llegar a las \(arrivalTimeFormatted)."
            )
            await MainActor.run {
                isLoading = false
                withAnimation(.easeInOut(duration: 0.22)) { isClaimed = true }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func hoursFormatted(_ h: Double) -> String {
        h.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", h)
            : String(format: "%.1f", h)
    }
}

#Preview {
    NavigationStack { StudentDetailView(request: PreviewData.openRequest) }
}
