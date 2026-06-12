import SwiftUI

struct FamilyStudentProfileView: View {
    let studentId: String

    @State private var profile: StudentProfile?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showChat = false

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if isLoading && profile == nil {
                ProgressView("Cargando perfil…").tint(Color.acoFamily)
            } else if let errorMessage, profile == nil {
                VStack(spacing: 12) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.body)
                        .foregroundStyle(Color.acoUrgent)
                        .multilineTextAlignment(.center)
                    Button("Reintentar") { Task { await load() } }
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.acoFamily)
                }
                .padding(.horizontal, 32)
            } else if let profile {
                profileContent(profile)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(isPresented: $showChat) {
            ChatThreadView(
                title: profile?.name ?? "Becario",
                otherId: studentId,
                tint: .acoFamily,
                isFamily: true
            )
        }
    }

    @ViewBuilder
    private func profileContent(_ profile: StudentProfile) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    AvatarView(name: profile.name, tint: .acoFamily, size: 96, ring: true)
                        .padding(.bottom, 14)

                    Text(profile.name.components(separatedBy: " ").first ?? profile.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.acoInk)

                    HStack(spacing: 8) {
                        UniversityBadge(university: profile.universityName, color: .acoFamily)
                        if !profile.career.isEmpty {
                            BadgeLabel(text: profile.career, color: .acoInk2)
                        }
                    }
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .padding(.bottom, 26)

                HStack(spacing: 8) {
                    statCell(
                        value: hoursText(profile.totalHours),
                        label: profile.totalHours == 1 ? "hora de servicio" : "horas de servicio",
                        color: .acoFamily
                    )
                    statCell(
                        value: profile.averageRating > 0
                            ? String(format: "%.1f ★", profile.averageRating)
                            : "Nuevo",
                        label: "de otras familias",
                        color: .acoStar
                    )
                }
                .padding(.bottom, 24)

                SectionLabel(text: "Lo que dicen otras familias")
                    .frame(maxWidth: .infinity, alignment: .leading)

                if profile.ratings.isEmpty {
                    Text("Aún no hay reseñas de otras familias.")
                        .font(.body)
                        .foregroundStyle(Color.acoInk3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(profile.ratings) { rating in
                            AcoCard(padding: 13) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        StarRating(value: Double(rating.stars), size: 13)
                                        Spacer()
                                        Text(rating.authorName)
                                            .font(.caption)
                                            .foregroundStyle(Color.acoInk3)
                                    }
                                    if !rating.tags.isEmpty {
                                        HStack(spacing: 6) {
                                            ForEach(rating.tags, id: \.self) { tag in
                                                ChipButton(label: tag, tint: .acoDone, soft: Color(acoHex: "EFF1E6"), isActive: false) {}
                                            }
                                        }
                                    }
                                    if !rating.comment.isEmpty {
                                        Text(rating.comment)
                                            .font(.caption)
                                            .foregroundStyle(Color.acoInk2)
                                    }
                                }
                            }
                        }
                    }
                }

                VStack(spacing: 10) {
                    CTAButton(label: "Enviar mensaje", leadingSymbol: "bubble.left.fill", tint: .acoFamily) {
                        showChat = true
                    }
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

    private func hoursText(_ hours: Double) -> String {
        hours.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", hours)
            : String(format: "%.1f", hours)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            profile = try await APIClient.shared.fetchStudentProfile(id: studentId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        FamilyStudentProfileView(studentId: "preview-student")
    }
}
