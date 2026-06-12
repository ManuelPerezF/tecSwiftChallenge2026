import SwiftUI

private let visitSteps = ["En camino", "Llegué", "Tareas", "Terminé"]

struct StudentCommitmentsView: View {
    @State private var stepsByCommitment: [String: Int] = ["c1": 1, "c2": 0]

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(sampleCommitments) { commitment in
                        CommitmentCard(
                            commitment: commitment,
                            currentStep: stepsByCommitment[commitment.id, default: 0],
                            onAdvance: {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    let current = stepsByCommitment[commitment.id, default: 0]
                                    stepsByCommitment[commitment.id] = min(current + 1, 4)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Mis visitas")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct CommitmentCard: View {
    let commitment: CommitmentItem
    let currentStep: Int
    let onAdvance: () -> Void

    private var isDone: Bool { currentStep >= 4 }

    var body: some View {
        AcoCard(padding: 0) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 13) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.acoStudentSoft)
                                .frame(width: 48, height: 48)
                            Text(commitment.activityType.emoji)
                                .font(.system(size: 25))
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(commitment.title)
                                .font(.headline).foregroundStyle(Color.acoInk)
                            Text("\(commitment.elderlyName) · \(commitment.time)")
                                .font(.subheadline).foregroundStyle(Color.acoInk2)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("📍").font(.subheadline).accessibilityHidden(true)
                        Text(commitment.address)
                            .font(.subheadline).foregroundStyle(Color.acoInk)
                    }
                    .padding(10)
                    .background(Color(acoHex: "FCFAF7"))
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(.top, 12)

                    StepProgressBar(steps: visitSteps, currentStep: currentStep)
                        .padding(.top, 14)
                }
                .padding(16)

                Divider()
                actionFooter
                    .padding(14)
                    .background(isDone ? Color(acoHex: "F6FAEF") : Color(acoHex: "FCFAF7"))
            }
        }
    }

    @ViewBuilder
    private var actionFooter: some View {
        if isDone {
            Label("Visita completada · +1 h registrada", systemImage: "checkmark.circle.fill")
                .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.acoDone)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            VStack(spacing: 8) {
                Button(action: onAdvance) {
                    Label(stepActionLabel, systemImage: stepActionIcon)
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.acoStudent).clipShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                if currentStep == 1 {
                    Text("Tu llegada se valida automáticamente por GPS")
                        .font(.caption2).foregroundStyle(Color.acoInk3)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var stepActionLabel: String {
        switch currentStep {
        case 0: "Voy en camino"
        case 1: "Hacer check-in (GPS)"
        case 2: "Confirmar tareas"
        case 3: "Ya terminé"
        default: "Avanzar"
        }
    }

    private var stepActionIcon: String {
        switch currentStep {
        case 0: "figure.walk"
        case 1: "location.fill"
        case 2: "checkmark.square"
        case 3: "party.popper"
        default: "arrow.right"
        }
    }
}

private struct StepProgressBar: View {
    let steps: [String]
    let currentStep: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(index < currentStep ? Color.acoStudent : Color(acoHex: "E7DECF"))
                        .frame(height: 5)
                        .animation(.easeInOut(duration: 0.22), value: currentStep)
                    Text(step)
                        .font(.system(size: 10))
                        .fontWeight(index == currentStep ? .bold : .regular)
                        .foregroundStyle(
                            index < currentStep ? Color.acoStudent
                            : index == currentStep ? Color.acoInk
                            : Color.acoInk3
                        )
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    NavigationStack { StudentCommitmentsView() }
}
