import SwiftUI

struct RolePickerView: View {
    let onSelect: (AppRole) -> Void

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Wordmark — sin icon-box, sin gradient
                VStack(alignment: .leading, spacing: 6) {
                    Text("🤝 Acompaña")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundStyle(Color.acoInk)
                        .tracking(-0.6)
                    Text("Abuelitos + estudiantes")
                        .font(.subheadline)
                        .foregroundStyle(Color.acoInk3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 76)
                .padding(.bottom, 48)

                Text("¿Quién eres?")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Color.acoInk3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)

                // Roles: rows full-width, sin chrome de card
                VStack(spacing: 0) {
                    ForEach(Array(AppRole.allCases.enumerated()), id: \.element) { idx, role in
                        if idx > 0 {
                            Rectangle()
                                .fill(Color.acoHair)
                                .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
                        }
                        RoleRow(role: role, onSelect: onSelect)
                    }
                }

                Spacer()

                Text("Las pantallas son interactivas — toca tarjetas, botones y estrellas para recorrer el flujo.")
                    .font(.caption2)
                    .foregroundStyle(Color.acoInk3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
            }
        }
    }
}

private struct RoleRow: View {
    let role: AppRole
    let onSelect: (AppRole) -> Void

    var body: some View {
        Button { onSelect(role) } label: {
            HStack(spacing: 18) {
                Text(role.emoji)
                    .font(.system(size: 46))
                    .frame(width: 52, alignment: .center)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(role.title)
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(role.tint)
                    Text(role.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.acoInk2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(role.tint.opacity(0.4))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle(soft: role.soft))
        .accessibilityLabel("\(role.title), \(role.subtitle)")
    }
}

private struct RowPressStyle: ButtonStyle {
    let soft: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? soft : Color.clear)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

#Preview {
    RolePickerView { _ in }
}
