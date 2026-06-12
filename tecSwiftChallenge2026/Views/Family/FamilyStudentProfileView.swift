import SwiftUI

struct FamilyStudentProfileView: View {
    let request: FamilyRequestItem

    private var student: StudentMini {
        request.student ?? StudentMini(name: "Carlos Méndez", uni: "UNAM", career: "Medicina", hours: 84, rating: 4.9)
    }

    private let reviews: [(tags: [String], rating: Int, family: String)] = [
        (tags: ["Muy amable", "Puntual"],     rating: 5, family: "Fam. Robles"),
        (tags: ["Volvería a pedirlo"],         rating: 5, family: "Fam. Núñez"),
    ]

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    // Hero — directo, sin card
                    VStack(spacing: 0) {
                        AvatarView(name: student.name, tint: .acoFamily, size: 96, ring: true)
                            .padding(.bottom, 14)

                        Text(student.name.components(separatedBy: " ").first ?? student.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.acoInk)

                        HStack(spacing: 8) {
                            UniversityBadge(university: student.uni, color: .acoFamily)
                            BadgeLabel(text: student.career, color: .acoInk2)
                        }
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 26)

                    // Estadísticas — dos filas de datos, sin card grid
                    HStack(spacing: 8) {
                        statCell(
                            value: "\(student.hours)",
                            label: "horas de servicio",
                            color: .acoFamily
                        )
                        statCell(
                            value: String(format: "%.1f ★", student.rating),
                            label: "de otras familias",
                            color: .acoStar
                        )
                    }
                    .padding(.bottom, 24)

                    // Reseñas
                    SectionLabel(text: "Lo que dicen otras familias")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 8) {
                        ForEach(reviews.indices, id: \.self) { i in
                            AcoCard(padding: 13) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        StarRating(value: Double(reviews[i].rating), size: 13)
                                        Spacer()
                                        Text(reviews[i].family)
                                            .font(.caption)
                                            .foregroundStyle(Color.acoInk3)
                                    }
                                    HStack(spacing: 6) {
                                        ForEach(reviews[i].tags, id: \.self) { tag in
                                            ChipButton(label: tag, tint: .acoDone, soft: Color(acoHex: "EFF1E6"), isActive: false) {}
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // CTA
                    VStack(spacing: 10) {
                        CTAButton(label: "Enviar mensaje", leadingSymbol: "bubble.left.fill", tint: .acoFamily) {}
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.acoInk3)
                            Text("Solo mensajería en la app — sin números de teléfono")
                                .font(.caption)
                                .foregroundStyle(Color.acoInk3)
                        }
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        AcoCard(padding: 14) {
            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.acoInk2)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NavigationStack {
        FamilyStudentProfileView(request: sampleFamilyRequests[0])
    }
}
