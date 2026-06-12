import SwiftUI
import UIKit

struct FamilyManageView: View {
    @AppStorage("aco_familyCode") private var cachedFamilyCode: String = ""
    @AppStorage("aco_userName") private var userName: String = ""

    @State private var family: FamilyInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didCopy = false
    @State private var editingElderly: ElderlySummary?

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
        .sheet(item: $editingElderly) { person in
            ElderlyEditSheet(person: person) {
                await load()
            }
        }
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
            SectionLabel(text: "Cómo funciona")

            instructionRow(number: "1", text: "Comparte el código con tu familiar adulto mayor.")
            instructionRow(number: "2", text: "En su app, entra a **Mi familia** y escribe el código.")
            instructionRow(number: "3", text: "Ya podrás publicar solicitudes para esa persona.")
        }
    }

    private var elderlySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Adultos mayores vinculados")

            if let elderly = family?.elderly, !elderly.isEmpty {
                ForEach(elderly) { person in
                    elderlyCard(person)
                }
            } else {
                AcoCard {
                    VStack(spacing: 10) {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.acoElderly)
                            .accessibilityHidden(true)
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
        Button {
            editingElderly = person
        } label: {
            AcoCard(padding: 14) {
                HStack(spacing: 14) {
                    AvatarView(name: person.firstName, tint: .acoElderly, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(person.firstName)
                                .font(.headline).foregroundStyle(Color.acoInk)
                            if let age = person.age {
                                Text("\(age) años")
                                    .font(.caption).foregroundStyle(Color.acoInk3)
                            }
                        }
                        Text(person.neighborhood)
                            .font(.subheadline).foregroundStyle(Color.acoInk2)
                        Text(person.address)
                            .font(.caption).foregroundStyle(Color.acoInk3)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.acoInk3)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Editar perfil de \(person.firstName)")
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

// MARK: - 3.12/3.16: Edición de perfil del adulto mayor + control parental

struct ElderlyEditSheet: View {
    let person: ElderlySummary
    /// false cuando edita el propio adulto mayor: oculta y no envía los flags de control parental.
    var isFamilyEditor: Bool = true
    var onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var address: String
    @State private var neighborhood: String
    @State private var ageText: String
    @State private var tags: [String]
    @State private var newTag = ""
    @State private var allowSocial: Bool
    @State private var allowSelfEdit: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(person: ElderlySummary, isFamilyEditor: Bool = true, onSaved: @escaping () async -> Void) {
        self.person = person
        self.isFamilyEditor = isFamilyEditor
        self.onSaved = onSaved
        _address = State(initialValue: person.address)
        _neighborhood = State(initialValue: person.neighborhood)
        _ageText = State(initialValue: person.age.map(String.init) ?? "")
        _tags = State(initialValue: person.tagList)
        _allowSocial = State(initialValue: person.socialAllowed)
        _allowSelfEdit = State(initialValue: person.selfEditAllowed)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos de \(person.firstName)") {
                    TextField("Dirección", text: $address)
                    TextField("Colonia", text: $neighborhood)
                    TextField("Edad", text: $ageText)
                        .keyboardType(.numberPad)
                }

                Section {
                    ForEach(tags, id: \.self) { tag in
                        Label(tag, systemImage: "tag.fill")
                            .foregroundStyle(Color.acoInk2)
                    }
                    .onDelete { tags.remove(atOffsets: $0) }

                    HStack {
                        TextField("Agregar gusto o interés", text: $newTag)
                            .onSubmit(addTag)
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.acoFamily)
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityLabel("Agregar interés")
                    }
                } header: {
                    Text("Gustos e intereses")
                } footer: {
                    Text("Estos datos ayudan a recomendarle eventos y compañía afín.")
                }

                if isFamilyEditor {
                    Section {
                        Toggle("Permitir conocer gente y chatear", isOn: $allowSocial)
                        Toggle("Puede editar su propio perfil", isOn: $allowSelfEdit)
                    } header: {
                        Text("Control parental")
                    } footer: {
                        Text("Si desactivas la primera opción, \(person.firstName) no aparecerá en recomendaciones de conexión ni podrá iniciar o recibir chats nuevos.")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Color.acoUrgent)
                    }
                }
            }
            .tint(Color.acoFamily)
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.acoInk3)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Guardar").bold()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        withAnimation(.easeOut(duration: 0.15)) { tags.append(tag) }
        newTag = ""
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.updateElderly(
                id: person.id,
                address: address.trimmingCharacters(in: .whitespaces),
                neighborhood: neighborhood.trimmingCharacters(in: .whitespaces),
                age: Int(ageText.trimmingCharacters(in: .whitespaces)),
                tags: tags,
                allowSocialConnections: isFamilyEditor ? allowSocial : nil,
                allowSelfProfileEdit: isFamilyEditor ? allowSelfEdit : nil
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack { FamilyManageView() }
}
