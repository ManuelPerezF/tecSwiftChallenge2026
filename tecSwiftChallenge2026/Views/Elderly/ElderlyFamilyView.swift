import SwiftUI

struct ElderlyFamilyView: View {
    @AppStorage("aco_joinedFamily") private var joinedFamily: Bool = false
    @AppStorage("aco_familyCode") private var cachedFamilyCode: String = ""

    @State private var family: FamilyInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?

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
    }

    // MARK: - Vinculado

    private var linkedContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.body).foregroundStyle(Color.acoUrgent)
                }

                linkedHero

                if let elderly = family?.elderly.first {
                    AcoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TU PERFIL")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(Color.acoInk3)
                            HStack(spacing: 12) {
                                AvatarView(name: elderly.firstName, tint: .acoElderly, size: 52)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(elderly.firstName)
                                        .font(.title3).fontWeight(.bold).foregroundStyle(Color.acoInk)
                                    Text(elderly.address)
                                        .font(.body).foregroundStyle(Color.acoInk2)
                                    Text(elderly.neighborhood)
                                        .font(.subheadline).foregroundStyle(Color.acoInk3)
                                }
                            }
                        }
                    }
                }

                AcoCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Todo listo", systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(Color.acoDone)
                        Text("Cuando tu familia programe una visita, la verás en la pestaña **Mis visitas**.")
                            .font(.body).foregroundStyle(Color.acoInk2)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
    }

    private var linkedHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.acoElderlySoft).frame(width: 88, height: 88)
                Text("👨‍👩‍👧").font(.system(size: 40)).accessibilityHidden(true)
            }

            Text("Estás vinculado")
                .font(.title2).fontWeight(.bold).foregroundStyle(Color.acoInk)

            if let name = family?.name {
                Text(name)
                    .font(.title3).foregroundStyle(Color.acoInk2)
            }

            if !displayCode.isEmpty {
                Text("Código: \(displayCode)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.acoElderly)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.acoElderlySoft)
                    .clipShape(.capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var displayCode: String {
        family?.familyCode ?? cachedFamilyCode
    }

    private func handleJoined() {
        joinedFamily = true
        Task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let info = try await APIClient.shared.fetchMyFamily()
            family = info
            cachedFamilyCode = info.familyCode
            joinedFamily = true
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

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                ZStack {
                    Circle().fill(Color.acoElderlySoft).frame(width: 110, height: 110)
                    Text("👨‍👩‍👧").font(.system(size: 48)).accessibilityHidden(true)
                }
                .padding(.bottom, 24)

                Text("Únete a tu familia")
                    .font(.title).bold().foregroundStyle(Color.acoInk)

                Text("Pide a tu familiar el código\nde 6 letras y escríbelo aquí.")
                    .font(.title3).foregroundStyle(Color.acoInk3)
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
                            .strokeBorder(Color.acoElderly.opacity(0.4), lineWidth: 2)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 28)
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.uppercased().prefix(6))
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.body).foregroundStyle(Color.acoUrgent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14).padding(.horizontal, 40)
                }

                Button(action: join) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Unirme a mi familia")
                                .font(.title3).fontWeight(.bold)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(code.count == 6 && !isLoading ? Color.acoElderly : Color.acoInk.opacity(0.18))
                    .clipShape(.rect(cornerRadius: 16))
                }
                .disabled(code.count != 6 || isLoading)
                .padding(.horizontal, 40)
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 10) {
                    Text("¿DÓNDE LO ENCUENTRO?")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.acoInk3)
                    Text("Tu familiar lo ve en la app, pestaña **Mi familia**, en letras grandes.")
                        .font(.body).foregroundStyle(Color.acoInk2)
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)

                Spacer().frame(height: 40)
            }
        }
        .scrollIndicators(.hidden)
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

