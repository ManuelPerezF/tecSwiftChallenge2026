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
        VStack(alignment: .leading, spacing: 16) {
            Text("Cómo funciona")
                .font(.title2).bold()
                .foregroundStyle(Color.acoInk)
                .accessibilityAddTraits(.isHeader)

            instructionRow(number: "1", text: "Tu familia agenda una visita para ti desde su app.")
            instructionRow(number: "2", text: "Un becario universitario acepta ayudarte.")
            instructionRow(number: "3", text: "En cuanto lo acepten, la visita aparece en **Mis visitas** con su nombre y hora.")
            instructionRow(number: "4", text: "El día de la visita podrás seguirlo en el mapa.")
        }
    }

    private func instructionRow(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.body)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.acoElderly)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(.title3)
                .foregroundStyle(Color.acoInk)
                .lineSpacing(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Paso \(number)")
    }

    private func sectionLabel(_ text: String) -> some View {
        AcoTypography.sectionHeader(text)
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

// MARK: - Perfil del adulto mayor (icono arriba a la izquierda)
// Lectura siempre; edición solo si la familia activó `allow_self_profile_edit` (3.16).

struct ElderlyProfileView: View {
    let onLogout: () -> Void

    @AppStorage("aco_elderlyProfileId") private var myProfileId: String = ""
    @AppStorage("aco_userName") private var userName: String = ""
    @Environment(\.dismiss) private var dismiss

    @State private var family: FamilyInfo?
    @State private var isEditing = false
    @State private var errorMessage: String?

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
        NavigationStack {
            ZStack {
                Color.acoBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        if let profile = myProfile {
                            infoCard(profile)

                            if profile.selfEditAllowed {
                                Button {
                                    isEditing = true
                                } label: {
                                    Label("Editar mi perfil", systemImage: "pencil")
                                        .font(.title3).fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.acoElderly)
                                        .clipShape(.rect(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $isEditing) {
                                    ElderlyEditSheet(person: profile, isFamilyEditor: false) {
                                        await load()
                                    }
                                }
                            } else {
                                Label("Tu familia administra tu perfil. Pídeles ayuda si quieres cambiar algo.", systemImage: "lock.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.acoInk3)
                            }
                        } else if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.body).foregroundStyle(Color.acoUrgent)
                        } else {
                            ProgressView("Cargando…").tint(Color.acoElderly)
                                .frame(maxWidth: .infinity)
                        }

                        logoutSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Mi perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.acoInk3)
                }
            }
        }
        .task { await load() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            AvatarView(name: myProfile?.firstName ?? userName, tint: .acoElderly, size: 84)
            Text(myProfile?.firstName ?? userName)
                .font(.title).bold()
                .foregroundStyle(Color.acoInk)
            if let age = myProfile?.age {
                Text("\(age) años")
                    .font(.title3)
                    .foregroundStyle(Color.acoInk2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
    }

    private func infoCard(_ profile: ElderlySummary) -> some View {
        AcoCard {
            VStack(alignment: .leading, spacing: 14) {
                infoRow(icon: "house.fill", label: "Dirección",
                        value: profile.address.isEmpty ? "Sin registrar" : profile.address)
                Divider()
                infoRow(icon: "mappin.and.ellipse", label: "Colonia",
                        value: profile.neighborhood.isEmpty ? "Sin registrar" : profile.neighborhood)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Label("Mis gustos", systemImage: "heart.fill")
                        .font(.body).fontWeight(.semibold)
                        .foregroundStyle(Color.acoElderly)
                    if profile.tagList.isEmpty {
                        Text("Aún no hay gustos registrados.")
                            .font(.body).foregroundStyle(Color.acoInk3)
                    } else {
                        FlowTags(tags: profile.tagList, tint: .acoElderly)
                    }
                }
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.acoElderly)
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline).foregroundStyle(Color.acoInk3)
                Text(value)
                    .font(.title3).foregroundStyle(Color.acoInk)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var logoutSection: some View {
        Button(role: .destructive) {
            dismiss()
            onLogout()
        } label: {
            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.title3).fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .padding(.top, 12)
    }

    private func load() async {
        errorMessage = nil
        do {
            family = try await APIClient.shared.fetchMyFamily()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Sin vincular") {
    NavigationStack { ElderlyFamilyView() }
}
#Preview("Formulario") {
    NavigationStack { ElderlyJoinFamilyForm(onJoined: {}) }
}
