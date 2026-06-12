import SwiftUI

struct ElderlyVisitView: View {
    @State private var isOnWay: Bool = true
    @State private var hasArrived: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let studentName = "Carlos"
    private let studentFullName = "Carlos Méndez"

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Top label
                Text("Hoy te visita")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.acoElderly)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 0) {
                        // Big avatar with optional pulse ring
                        ZStack {
                            if isOnWay && !hasArrived && !reduceMotion {
                                PulseRing(color: .acoElderly)
                            }
                            AvatarView(name: studentFullName, tint: .acoElderly, size: 168)
                        }
                        .padding(.top, 6)
                        .frame(width: 220, height: 220)

                        Text(studentName)
                            .font(.system(size: 44, weight: .heavy))
                            .foregroundStyle(Color.acoInk)
                            .tracking(-1)
                            .padding(.top, 22)

                        Text("Estudiante de la UNAM")
                            .font(.title3)
                            .foregroundStyle(Color.acoInk2)
                            .padding(.top, 4)

                        // Activity summary card
                        VStack(spacing: 10) {
                            Text("🛒")
                                .font(.system(size: 48))
                                .accessibilityHidden(true)
                            Text("Te va a ayudar con\nel mandado del super")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.acoInk)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 22)
                        .background(Color.acoElderlySoft)
                        .clipShape(.rect(cornerRadius: 22))
                        .padding(.horizontal, 24)
                        .padding(.top, 26)

                        // Status
                        if isOnWay && !hasArrived {
                            onWayStatus
                                .padding(.top, 26)
                                .padding(.horizontal, 24)
                        } else if !isOnWay {
                            scheduledArrivalTime
                                .padding(.top, 26)
                        }

                        Spacer().frame(height: 20)
                    }
                }
                .scrollIndicators(.hidden)

                // Bottom action
                VStack(spacing: 14) {
                    Divider()
                    if !hasArrived {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                hasArrived = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text("👋").font(.system(size: 32)).accessibilityHidden(true)
                                Text("Ya llegó")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 26)
                            .background(Color.acoElderly)
                            .clipShape(.rect(cornerRadius: 24))
                            .shadow(color: Color.acoElderly.opacity(0.42), radius: 11, y: 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ya llegó Carlos")
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
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var onWayStatus: some View {
        HStack(spacing: 12) {
            PulsingDot(color: .acoElderly, pulse: true, size: 16)
            Text("Carlos va en camino")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.acoElderly)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color(acoHex: "FBEDE2"))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var scheduledArrivalTime: some View {
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

    private var arrivedConfirmation: some View {
        VStack(spacing: 14) {
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

// Separate pulsing ring view to keep ElderlyVisitView's body cleaner
private struct PulseRing: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 5)
            .frame(width: 188, height: 188)
            .scaleEffect(animating ? 1.18 : 1)
            .opacity(animating ? 0 : 0.7)
            .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: animating)
            .onAppear { animating = true }
    }
}

#Preview {
    NavigationStack {
        ElderlyVisitView()
    }
}
