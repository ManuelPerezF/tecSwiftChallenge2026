import SwiftUI

struct StudentMapView: View {
    @State private var selectedId: String = "o1"
    @State private var filterActivity: ActivityType? = nil

    private var filteredRequests: [OpenRequest] {
        guard let f = filterActivity else { return sampleOpenRequests }
        return sampleOpenRequests.filter { $0.activityType == f }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Map fills everything
            MapLayer(
                requests: filteredRequests,
                selectedId: selectedId,
                onPinTap: { selectedId = $0 }
            )
            .ignoresSafeArea(edges: .top)

            // Top filter bar
            VStack(alignment: .leading, spacing: 6) {
                Text("Cerca de ti")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.acoInk)
                    .shadow(color: Color(acoHex: "EAE3D7").opacity(0.9), radius: 6)

                Text("^[\(filteredRequests.count) solicitud](inflect: true) abierta")
                    .font(.subheadline)
                    .foregroundStyle(Color.acoInk2)
                    .shadow(color: Color(acoHex: "EAE3D7").opacity(0.9), radius: 4)

                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ChipButton(
                            label: "Todas",
                            tint: .acoStudent,
                            soft: Color.white.opacity(0.92),
                            isActive: filterActivity == nil
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                filterActivity = nil
                            }
                        }
                        ForEach(ActivityType.allCases, id: \.self) { act in
                            ChipButton(
                                label: "\(act.emoji) \(act.label.components(separatedBy: " ").first ?? act.label)",
                                tint: .acoStudent,
                                soft: Color.white.opacity(0.92),
                                isActive: filterActivity == act
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    filterActivity = act
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Legend (top-right)
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 7) {
                    MapLegendRow(color: .acoUrgent, label: "Urgente")
                    MapLegendRow(color: .acoMapPin, label: "Normal")
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(.regularMaterial)
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.10), radius: 5)
            }
            .padding(.trailing, 14)
            .padding(.top, 120)

            // Bottom sheet
            VStack {
                Spacer()
                MapBottomSheet(
                    filteredRequests: filteredRequests,
                    selectedId: $selectedId
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Map layer (background + pins using GeometryReader for % positioning)
private struct MapLayer: View {
    let requests: [OpenRequest]
    let selectedId: String
    let onPinTap: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                MapCanvasBackground()

                ForEach(requests) { req in
                    MapPinButton(
                        request: req,
                        isSelected: req.id == selectedId,
                        onTap: { onPinTap(req.id) }
                    )
                    .position(
                        x: w * req.xPct / 100,
                        y: h * req.yPct / 100
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(acoHex: "EAE3D7"))
    }
}

// MARK: - Stylised map drawn with Canvas (avoids nested GeometryReader)
private struct MapCanvasBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // Park 1 (bottom-left)
            ctx.fill(
                Path(roundedRect: CGRect(x: w*0.04, y: h*0.55, width: w*0.34, height: h*0.32), cornerRadius: 20),
                with: .color(Color(acoHex: "CDDCB6"))
            )
            // Park 2 (top-right)
            ctx.fill(
                Path(roundedRect: CGRect(x: w*0.68, y: h*0.06, width: w*0.26, height: h*0.22), cornerRadius: 18),
                with: .color(Color(acoHex: "CDDCB6"))
            )
            // Water triangle (bottom-right)
            var water = Path()
            water.move(to:    CGPoint(x: w*0.70, y: h))
            water.addLine(to: CGPoint(x: w,       y: h*0.72))
            water.addLine(to: CGPoint(x: w,       y: h))
            water.closeSubpath()
            ctx.fill(water, with: .color(Color(acoHex: "BAD3E0")))

            // Horizontal roads
            for t: CGFloat in [0.18, 0.44, 0.70] {
                ctx.fill(Path(CGRect(x: 0, y: h*t-6, width: w, height: 12)),
                         with: .color(Color(acoHex: "F6F1E9")))
            }
            // Vertical roads
            for l: CGFloat in [0.26, 0.52, 0.78] {
                ctx.fill(Path(CGRect(x: w*l-6, y: 0, width: 12, height: h)),
                         with: .color(Color(acoHex: "F6F1E9")))
            }
            // Diagonal avenue (14° strip computed as parallelogram)
            let tanAngle = CGFloat(tan(14.0 * Double.pi / 180))
            let roadBaseY = h * 0.20
            let x0: CGFloat = -w * 0.1
            let x1: CGFloat = w * 1.1
            var diag = Path()
            diag.move(to:    CGPoint(x: x0, y: roadBaseY + x0 * tanAngle - 7))
            diag.addLine(to: CGPoint(x: x1, y: roadBaseY + x1 * tanAngle - 7))
            diag.addLine(to: CGPoint(x: x1, y: roadBaseY + x1 * tanAngle + 7))
            diag.addLine(to: CGPoint(x: x0, y: roadBaseY + x0 * tanAngle + 7))
            diag.closeSubpath()
            ctx.fill(diag, with: .color(Color(acoHex: "F6F1E9")))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(acoHex: "EAE3D7"))
    }
}

