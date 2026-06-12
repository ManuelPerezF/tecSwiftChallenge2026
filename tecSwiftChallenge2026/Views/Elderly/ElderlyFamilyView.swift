import SwiftUI

struct ElderlyFamilyView: View {
    @AppStorage("aco_joinedFamily") private var joinedFamily: Bool = false
    @AppStorage("aco_familyCode") private var cachedFamilyCode: String = ""
    @AppStorage("aco_elderlyProfileId") private var myProfileId: String = ""
    @AppStorage("aco_userName") private var userName: String = ""

    @State private var family: FamilyInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var contentVisible = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var displayCode: String {
        family?.familyCode ?? cachedFamilyCode
    }

    /// Perfil del adulto mayor logueado — no el primero de la familia.
    private var myProfile: ElderlySummary? {
        if !myProfileId.isEmpty,
           let match = family?.elderly.first(where: { $0.id == myProfileId }) {
            return match
        }
        if !userName.isEmpty,
           let match = family?.elderly.first(where: { $0.firstName == userName }) {
            return match
        }
        return nil
    }

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if isLoading && family == nil && joinedFamily {
                ProgressView("Cargando…").tint(Color.acoElderly)
            } else if !joinedFamily {
                ElderlyJoinFamilyForm(onJoined: handleJoined)
            } else {
                linkedContent
            }
        }
        .navigationTitle("Mi familia")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if joinedFamily { await load() }
        }
        .refreshable {
            if joinedFamily { await load() }
        }
        .onChange(of: joinedFamily) { _, linked in
            if linked { revealContent() }
        }
        .onAppear {
            if joinedFamily { revealContent() }
        }
    }

    // MARK: - Vinculado (misma estructura que FamilyManageView)

    private var linkedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.body)
                        .foregroundStyle(Color.acoUrgent)
                }

                codeHero
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 12)

                howItWorks
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 16)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.86).delay(0.06),
                        value: contentVisible
                    )

                profileSection
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.86).delay(0.1),
                        value: contentVisible
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    private var codeHero: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.acoDone)
                    Text("Estás vinculado")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.acoDone)
                }

                Text(family?.name ?? "Tu familia")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.acoInk)

                if !displayCode.isEmpty {
                    Text(displayCode)
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .tracking(8)
                        .foregroundStyle(Color.acoInk)
                        .padding(.vertical, 4)
                }

                Text("Código de tu familia")
                    .font(.caption)
                    .foregroundStyle(Color.acoInk3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Vinculado a \(family?.name ?? "tu familia"). Código \(displayCode)")
        }
        .background(Color.white)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.acoElderly.opacity(0.15), lineWidth: 1)
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("CÓMO FUNCIONA")

            instructionRow(number: "1", text: "Tu familia publica solicitudes desde su app.")
            instructionRow(number: "2", text: "Las verás en la pestaña **Mis visitas**.")
            instructionRow(number: "3", text: "Cuando el becario venga, podrás seguirlo en el mapa.")
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("TU PERFIL")

            if let profile = myProfile {
                profileCard(profile)
            } else {
                AcoCard {
                    HStack(spacing: 14) {
                        AvatarView(name: userName, tint: .acoElderly, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(userName.isEmpty ? "Tu perfil" : userName)
                                .font(.headline)
                                .foregroundStyle(Color.acoInk)
                            Text("Completa tu dirección con ayuda de tu familia.")
                                .font(.subheadline)
                                .foregroundStyle(Color.acoInk3)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func profileCard(_ person: ElderlySummary) -> some View {
        AcoCard(padding: 14) {
            HStack(spacing: 14) {
                AvatarView(name: person.firstName, tint: .acoElderly, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(person.firstName)
                        .font(.headline)
                        .foregroundStyle(Color.acoInk)
                    if !person.neighborhood.isEmpty {
                        Text(person.neighborhood)
                            .font(.subheadline)
                            .foregroundStyle(Color.acoInk2)
                    }
                    if !person.address.isEmpty {
                        Text(person.address)
                            .font(.caption)
                            .foregroundStyle(Color.acoInk3)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.acoDone)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tu perfil, \(person.firstName), \(person.address), \(person.neighborhood)")
    }

    private func instructionRow(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.acoElderly)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.acoInk2)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Color.acoInk3)
    }

    private func handleJoined() {
        joinedFamily = true
        Task { await load() }
    }

    private func revealContent() {
        guard !reduceMotion else {
            contentVisible = true
            return
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            contentVisible = true
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let info = try await APIClient.shared.fetchMyFamily()
            family = info
            cachedFamilyCode = info.familyCode
            joinedFamily = true
            revealContent()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Formulario unirse

struct ElderlyJoinFamilyForm: View {
    let onJoined: () -> Void

    @AppStorage("aco_familyCode") private var cachedFamilyCode: String = ""
    @AppStorage("aco_elderlyProfileId") private var myProfileId: String = ""

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var heroVisible = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 28)

                ZStack {
                    Circle()
                        .fill(Color.acoElderlySoft)
                        .frame(width: 120, height: 120)
                    Image(systemName: "person.2.badge.gearshape.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(Color.acoElderly)
                }
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1 : 0.9)
                .padding(.bottom, 22)

                Text("Únete a tu familia")
                    .font(.title)
                    .bold()
                    .foregroundStyle(Color.acoInk)

                Text("Pide a tu familiar el código\nde 6 letras y escríbelo aquí.")
                    .font(.title3)
                    .foregroundStyle(Color.acoInk3)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                TextField("CÓDIGO", text: $code)
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .tracking(6)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(Color.acoInk)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.acoElderly.opacity(code.count == 6 ? 0.55 : 0.3), lineWidth: 2)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 28)
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.uppercased().prefix(6))
                    }
                    .accessibilityLabel("Código de familia")

                if let errorMessage {
                    Text(errorMessage)
                        .font(.body)
                        .foregroundStyle(Color.acoUrgent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                        .padding(.horizontal, 40)
                }

                Button(action: join) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Unirme a mi familia")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(code.count == 6 && !isLoading ? Color.acoElderly : Color.acoInk.opacity(0.18))
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(
                        color: code.count == 6 ? Color.acoElderly.opacity(0.28) : .clear,
                        radius: 10,
                        y: 4
                    )
                }
                .disabled(code.count != 6 || isLoading)
                .padding(.horizontal, 40)
                .padding(.top, 22)
                .animation(.easeOut(duration: 0.2), value: code.count)

                AcoCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("¿Dónde lo encuentro?", systemImage: "questionmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.acoElderly)
                        Text("Tu familiar lo ve en la app, pestaña **Mi familia**, en letras grandes.")
                            .font(.body)
                            .foregroundStyle(Color.acoInk2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)

                Spacer().frame(height: 40)
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            guard !reduceMotion else {
                heroVisible = true
                return
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                heroVisible = true
            }
        }
    }

    private func join() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let info = try await APIClient.shared.joinFamily(code: code)
                cachedFamilyCode = info.familyCode
                onJoined()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview("Sin vincular") {
    NavigationStack { ElderlyFamilyView() }
}
#Preview("Formulario") {
    NavigationStack { ElderlyJoinFamilyForm(onJoined: {}) }
}
