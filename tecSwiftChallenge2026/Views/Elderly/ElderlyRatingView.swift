import SwiftUI

struct ElderlyRatingView: View {
    @State private var selectedStars: Int = 0
    @State private var selectedTags: Set<String> = []
    @State private var isSent: Bool = false

    private let studentName = "Carlos"
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

    // MARK: - Thank you
    private var thankYouView: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("💛")
                .font(.system(size: 80))
                .accessibilityHidden(true)
            Text("¡Gracias!")
                .font(.system(size: 38, weight: .heavy))
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

    // MARK: - Rating form
    private var ratingForm: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    AvatarView(name: "Carlos Méndez", tint: .acoElderly, size: 120)

                    Text("¿Cómo te trató\n\(studentName)?")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(Color.acoInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, 22)

                    // Giant tappable stars
                    HStack(spacing: 6) {
                        ForEach(1 ... 5, id: \.self) { i in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    selectedStars = i
                                }
                            } label: {
                                Text("★")
                                    .font(.system(size: 50))
                                    .foregroundStyle(i <= selectedStars ? Color.acoStar : Color(acoHex: "E2D8CC"))
                                    .scaleEffect(i <= selectedStars ? 1.05 : 1)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: selectedStars)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(i) estrella\(i == 1 ? "" : "s")")
                            .accessibilityAddTraits(i <= selectedStars ? .isSelected : [])
                        }
                    }
                    .padding(.top, 30)
                    .sensoryFeedback(.selection, trigger: selectedStars)

                    Text(selectedStars == 0 ? "Toca las estrellas" : ratingLabels[selectedStars])
                        .font(.body)
                        .foregroundStyle(Color.acoInk3)
                        .padding(.top, 12)
                        .frame(minHeight: 24)
                        .animation(.easeInOut(duration: 0.15), value: selectedStars)

                    // Tags (shown for 4+ stars)
                    if selectedStars >= 4 {
                        VStack(spacing: 12) {
                            Text("¿Qué te gustó? (opcional)")
                                .font(.title3)
                                .foregroundStyle(Color.acoInk2)
                                .padding(.bottom, 2)

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
                                                .font(.body)
                                                .fontWeight(.bold)
                                        }
                                        Text(tag)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(isOn ? Color.acoElderly : Color.acoInk)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(isOn ? Color.acoElderlySoft : Color.white)
                                    .clipShape(.rect(cornerRadius: 18))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18)
                                            .strokeBorder(
                                                isOn ? Color.acoElderly : Color(acoHex: "3C3228").opacity(0.12),
                                                lineWidth: 2
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(isOn ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 26)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)

            // Send button (large, bottom-pinned)
            VStack(spacing: 12) {
                Divider()
                Button {
                    guard selectedStars > 0 else { return }
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isSent = true
                    }
                } label: {
                    Text("Enviar")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(selectedStars > 0 ? Color.acoElderly : Color(acoHex: "E0D6C9"))
                        .clipShape(.rect(cornerRadius: 22))
                        .shadow(color: selectedStars > 0 ? Color.acoElderly.opacity(0.38) : .clear, radius: 11, y: 8)
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
