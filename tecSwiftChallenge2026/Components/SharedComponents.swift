import SwiftUI

// MARK: - AvatarView
struct AvatarView: View {
    let name: String
    let tint: Color
    var size: CGFloat = 44
    var ring: Bool = false

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
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
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
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(isActive ? .white : tint)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(isActive ? tint : soft)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BadgeLabel
struct BadgeLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.3)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.11))
            .clipShape(.rect(cornerRadius: 6))
    }
}

// MARK: - StarRating (display)
struct StarRating: View {
    let value: Double
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(1 ... 5, id: \.self) { i in
                Text("★")
                    .font(.system(size: size))
                    .foregroundStyle(i <= Int(value.rounded()) ? Color.acoStar : Color(acoHex: "E2D8CC"))
            }
        }
    }
}

// MARK: - AcoCard
// Radius reducido 20→14, superficie levemente más cálida, sombra más sutil
struct AcoCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(Color(acoHex: "FDFBF8"))
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: Color(acoHex: "2A1F14").opacity(0.07), radius: 8, x: 0, y: 3)
            .shadow(color: Color(acoHex: "2A1F14").opacity(0.03), radius: 1, x: 0, y: 1)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(acoHex: "3C3228").opacity(0.055), lineWidth: 1)
            }
    }
}

// MARK: - CTAButton
struct CTAButton: View {
    let label: String
    var leadingEmoji: String? = nil
    let tint: Color
    var big: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let e = leadingEmoji { Text(e).font(.system(size: big ? 20 : 17)) }
                Text(label)
                    .font(.system(size: big ? 20 : 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, big ? 18 : 16)
            .background(disabled ? Color(acoHex: "D8CFC4") : tint)
            .clipShape(.rect(cornerRadius: big ? 20 : 15))
            .shadow(color: disabled ? .clear : tint.opacity(0.32), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - SectionLabel
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(Color.acoInk3)
            .padding(.bottom, 10)
            .padding(.horizontal, 2)
    }
}

// MARK: - UniversityBadge
struct UniversityBadge: View {
    let university: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text("🎓").font(.system(size: 11))
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