// MARK: - Map pin button
private struct MapPinButton: View {
    let request: OpenRequest
    let isSelected: Bool
    let onTap: () -> Void

    private var pinColor: Color { request.isUrgent ? .acoUrgent : .acoMapPin }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: 38, height: 38)
                    .overlay {
                        Circle().strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2.5)
                    }
                Text(request.activityType.emoji)
                    .font(.system(size: 18))
                    .accessibilityHidden(true)
            }
            .shadow(
                color: isSelected ? pinColor.opacity(0.45) : .black.opacity(0.25),
                radius: isSelected ? 10 : 5,
                y: 3
            )
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(request.activityType.label), \(request.neighborhood), \(request.isUrgent ? "urgente" : "normal")"
        )
    }
}

// MARK: - Legend row
private struct MapLegendRow: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 11, height: 11)
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.acoInk2)
        }
    }
}

// MARK: - Bottom sheet
private struct MapBottomSheet: View {
    let filteredRequests: [OpenRequest]
    @Binding var selectedId: String

    private var selected: OpenRequest? {
        sampleOpenRequests.first { $0.id == selectedId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 999)
                .fill(Color(acoHex: "3C3228").opacity(0.18))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 4)

            // Selected callout
            if let req = selected {
                NavigationLink(value: req) {
                    SelectedRequestCallout(request: req)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            // Sort hint
            HStack(spacing: 5) {
                Text("✨").font(.caption).accessibilityHidden(true)
                Text("Ordenado por distancia y afinidad contigo")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.acoInk3)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)

            // Ranked list
            ScrollView {
                VStack(spacing: 9) {
                    ForEach(filteredRequests.sorted { $0.matchScore > $1.matchScore }) { req in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedId = req.id
                            }
                        } label: {
                            RankedRow(request: req, isSelected: req.id == selectedId)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 220)
        }
        .background(Color.acoBg)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
    }
}

private struct SelectedRequestCallout: View {
    let request: OpenRequest

    var body: some View {
        AcoCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Color.acoStudentSoft)
                        .frame(width: 46, height: 46)
                    Text(request.activityType.emoji).font(.system(size: 24)).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(request.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.acoInk)
                        if request.isUrgent {
                            BadgeLabel(text: "Urgente", color: .acoUrgent)
                        }
                    }
                    Text("📍 \(request.neighborhood) · \(request.distance) · \(request.timeWindow.shortLabel) · \(request.duration)")
                        .font(.caption)
                        .foregroundStyle(Color.acoInk2)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("+\(hoursFormatted(request.hours))")
                        .font(.title3).fontWeight(.heavy).foregroundStyle(Color.acoStudent)
                    Text("HRS").font(.caption2).fontWeight(.semibold).foregroundStyle(Color.acoInk3)
                }
            }
        }
    }
}

private struct RankedRow: View {
    let request: OpenRequest
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(request.activityType.emoji).font(.system(size: 23)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.title)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.acoInk).lineLimit(1)
                Text("\(request.neighborhood) · \(request.distance) · \(request.timeWindow.shortLabel)")
                    .font(.caption).foregroundStyle(Color.acoInk2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(hoursFormatted(request.hours)) h")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.acoStudent)
                Text("\(request.matchScore)% match")
                    .font(.caption2).fontWeight(.bold).foregroundStyle(Color.acoStudent)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.acoStudentSoft).clipShape(.rect(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(isSelected ? Color.acoStudentSoft : Color.white)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Color.acoStudent : Color(acoHex: "3C3228").opacity(0.05),
                              lineWidth: isSelected ? 1.5 : 1)
        }
        .accessibilityLabel("\(request.title), \(request.neighborhood), \(request.matchScore) por ciento")
    }
}

private func hoursFormatted(_ h: Double) -> String {
    h.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", h)
        : String(format: "%.1f", h)
}

#Preview {
    NavigationStack {
        StudentMapView()
    }
}
