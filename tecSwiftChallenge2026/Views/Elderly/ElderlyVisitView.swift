import SwiftUI

enum ElderlyDestination: Hashable {
    case rating
}

struct ElderlyVisitView: View {
    @State private var isOnWay: Bool = true
    @State private var hasArrived: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let studentName     = "Carlos"
    private let studentFullName = "Carlos Méndez"
    private let initials        = "CM"

    var body: some View {
        VStack(spacing: 0) {
            studentHeader
            scrollContent
            actionZone
        }
        .background(Color.acoBg.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header — naranja comprometido

    private var studentHeader: some View {
        ZStack(alignment: .bottom) {
            Color.acoElderly.ignoresSafeArea(edges: .top)

            VStack(spacing: 10) {
                // Avatar con ring pulsante
                ZStack {
                    if isOnWay && !hasArrived && !reduceMotion {
                        PulseRing(color: .white.opacity(0.45))
                    }
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 86, height: 86)
                    Text(initials)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 106, height: 106)

                VStack(spacing: 6) {
                    Text(studentName)
                        .font(.system(size: 44, weight: .heavy))
                        .foregroundStyle(.white)
                        .tracking(-0.5)
                    Text("Estudiante de la UNAM")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 64)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Actividad
                VStack(spacing: 10) {
                    Text("🛒")
                        .font(.system(size: 42))
                        .accessibilityHidden(true)
                    Text("Te va a ayudar con\nel mandado del super")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.acoInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(Color.acoElderlySoft)
                .clipShape(.rect(cornerRadius: 14))

                // Estado
                if isOnWay && !hasArrived {
                    onWayStatus
                } else if !isOnWay {
                    scheduledTime
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private var onWayStatus: some View {
        HStack(spacing: 12) {
            PulsingDot(color: .acoElderly, pulse: true, size: 13)
            Text("Carlos va en camino")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.acoElderly)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color(acoHex: "FBEDE2"))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var scheduledTime: some View {
        VStack(spacing: 4) {
            Text("Llega a las")
                .font(.title3)
                .foregroundStyle(Color.acoInk2)
            Text("10:30")
                .font(.system(size: 58, weight: .heavy))
                .foregroundStyle(Color.acoInk)
                .tracking(-2)
            Text("de la mañana")
                .font(.title3)
                .foregroundStyle(Color.acoInk2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Zona de acción fija

    private var actionZone: some View {
        VStack(spacing: 14) {
            Rectangle()
                .fill(Color.acoHair)
                .frame(height: 1)
            if !hasArrived {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        hasArrived = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "hand.wave.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                        Text("Ya llegó")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Color.acoElderly)
                    .clipShape(.rect(cornerRadius: 20))
                    .shadow(color: Color.acoElderly.opacity(0.4), radius: 14, x: 0, y: 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ya llegó \(studentName)")
                .sensoryFeedback(.impact, trigger: hasArrived)
            } else {
                arrivedConfirmation
            }

            Text("Toca el botón cuando \(studentName) toque la puerta")
                .font(.body)
                .foregroundStyle(Color.acoInk3)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .background(Color.acoBg)
    }

    private var arrivedConfirmation: some View {
        VStack(spacing: 16) {
            Label("¡Llegada confirmada!", systemImage: "checkmark.circle.fill")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.acoDone)

            NavigationLink(value: ElderlyDestination.rating) {
                Text("Al terminar, calificar a \(studentName) →")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.acoElderly)
                    .underline()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Pulse ring

private struct PulseRing: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 4)
            .frame(width: 102, height: 102)
            .scaleEffect(animating ? 1.20 : 1)
            .opacity(animating ? 0 : 0.65)
            .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: animating)
            .onAppear { animating = true }
    }
}

#Preview {
    NavigationStack {
        ElderlyVisitView()
    }
}
