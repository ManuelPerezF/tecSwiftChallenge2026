import SwiftUI

// MARK: - AvatarView
struct AvatarView: View {
    let name: String
    let tint: Color
    var size: CGFloat = 44
    var ring: Bool = false

    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 44

    private var displaySize: CGFloat { max(size, scaledSize) }

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
    }

    var body: some View {
        ZStack {
            Circle().fill(tint)
            Text(initials)
                .font(.system(size: displaySize * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: displaySize, height: displaySize)
        .overlay {
            if ring {
                Circle()
                    .strokeBorder(Color.acoBg, lineWidth: 4)
                    .overlay {
                        Circle().strokeBorder(tint.opacity(0.22), lineWidth: 2)
                    }
            }
        }
        .accessibilityLabel(name)
        .accessibilityHidden(true)
    }
}

// MARK: - PulsingDot
struct PulsingDot: View {
    let color: Color
    var pulse: Bool = false
    var size: CGFloat = 9

    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if pulse && !reduceMotion {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .scaleEffect(animating ? 1.9 : 1)
                    .opacity(animating ? 0 : 0.55)
                    .animation(
                        .easeOut(duration: 1.8).repeatForever(autoreverses: false),
                        value: animating
                    )
                    .onAppear { animating = true }
            }
            Circle().fill(color).frame(width: size, height: size)
        }
    }
}

// MARK: - ChipButton
struct ChipButton: View {
    let label: String
    let tint: Color
    var soft: Color = Color(acoHex: "F0EAE2")
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isActive ? .white : tint)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(isActive ? tint : soft)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - BadgeLabel
struct BadgeLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - StarRating (display)
struct StarRating: View {
    let value: Double
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1 ... 5, id: \.self) { i in
                Image(systemName: i <= Int(value.rounded()) ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i <= Int(value.rounded()) ? Color.acoStar : Color.acoInk3.opacity(0.35))
            }
        }
        .accessibilityLabel("\(Int(value.rounded())) de 5 estrellas")
    }
}

// MARK: - AcoCard
struct AcoCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .acoGroupedSurface()
    }
}

// MARK: - AcoFormField

struct AcoFormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AcoSpacing.xs) {
            AcoTypography.fieldLabel(label)
            content()
        }
    }
}

/// Campos apilados con divisores, estilo formulario iOS.
struct AcoGroupedFields<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, AcoSpacing.md)
        .acoGroupedSurface()
    }
}

// MARK: - AcoEmptyState

struct AcoEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var tint: Color = .acoFamily
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        } description: {
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.acoInk2)
        } actions: {
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
            }
        }
        .padding(.horizontal, AcoSpacing.lg)
    }
}

// MARK: - CTAButton
struct CTAButton: View {
    let label: String
    var leadingSymbol: String? = nil
    let tint: Color
    var big: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            guard !disabled else { return }
            KuidarHaptic.light()
            action()
        } label: {
            HStack(spacing: 9) {
                if let s = leadingSymbol {
                    Image(systemName: s).font(.body.weight(.semibold))
                }
                Text(label)
                    .font(big ? .title3.weight(.semibold) : .body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(disabled ? Color.acoInk3.opacity(0.35) : tint)
            .clipShape(.rect(cornerRadius: AcoRadius.md, style: .continuous))
        }
        .buttonStyle(AcoPressStyle())
        .disabled(disabled)
        .accessibilityHint(disabled ? "Completa los campos requeridos" : "")
    }
}

// MARK: - SectionLabel
struct SectionLabel: View {
    let text: String

    var body: some View {
        AcoTypography.sectionHeader(text)
    }
}

// MARK: - UniversityBadge
struct UniversityBadge: View {
    let university: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "graduationcap.fill").font(.system(size: 11))
                .foregroundStyle(color)
            Text(university)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 6))
    }
}

// MARK: - KuidarLogoView

struct KuidarLogoView: View {
    var height: CGFloat = 100
    var maxWidth: CGFloat? = nil
    var animate: Bool = false

    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("KuidarLogo")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: maxWidth)
            .frame(height: height)
            .scaleEffect(animate && breathe && !reduceMotion ? 1.04 : 1)
            .animation(
                animate && !reduceMotion
                    ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
                    : .default,
                value: breathe
            )
            .onAppear {
                if animate && !reduceMotion { breathe = true }
            }
            .accessibilityLabel("Kuidar")
    }
}

// MARK: - AcoMapMarker

struct AcoMapMarker: View {
    let symbol: String
    let color: Color
    var isSelected: Bool = false
    var pulse: Bool = false
    var size: CGFloat = 44

    @State private var ringPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if (pulse || isSelected) && !reduceMotion {
                Circle()
                    .stroke(color.opacity(0.35), lineWidth: 2)
                    .frame(width: size * 1.45, height: size * 1.45)
                    .scaleEffect(ringPulse ? 1.15 : 0.85)
                    .opacity(ringPulse ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                        value: ringPulse
                    )
                    .onAppear { ringPulse = true }
            }

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: size, height: size)
                    Circle()
                        .strokeBorder(color, lineWidth: isSelected ? 3 : 2)
                        .frame(width: size, height: size)
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(color)
                }
                PinPointer()
                    .fill(color)
                    .frame(width: size * 0.26, height: size * 0.16)
                    .offset(y: -3)
            }
            .shadow(
                color: color.opacity(isSelected ? 0.42 : 0.22),
                radius: isSelected ? 14 : 7,
                y: isSelected ? 6 : 3
            )
            .scaleEffect(isSelected ? 1.1 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
        }
        .accessibilityHidden(true)
    }
}

private struct PinPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - BadgeCard
struct BadgeCard: View {
    let badge: APIBadge

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(badge.icon)
                .font(.system(size: 30))
            Text(badge.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.acoInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(badge.description)
                .font(.caption2)
                .foregroundStyle(Color.acoInk2)
                .lineLimit(3)
        }
        .padding(13)
        .frame(width: 130, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: AcoRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AcoRadius.md, style: .continuous)
                .strokeBorder(Color.acoHair, lineWidth: 0.5)
        }
    }
}

// MARK: - RatingRow
struct RatingRow: View {
    let rating: APIRating

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
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
        .padding(.vertical, 2)
    }
}

// MARK: - StatusRow
struct StatusRow: View {
    let status: RequestStatus
    let eta: String?

    var statusColor: Color {
        switch status {
        case .open:       .acoInk3
        case .claimed:    .acoFamily
        case .inProgress: .acoStudent
        case .completed:  .acoDone
        case .cancelled:  .acoInk3
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            PulsingDot(color: statusColor, pulse: status == .inProgress, size: 8)
            Text(status.label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(statusColor)
            if let eta {
                Text("· \(eta)")
                    .font(.caption)
                    .foregroundStyle(Color.acoInk3)
            }
        }
    }
}
