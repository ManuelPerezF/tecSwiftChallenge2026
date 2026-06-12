import SwiftUI

struct StudentHoursView: View {
    private let totalHours = 84
    private let goalHours  = 120
    private var progress: Double { Double(totalHours) / Double(goalHours) }

    private let breakdown: [(type: ActivityType, hours: Int)] = [
        (.compania, 28), (.mandados, 22), (.citas, 16), (.tecnologia, 12), (.hogar, 6),
    ]

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Hero — tipografía editorial, sin card de color
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(totalHours)")
                                .font(.system(size: 76, weight: .heavy))
                                .foregroundStyle(Color.acoStudent)
                                .tracking(-2)
                            Text("h")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(Color.acoStudent.opacity(0.55))
                        }
                        Text("de \(goalHours) h · meta anual")
                            .font(.subheadline)
                            .foregroundStyle(Color.acoInk2)
                            .padding(.top, 2)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(acoHex: "E7DECF"))
                                Capsule()
                                    .fill(Color.acoStudent)
                                    .frame(width: geo.size.width * progress)
                            }
                            .frame(height: 6)
                        }
                        .frame(height: 6)
                        .padding(.top, 16)

                        HStack {
                            Text("\(Int(progress * 100))% completado")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.acoStudent)
                            Spacer()
                            Text("\(goalHours - totalHours) h restantes")
                                .font(.caption)
                                .foregroundStyle(Color.acoInk3)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 8)

                    // Stats inline — sin mini-cards
                    HStack(spacing: 0) {
                        inlineStat(symbol: "flame.fill", value: "5 sem", label: "seguidas")
                        Rectangle()
                            .fill(Color.acoHair)
                            .frame(width: 1, height: 32)
                            .padding(.horizontal, 20)
                        inlineStat(symbol: "person.2.fill", value: "8", label: "familias este sem.")
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 6)

                    // Breakdown
                    SectionLabel(text: "Por tipo de actividad").padding(.top, 22)

                    AcoCard {
                        VStack(spacing: 0) {
                            let maxH = breakdown.map(\.hours).max() ?? 1
                            ForEach(Array(breakdown.enumerated()), id: \.element.type) { index, item in
                                HStack(alignment: .center, spacing: 11) {
                                    Image(systemName: item.type.symbolName)
                                        .font(.body)
                                        .foregroundStyle(Color.acoStudent)
                                        .frame(width: 24)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text(item.type.label)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.acoInk)
                                            Spacer()
                                            Text("\(item.hours) h")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(Color.acoStudent)
                                        }
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(Color(acoHex: "EFE8DC"))
                                                Capsule()
                                                    .fill(Color.acoStudent)
                                                    .frame(width: geo.size.width * Double(item.hours) / Double(maxH))
                                            }
                                            .frame(height: 7)
                                        }
                                        .frame(height: 7)
                                    }
                                }
                                .padding(.vertical, index == 0 ? 0 : 7)
                                if index < breakdown.count - 1 {
                                    Divider().padding(.vertical, 7)
                                }
                            }
                        }
                    }

                    // Constancia
                    SectionLabel(text: "Constancia").padding(.top, 22)

                    AcoCard(padding: 0) {
                        VStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("CONSTANCIA DE SERVICIO")
                                            .font(.system(size: 11, weight: .bold))
                                            .tracking(1)
                                            .foregroundStyle(Color.acoInk3)
                                        Text("Carlos Méndez")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.acoInk)
                                        Text("UNAM · Medicina")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.acoInk2)
                                    }
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .strokeBorder(Color.acoStudent, lineWidth: 2)
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "medal.fill")
                                            .font(.title3)
                                            .foregroundStyle(Color.acoStudent)
                                            .accessibilityHidden(true)
                                    }
                                }
                                Divider()
                                    .padding(.top, 14)
                                    .background(Color.clear)
                                    .overlay(alignment: .top) {
                                        Rectangle()
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                            .foregroundStyle(Color.acoHair)
                                    }

                                HStack(spacing: 18) {
                                    certStat(value: "\(totalHours) h", label: "verificadas")
                                    certStat(value: "4.9 ★",          label: "promedio")
                                    certStat(value: "32",              label: "visitas")
                                }
                                .padding(.top, 14)
                            }
                            .padding(18)
                            .background(
                                LinearGradient(colors: [Color(acoHex: "FCFAF7"), .white], startPoint: .bottom, endPoint: .top)
                            )

                            VStack(spacing: 10) {
                                Button {} label: {
                                    Label("Descargar para mi escuela", systemImage: "arrow.down.circle.fill")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(Color.acoStudent)
                                        .clipShape(.rect(cornerRadius: 13))
                                }

                                Label("Todas las horas verificadas por GPS — sin firmas", systemImage: "antenna.radiowaves.left.and.right")
                                    .font(.caption2)
                                    .foregroundStyle(Color.acoInk3)
                            }
                            .padding(14)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Mis horas")
        .navigationBarTitleDisplayMode(.large)
    }

    private func inlineStat(symbol: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.acoStudent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundStyle(Color.acoInk)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Color.acoInk2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func certStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.title3)
                .fontWeight(.heavy)
                .foregroundStyle(Color.acoInk)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.acoInk3)
        }
    }
}

#Preview {
    NavigationStack {
        StudentHoursView()
    }
}
