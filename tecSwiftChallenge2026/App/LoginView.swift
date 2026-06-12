import SwiftUI

struct LoginView: View {
    @AppStorage("aco_authToken")  private var savedToken: String = ""
    @AppStorage("aco_userName")   private var savedName: String = ""
    @AppStorage("aco_userRole")   private var savedRoleRaw: String = ""
    @AppStorage("aco_familyCode") private var savedFamilyCode: String = ""
    @AppStorage("aco_joinedFamily") private var joinedFamily: Bool = false

    @State private var isRegistering = false

    // Campos comunes
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var selectedRole: AppRole = .family

    // Estudiante
    @State private var universities: [University] = []
    @State private var selectedUniversityId: String?
    @State private var career = ""

    // Familiar
    @State private var familyName = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case name, email, password, career, familyName }

    private var canSubmit: Bool {
        let base = !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
        guard isRegistering else { return base }
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let studentOk = selectedRole != .student || selectedUniversityId != nil
        return base && hasName && studentOk
    }

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    brandHeader

                    modeToggle

                    if isRegistering {
                        rolePicker
                        labeledField("NOMBRE", placeholder: "Tu nombre completo", text: $name, field: .name)
                    }

                    labeledField("CORREO", placeholder: "tu@correo.com", text: $email, field: .email, keyboard: .emailAddress)
                    passwordField

                    if isRegistering {
                        roleSpecificFields
                    }

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    submitButton

                    if !isRegistering {
                        demoHint
                    }

                    Spacer().frame(height: 48)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .task {
            if universities.isEmpty {
                universities = (try? await APIClient.shared.fetchUniversities()) ?? []
                if selectedUniversityId == nil { selectedUniversityId = universities.first?.id }
            }
        }
    }

    // MARK: - Header

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.acoFamily)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.acoFamily.opacity(0.35), radius: 12, x: 0, y: 6)
                Image(systemName: "heart.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 64)
            .padding(.bottom, 22)

            Text("Kuidar")
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(Color.acoInk)
                .tracking(-1.5)

            Text(isRegistering ? "Crea tu cuenta para empezar." : "Inicia sesión para continuar.")
                .font(.body)
                .foregroundStyle(Color.acoInk3)
                .padding(.top, 6)
        }
        .padding(.bottom, 28)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton("Entrar", active: !isRegistering) { isRegistering = false }
            modeButton("Crear cuenta", active: isRegistering) { isRegistering = true }
        }
        .background(Color(acoHex: "EFE9E1"))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.bottom, 24)
    }

    private func modeButton(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                action()
                errorMessage = nil
            }
        } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(active ? .bold : .regular)
                .foregroundStyle(active ? Color.acoInk : Color.acoInk3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(active ? Color.white : Color.clear)
                .clipShape(.rect(cornerRadius: 10))
                .padding(2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rol

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("¿QUIÉN ERES?")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.acoInk3)

            HStack(spacing: 8) {
                ForEach(AppRole.allCases, id: \.self) { role in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selectedRole = role }
                    } label: {
                        VStack(spacing: 5) {
                            Text(role.emoji).font(.system(size: 24)).accessibilityHidden(true)
                            Text(role.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selectedRole == role ? role.tint : Color.acoInk2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedRole == role ? role.soft : Color.white)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    selectedRole == role ? role.tint : Color(acoHex: "3C3228").opacity(0.08),
                                    lineWidth: selectedRole == role ? 2 : 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(role.title)
                    .accessibilityAddTraits(selectedRole == role ? .isSelected : [])
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Campos por rol

    @ViewBuilder
    private var roleSpecificFields: some View {
        switch selectedRole {
        case .student:
            VStack(alignment: .leading, spacing: 10) {
                Text("UNIVERSIDAD")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.acoInk3)

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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(acoHex: "3C3228").opacity(0.10), lineWidth: 1.5)
                    }
                }
            }
            .padding(.bottom, 20)

            labeledField("CARRERA (OPCIONAL)", placeholder: "Ej. Medicina", text: $career, field: .career)

        case .family:
            labeledField("NOMBRE DE TU FAMILIA (OPCIONAL)", placeholder: "Ej. Familia Pérez", text: $familyName, field: .familyName)

        case .elderly:
            Text("Después de crear tu cuenta podrás unirte a tu familia con el código que te compartan.")
                .font(.caption)
                .foregroundStyle(Color.acoInk3)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Campos genéricos

    private func labeledField(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.acoInk3)

            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(Color.acoInk)
                .textInputAutocapitalization(field == .email ? .never : .words)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(.rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            focusedField == field
                                ? Color.acoInk.opacity(0.35)
                                : Color(acoHex: "3C3228").opacity(0.10),
                            lineWidth: 1.5
                        )
                }
                .focused($focusedField, equals: field)
        }
        .padding(.bottom, 20)
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONTRASEÑA")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.acoInk3)

            SecureField("••••••••", text: $password)
                .font(.body)
                .foregroundStyle(Color.acoInk)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(.rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            focusedField == .password
                                ? Color.acoInk.opacity(0.35)
                                : Color(acoHex: "3C3228").opacity(0.10),
                            lineWidth: 1.5
                        )
                }
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }
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
            .background(canSubmit ? (isRegistering ? selectedRole.tint : Color.acoFamily) : Color.acoInk.opacity(0.18))
            .clipShape(.rect(cornerRadius: 16))
        }
        .disabled(!canSubmit)
        .animation(.easeOut(duration: 0.2), value: canSubmit)
        .padding(.bottom, 24)
    }

    private var demoHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CUENTAS DEMO")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.acoInk3)
            Text("familia@kuidar.app · becario@kuidar.app · adulto@kuidar.app")
                .font(.caption)
                .foregroundStyle(Color.acoInk2)
            Text("Contraseña: demo123")
                .font(.caption)
                .foregroundStyle(Color.acoInk3)
        }
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
                savedToken = response.token
                savedName = response.user.name
                savedRoleRaw = role.rawValue
            } catch let error as APIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = APIError.serverUnreachable.errorDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    LoginView()
}
