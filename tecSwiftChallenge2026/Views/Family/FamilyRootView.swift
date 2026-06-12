import SwiftUI

enum FamilyTab: Hashable {
    case publish, dashboard, messages, family, events
}

struct FamilyRootView: View {
    let onLogout: () -> Void
    @State private var selectedTab: FamilyTab = .dashboard
    @State private var showProfile = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Publicar", systemImage: "square.and.pencil", value: FamilyTab.publish) {
                NavigationStack {
                    FamilyPublishView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { NotificationBellButton(tint: .acoFamily) }
                            ToolbarItem(placement: .topBarLeading) { profileButton }
                        }
                }
            }
            Tab("Solicitudes", systemImage: "list.bullet", value: FamilyTab.dashboard) {
                NavigationStack {
                    FamilyDashboardView(onAddTapped: { selectedTab = .publish })
                        .navigationDestination(for: APIRequest.self) { request in
                            FamilyApplicantsView(request: request)
                        }
                        .navigationDestination(for: APIAssignment.self) { assignment in
                            FamilyLiveVisitView(assignment: assignment)
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { NotificationBellButton(tint: .acoFamily) }
                            ToolbarItem(placement: .topBarLeading) { profileButton }
                        }
                }
            }
            Tab("Mensajes", systemImage: "bubble.left.and.bubble.right", value: FamilyTab.messages) {
                NavigationStack {
                    FamilyConversationsView()
                        .navigationDestination(for: APIConversation.self) { conv in
                            ChatThreadView(
                                title: conv.studentName,
                                otherId: conv.studentId,
                                tint: .acoFamily,
                                isFamily: true
                            )
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { NotificationBellButton(tint: .acoFamily) }
                            ToolbarItem(placement: .topBarLeading) { profileButton }
                        }
                }
            }
            Tab("Eventos", systemImage: "person.3.fill", value: FamilyTab.events) {
                NavigationStack {
                    CommunityEventsView(isOrganizer: false)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { NotificationBellButton(tint: .acoFamily) }
                            ToolbarItem(placement: .topBarLeading) { profileButton }
                        }
                }
            }
            Tab("Mi familia", systemImage: "person.2.fill", value: FamilyTab.family) {
                NavigationStack {
                    FamilyManageView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { NotificationBellButton(tint: .acoFamily) }
                            ToolbarItem(placement: .topBarLeading) { profileButton }
                        }
                }
            }
        }
        .tint(.acoFamily)
        .sheet(isPresented: $showProfile) {
            FamilyProfileView(onLogout: onLogout)
        }
    }

    /// Perfil arriba a la izquierda (patrón común a todos los roles).
    private var profileButton: some View {
        Button {
            showProfile = true
        } label: {
            Image(systemName: "person.circle")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(Color.acoInk2)
        }
        .accessibilityLabel("Mi perfil")
    }
}

// MARK: - Perfil de la familia (datos, código de vinculación y logout)

struct FamilyProfileView: View {
    let onLogout: () -> Void

    @AppStorage("aco_userName") private var userName: String = ""
    @AppStorage("aco_familyCode") private var cachedFamilyCode: String = ""
    @Environment(\.dismiss) private var dismiss

    @State private var family: FamilyInfo?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.acoBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            AvatarView(name: userName, tint: .acoFamily, size: 76)
                            Text(userName)
                                .font(.title2).bold()
                                .foregroundStyle(Color.acoInk)
                            Text(family?.name ?? "Tu familia")
                                .font(.subheadline)
                                .foregroundStyle(Color.acoInk2)
                        }
                        .padding(.top, 10)

                        AcoCard {
                            VStack(spacing: 6) {
                                Text("Código para vincular adultos mayores")
                                    .font(.caption).foregroundStyle(Color.acoInk3)
                                Text(family?.familyCode ?? cachedFamilyCode)
                                    .font(.system(size: 34, weight: .black, design: .monospaced))
                                    .tracking(6)
                                    .foregroundStyle(Color.acoInk)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        if let elderly = family?.elderly, !elderly.isEmpty {
                            AcoCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Adultos mayores vinculados")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.acoInk)
                                    ForEach(elderly) { person in
                                        HStack(spacing: 10) {
                                            AvatarView(name: person.firstName, tint: .acoElderly, size: 34)
                                            Text(person.firstName)
                                                .font(.subheadline).foregroundStyle(Color.acoInk2)
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }

                        Button(role: .destructive) {
                            dismiss()
                            onLogout()
                        } label: {
                            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.body).fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .padding(.top, 8)
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
        .task {
            family = try? await APIClient.shared.fetchMyFamily()
        }
    }
}

#Preview {
    FamilyRootView(onLogout: {})
}
