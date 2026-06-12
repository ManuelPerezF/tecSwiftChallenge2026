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
        ZStack {
            Color.acoBg.ignoresSafeArea()
            if isClaimed {
                claimedConfirmation
            } else {
                detailContent
            }
        }
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
                // Hero — actividad + badges, sin card wrapper
                VStack(spacing: 12) {
                    Image(systemName: request.activityType.symbolName)
                        .font(.system(size: 48))
                        .foregroundStyle(Color.acoStudent)
                        .accessibilityHidden(true)
                    HStack(spacing: 7) {
                        BadgeLabel(text: request.activityType.label, color: .acoStudent)
                        if request.isUrgent { BadgeLabel(text: "Urgente", color: .acoUrgent) }
                    }
                    Text(request.title)
                        .font(.title3).fontWeight(.bold).foregroundStyle(Color.acoInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 20)

                // Descripción
                AcoCard {
                    Text("\u{201C}\(request.description)\u{201D}")
                        .font(.body).foregroundStyle(Color.acoInk).lineSpacing(3)
                }
                .padding(.bottom, 10)

                // Privacy card del adulto mayor
                AcoCard(padding: 13) {
                    HStack(spacing: 12) {
                        AvatarView(name: request.elderlyName, tint: .acoElderly, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.elderlyName)
                                .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.acoInk)
                            Label(request.neighborhood, systemImage: "mappin.circle.fill")
                                .font(.caption).foregroundStyle(Color.acoInk2)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.bottom, 10)

                // Datos clave — 3 celdas inline sin card individual
                HStack(spacing: 8) {
                    factCell(symbol: "clock", value: request.scheduledDateFormatted, label: "horario")
                    factCell(symbol: "timer", value: request.duration, label: "duración")
                    factCell(symbol: "star.fill", value: "+\(hoursFormatted(request.hours)) h", label: "servicio")
                }
                .padding(.bottom, 14)

                // Sugerencia IA — tip de preparación on-device
                if isLoadingTip || aiTip != nil {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.body)
                            .foregroundStyle(Color(acoHex: "13684D"))
                            .accessibilityHidden(true)
                        if isLoadingTip {
                            Text("Preparando consejo…")
                                .font(.subheadline)
                                .foregroundStyle(Color(acoHex: "13684D").opacity(0.55))
                                .redacted(reason: .placeholder)
                        } else if let tip = aiTip {
                            Text(tip)
                                .font(.subheadline)
                                .foregroundStyle(Color(acoHex: "13684D"))
                        }
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.acoStudentSoft)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(.bottom, 20)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(aiTip.map { "Consejo: \($0)" } ?? "Cargando consejo")
                }

                // Selector de hora
                Text("Propón tu hora de llegada")
                    .font(.caption).fontWeight(.bold).textCase(.uppercase)
                    .tracking(0.3).foregroundStyle(Color.acoStudent).padding(.bottom, 10)

                DatePicker("Hora de llegada", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .tint(.acoStudent)
                    .labelsHidden()
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(acoHex: "FDFAF6"))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.acoStudent.opacity(0.25), lineWidth: 1.5)
                    }
                    .padding(.bottom, 22)

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

    private func factCell(symbol: String, value: String, label: String) -> some View {
        AcoCard(padding: 12) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Color.acoStudent)
                    .accessibilityHidden(true)
                Text(value).font(.subheadline).fontWeight(.bold).foregroundStyle(Color.acoInk)
                Text(label).font(.caption2).foregroundStyle(Color.acoInk3)
            }
            .frame(maxWidth: .infinity)
        }
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
