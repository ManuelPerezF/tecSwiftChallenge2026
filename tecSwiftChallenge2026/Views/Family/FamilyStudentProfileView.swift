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
                    // Hero
                    VStack(spacing: 0) {
                        AvatarView(name: student.name, tint: .acoFamily, size: 104, ring: true)

                        Text(student.name.components(separatedBy: " ").first ?? student.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.acoInk)
                            .padding(.top, 16)

                        HStack(spacing: 8) {
                            UniversityBadge(university: student.uni, color: .acoFamily)
                            BadgeLabel(text: student.career, color: .acoInk2)
                        }
                        .padding(.top, 10)
                        .flexibleFrame()
                        .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 22)

                    // Stats
                    HStack(spacing: 10) {
                        AcoCard(padding: 15) {
                            VStack(spacing: 2) {
                                Text("\(student.hours)")
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundStyle(Color.acoFamily)
                                Text("horas de servicio")
                                    .font(.caption)
                                    .foregroundStyle(Color.acoInk2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        AcoCard(padding: 15) {
                            VStack(spacing: 2) {
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text(String(format: "%.1f", student.rating))
                                        .font(.system(size: 28, weight: .heavy))
                                        .foregroundStyle(Color.acoStar)
                                    Text("★")
                                        .font(.title3)
                                        .foregroundStyle(Color.acoStar)
                                }
                                Text("de otras familias")
                                    .font(.caption)
                                    .foregroundStyle(Color.acoInk2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Reviews
                    SectionLabel(text: "Lo que dicen otras familias")
                        .padding(.top, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 10) {
                        ForEach(reviews.indices, id: \.self) { i in
                            AcoCard(padding: 14) {
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        StarRating(value: Double(reviews[i].rating), size: 14)
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

                    // Privacy + CTA
                    VStack(spacing: 12) {
                        CTAButton(label: "Enviar mensaje", leadingEmoji: "💬", tint: .acoFamily) {}
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
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Small helper to center content
private extension View {
    func flexibleFrame() -> some View {
        self.frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        FamilyStudentProfileView(request: sampleFamilyRequests[0])
    }
}
