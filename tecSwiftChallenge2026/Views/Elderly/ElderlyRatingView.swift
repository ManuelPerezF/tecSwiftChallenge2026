import SwiftUI

struct ElderlyRatingView: View {
    @State private var selectedStars: Int = 0
    @State private var selectedTags: Set<String> = []
    @State private var isSent: Bool = false

    private let studentName  = "Carlos"
    private let positiveTags = ["Muy amable", "Puntual", "Volvería a pedirlo"]
    private let ratingLabels = ["", "Mal", "Regular", "Bien", "Muy bien", "¡Excelente!"]

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            if isSent {
                thankYouView
            } else {
                ratingForm
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSent)
    }

    // MARK: - Gracias

    private var thankYouView: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("💛")
                .font(.system(size: 80))
                .accessibilityHidden(true)
            Text("¡Gracias!")
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(Color.acoInk)
                .padding(.top, 18)
            Text("Tu opinión ayuda a otros\nabuelitos a sentirse seguros.")
                .font(.title3)
                .foregroundStyle(Color.acoInk2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 12)
            StarRating(value: Double(selectedStars), size: 40)
                .padding(.top, 30)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Formulario

    private var ratingForm: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // Avatar del estudiante
                    AvatarView(name: "Carlos Méndez", tint: .acoElderly, size: 104)

                    Text("¿Cómo te trató\n\(studentName)?")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(Color.acoInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, 20)

                    // Estrellas grandes
                    HStack(spacing: 8) {
                        ForEach(1 ... 5, id: \.self) { i in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    selectedStars = i
                                }
                            } label: {
                                Text("★")
                                    .font(.system(size: 52))
                                    .foregroundStyle(i <= selectedStars ? Color.acoStar : Color(acoHex: "E2D8CC"))
                                    .scaleEffect(i <= selectedStars ? 1.06 : 1)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: selectedStars)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(i) estrella\(i == 1 ? "" : "s")")
                            .accessibilityAddTraits(i <= selectedStars ? .isSelected : [])
                        }
                    }
                    .padding(.top, 28)
                    .sensoryFeedback(.selection, trigger: selectedStars)

                    Text(selectedStars == 0 ? "Toca las estrellas" : ratingLabels[selectedStars])
                        .font(.body)
                        .foregroundStyle(Color.acoInk3)
                        .padding(.top, 12)
                        .frame(minHeight: 26)
                        .animation(.easeInOut(duration: 0.15), value: selectedStars)

                    // Tags — botones full-width, más grandes
                    if selectedStars >= 4 {
                        VStack(spacing: 10) {
                            Text("¿Qué te gustó? (opcional)")
                                .font(.title3)
                                .foregroundStyle(Color.acoInk2)
                                .padding(.bottom, 4)

                            ForEach(positiveTags, id: \.self) { tag in
                                let isOn = selectedTags.contains(tag)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if isOn { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        if isOn {
                                            Image(systemName: "checkmark")
                                                .font(.body.weight(.bold))
                                        }
                                        Text(tag)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(isOn ? Color.acoElderly : Color.acoInk)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(isOn ? Color.acoElderlySoft : Color(acoHex: "FDFAF6"))
                                    .clipShape(.rect(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(
                                                isOn ? Color.acoElderly : Color(acoHex: "3C3228").opacity(0.10),
                                                lineWidth: isOn ? 2 : 1
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(isOn ? .isSelected : [])
                            }
                        }
                        .padding(.top, 28)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer().frame(height: 28)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)

            // Botón enviar — grande y fijo abajo
            VStack(spacing: 12) {
                Rectangle()
                    .fill(Color.acoHair)
                    .frame(height: 1)
                Button {
                    guard selectedStars > 0 else { return }
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isSent = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        if selectedStars > 0 {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        Text("Enviar")
                            .font(.system(size: 26, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(selectedStars > 0 ? Color.acoElderly : Color(acoHex: "E0D6C9"))
                    .clipShape(.rect(cornerRadius: 20))
                    .shadow(color: selectedStars > 0 ? Color.acoElderly.opacity(0.38) : .clear, radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(selectedStars == 0)
                .animation(.easeInOut(duration: 0.15), value: selectedStars)
                .sensoryFeedback(.success, trigger: isSent)

                Text("No necesitas escribir nada")
                    .font(.body)
                    .foregroundStyle(Color.acoInk3)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .background(Color.acoBg)
        }
    }
}

#Preview {
    NavigationStack {
        ElderlyRatingView()
    }
}
