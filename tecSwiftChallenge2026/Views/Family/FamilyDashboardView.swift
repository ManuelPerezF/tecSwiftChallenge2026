import SwiftUI

struct FamilyDashboardView: View {
    let onAddTapped: () -> Void

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sampleFamilyRequests) { request in
                        if request.student != nil {
                            NavigationLink(value: request) {
                                FamilyRequestCard(request: request)
                            }
                            .buttonStyle(.plain)
                        } else {
                            FamilyRequestCard(request: request)
                        }
                    }

                    SectionLabel(text: "Historial de visitas")
                        .padding(.top, 6)

                    AcoCard {
                        VStack(spacing: 0) {
                            ForEach(Array(sampleHistory.enumerated()), id: \.element.id) { index, entry in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.acoDone)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(entry.activity) · \(entry.studentName)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.acoInk)
                                        Text(entry.date)
                                            .font(.caption)
                                            .foregroundStyle(Color.acoInk3)
                                    }
                                    Spacer()
                                    StarRating(value: Double(entry.rating), size: 13)
                                }
                                .padding(.vertical, index == 0 ? 0 : 7)

                                if index < sampleHistory.count - 1 {
                                    Divider().padding(.vertical, 7)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Mis solicitudes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nueva solicitud", systemImage: "plus.circle.fill", action: onAddTapped)
                    .font(.title3)
                    .foregroundStyle(Color.acoFamily)
                    .labelStyle(.iconOnly)
            }
        }
    }
}

private struct FamilyRequestCard: View {
    let request: FamilyRequestItem

    var body: some View {
        AcoCard(padding: 0) {
            VStack(spacing: 0) {
                // Main info row
                HStack(alignment: .top, spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.acoFamilySoft)
                            .frame(width: 48, height: 48)
                        Text(request.activityType.emoji)
                            .font(.system(size: 25))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .center, spacing: 7) {
                            Text(request.title)
                                .font(.headline)
                                .foregroundStyle(Color.acoInk)
                            if request.isUrgent {
                                BadgeLabel(text: "Urgente", color: .acoUrgent)
                            }
                        }
                        Text(request.when)
                            .font(.subheadline)
                            .foregroundStyle(Color.acoInk2)

                        StatusRow(status: request.status, eta: request.eta)
                            .padding(.top, 6)
                    }
                }
                .padding(16)

                // Student strip
                if let student = request.student {
                    Divider().padding(.leading, 16)
                    HStack(spacing: 11) {
                        AvatarView(name: student.name, tint: .acoFamily, size: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(student.name.components(separatedBy: " ").first ?? student.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.acoInk)
                            UniversityBadge(university: student.uni, color: .acoFamily)
                        }
                        Spacer()
                        if request.status == .completed, let r = request.completedRating {
                            StarRating(value: Double(r), size: 15)
                        } else {
                            Text("Ver perfil ›")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.acoFamily)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(acoHex: "FCFAF7"))
                }

                // AI summary
                if let summary = request.aiSummary {
                    Divider().padding(.leading, 16)
                    HStack(alignment: .top, spacing: 9) {
                        Text("✨")
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(Color.acoInk2)
                            .italic()
                            .lineLimit(4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(acoHex: "FAFBF7"))
                }

                // Republish for completed
                if request.status == .completed {
                    Button("↻ Volver a publicar") { }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.acoFamily)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .overlay {
                            RoundedRectangle(cornerRadius: 13)
                                .strokeBorder(Color.acoFamily, lineWidth: 1.5)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                        .background(Color(acoHex: "FAFBF7"))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.title), \(request.status.label)")
    }
}

#Preview {
    NavigationStack {
        FamilyDashboardView(onAddTapped: {})
    }
}
