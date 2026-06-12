import SwiftUI

struct FamilyPublishView: View {
    @State private var selectedActivity: ActivityType = .mandados
    @State private var selectedWindow: TimeWindow = .morning
    @State private var selectedFrequency: String = "Una vez"
    @State private var isUrgent: Bool = false
    @State private var descriptionText: String = "Necesita ayuda cargando el mandado, vive en 3er piso sin elevador."
    @State private var isPublished: Bool = false

    private let frequencies = ["Una vez", "Semanal", "Según se necesite"]

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            if isPublished {
                publishedConfirmation
            } else {
                publishForm
            }
        }
        .navigationTitle(isPublished ? "Publicar" : "Nueva solicitud")
        .navigationBarTitleDisplayMode(isPublished ? .inline : .large)
    }

    // MARK: - Published Confirmation
    private var publishedConfirmation: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)
                ZStack {
                    Circle().fill(Color.acoFamilySoft).frame(width: 88, height: 88)
                    Text(selectedActivity.emoji)
                        .font(.system(size: 42))
                        .accessibilityHidden(true)
                }
                Text("¡Solicitud publicada!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.acoInk)
                    .padding(.top, 22)

                Text("Ya está visible en el mapa de los becarios. Te avisaremos en cuanto alguien se apunte.")
                    .font(.body)
                    .foregroundStyle(Color.acoInk2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 10)

                VStack(spacing: 11) {
                    CTAButton(label: "Ver mis solicitudes", tint: .acoFamily) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPublished = false
                        }
                    }
                    Button("Publicar otra") {
                        withAnimation(.easeInOut(duration: 0.2), completionCriteria: .logicallyComplete) {
                            isPublished = false
                        } completion: {
                            selectedActivity = .mandados
                            descriptionText = ""
                        }
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.acoFamily)
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Publish Form
    private var publishForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Para Doña Carmen · tu mamá")
                    .font(.subheadline)
                    .foregroundStyle(Color.acoInk2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                // Activity picker
                fieldLabel("¿Con qué necesita ayuda?")
                    .padding(.horizontal, 20)

                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 10) {
                    ForEach(ActivityType.allCases, id: \.self) { act in
                        ActivityPickerCell(
                            activity: act,
                            isSelected: selectedActivity == act,
                            tint: .acoFamily,
                            soft: .acoFamilySoft
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedActivity = act
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Description
                fieldLabel("Detalles")
                    .padding(.horizontal, 20)
                    .padding(.top, 22)

                TextField("Describe la ayuda que necesita…", text: $descriptionText, axis: .vertical)
                    .lineLimit(3...)
                    .font(.body)
                    .foregroundStyle(Color.acoInk)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color(acoHex: "3C3228").opacity(0.12), lineWidth: 1)
                    }
                    .padding(.horizontal, 20)

                // Time window
                fieldLabel("Horario preferido")
                    .padding(.horizontal, 20)
                    .padding(.top, 22)

                HStack(spacing: 8) {
                    ForEach(TimeWindow.allCases, id: \.self) { win in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedWindow = win
                            }
                        } label: {
                            Text(win.shortLabel)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(selectedWindow == win ? .white : Color.acoInk2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(selectedWindow == win ? Color.acoFamily : Color.white)
                                .clipShape(.rect(cornerRadius: 14))
                                .shadow(color: Color(acoHex: "3C3228").opacity(0.04), radius: 1, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Text("Solo un rango — el becario elige su hora exacta dentro de él.")
                    .font(.caption)
                    .foregroundStyle(Color.acoInk3)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // Frequency
                fieldLabel("Frecuencia")
                    .padding(.horizontal, 20)
                    .padding(.top, 22)

                HStack(spacing: 8) {
                    ForEach(frequencies, id: \.self) { freq in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedFrequency = freq
                            }
                        } label: {
                            Text(freq)
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(selectedFrequency == freq ? Color.acoFamily : Color.acoInk2)
                                .multilineTextAlignment(.center)
                                .lineLimit(2, reservesSpace: true)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 4)
                                .background(selectedFrequency == freq ? Color.acoFamilySoft : Color.white)
                                .clipShape(.rect(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            selectedFrequency == freq ? Color.acoFamily : Color.clear,
                                            lineWidth: 1.5
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                // Urgency toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isUrgent.toggle()
                    }
                } label: {
                    UrgencyToggleRow(isUrgent: isUrgent)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .accessibilityLabel(isUrgent ? "Urgente activado" : "Urgente desactivado")
                .accessibilityHint("Activa para resaltar en el mapa")

                // CTA
                CTAButton(
                    label: "Publicar solicitud",
                    leadingEmoji: selectedActivity.emoji,
                    tint: .acoFamily
                ) {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isPublished = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .background(Color.acoBg)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .textCase(.uppercase)
            .tracking(0.3)
            .foregroundStyle(Color.acoFamily)
    }
}

private struct ActivityPickerCell: View {
    let activity: ActivityType
    let isSelected: Bool
    let tint: Color
    let soft: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(activity.emoji)
                    .font(.system(size: 27))
                    .accessibilityHidden(true)
                Text(activity.label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isSelected ? tint : Color.acoInk2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(isSelected ? soft : Color.white)
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? tint : Color.clear, lineWidth: 2)
            }
            .shadow(color: Color(acoHex: "3C3228").opacity(0.04), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(activity.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct UrgencyToggleRow: View {
    let isUrgent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(isUrgent ? "🔴" : "⚪️")
                .font(.system(size: 20))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Marcar como urgente")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.acoInk)
                Text("Resalta tu solicitud en el mapa")
                    .font(.caption)
                    .foregroundStyle(Color.acoInk2)
            }
            Spacer()
            ZStack(alignment: isUrgent ? .trailing : .leading) {
                Capsule()
                    .fill(isUrgent ? Color.acoUrgent : Color(acoHex: "D8CFC4"))
                    .frame(width: 46, height: 28)
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .padding(.horizontal, 2)
            }
            .animation(.easeInOut(duration: 0.15), value: isUrgent)
        }
        .padding(14)
        .background(isUrgent ? Color(acoHex: "FBEDE2") : Color.white)
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isUrgent ? Color.acoUrgent : Color.clear, lineWidth: 1.5)
        }
    }
}

#Preview {
    NavigationStack {
        FamilyPublishView()
    }
}
