import SwiftUI
import UIKit

struct FamilyManageView: View {
    @AppStorage("aco_familyCode") private var cachedFamilyCode: String = ""
    @AppStorage("aco_userName") private var userName: String = ""

    @State private var family: FamilyInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didCopy = false

    private var displayCode: String {
        family?.familyCode ?? cachedFamilyCode
    }

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if isLoading && family == nil {
                ProgressView("Cargando…").tint(Color.acoFamily)
            } else if let errorMessage, family == nil {
                errorState(errorMessage)
            } else {
                content
            }
        }
        .navigationTitle("Mi familia")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                codeHero
                howItWorks
                elderlySection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    private var codeHero: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(family?.name ?? "Tu familia")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.acoInk2)

                if !displayCode.isEmpty {
                    Text(displayCode)
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .tracking(8)
                        .foregroundStyle(Color.acoInk)
                        .padding(.vertical, 4)
                } else {
                    Text("— — — — — —")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.acoInk3)
                }

                Text("Código para vincular adultos mayores")
                    .font(.caption)
                    .foregroundStyle(Color.acoInk3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)

            Rectangle().fill(Color.acoHair).frame(height: 1)

            HStack(spacing: 0) {
                actionButton(
                    icon: didCopy ? "checkmark" : "doc.on.doc",
                    label: didCopy ? "Copiado" : "Copiar"
                ) {
                    copyCode()
                }

                Rectangle().fill(Color.acoHair).frame(width: 1, height: 44)

                ShareLink(item: shareMessage) {
                    VStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body)
                        Text("Compartir")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.acoFamily)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(Color.white)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.acoFamily.opacity(0.15), lineWidth: 1)
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("CÓMO FUNCIONA")

            instructionRow(number: "1", text: "Comparte el código con tu familiar adulto mayor.")
            instructionRow(number: "2", text: "En su app, entra a **Mi familia** y escribe el código.")
            instructionRow(number: "3", text: "Ya podrás publicar solicitudes para esa persona.")
        }
    }

    private var elderlySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ADULTOS MAYORES VINCULADOS")

            if let elderly = family?.elderly, !elderly.isEmpty {
                ForEach(elderly) { person in
                    elderlyCard(person)
                }
            } else {
                AcoCard {
                    VStack(spacing: 10) {
                        Text("🧓").font(.system(size: 36)).accessibilityHidden(true)
                        Text("Nadie vinculado aún")
                            .font(.headline).foregroundStyle(Color.acoInk)
                        Text("Comparte tu código para que un adulto mayor se una a tu familia.")
                            .font(.subheadline).foregroundStyle(Color.acoInk3)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func elderlyCard(_ person: ElderlySummary) -> some View {
        AcoCard(padding: 14) {
            HStack(spacing: 14) {
                AvatarView(name: person.firstName, tint: .acoElderly, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(person.firstName)
                        .font(.headline).foregroundStyle(Color.acoInk)
                    Text(person.neighborhood)
                        .font(.subheadline).foregroundStyle(Color.acoInk2)
                    Text(person.address)
                        .font(.caption).foregroundStyle(Color.acoInk3)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.acoDone)
            }
        }
    }

    private func instructionRow(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.acoFamily)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.acoInk2)
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.body)
                Text(label).font(.caption).fontWeight(.semibold)
            }
            .foregroundStyle(Color.acoFamily)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Color.acoInk3)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44)).foregroundStyle(Color.acoInk3)
            Text("No se pudo cargar tu familia")
                .font(.headline).foregroundStyle(Color.acoInk)
            Text(message)
                .font(.caption).foregroundStyle(Color.acoInk3)
                .multilineTextAlignment(.center)
            Button("Reintentar") { Task { await load() } }
                .font(.subheadline.bold()).foregroundStyle(Color.acoFamily)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Actions

    private var shareMessage: String {
        let name = userName.isEmpty ? "Tu familiar" : userName
        return "Hola, \(name) te invita a unirte a su familia en Kuidar. Descarga la app e ingresa este código: \(displayCode)"
    }

    private func copyCode() {
        guard !displayCode.isEmpty else { return }
        UIPasteboard.general.string = displayCode
        withAnimation(.easeOut(duration: 0.15)) { didCopy = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { didCopy = false }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let info = try await APIClient.shared.fetchMyFamily()
            family = info
            cachedFamilyCode = info.familyCode
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack { FamilyManageView() }
}
