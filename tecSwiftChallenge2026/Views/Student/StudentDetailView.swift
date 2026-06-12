import SwiftUI

struct StudentDetailView: View {
    let request: OpenRequest
    @State private var selectedTime: String = "10:30"
    @State private var isClaimed: Bool = false

    private let timeSlots = ["9:00", "9:30", "10:00", "10:30", "11:00", "11:30"]

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
    }

    // MARK: - Claimed confirmation
    private var claimedConfirmation: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)
                ZStack {
                    Circle().fill(Color.acoStudentSoft).frame(width: 88, height: 88)
                    Text("✅").font(.system(size: 40)).accessibilityHidden(true)
                }
                Text("¡Te apuntaste!")
                    .font(.title2).fontWeight(.bold).foregroundStyle(Color.acoInk)
                    .padding(.top, 20)

                Text("La familia de \(request.elderlyName) ya fue notificada. Aquí está la dirección exacta:")
                    .font(.body).foregroundStyle(Color.acoInk2)
                    .multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 10)

                AcoCard {
                    HStack(alignment: .top, spacing: 11) {
                        Text("📍").font(.title3).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Av. Coyoacán 1435, int. 3")
                                .font(.headline).foregroundStyle(Color.acoInk)
                            Text("Col. \(request.neighborhood) · \(request.distance)")
                                .font(.subheadline).foregroundStyle(Color.acoInk2)
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 20)

                CTAButton(label: "Ver en mis visitas", tint: .acoStudent) {}
                    .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Detail content
    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.acoStudentSoft).frame(width: 84, height: 84)
                        Text(request.activityType.emoji).font(.system(size: 40)).accessibilityHidden(true)
                    }
                    HStack(spacing: 7) {
                        BadgeLabel(text: request.activityType.label, color: .acoStudent)
                        if request.isUrgent { BadgeLabel(text: "Urgente", color: .acoUrgent) }
                    }
                    Text(request.title)
                        .font(.title3).fontWeight(.bold).foregroundStyle(Color.acoInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 18)

                // Description
                AcoCard {
                    Text("\u{201C}\(request.description)\u{201D}")
                        .font(.body).foregroundStyle(Color.acoInk).lineSpacing(3)
                }
                .padding(.bottom, 12)

                // Elderly privacy card
                AcoCard(padding: 14) {
                    HStack(spacing: 12) {
                        AvatarView(name: request.elderlyName, tint: .acoElderly, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.elderlyName)
                                .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.acoInk)
                            Text("📍 \(request.neighborhood)")
                                .font(.caption).foregroundStyle(Color.acoInk2)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.caption2).foregroundStyle(Color.acoInk3)
                            Text("dirección al apuntarte")
                                .font(.caption2).foregroundStyle(Color.acoInk3)
                        }
                    }
                }
                .padding(.bottom, 12)

                // Facts grid
                HStack(spacing: 10) {
                    factCell(emoji: "🕑", value: request.timeWindow.shortLabel, label: "horario")
                    factCell(emoji: "⏱️", value: request.duration, label: "duración")
                    factCell(emoji: "⭐️",
                             value: "+\(hoursFormatted(request.hours)) h",
                             label: "servicio")
                }
                .padding(.bottom, 14)

                // AI suggestion
                HStack(alignment: .top, spacing: 10) {
                    Text("✨").font(.body).accessibilityHidden(true)
                    Text("**Mejor hora para ti:** según tu agenda, el **jueves por la mañana** te queda perfecto entre clases.")
                    .font(.subheadline)
                    .foregroundStyle(Color(acoHex: "13684D"))
                }
                .padding(13)
                .background(Color.acoStudentSoft)
                .clipShape(.rect(cornerRadius: 16))
                .padding(.bottom, 20)

                // Time picker
                Text("Propón tu hora de llegada")
                    .font(.caption).fontWeight(.bold).textCase(.uppercase)
                    .tracking(0.3).foregroundStyle(Color.acoStudent).padding(.bottom, 10)

                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 9) {
                    ForEach(timeSlots, id: \.self) { slot in
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) { selectedTime = slot }
                        } label: {
                            Text(slot)
                                .font(.body).fontWeight(.semibold)
                                .foregroundStyle(selectedTime == slot ? .white : Color.acoInk)
                                .frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(selectedTime == slot ? Color.acoStudent : Color.white)
                                .clipShape(.rect(cornerRadius: 13))
                                .shadow(color: Color(acoHex: "3C3228").opacity(0.05), radius: 1, y: 1)
                                .animation(.easeInOut(duration: 0.12), value: selectedTime)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(slot)
                        .accessibilityAddTraits(selectedTime == slot ? .isSelected : [])
                    }
                }
                .padding(.bottom, 24)

                CTAButton(label: "Apuntarme a esta actividad", tint: .acoStudent, big: true) {
                    withAnimation(.easeInOut(duration: 0.22)) { isClaimed = true }
                }

                Text("Llegada propuesta: \(request.timeWindow.shortLabel.lowercased()), \(selectedTime)")
                    .font(.caption).foregroundStyle(Color.acoInk3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 11).padding(.bottom, 40)
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func factCell(emoji: String, value: String, label: String) -> some View {
        AcoCard(padding: 13) {
            VStack(spacing: 5) {
                Text(emoji).font(.title3).accessibilityHidden(true)
                Text(value).font(.subheadline).fontWeight(.bold).foregroundStyle(Color.acoInk)
                Text(label).font(.caption2).foregroundStyle(Color.acoInk3)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func hoursFormatted(_ h: Double) -> String {
        h.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", h)
            : String(format: "%.1f", h)
    }
}

#Preview {
    NavigationStack { StudentDetailView(request: sampleOpenRequests[0]) }
}
