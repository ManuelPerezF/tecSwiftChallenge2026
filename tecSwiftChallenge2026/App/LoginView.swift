import SwiftUI

struct LoginView: View {
    @AppStorage("aco_authToken")  private var savedToken: String = ""
    @AppStorage("aco_userName")   private var savedName: String = ""
    @AppStorage("aco_userRole")   private var savedRoleRaw: String = ""
    @AppStorage("aco_familyCode") private var savedFamilyCode: String = ""
    @AppStorage("aco_joinedFamily") private var joinedFamily: Bool = false
    @AppStorage("aco_elderlyProfileId") private var savedElderlyProfileId: String = ""
    @AppStorage("aco_studentId") private var savedStudentId: String = ""
    @AppStorage("aco_userId")    private var savedUserId: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = true
    @State private var formVisible = false
    @State private var splashLogoVisible = false
    @State private var splashTaglineVisible = false
    @State private var splashRingScale: CGFloat = 0.6
    @State private var splashRingOpacity: CGFloat = 0

    @State private var isRegistering = false

    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var selectedRole: AppRole = .family

    @State private var universities: [University] = []
    @State private var selectedUniversityId: String?
    @State private var career = ""

    @State private var familyName = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, email, password, career, familyName }

    private var canSubmit: Bool {
        let base = !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !isLoading
        guard isRegistering else { return base }
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let studentOk = selectedRole != .student || selectedUniversityId != nil
        return base && hasName && studentOk
    }

    private var brandHeaderFill: Color { .acoFamily }

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            if showSplash {
                splash
            } else {
                loginScreen
            }
        }
        .task {
            if reduceMotion {
                splashLogoVisible = true
                splashTaglineVisible = true
                showSplash = false
                formVisible = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
                    splashLogoVisible = true
                    splashRingScale = 1
                    splashRingOpacity = 1
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
                    splashTaglineVisible = true
                }
                try? await Task.sleep(for: .seconds(1.35))
                withAnimation(.spring(response: 0.65, dampingFraction: 0.85)) {
                    showSplash = false
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                    formVisible = true
                }
            }
            if universities.isEmpty {
                universities = (try? await APIClient.shared.fetchUniversities()) ?? []
                if selectedUniversityId == nil { selectedUniversityId = universities.first?.id }
            }
        }
    }

    // MARK: - Splash

    private var splash: some View {
        ZStack {
            brandHeaderFill.ignoresSafeArea()

            // Radial light burst
            RadialGradient(
                colors: [.white.opacity(0.13), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()

            // Decorative concentric rings
            if !reduceMotion {
                ZStack {
                    splashRing(size: 500, opacity: 0.06)
                    splashRing(size: 360, opacity: 0.09)
                    splashRing(size: 230, opacity: 0.13)
                }
                .scaleEffect(splashRingScale)
                .opacity(splashRingOpacity)
            }

            VStack(spacing: 32) {
                KuidarLogoView(height: 260, maxWidth: 300, animate: true)
                    .scaleEffect(splashLogoVisible ? 1 : 0.78)
                    .opacity(splashLogoVisible ? 1 : 0)

                VStack(spacing: 10) {
                    Text("Cuidar es estar cerca")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .opacity(splashTaglineVisible ? 1 : 0)
                        .offset(y: splashTaglineVisible ? 0 : 14)

                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 28, height: 1.5)
                        .scaleEffect(x: splashTaglineVisible ? 1 : 0)
                        .opacity(splashTaglineVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.55), value: splashTaglineVisible)
                }
            }
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kuidar. Cuidar es estar cerca")
    }

    private func splashRing(size: CGFloat, opacity: CGFloat) -> some View {
        Circle()
            .strokeBorder(.white.opacity(opacity), lineWidth: 1)
            .frame(width: size, height: size)
    }

    // MARK: - Login screen

    private var loginScreen: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                formCard
                    .opacity(formVisible ? 1 : 0)
                    .offset(y: formVisible ? 0 : 24)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: .top)
        .background(Color.acoBg)
    }

    // MARK: - Header (cinematic)

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            brandHeaderFill

            // Decorative geometry (off-canvas circles)
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 300)
                .offset(x: 130, y: -80)
                .allowsHitTesting(false)

            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 180)
                .offset(x: 170, y: 30)
                .allowsHitTesting(false)

            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 100)
                .offset(x: -30, y: -20)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                Text("Kuidar")
                    .font(.system(size: 52, weight: .black, design: .default))
                    .tracking(-1.8)
                    .foregroundStyle(.white)

                Text(isRegistering
                     ? "Crea tu cuenta\npara empezar."
                     : "Qué bueno\nverte de nuevo.")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineSpacing(3)
                    .animation(.easeOut(duration: 0.2), value: isRegistering)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 80)
            .padding(.bottom, 48)
        }
        .clipShape(UnevenRoundedRectangle(
            bottomLeadingRadius: 36, bottomTrailingRadius: 36
        ))
        .shadow(color: brandHeaderFill.opacity(0.25), radius: 16, y: 8)
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            modeToggle

            if isRegistering {
                rolePicker
                labeledField("Nombre", placeholder: "Tu nombre completo", text: $name, field: .name)
            }

            labeledField("Correo", placeholder: "tu@correo.com", text: $email, field: .email, keyboard: .emailAddress)
            passwordField

            if isRegistering {
                roleSpecificFields
            }

            if let errorMessage {
                errorBanner(errorMessage)
            }

            submitButton

            Spacer().frame(height: 48)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }

    // MARK: - Mode toggle (premium pill)

    private var modeToggle: some View {
        HStack(spacing: 0) {
            toggleTab(label: "Entrar", selected: !isRegistering) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) { isRegistering = false }
            }
            toggleTab(label: "Crear cuenta", selected: isRegistering) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) { isRegistering = true }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.acoHair, lineWidth: 1)
        }
        .padding(.bottom, AcoSpacing.lg)
        .onChange(of: isRegistering) { _, _ in errorMessage = nil }
    }

    private func toggleTab(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.acoInk : Color.acoInk3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.09), radius: 6, y: 2)
                            .padding(3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(label)
    }

    // MARK: - Role picker

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            AcoTypography.fieldLabel("¿Quién eres?")

            HStack(spacing: 8) {
                ForEach(AppRole.allCases, id: \.self) { role in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selectedRole = role }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: role.symbolName)
                                .font(.system(size: 22))
                                .foregroundStyle(selectedRole == role ? role.tint : Color.acoInk3)
                                .accessibilityHidden(true)
                            Text(role.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedRole == role ? role.tint : Color.acoInk2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedRole == role ? role.soft : Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: AcoRadius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AcoRadius.md, style: .continuous)
                                .strokeBorder(
                                    selectedRole == role ? role.tint : Color.acoHair,
                                    lineWidth: selectedRole == role ? 2 : 0.5
                                )
                        }
                    }
                    .buttonStyle(AcoPressStyle())
                    .accessibilityLabel(role.title)
                    .accessibilityAddTraits(selectedRole == role ? .isSelected : [])
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Role-specific fields

    @ViewBuilder
    private var roleSpecificFields: some View {
        switch selectedRole {
        case .student:
            VStack(alignment: .leading, spacing: 10) {
                AcoTypography.fieldLabel("Universidad")

                Menu {
                    ForEach(universities) { uni in
                        Button(uni.name) { selectedUniversityId = uni.id }
                    }
                } label: {
                    HStack {
                        Text(universities.first(where: { $0.id == selectedUniversityId })?.name ?? "Elige tu universidad")
                            .font(.body)
                            .foregroundStyle(selectedUniversityId == nil ? Color.acoInk3 : Color.acoInk)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(Color.acoInk3)
                    }
                    .padding(.horizontal, AcoSpacing.md)
                    .padding(.vertical, 14)
                    .acoGroupedSurface()
                }
            }
            .padding(.bottom, 20)

            labeledField("Carrera (opcional)", placeholder: "Ej. Medicina", text: $career, field: .career)

        case .family:
            labeledField("Nombre de tu familia (opcional)", placeholder: "Ej. Familia Pérez", text: $familyName, field: .familyName)

        case .elderly:
            Text("Después de crear tu cuenta podrás unirte a tu familia con el código que te compartan.")
                .font(.caption)
                .foregroundStyle(Color.acoInk3)
                .padding(.bottom, 20)

        case .organizer:
            labeledField("Nombre de tu organización (opcional)", placeholder: "Ej. Centro Comunitario Del Valle", text: $familyName, field: .familyName)
        }
    }

    // MARK: - Generic fields

    private func labeledField(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        AcoFormField(label: label) {
            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(Color.acoInk)
                .textInputAutocapitalization(field == .email ? .never : .words)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(.horizontal, AcoSpacing.md)
                .padding(.vertical, 14)
                .acoGroupedSurface()
                .overlay {
                    if focusedField == field {
                        RoundedRectangle(cornerRadius: AcoRadius.md, style: .continuous)
                            .strokeBorder(Color.acoFamily, lineWidth: 2)
                    }
                }
                .focused($focusedField, equals: field)
        }
        .padding(.bottom, 20)
    }

    private var passwordField: some View {
        AcoFormField(label: "Contraseña") {
            HStack(spacing: 8) {
                Group {
                    if isPasswordVisible {
                        TextField("••••••••", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("••••••••", text: $password)
                    }
                }
                .font(.body)
                .foregroundStyle(Color.acoInk)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(.body)
                        .foregroundStyle(Color.acoInk3)
                        .frame(width: 44, height: 30)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPasswordVisible ? "Ocultar contraseña" : "Mostrar contraseña")
            }
            .padding(.horizontal, AcoSpacing.md)
            .padding(.vertical, 14)
            .acoGroupedSurface()
            .overlay {
                if focusedField == .password {
                    RoundedRectangle(cornerRadius: AcoRadius.md, style: .continuous)
                        .strokeBorder(Color.acoFamily, lineWidth: 2)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(Color.acoUrgent)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.acoUrgent.opacity(0.08))
            .clipShape(.rect(cornerRadius: 12))
            .padding(.bottom, 16)
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(isRegistering ? "Crear cuenta" : "Entrar").fontWeight(.bold)
                    Image(systemName: "arrow.right").fontWeight(.bold)
                }
            }
            .font(.body)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background {
                if canSubmit {
                    isRegistering ? selectedRole.tint : Color.acoFamily
                } else {
                    Color.acoInk3.opacity(0.35)
                }
            }
            .clipShape(.rect(cornerRadius: AcoRadius.md, style: .continuous))
            .shadow(
                color: (canSubmit ? brandHeaderFill : .clear).opacity(0.35),
                radius: 10,
                y: 4
            )
        }
        .buttonStyle(AcoPressStyle())
        .disabled(!canSubmit)
        .animation(.easeOut(duration: 0.2), value: canSubmit)
        .padding(.bottom, 24)
    }

    private func submit() {
        guard canSubmit else { return }
        focusedField = nil
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let response: LoginResponse
                if isRegistering {
                    response = try await APIClient.shared.register(
                        email: email,
                        password: password,
                        name: name,
                        role: selectedRole,
                        universityId: selectedRole == .student ? selectedUniversityId : nil,
                        career: career,
                        familyName: familyName
                    )
                } else {
                    response = try await APIClient.shared.login(email: email, password: password)
                }

                guard let role = response.user.roleEnum else {
                    errorMessage = "Rol de usuario no reconocido."
                    isLoading = false
                    return
                }
                savedFamilyCode = response.profile.familyCode ?? ""
                joinedFamily = response.profile.joinedFamily ?? (role != .elderly)
                savedElderlyProfileId = response.profile.elderlyProfileId ?? ""
                savedStudentId = response.profile.studentId ?? ""
                savedUserId = response.user.id
                savedToken = response.token
                savedName = response.user.name
                savedRoleRaw = role.rawValue
                KuidarHaptic.success()
            } catch let error as APIError {
                errorMessage = error.errorDescription
                KuidarHaptic.error()
            } catch let error as URLError {
                errorMessage = connectionMessage(for: error)
                KuidarHaptic.error()
            } catch {
                errorMessage = connectionMessage(for: URLError(.cannotConnectToHost))
                KuidarHaptic.error()
            }
            isLoading = false
        }
    }

    private func connectionMessage(for error: URLError) -> String {
        switch error.code {
        case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
            """
            No se pudo conectar al servidor (\(APIConfig.host):\(APIConfig.port)). \
            Confirma que `npm run dev` está activo y que el iPhone usa la misma WiFi.
            """
        default:
            error.localizedDescription
        }
    }
}

#Preview {
    LoginView()
}
